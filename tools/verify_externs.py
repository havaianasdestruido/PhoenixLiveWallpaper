#!/usr/bin/env python3
"""Verify the hand written Android bindings against real AOSP sources.

source/hxandroid/*.hx declares the Android API surface this wallpaper uses, and
android/app/src/main/java/dev/phoenix/wallpaper/PhoenixWallpaperService.java
overrides framework methods. Both are written by hand (no -java-lib android.jar,
no extern generator), so a typo or a wrong arity would otherwise only surface as a
javac failure deep inside a Gradle build. This script catches it up front:

  * resolves every `@:native("android.x.Y")` - including nested types such as
    android.widget.CompoundButton.OnCheckedChangeListener - to a file in
    aosp-mirror/platform_frameworks_base, fetched through the GitHub API and cached
    in .cache/aosp/
  * walks the superclass chain, so inherited members (SeekBar.setProgress lives in
    AbsProgressBar, TextView.setText in TextView, View.setOnClickListener in View)
    are found
  * checks every declared method exists with a matching parameter count and every
    declared static field / enum constant exists
  * checks each @Override in the Java shim exists in WallpaperService.Engine /
    SurfaceHolder.Callback with the same arity

Needs `gh` (or curl) plus network. Run:  python3 tools/verify_externs.py
"""
import base64
import glob
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source", "hxandroid")
JAVA_SHIM = os.path.join(ROOT, "android", "app", "src", "main", "java", "dev", "phoenix",
                         "wallpaper", "PhoenixWallpaperService.java")
CACHE = os.path.join(ROOT, ".cache", "aosp")
REPO = "aosp-mirror/platform_frameworks_base"

MODULE_DIRS = ["core/java", "graphics/java", "opengl/java", "media/java"]

# Types that do not live in frameworks/base at all.
SKIP = {"java.lang.Runnable"}

# Some text pipelines drop the "d" from "...ChangedListener" identifiers. Compare
# identifiers with that spelling normalised so the check stays meaningful.
_D = chr(100)


def norm(name):
    """Exact names: Android spells the compound family d-FULL and the SeekBar
    family d-LESS, so there is nothing to normalise on the extern side."""
    return name


cache = {}


def api(endpoint, jq=None):
    if shutil.which("gh"):
        cmd = ["gh", "api", endpoint] + (["--jq", jq] if jq else [])
    else:
        cmd = ["curl", "-sfL", "-H", "Accept: application/vnd.github+json",
               "https://api.github.com/" + endpoint]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    return proc.stdout


def fetch(rel_path):
    """One AOSP source file, cached. Falls back to the blob API above 1 MB."""
    if rel_path in cache:
        return cache[rel_path]
    dest = os.path.join(CACHE, rel_path.replace("/", "__"))
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        cache[rel_path] = open(dest, encoding="utf-8", errors="replace").read()
        return cache[rel_path]

    meta = api("repos/%s/contents/%s" % (REPO, rel_path))
    if meta is None:
        cache[rel_path] = None
        return None
    info = json.loads(meta)
    content = info.get("content") or ""
    if not content.strip():
        # >1 MB: the contents API omits the body, the blob API does not
        blob = api("repos/%s/git/blobs/%s" % (REPO, info["sha"]), ".content")
        if blob is None:
            cache[rel_path] = None
            return None
        content = blob
    data = base64.b64decode(content.replace("\n", ""))
    os.makedirs(CACHE, exist_ok=True)
    with open(dest, "wb") as fh:
        fh.write(data)
    text = data.decode("utf-8", "replace")
    cache[rel_path] = text
    return text


def split_native(native):
    """android.widget.SeekBar.OnSeekBarChangeListener -> (pkg/path, class, nested)."""
    parts = native.split(".")
    for i, part in enumerate(parts):
        if part[:1].isupper():
            pkg = "/".join(parts[:i])
            return pkg, part, parts[i + 1:]
    return None, None, []


def fetch_class(pkg_path, cls):
    for module in MODULE_DIRS:
        text = fetch("%s/%s/%s.java" % (module, pkg_path, cls))
        if text:
            return "%s/%s/%s.java" % (module, pkg_path, cls), text
    return None, None


def class_chain(pkg_path, cls):
    """[(file, source)] for a class and its superclasses inside the same package."""
    chain = []
    seen = set()
    current = cls
    while current and current not in seen and current not in ("Object",):
        seen.add(current)
        rel, text = fetch_class(pkg_path, current)
        if not text:
            break
        chain.append((rel, text))
        m = re.search(r"\bclass\s+%s\s+extends\s+([\w.]+)" % re.escape(current), text)
        if not m:
            break
        parent = m.group(1)
        if "." in parent:            # fully qualified: try its own package
            pp, pc, _ = split_native(parent)
            if pp:
                chain.extend(class_chain(pp, pc))
                break
        current = parent
    return chain


def arities(source, name):
    """Parameter counts of every `name(...)` in the source."""
    out = set()
    for m in re.finditer(r"\b%s\s*\(" % re.escape(name), source):
        i = m.end() - 1
        depth, j = 0, i
        while j < len(source):
            if source[j] == "(":
                depth += 1
            elif source[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if depth:
            continue
        params = re.sub(r"@\w+(\([^)]*\))?", "", source[i + 1:j])
        depth, n = 0, (0 if not params.strip() else 1)
        for c in params:
            if c in "(<[{":
                depth += 1
            elif c in ")>]}":
                depth -= 1
            elif c == "," and depth == 0:
                n += 1
        out.add(n)
    return out


def arity_of(params):
    params = params.strip()
    if not params:
        return 0
    depth, n = 0, 1
    for c in params:
        if c in "(<[{":
            depth += 1
        elif c in ")>]}":
            depth -= 1
        elif c == "," and depth == 0:
            n += 1
    return n


def norm_source(text):
    """Identity. The compound interfaces are d-LESS before Listener
    (OnCheckedChange + Listener) while the callback method keeps its d
    (onCheckedChanged); the SeekBar family is d-LESS too. Nothing to
    normalise - an earlier "repair" here corrupted the AOSP side to hide a
    fictional extra d in the externs."""
    return text


errors = []


def check_native(native, methods, fields, where):
    if native in SKIP:
        print("  %-56s skipped (not in frameworks/base)" % native)
        return 0
    pkg_path, cls, nested = split_native(native)
    if not pkg_path:
        errors.append("%s: cannot parse @:native" % native)
        return 0
    chain = class_chain(pkg_path, cls)
    if not chain:
        errors.append("%s: no AOSP source found for %s" % (native, cls))
        return 0

    # for nested types, narrow the search to the nested block when we can find it
    scope = [(rel, norm_source(text)) for rel, text in chain]
    if nested:
        joined = ".".join(nested)
        narrowed = [(rel, text) for rel, text in scope
                    if re.search(r"\b(interface|class|enum)\s+%s\b" % re.escape(nested[0]), text)]
        if narrowed:
            scope = narrowed
        else:
            errors.append("%s: nested type %s not found in %s" % (native, joined, chain[0][0]))
            return 0

    checked = 0
    for name, params in methods:
        if name == "new":
            checked += 1
            continue
        want = arity_of(params)
        found = set()
        for _, text in scope:
            found |= arities(text, norm(name))
        if not found:
            errors.append("%s: %s.%s() not found in AOSP" % (where, native, name))
        elif want not in found:
            errors.append("%s: %s.%s() takes %d args in the binding, AOSP has %s"
                          % (where, native, name, want, sorted(found)))
        checked += 1

    for name in fields:
        if not any(re.search(r"\b%s\b" % re.escape(norm(name)), text) for _, text in scope):
            errors.append("%s: %s.%s is not an AOSP field" % (where, native, name))
        checked += 1

    print("  %-56s %-24s %d members" % (native, os.path.basename(chain[0][0]), checked))
    return checked


def haxe_members(path):
    code = open(path, encoding="utf-8").read()
    native = re.search(r'@:native\("([^"]+)"\)', code)
    if not native:
        return None, [], []
    methods = re.findall(r"^\s*(?:public\s+)?(?:static\s+)?function\s+(\w+)\s*\(([^)]*)\)", code, re.M)
    fields = re.findall(r"^\s*(?:public\s+)?static\s+var\s+(\w+)\s*:", code, re.M)
    fields += re.findall(r"^\s*(?:public\s+)?var\s+(\w+)\s*:", code, re.M)
    return native.group(1), methods, fields


def check_haxe_externs():
    total = 0
    for path in sorted(glob.glob(os.path.join(SRC, "**", "*.hx"), recursive=True)):
        native, methods, fields = haxe_members(path)
        if native is None:
            continue
        total += check_native(native, methods, fields, os.path.relpath(path, ROOT))
    return total


def check_java_shim():
    """Every @Override in the shim must exist in the framework with that arity."""
    code = open(JAVA_SHIM, encoding="utf-8").read()
    total = 0
    engine_chain = class_chain("android/service/wallpaper", "WallpaperService")
    holder_chain = class_chain("android/view", "SurfaceHolder")
    scope = [(rel, norm_source(text)) for rel, text in engine_chain + holder_chain]
    for m in re.finditer(r"@Override\s+public\s+[\w.<>\[\]]+\s+(\w+)\s*\(([^)]*)\)", code):
        name, params = m.group(1), m.group(2)
        want = arity_of(params)
        found = set()
        for _, text in scope:
            found |= arities(text, norm(name))
        if not found:
            errors.append("Java shim: @Override %s() is not a framework method" % name)
        elif want not in found:
            errors.append("Java shim: @Override %s() takes %d args, framework has %s"
                          % (name, want, sorted(found)))
        total += 1
        print("  shim @Override %-22s %d args %s" % (name, want, "ok" if want in found else "MISMATCH"))
    return total


def main():
    if not shutil.which("gh") and not shutil.which("curl"):
        print("needs gh or curl on PATH")
        return 2
    print("Haxe externs vs AOSP:")
    total = check_haxe_externs()
    print("\nJava shim overrides vs AOSP:")
    total += check_java_shim()
    print("\nchecked %d members" % total)
    if errors:
        for e in errors:
            print("FAIL: %s" % e)
        print("\n%d problem(s)" % len(errors))
        return 1
    print("ok: every binding matches AOSP")
    return 0


if __name__ == "__main__":
    sys.exit(main())
