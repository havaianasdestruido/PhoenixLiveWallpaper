package phoenix.wallpaper;

import hxandroid.content.Context;
import hxandroid.content.SharedPreferences;
import hxandroid.content.SharedPrefsEditor;
import hxandroid.util.Log;

/**
 * Everything the settings screen can change.
 *
 * The wallpaper re-reads this whenever it becomes visible and on every slide
 * change, so a tweak in the settings activity applies to a running wallpaper
 * without any IPC (SharedPreferences is cached in-process).
 */
class Prefs
{
	// keys
	static inline var K_INTERVAL:String = "interval_ms";
	static inline var K_FADE:String = "fade_ms";
	static inline var K_DIM:String = "dim_pct";
	static inline var K_MODE:String = "fit_mode";
	static inline var K_SHUFFLE:String = "shuffle";
	static inline var K_TAP:String = "tap_to_skip";
	static inline var K_PARALLAX:String = "parallax";
	static inline var K_LAST_LABEL:String = "last_label";
	static inline var K_LAST_INDEX:String = "last_index";
	static inline var K_SWAPS:String = "swaps";

	public var intervalMs:Int;
	public var fadeMs:Int;
	public var dimPct:Int;
	public var mode:Int;
	public var shuffle:Bool;
	public var tapToSkip:Bool;
	public var parallax:Bool;

	// telemetry for the "now showing" line in the settings screen
	public var lastLabel:String;
	public var lastIndex:Int;
	public var swaps:Int;

	public function new()
	{
		intervalMs = Config.DEFAULT_INTERVAL_MS;
		fadeMs = Config.DEFAULT_FADE_MS;
		dimPct = 0;
		mode = Config.MODE_AUTO;
		shuffle = false;
		tapToSkip = true;
		parallax = Config.PARALLAX_ENABLED_DEFAULT;
		lastLabel = '';
		lastIndex = 0;
		swaps = 0;
	}

	static function prefs(context:Context):SharedPreferences
	{
		return context.getSharedPreferences(Config.PREFS_NAME, Context.MODE_PRIVATE);
	}

	public static function load(context:Context):Prefs
	{
		var p = new Prefs();
		if (context == null)
			return p;
		try
		{
			var sp = prefs(context);
			p.intervalMs = clamp(sp.getInt(K_INTERVAL, Config.DEFAULT_INTERVAL_MS), Config.MIN_INTERVAL_MS, Config.MAX_INTERVAL_MS);
			p.fadeMs = clamp(sp.getInt(K_FADE, Config.DEFAULT_FADE_MS), 0, Config.MAX_FADE_MS);
			p.dimPct = clamp(sp.getInt(K_DIM, 0), 0, 90);
			p.mode = clamp(sp.getInt(K_MODE, Config.MODE_AUTO), Config.MODE_AUTO, Config.MODE_STRETCH);
			p.shuffle = sp.getBoolean(K_SHUFFLE, false);
			p.tapToSkip = sp.getBoolean(K_TAP, true);
			p.parallax = sp.getBoolean(K_PARALLAX, Config.PARALLAX_ENABLED_DEFAULT);
			p.lastLabel = sp.getString(K_LAST_LABEL, '');
			p.lastIndex = sp.getInt(K_LAST_INDEX, 0);
			p.swaps = sp.getInt(K_SWAPS, 0);
		}
		catch (e:Dynamic)
		{
			Log.w(Config.TAG, 'prefs load failed, using defaults: ' + e);
			p = new Prefs();
		}
		if (p.lastLabel == null)
			p.lastLabel = '';
		return p;
	}

	public function save(context:Context):Void
	{
		if (context == null)
			return;
		try
		{
			var ed:SharedPrefsEditor = prefs(context).edit();
			ed.putInt(K_INTERVAL, intervalMs);
			ed.putInt(K_FADE, fadeMs);
			ed.putInt(K_DIM, dimPct);
			ed.putInt(K_MODE, mode);
			ed.putBoolean(K_SHUFFLE, shuffle);
			ed.putBoolean(K_TAP, tapToSkip);
			ed.putBoolean(K_PARALLAX, parallax);
			ed.apply();
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'prefs save failed: ' + e);
		}
	}

	/** Written by the engine after every slide change (best effort). */
	public static function noteSlide(context:Context, label:String, index:Int, swaps:Int):Void
	{
		if (context == null)
			return;
		try
		{
			var ed = prefs(context).edit();
			ed.putString(K_LAST_LABEL, label);
			ed.putInt(K_LAST_INDEX, index);
			ed.putInt(K_SWAPS, swaps);
			ed.apply();
		}
		catch (e:Dynamic)
		{
			// purely cosmetic, ignore
		}
	}

	public static function clamp(value:Int, min:Int, max:Int):Int
	{
		if (value < min)
			return min;
		if (value > max)
			return max;
		return value;
	}

	// ---- helpers shared with the settings screen -------------------------

	public static function secondsFromMs(ms:Int):Int
	{
		return Math.round(ms / 1000);
	}

	public static function msFromSeconds(seconds:Int):Int
	{
		return clamp(seconds * 1000, Config.MIN_INTERVAL_MS, Config.MAX_INTERVAL_MS);
	}

	public static function modeName(mode:Int):String
	{
		if (mode == Config.MODE_COVER)
			return 'Cover';
		if (mode == Config.MODE_FIT)
			return 'Fit';
		if (mode == Config.MODE_STRETCH)
			return 'Stretch';
		return 'Auto';
	}

	public function describe():String
	{
		return 'every ' + secondsFromMs(intervalMs) + 's, fade ' + fadeMs + 'ms, dim ' + dimPct + '%, '
			+ modeName(mode) + (shuffle ? ', shuffle' : ', in order');
	}
}
