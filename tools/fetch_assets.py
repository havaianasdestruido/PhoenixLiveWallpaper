#!/usr/bin/env python3
"""Pull the FNF Phoenix Engine menu background art into ./assets/fnf.

The images live in the engine fork at `assets/preload/images/` and are mirrored
here as `assets/fnf/preload/images/` so the APK keeps the exact same relative
paths as the game (`fnf/preload/images/menuBG.png`).

We go through the GitHub REST API (git tree + git blobs) instead of
raw.githubusercontent.com because the API also lets us pin the exact commit the
art came from. Needs either an authenticated `gh` CLI or a plain `curl`.

  python3 tools/fetch_assets.py            # latest main
  PHOENIX_REF=v1.2.3 python3 tools/fetch_assets.py
"""
import base64
import json
import os
import shutil
import subprocess
import sys

REPO = os.environ.get("PHOENIX_REPO", "havaianasdestruido/FNF-Phoenix-Engine")
REF = os.environ.get("PHOENIX_REF", "main")

# Everything under these prefixes is a "menu background" in the engine.
PREFIXES = (
    "assets/preload/images/menuBG",
    "assets/preload/images/menuDesat",
    "assets/preload/images/menubackgrounds/",
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets", "fnf")


def api(endpoint):
    """GET an api.github.com endpoint, return the decoded JSON body."""
    if shutil.which("gh"):
        cmd = ["gh", "api", endpoint]
    else:
        cmd = ["curl", "-sfL", "-H", "Accept: application/vnd.github+json",
               "https://api.github.com/" + endpoint.lstrip("/")]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise SystemExit("request failed: %s\n%s" % (endpoint, (proc.stderr or proc.stdout)[:600]))
    return json.loads(proc.stdout)


def main():
    tree = api("repos/%s/git/trees/%s?recursive=1" % (REPO, REF))
    commit = api("repos/%s/commits/%s" % (REPO, REF))["sha"]

    blobs = [t for t in tree["tree"]
             if t["type"] == "blob" and t["path"].startswith(PREFIXES)]
    if not blobs:
        raise SystemExit("no menu backgrounds found - did the engine layout change?")

    total = 0
    written = []
    for blob in blobs:
        rel = blob["path"][len("assets/"):]          # preload/images/menuBG.png
        out = os.path.join(DEST, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)

        content = api("repos/%s/git/blobs/%s" % (REPO, blob["sha"]))["content"]
        data = base64.b64decode(content.replace("\n", ""))
        if len(data) != blob["size"]:
            print("  !! size mismatch for %s" % rel, file=sys.stderr)
        with open(out, "wb") as fh:
            fh.write(data)
        total += len(data)
        written.append("fnf/" + rel)
        print("  %-58s %7d bytes" % ("fnf/" + rel, len(data)))

    with open(os.path.join(DEST, "source.json"), "w") as fh:
        json.dump({
            "repo": "https://github.com/%s" % REPO,
            "ref": REF,
            "commit": commit,
            "note": "Menu background art from the FNF Phoenix Engine fork. "
                    "Regenerate with: python3 tools/fetch_assets.py",
        }, fh, indent=2)
        fh.write("\n")

    print("\n%d files, %.2f MB -> %s" % (len(written), total / 1048576.0, DEST))
    print("pinned to %s@%s" % (REPO, commit[:12]))

    # Sanity-check the playlist against what we just downloaded.
    playlist = os.path.join(DEST, "slides.json")
    if os.path.exists(playlist):
        with open(playlist) as fh:
            slides = json.load(fh)["slides"]
        missing = [s["asset"] for s in slides if s["asset"] not in written]
        extra = [w for w in written if w not in [s["asset"] for s in slides]]
        if missing:
            print("\nWARNING: slides.json references files that were not downloaded:",
                  file=sys.stderr)
            for m in missing:
                print("  - %s" % m, file=sys.stderr)
        if extra:
            print("\nNOTE: downloaded files not listed in slides.json:")
            for e in extra:
                print("  - %s" % e)


if __name__ == "__main__":
    main()
