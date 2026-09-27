#!/usr/bin/env python3
"""Generate the launcher icon + wallpaper thumbnail vector drawables.

The art is a three armed swirl in the colours the FNF Phoenix Engine menus use
(white / blue / magenta). Everything is vector XML so the repo stays free of
binary blobs - run this again after touching the maths:

    python3 tools/make_icon.py
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

CX = CY = 54.0
ARMS = ("#FDFDFD", "#31B0D1", "#FD719B")   # menuBG / menuBGBlue / menuBGMagenta
BG = "#0B0B16"


def spiral(turns, r_max, steps=90, phase=0.0, r_start=2.0):
    pts = []
    n = int(turns * steps)
    for i in range(n + 1):
        t = i / n
        theta = phase + t * turns * 2 * math.pi
        r = r_start + (r_max - r_start) * (t ** 1.15)
        pts.append((CX + r * math.cos(theta), CY - r * math.sin(theta)))
    return pts


def path_data(pts):
    out = ["M %.2f %.2f" % pts[0]]
    out += ["L %.2f %.2f" % p for p in pts[1:]]
    return " ".join(out)


def arms(r_max, turns=1.6, width=4.6):
    return "\n".join(
        '''    <path
        android:pathData="%s"
        android:strokeColor="%s"
        android:strokeWidth="%.1f"
        android:strokeLineCap="round"
        android:fillColor="#00000000" />'''
        % (path_data(spiral(turns, r_max, phase=i * (2 * math.pi / 3))), color, width)
        for i, color in enumerate(ARMS)
    )


def rect():
    return '''    <path
        android:pathData="M0 0h108v108H0z"
        android:fillColor="%s" />''' % BG


def vector(body, comment):
    return '''<!-- %s
     Regenerate with: python3 tools/make_icon.py -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
%s
</vector>
''' % (comment, body)


def write(rel, text):
    dest = os.path.join(RES, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w") as fh:
        fh.write(text)
    print("  wrote %s" % rel)


def main():
    # adaptive icon foreground: keep inside the 72dp safe zone (radius 36)
    write("drawable/ic_launcher_foreground.xml",
          vector(arms(r_max=29, width=5.0),
                 "Adaptive icon foreground (the mask keeps the middle 72dp)."))
    # solid background: VectorDrawable gradients need API 24 and minSdk is 21
    write("drawable/ic_launcher_background.xml",
          vector(rect(), "Adaptive icon background."))
    # pre API 26 launcher icon
    write("drawable/ic_launcher_legacy.xml",
          vector(rect() + "\n" + arms(r_max=37), "Launcher icon for API 21-25."))
    # thumbnail shown in the system wallpaper picker
    write("drawable/ic_phoenix_swirl.xml",
          vector(rect() + "\n" + arms(r_max=37),
                 "Wallpaper picker thumbnail (res/xml/wallpaper.xml android:thumbnail)."))


if __name__ == "__main__":
    main()
