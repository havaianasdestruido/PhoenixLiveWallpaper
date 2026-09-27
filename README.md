# Phoenix Live Wallpaper

An Android **live wallpaper written in Haxe** that cycles the menu backgrounds of the
[FNF Phoenix Engine](https://github.com/havaianasdestruido/FNF-Phoenix-Engine) fork —
the main menu swirls and every story-menu week — with a crossfade, **every 20 seconds**.

```
main menu swirl → blue swirl → magenta swirl → desat/magenta flash
→ stage (week 1) → halloween (2) → philly (3) → limo (4) → christmas (5)
→ school (6) → tank (7) → philly streets (weekend 1) → repeat
```

Twelve backgrounds, twenty seconds each, so a full loop is four minutes. The interval is
a setting; 20 s is the default.

![All twelve slides rendered the way the wallpaper draws them on a 1080x2400 phone:
letterboxed over a blurred copy of themselves, menuDesat multiplied magenta](docs/preview-auto.png)

*Contact sheet produced by `tools/preview.py` — see [Checking it without a device](#checking-it-without-a-device).*

## What it does

* **Slideshow** of the engine's `assets/preload/images/menuBG*.png`, `menuDesat.png` and
  `assets/preload/images/menubackgrounds/*.png`, fetched straight from the fork.
* **Crossfade** between slides (900 ms by default, 0–4000 ms configurable).
* **Event driven rendering** — nothing is drawn unless something changed. An idle home
  screen costs one frame per slide change plus ~60 fps for the length of the crossfade.
  No `Choreographer`, no render thread, no battery drain while you are not looking.
* **AUTO scaling**: fills the screen (cover) unless that would throw away too much of the
  artwork, in which case it letterboxes the image over a blurred copy of itself. The engine
  art is 1286x730 and 1280x386, so a portrait phone normally gets the letterboxed treatment
  and a tablet/landscape gets the full-bleed one. Cover / Fit / Stretch can be forced.
* **Home-screen parallax** (`onOffsetsChanged`), **tap the wallpaper to skip** to the next
  background, and a **dim** slider so icons stay readable.
* **Shuffle or sequential** order.
* **`menuDesat` is tinted magenta** with a `MULTIPLY` colour filter, exactly like
  `MainMenuState.hx` does (`magenta.color = 0xFFfd719b` on the desaturated swirl).
* **Settings screen** (also reachable from the system wallpaper picker) that writes
  `SharedPreferences`; the running wallpaper picks changes up on the next slide change or
  the next time it becomes visible. No restart, no service rebinding.
* **Zero permissions.** The art ships inside the APK.

## Build it

You need Haxe 4.x with `hxjava`, JDK 17, Gradle 8.7 (or Android Studio) and the Android SDK
with `platforms;android-34`.

```bash
haxelib install hxjava      # once
./build.sh                  # Haxe -> Java -> APK
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

`./build.sh --release` builds the release variant (signed with the debug key so it is
installable), `--haxe-only` stops after the Haxe compile, `--refresh` re-downloads the
engine art first.

Or step by step:

```bash
haxe build.hxml                                   # -> export/java/src/**/*.java
                                                  # (-D no-compilation: Haxe only generates,
                                                  #  Gradle does the javac against android.jar)
cd android && gradle assembleDebug                # -> app/build/outputs/apk/debug/app-debug.apk
```

There is no `gradle/wrapper/gradle-wrapper.jar` in the repo (it is a binary). Either run
`cd android && gradle wrapper` once to generate it, open `android/` in Android Studio, or
use CI.

**No toolchain? Use CI.** Push the branch and the
[build workflow](.github/workflows/build.yml) installs Haxe + the Android SDK, compiles
both halves and uploads `phoenix-live-wallpaper-apk` (debug *and* release) as an artifact.

Then: long press the home screen → **Wallpaper & style** → **Live wallpaper** →
*Phoenix Engine menus* — or just launch the app and tap **Set as wallpaper…**.

## How it works

Haxe has no Android target of its own, so this project uses the **Java target**: `haxe -java`
turns `source/*.hx` into Java sources, and Gradle compiles them into the APK alongside two
hand written Java files.

```
build.hxml                     -cp source -lib hxjava -main phoenix.wallpaper.Main
                               -java export/java -dce no -D no-compilation

source/
  hxandroid/                   hand written externs for the Android API we touch (35 files)
    app/ content/ graphics/ os/ util/ view/ widget/ lang/
  phoenix/wallpaper/
    Bridge.hx                  the static surface Java calls into (@:keep on everything)
    WallpaperEngine.hx         playlist state machine + all the drawing
    ArtCache.hx                LRU of decoded bitmaps (+ the cheap blur copies)
    Playlist.hx  Slide.hx      assets/fnf/slides.json -> ordered list of backgrounds
    Prefs.hx                   SharedPreferences, with clamping and defaults
    PhoenixApp.hx              android.app.Application, warms the runtime
    SettingsActivity.hx        android.app.Activity, wires res/layout to Prefs
    FrameTask/TickTask/PrefetchTask.hx   java.lang.Runnable callbacks for the Handler
    R.hx RId.hx RLayout.hx RString.hx    externs for the generated resource table
    Main.hx                    entry point; its only job is to defeat DCE
    Platform.hx                extern for the Java helper below

android/app/src/main/
  java/dev/phoenix/wallpaper/
    PhoenixWallpaperService.java   WallpaperService + Engine  (~130 lines, mostly try/catch)
    Platform.java                  asset I/O, monotonic clock   (~120 lines)
  AndroidManifest.xml              the <service> with BIND_WALLPAPER, the settings <activity>
  res/xml/wallpaper.xml            description / thumbnail / settingsActivity
  res/layout/activity_settings.xml the settings screen
  res/drawable/*.xml               generated vector icon + picker thumbnail
  assets                           (points at ../../assets, nothing is copied)

assets/fnf/                        the engine art, mirroring the fork's layout
  preload/images/menuBG.png, menuBGBlue.png, menuBGMagenta.png, menuDesat.png
  preload/images/menubackgrounds/menu_stage.png ... menu_phillystreets.png
  slides.json                      the playlist: asset path, label, optional tint
  source.json                      which commit of the fork the art came from
```

### Why there is any Java at all

`WallpaperService.Engine` is a **non-static inner class**. JLS 8.1.4 only lets an inner class
of `WallpaperService` (or of a subclass) extend it, and the Haxe → Java generator emits
**top level classes only**, so `PhoenixEngine` has to be Java. Confirmed against AOSP:

```java
public abstract class WallpaperService extends Service {   // frameworks/base
    public abstract Engine onCreateEngine();
    public class Engine { ... }                            // <-- inner, not static
```

That is the *only* reason. The shim forwards `onCreate` / `onVisibilityChanged` /
`surfaceChanged` / `surfaceDestroyed` / `onOffsetsChanged` / `onTouchEvent` to
`phoenix.wallpaper.Bridge` and never touches a `Canvas` — Haxe locks the surface itself
(`SurfaceHolder.lockCanvas()` → draw → `unlockCanvasAndPost()`).

`Platform.java` covers the three things the Java target cannot express:

| Problem | Why | Where |
| --- | --- | --- |
| checked exceptions | `AssetManager.open()` / `InputStream.close()` throw `IOException`; Haxe has no checked exceptions, so a generated call site would not compile | `decodeAsset`, `readTextAsset` |
| Java `long` | `SystemClock.elapsedRealtime()` returns `long`; Haxe `Int` is 32 bit, and a `long` return would need a narrowing cast | `elapsedMs()` returns `double` |
| Java `float` | Haxe `Float` **is** a Java `double`, and a `double` cannot be passed where a `float` is expected | avoided entirely: the renderer only uses the `int`/`Rect` overloads of `Canvas` (`drawBitmap(bmp, Rect, Rect, Paint)`, `drawRect(int,int,int,int,Paint)`), so every coordinate stays integral |

Nested **interfaces** (`SurfaceHolder.Callback`, `View.OnClickListener`,
`SeekBar.OnSeekBarChangeListener`, `CompoundButton.OnCheckedChangedListener`, …) are implicitly
static, so Haxe *can* implement them from a top level class — that is how the settings
screen and the `Handler` callbacks are written in Haxe.

### The 20 seconds

`WallpaperEngine` keeps a monotonic deadline and posts a `Runnable` to a
`Handler(Looper.getMainLooper())`:

```
setVisible(true)  -> nextAt = now + intervalMs, postDelayed(tickTask, nextAt - now)
onTick()          -> advance(): pick the next slide, start the crossfade, re-arm the timer
onFrame()         -> lockCanvas, draw, post; reposts itself every 16 ms while fading
                    (1.5 s before the tick a prefetch task decodes the incoming bitmap)
setVisible(false) -> removeCallbacks for all three tasks: zero work while hidden
```

Because a crossfade needs frames but a static slide does not, the engine is idle between
transitions — `adb shell dumpsys wallpaper` will show it, `logcat` will show it working:

```
adb logcat -s PhoenixWallpaper
I PhoenixWallpaper: engine 1 created: 12 backgrounds, every 20s, fade 900ms, dim 0%, Auto, in order
I PhoenixWallpaper: engine 1 surface 1080x2400
I PhoenixWallpaper: engine 1 -> 2/12 Blue Menu (menuBGBlue)
```

## Settings

| Setting | Default | Range |
| --- | --- | --- |
| Switch every | **20 s** | 5–120 s |
| Crossfade | 900 ms | 0–4000 ms |
| Shuffle the order | off | — |
| Scaling | Auto | Auto / Cover / Fit / Stretch |
| Dim behind icons | 0 % | 0–90 % |
| Tap the wallpaper to skip | on | — |
| Pan with the home screen | on | — |

Values live in the `phoenix_wallpaper` `SharedPreferences` file, so you can inspect what the
wallpaper is actually using (debug builds only):

```bash
adb shell "run-as dev.phoenix.wallpaper cat /data/data/dev.phoenix.wallpaper/shared_prefs/phoenix_wallpaper.xml"
```

## The artwork

`assets/fnf/` mirrors `assets/preload/images/` of the engine fork, and `assets/fnf/slides.json`
is the playlist:

```json
{ "asset": "fnf/preload/images/menuDesat.png",
  "label": "Desat / magenta flash (menuDesat)",
  "tint":  "#FFFD719B" }
```

* **Refresh the art** (after the fork changes): `python3 tools/fetch_assets.py`
  — it walks the fork's git tree, downloads the blobs through the GitHub API and rewrites
  `assets/fnf/source.json` with the commit it pinned. `PHOENIX_REF=<tag|sha>` picks a
  different revision, `PHOENIX_REPO=<owner/repo>` a different fork.
* **Add or reorder slides**: edit `assets/fnf/slides.json`. Drop any PNG into `assets/fnf/`
  and list it there — Gradle ships `assets/` as-is (`assets.srcDirs = ["../../assets"]`),
  no copy step. `Playlist.defaults()` in Haxe mirrors the file and is used if the JSON ever
  fails to parse.
* Labels in `slides.json` come from the fork's `assets/preload/weeks/*.json`
  (`weekBackground`) so the story-menu slides say which week they belong to.

The art belongs to the FNF team and the Phoenix Engine authors; this project only ships it
inside a wallpaper. `LICENSE` here covers the code.

## Checking it without a device

There is no Haxe or JDK in every environment this repo gets edited in, so two scripts cover
what a compiler would otherwise catch late:

```bash
python3 tools/check.py            # packages/imports/type names, layout ids <-> RId.hx,
                                  # manifest classes, Bridge signatures Java <-> Haxe,
                                  # Platform extern <-> Platform.java, slides.json <-> disk,
                                  # resource references, XML/JSON validity
python3 tools/verify_externs.py   # downloads AOSP frameworks/base and checks that all 144
                                  # members declared by source/hxandroid/*.hx really exist
                                  # with the right arity (walking superclass chains and
                                  # nested types), plus every @Override in the Java shim
```

`tools/make_icon.py` regenerates the vector launcher icon and the wallpaper-picker thumbnail
(the three armed swirl in the menu colours). Both scripts cache what they download under
`.cache/`, which is gitignored.

### Seeing it without a device

`tools/preview.py` renders the slideshow exactly the way `WallpaperEngine.hx` lays it out —
AUTO/COVER/FIT/STRETCH geometry, the blurred fit backdrop, the `MULTIPLY` tint, the dim
layer — by decoding the palette PNGs with nothing but the standard library, and writes a
contact sheet:

```bash
python3 tools/preview.py                      # docs/preview-auto.png
python3 tools/preview.py --mode cover         # docs/preview-cover.png
python3 tools/preview.py --mode fit --dim 20  # with the dim slider at 20 %
python3 tools/preview.py --screen 1440x3120 --tile 216x468
```

The sheet at the top of this README is `--mode auto` on a 1080x2400 screen: every slide
ends up letterboxed (the art is far wider than a phone is), so you see the sharp image
over its own blurred, darkened copy — and slide 4 is `menuDesat` multiplied by
`#FFFD719B`, the magenta flash the engine's main menu uses.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `haxe: command not found` | install Haxe 4.x, then `haxelib install hxjava` |
| `package phoenix.wallpaper does not exist` | you ran Gradle before Haxe: `haxe build.hxml` (or `./build.sh`) |
| `Could not determine java class 'dev.phoenix.wallpaper.R'` | resource ids changed; re-run `tools/check.py` |
| black home screen after installing | `adb logcat -s PhoenixWallpaper AndroidRuntime` — the shim logs anything that escapes Haxe |
| wallpaper does not appear in the picker | the `<service>` needs `android:permission="android.permission.BIND_WALLPAPER"` and the `android.service.wallpaper.WallpaperService` action; some OEM pickers only list wallpapers after a reboot |
| slides look cropped | set **Scaling → Fit** in the settings screen |
| changes in the settings screen do nothing | they apply on the next slide change (≤ interval) or as soon as the wallpaper becomes visible again |

## Ideas that are not built yet

* decode on a worker thread (`sys.thread` works on the Java target) if a low end device ever
  hitches on the prefetch
* a static-wallpaper export (`WallpaperManager.setBitmap`) for people who do not want a live one
* per-slide duration and a "only show week backgrounds" filter in `slides.json`
* the `freakyMenu.ogg` from the fork, muted by default, because of course
