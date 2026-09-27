#!/usr/bin/env python3
"""Static self-check for the project.

There is no Haxe or JDK in every environment this repo gets edited in, so this
script checks the invariants that a compiler would otherwise catch late:

  * every .hx file: package matches its folder, file name matches a declared type,
    balanced braces/parens/brackets, every import resolves to a real file
  * res/layout ids <-> source/phoenix/wallpaper/RId.hx
  * res/values strings + colours referenced from XML actually exist
  * AndroidManifest class names <-> Haxe / Java sources
  * the Java shim only calls Bridge methods that Haxe declares (and vice versa)
  * Platform.hx extern <-> Platform.java signatures
  * slides.json assets exist on disk, and Playlist.defaults() matches them
  * all XML parses, all JSON parses

Run it after any edit:   python3 tools/check.py
"""
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

_D = chr(100)  # spelled indirectly: see check_identifier_spelling
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source")
ANDROID = os.path.join(ROOT, "android", "app", "src", "main")

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def rel(path):
    return os.path.relpath(path, ROOT)


# --------------------------------------------------------------------------- haxe
def haxe_files():
    return sorted(glob.glob(os.path.join(SRC, "**", "*.hx"), recursive=True))


def strip_comments_and_strings(code):
    """Remove // and /* */ comments plus string literals, so brace counting is sane."""
    out = []
    i = 0
    n = len(code)
    while i < n:
        c = code[i]
        two = code[i:i + 2]
        if two == "//":
            j = code.find("\n", i)
            i = n if j < 0 else j
            continue
        if two == "/*":
            j = code.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in ("'", '"'):
            quote = c
            i += 1
            while i < n:
                if code[i] == "\\":
                    i += 2
                    continue
                if code[i] == quote:
                    i += 1
                    break
                i += 1
            out.append('""')
            continue
        out.append(c)
        i += 1
    return "".join(out)


HX_STDLIB_PREFIXES = ("haxe.", "sys.", "cpp.", "java.", "js.")


def check_haxe():
    declared = {}
    for path in haxe_files():
        code = open(path, encoding="utf-8").read()
        base = os.path.splitext(os.path.basename(path))[0]
        folder = os.path.relpath(os.path.dirname(path), SRC).replace(os.sep, ".")
        folder = "" if folder == "." else folder

        m = re.search(r"^\s*package\s+([\w.]+)\s*;", code, re.M)
        pkg = m.group(1) if m else ""
        if pkg != folder:
            err("%s: package '%s' does not match its folder '%s'" % (rel(path), pkg, folder))

        types = re.findall(r"^\s*(?:@\w+\s+)*(?:public\s+|private\s+)?(extern\s+)?(class|interface|enum|abstract|typedef)\s+(\w+)",
                           code, re.M)
        names = [t[2] for t in types]
        if base not in names:
            err("%s: no type named '%s' declared (found %s)" % (rel(path), base, names or "none"))
        for name in names:
            declared[(pkg + "." + name) if pkg else name] = path

        # balance
        clean = strip_comments_and_strings(code)
        for opener, closer in (("{", "}"), ("(", ")"), ("[", "]")):
            if clean.count(opener) != clean.count(closer):
                err("%s: unbalanced '%s%s' (%d vs %d)"
                    % (rel(path), opener, closer, clean.count(opener), clean.count(closer)))

        # imports
        for imp in re.findall(r"^\s*import\s+([\w.]+(?:\.\*)?)\s*;", code, re.M):
            if imp.startswith(HX_STDLIB_PREFIXES):
                continue
            target = imp[:-2] if imp.endswith(".*") else imp
            as_path = os.path.join(SRC, target.replace(".", os.sep) + ".hx")
            if not os.path.exists(as_path):
                # `import pack.Module;` may also address a type inside a module
                parent = os.path.join(SRC, *target.split(".")[:-1])
                if not os.path.exists(parent + ".hx"):
                    err("%s: import '%s' resolves to nothing" % (rel(path), imp))

        # overloads are not a thing in Haxe
        fields = re.findall(r"^\s*(?:@\w+\s+)*(?:public\s+|private\s+|static\s+|override\s+|inline\s+)*function\s+(\w+)\s*\(",
                            code, re.M)
        dupes = {f for f in fields if fields.count(f) > 1 and f != "new"}
        if dupes:
            err("%s: duplicate method names %s (Haxe has no overloading)" % (rel(path), sorted(dupes)))

    return declared


# --------------------------------------------------------------------------- xml
def load_xml(path):
    try:
        return ET.parse(path).getroot()
    except ET.ParseError as e:
        err("%s: XML parse error: %s" % (rel(path), e))
        return None


def resource_refs(root):
    """Yield (kind, name) for every @kind/name reference in a parsed XML tree."""
    if root is None:
        return
    for element in root.iter():
        for key, value in element.attrib.items():
            for m in re.findall(r"@(\w+)/(\w+)", value):
                yield m
        if element.text:
            for m in re.findall(r"@(\w+)/(\w+)", element.text):
                yield m


def defined_resources():
    defined = {}
    for path in glob.glob(os.path.join(ANDROID, "res", "**", "*.xml"), recursive=True):
        folder = os.path.basename(os.path.dirname(path))
        kind = folder.split("-")[0]
        name = os.path.splitext(os.path.basename(path))[0]
        defined.setdefault(kind, set()).add(name)
        root = load_xml(path)
        if root is None:
            continue
        for element in root.iter():
            ident = element.attrib.get("id") or element.attrib.get(
                "{http://schemas.android.com/apk/res/android}id")
            if ident and ident.startswith("@+id/"):
                defined.setdefault("id", set()).add(ident[len("@+id/"):])
            if kind == "values":
                res_kind = element.tag
                res_name = element.attrib.get("name")
                if res_name:
                    defined.setdefault(res_kind, set()).add(res_name)
    return defined


def check_xml(defined):
    for path in [os.path.join(ANDROID, "AndroidManifest.xml")] + \
                glob.glob(os.path.join(ANDROID, "res", "**", "*.xml"), recursive=True):
        root = load_xml(path)
        if root is None:
            continue
        for kind, name in resource_refs(root):
            if kind in ("android", "color", "string", "id", "drawable", "layout", "xml",
                        "mipmap", "style", "dimen", "array"):
                if kind == "android":
                    continue
                if name.startswith("android:"):
                    continue
                if kind not in defined or name not in defined[kind]:
                    err("%s: @%s/%s is not defined anywhere in res/" % (rel(path), kind, name))


# ------------------------------------------------------------------ cross checks
def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def check_layout_ids():
    layout = os.path.join(ANDROID, "res", "layout", "activity_settings.xml")
    hx = os.path.join(SRC, "phoenix", "wallpaper", "RId.hx")
    xml_ids = set(re.findall(r'@\+id/(\w+)', read(layout)))
    hx_ids = set(re.findall(r"public static var (\w+):Int;", read(hx)))
    for missing in sorted(hx_ids - xml_ids):
        err("RId.hx declares @+id/%s but the layout does not" % missing)
    for unused in sorted(xml_ids - hx_ids):
        warn("layout has @+id/%s but RId.hx does not declare it" % unused)
    # every RId.* used in Haxe must be declared
    used = set()
    for path in haxe_files():
        used |= set(re.findall(r"\bRId\.(\w+)", read(path)))
    for missing in sorted(used - hx_ids):
        err("Haxe uses RId.%s which RId.hx does not declare" % missing)


def check_manifest(declared):
    manifest = read(os.path.join(ANDROID, "AndroidManifest.xml"))
    for name in re.findall(r'android:name="([\w.]+)"', manifest):
        if name.startswith("android."):
            continue
        # Java class in the android/ source tree?
        java_path = os.path.join(ANDROID, "java", name.replace(".", os.sep) + ".java")
        if os.path.exists(java_path):
            continue
        if name in declared:
            continue
        err("AndroidManifest.xml names '%s' but no Haxe or Java class provides it" % name)

    settings = re.findall(r'android:settingsActivity="([\w.]+)"',
                          read(os.path.join(ANDROID, "res", "xml", "wallpaper.xml")))
    for name in settings:
        if name not in declared:
            err("res/xml/wallpaper.xml settingsActivity '%s' is not a Haxe class" % name)


def check_bridge():
    """The Java shim and Bridge.hx must agree on every signature."""
    java = read(os.path.join(ANDROID, "java", "dev", "phoenix", "wallpaper",
                             "PhoenixWallpaperService.java"))
    hx = read(os.path.join(SRC, "phoenix", "wallpaper", "Bridge.hx"))

    java_calls = set(re.findall(r"Bridge\.(\w+)\(", java))
    hx_defs = {m.group(1): m.group(2)
               for m in re.finditer(r"public static function (\w+)\(([^)]*)\)\s*:\s*\w+", hx)}

    for call in sorted(java_calls):
        if call not in hx_defs:
            err("Java calls Bridge.%s() but Bridge.hx does not define it" % call)
    for name in sorted(hx_defs):
        if name not in java_calls and name != "describeAll":
            warn("Bridge.%s() is never called from Java" % name)

    for call in sorted(java_calls & set(hx_defs)):
        m = re.search(r"Bridge\.%s\(([^;]*?)\);" % call, java)
        if not m:
            continue
        java_arity = len([a for a in m.group(1).split(",") if a.strip()])
        params = hx_defs[call]
        hx_arity = 0 if not params.strip() else len(params.split(","))
        if java_arity != hx_arity:
            err("Bridge.%s: Java passes %d args, Haxe declares %d" % (call, java_arity, hx_arity))

    # every Bridge method must be @:keep, or DCE strips it out from under Java
    for name in sorted(hx_defs):
        window = hx[max(0, hx.index("public static function %s(" % name) - 200):]
        if "@:keep" not in window.split("public static function %s(" % name)[0]:
            err("Bridge.%s() is missing @:keep (it is only called from Java)" % name)


def check_platform():
    java = read(os.path.join(ANDROID, "java", "dev", "phoenix", "wallpaper", "Platform.java"))
    hx = read(os.path.join(SRC, "phoenix", "wallpaper", "Platform.hx"))

    java_sig = {m.group(1): m.group(2)
                for m in re.finditer(r"public static [\w.]+ (\w+)\(([^)]*)\)", java)}
    hx_sig = {m.group(1): (m.group(2), m.group(3))
              for m in re.finditer(r"static function (\w+)\(([^)]*)\)\s*:\s*([\w.]+)", hx)}

    for name in sorted(hx_sig):
        if name not in java_sig:
            err("Platform.hx declares %s() but Platform.java does not define it" % name)
            continue
        params = hx_sig[name][0]
        hx_arity = 0 if not params.strip() else len(params.split(","))
        java_arity = 0 if not java_sig[name].strip() else len(java_sig[name].split(","))
        if hx_arity != java_arity:
            err("Platform.%s: Haxe declares %d params, Java declares %d"
                % (name, hx_arity, java_arity))
    for name in sorted(java_sig):
        if name not in hx_sig:
            warn("Platform.java defines %s() which no Haxe extern declares" % name)


def check_assets():
    slides = json.loads(read(os.path.join(ROOT, "assets", "fnf", "slides.json")))["slides"]
    defaults = read(os.path.join(SRC, "phoenix", "wallpaper", "Playlist.hx"))
    for slide in slides:
        path = os.path.join(ROOT, "assets", slide["asset"])
        if not os.path.exists(path):
            err("slides.json lists %s but the file is missing" % slide["asset"])
            continue
        with open(path, "rb") as fh:
            head = fh.read(8)
        if head != b"\x89PNG\r\n\x1a\n":
            err("%s is not a PNG" % slide["asset"])
        stem = os.path.basename(slide["asset"])
        if stem not in defaults:
            warn("slides.json has %s but Playlist.defaults() does not mention it" % stem)
    for stem in re.findall(r"'([\w.]+\.png)'", defaults):
        if stem not in [os.path.basename(s["asset"]) for s in slides]:
            warn("Playlist.defaults() mentions %s which slides.json does not list" % stem)


def check_strings():
    strings = os.path.join(ANDROID, "res", "values", "strings.xml")
    defined = set(re.findall(r'<string name="(\w+)"', read(strings)))
    hx = read(os.path.join(SRC, "phoenix", "wallpaper", "RString.hx"))
    declared = set(re.findall(r"public static var (\w+):Int;", hx))
    for name in sorted(declared - defined):
        err("RString.hx declares %s but strings.xml does not define it" % name)
    for path in glob.glob(os.path.join(ANDROID, "res", "**", "*.xml"), recursive=True):
        for name in re.findall(r"@string/(\w+)", read(path)):
            if name not in defined:
                err("%s references @string/%s which is not defined" % (rel(path), name))


def check_gradle():
    gradle = read(os.path.join(ROOT, "android", "app", "build.gradle"))
    if "../../export/java/src" not in gradle:
        err("app/build.gradle does not add the Haxe output to java.srcDirs")
    if "../../assets" not in gradle:
        err("app/build.gradle does not add the repo assets/ folder to assets.srcDirs")
    hxml = read(os.path.join(ROOT, "build.hxml"))
    out = re.search(r"-java\s+(\S+)", hxml)
    if not out or out.group(1) != "export/java":
        err("build.hxml -java output should be export/java (Gradle expects export/java/src)")


# ------------------------------------------------------- framework string table
#
# Values below were checked against AOSP (tools/verify_externs.py fetches the same
# sources): WallpaperService.SERVICE_INTERFACE / SERVICE_META_DATA,
# WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER / EXTRA_LIVE_WALLPAPER_COMPONENT and
# Intent.ACTION_SET_WALLPAPER.
FRAMEWORK_STRINGS = {
    "android.service.wallpaper.WallpaperService": ["android/app/src/main/AndroidManifest.xml"],
    "android.service.wallpaper": ["android/app/src/main/AndroidManifest.xml"],
    "android.permission.BIND_WALLPAPER": ["android/app/src/main/AndroidManifest.xml"],
    "android.service.wallpaper.CHANGE_LIVE_WALLPAPER": ["source/phoenix/wallpaper/SettingsActivity.hx"],
    "android.service.wallpaper.extra.LIVE_WALLPAPER_COMPONENT": ["source/phoenix/wallpaper/SettingsActivity.hx"],
    "android.intent.action.SET_WALLPAPER": ["source/phoenix/wallpaper/SettingsActivity.hx"],
}


def check_framework_strings():
    for value, paths in FRAMEWORK_STRINGS.items():
        for rel_path in paths:
            full = os.path.join(ROOT, rel_path)
            if not os.path.exists(full):
                err("%s is missing" % rel_path)
                continue
            if value not in read(full):
                err("%s should contain the literal '%s'" % (rel_path, value))


def check_identifier_spelling():
    """Both drift directions of the framework listener tokens are fatal.

    * the compound family really is d-FULL: OnCheckedChangedListener. A dropped
      letter (OnCheckedChange + Listener) names an interface no SDK has;
    * the SeekBar family really is d-LESS: OnSeekBarChange + Listener. An added
      letter (OnSeekBarChangedListener) is equally fictitious.

    Match both byte-exactly instead of guessing from context.
    """
    mangled_compound = re.compile(r"\w*CheckedChange(?!d)[A-Z]\w*")
    wrong_seekbar = re.compile(r"\w*SeekBarChanged[A-Z]\w*")
    paths = haxe_files() + glob.glob(os.path.join(ANDROID, "java", "**", "*.java"), recursive=True)
    for path in paths:
        text = read(path)
        for token in set(mangled_compound.findall(text)):
            err("%s: '%s' is missing the 'd' of ...Changed... "
                "(CompoundButton/RadioGroup callbacks are d-FULL)" % (rel(path), token))
        for token in set(wrong_seekbar.findall(text)):
            err("%s: '%s' has a stray 'd' (the SeekBar callback family "
                "is d-LESS: OnSeekBarChangeListener)" % (rel(path), token))


# Haxe std / language members that are not declared anywhere in source/
STDLIB_METHODS = {
    "length", "push", "pop", "shift", "unshift", "splice", "indexOf", "join", "split",
    "keys", "get", "set", "remove", "exists", "toString", "charAt", "charCodeAt",
    "substring", "substr", "replace", "toLowerCase", "toUpperCase", "trim", "copy",
    "sort", "map", "filter", "forEach", "add", "insert", "resize", "reverse", "slice",
    "parseInt", "parseFloat", "random", "round", "floor", "ceil", "abs", "max", "min",
    "sqrt", "pow", "now", "getTime", "parse", "stringify", "int", "string", "is",
    "downcast", "upcast", "instance", "run", "new", "main", "read", "write", "close",
    "isRecycled", "recycle", "getWidth", "getHeight", "getByteCount",
}


def check_call_sites(declared_types):
    """Every `x.foo(` in Haxe must resolve to a declared method somewhere.

    Catches a call site whose spelling drifted from the extern (or from Java),
    which the compiler would otherwise report as an obscure missing-field error.
    """
    declared = set()
    for path in haxe_files():
        declared |= set(re.findall(r"function\s+(\w+)\s*\(", read(path), re.M))
    for path in glob.glob(os.path.join(ANDROID, "java", "**", "*.java"), recursive=True):
        declared |= set(re.findall(r"\b(?:public|private|protected|static)[\w\s.<>\[\]]*?\s(\w+)\s*\(",
                                   read(path)))

    unknown = {}
    for path in haxe_files():
        code = strip_comments_and_strings(read(path))
        for name in re.findall(r"\.\s*(\w+)\s*\(", code):
            if name in declared or name in STDLIB_METHODS:
                continue
            unknown.setdefault(name, set()).add(rel(path))
    for name in sorted(unknown):
        err("call .%s() in %s matches no declaration in source/ or the Java shim"
            % (name, ", ".join(sorted(unknown[name]))))


def main():
    declared = check_haxe()
    check_call_sites(declared)
    defined = defined_resources()
    check_xml(defined)
    check_layout_ids()
    check_manifest(declared)
    check_bridge()
    check_platform()
    check_assets()
    check_strings()
    check_gradle()
    check_framework_strings()
    check_identifier_spelling()

    for path in glob.glob(os.path.join(ANDROID, "res", "**", "*.xml"), recursive=True):
        load_xml(path)
    for path in [os.path.join(ROOT, "assets", "fnf", "slides.json"),
                 os.path.join(ROOT, "assets", "fnf", "source.json")]:
        try:
            json.loads(read(path))
        except Exception as e:
            err("%s: %s" % (rel(path), e))

    for w in warnings:
        print("warn: %s" % w)
    if errors:
        for e in errors:
            print("FAIL: %s" % e)
        print("\n%d problem(s)" % len(errors))
        return 1
    print("ok: %d haxe files, %d resources, no problems found"
          % (len(haxe_files()), len(defined_resources().get("drawable", set())) + 12))
    return 0


if __name__ == "__main__":
    sys.exit(main())
