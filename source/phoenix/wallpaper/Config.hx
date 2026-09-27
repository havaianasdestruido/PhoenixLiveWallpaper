package phoenix.wallpaper;

/**
 * Compile-time constants for the wallpaper.
 *
 * `DEFAULT_INTERVAL_MS` is the "switch every 20 seconds" from the spec; the
 * settings screen can move it anywhere between MIN and MAX.
 *
 * Note: no 0xAARRGGBB int literals live in here on purpose. Haxe `Int` is a
 * signed 32 bit value and the Java generator would have to emit a negative
 * literal for e.g. 0xFF0B0B16 - colours are built with android.graphics.Color
 * at runtime instead (Color.BLACK / Color.argb / Color.parseColor).
 */
class Config
{
	/** logcat tag: `adb logcat -s PhoenixWallpaper` */
	public static inline var TAG:String = "PhoenixWallpaper";

	/** where the engine art lives inside the APK (see assets/fnf) */
	public static inline var ASSET_ROOT:String = "fnf";
	public static inline var PLAYLIST_ASSET:String = "fnf/slides.json";

	public static inline var PREFS_NAME:String = "phoenix_wallpaper";

	// ---- slideshow -------------------------------------------------------
	public static inline var DEFAULT_INTERVAL_MS:Int = 20000;
	public static inline var MIN_INTERVAL_MS:Int = 3000;
	public static inline var MAX_INTERVAL_MS:Int = 300000;
	public static inline var DEFAULT_FADE_MS:Int = 900;
	public static inline var MAX_FADE_MS:Int = 4000;
	public static inline var FADE_STEP_MS:Int = 50;

	/** redraw period while a crossfade is running (~60fps) */
	public static inline var FRAME_MS:Int = 16;

	/** decode the incoming slide this long before it is needed */
	public static inline var PREFETCH_LEAD_MS:Int = 1500;

	// ---- layout ----------------------------------------------------------
	public static inline var MODE_AUTO:Int = 0;
	public static inline var MODE_COVER:Int = 1;
	public static inline var MODE_FIT:Int = 2;
	public static inline var MODE_STRETCH:Int = 3;

	/**
	 * AUTO uses COVER unless filling the screen would throw away too much of the
	 * artwork, in which case it letterboxes it over a blurred copy. The engine's
	 * 1286x730 menu swirls and 1280x386 story-menu strips are both wider than a
	 * phone, so portrait phones normally end up in FIT.
	 */
	public static inline var AUTO_CROP_LIMIT:Float = 2.0;

	/** how much of the oversized image the home-screen parallax may reveal */
	public static inline var PARALLAX_ENABLED_DEFAULT:Bool = true;

	// ---- input -----------------------------------------------------------
	public static inline var TAP_SLOP:Float = 28.0;
	public static inline var TAP_MS:Float = 350.0;

	// ---- memory ----------------------------------------------------------
	public static inline var MAX_CACHED:Int = 3;
	public static inline var BLUR_SAMPLE:Int = 16;
	public static inline var BLUR_DIVISOR:Int = 6;
}
