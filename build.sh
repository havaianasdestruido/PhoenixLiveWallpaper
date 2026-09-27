#!/usr/bin/env bash
#
# One shot build: Haxe -> Java -> APK.
#
#   ./build.sh                 # debug APK   (export/java + android/app/build/...)
#   ./build.sh --release       # release APK, signed with the debug key
#   ./build.sh --haxe-only     # only compile source/*.hx to Java
#   ./build.sh --refresh       # re-download the menu backgrounds first
#
# Prerequisites: Haxe 4.x + hxjava, JDK 17, Gradle 8.7 (or Android Studio), and the
# Android SDK with platforms;android-34. CI does all of this for you - see
# .github/workflows/build.yml, which uploads the APK as an artifact.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VARIANT="Debug"
HAXE_ONLY=0
REFRESH=0

for arg in "$@"; do
	case "$arg" in
		--release)   VARIANT="Release" ;;
		--debug)     VARIANT="Debug" ;;
		--haxe-only) HAXE_ONLY=1 ;;
		--refresh)   REFRESH=1 ;;
		-h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
		*)           echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
	esac
done

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }
die()  { printf '\n\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- assets
if [ "$REFRESH" = "1" ]; then
	step "Refreshing the menu backgrounds from the engine fork"
	command -v python3 >/dev/null || die "python3 is needed by tools/fetch_assets.py"
	python3 tools/fetch_assets.py
fi

if [ ! -f "assets/fnf/preload/images/menuBG.png" ]; then
	die "assets/fnf is empty - run: python3 tools/fetch_assets.py"
fi

# ---------------------------------------------------------------- haxe
step "Compiling Haxe -> Java"
command -v haxe >/dev/null || die "haxe not found on PATH (https://haxe.org/download/)"

# The repo already ignores .haxelib/, so prefer a project local library repo when
# one exists (that is how the engine fork is built too).
if [ -d ".haxelib" ]; then
	export HAXELIB_PATH="$ROOT/.haxelib"
	echo "    using project haxelib repo: .haxelib"
fi

if ! haxelib list 2>/dev/null | grep -q '^hxjava'; then
	echo "    installing hxjava"
	haxelib install hxjava --always --quiet || die "haxelib install hxjava failed"
fi

haxe build.hxml

BRIDGE="export/java/src/phoenix/wallpaper/Bridge.java"
[ -f "$BRIDGE" ] || die "haxe produced no $BRIDGE - check the output above"
GENERATED=$(find export/java/src -name '*.java' | wc -l | tr -d ' ')
echo "    generated $GENERATED java files in export/java/src"

if [ "$HAXE_ONLY" = "1" ]; then
	printf '\n\033[1;32mhaxe build ok\033[0m (skipping gradle)\n'
	exit 0
fi

# ---------------------------------------------------------------- gradle
step "Building the ${VARIANT} APK"
command -v java >/dev/null || die "no JDK on PATH - install JDK 17"

GRADLE=""
if [ -x "android/gradlew" ]; then
	GRADLE="./gradlew"
elif command -v gradle >/dev/null; then
	GRADLE="gradle"
else
	die "neither android/gradlew nor gradle found.
  Install Gradle 8.7 (https://gradle.org/install/) or run once with Gradle on PATH:
      cd android && gradle wrapper
  Android Studio also works: open the android/ folder and run assembleDebug."
fi

TASK="assemble${VARIANT}"
( cd android && $GRADLE --console=plain "$TASK" )

APK_DIR="android/app/build/outputs/apk/$(echo "$VARIANT" | tr '[:upper:]' '[:lower:]')"
step "Done"
find "$APK_DIR" -name '*.apk' -print 2>/dev/null | sed 's/^/    /' || true
cat <<'TIP'

Install it with:
    adb install -r android/app/build/outputs/apk/debug/app-debug.apk
Then long press the home screen -> Wallpapers -> Live wallpaper ->
"Phoenix Engine menus" (or just launch the app and tap "Set as wallpaper...").

Watch it work:
    adb logcat -s PhoenixWallpaper
TIP
