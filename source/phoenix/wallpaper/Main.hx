package phoenix.wallpaper;

import hxandroid.util.Log;

/**
 * `haxe -java` wants an entry point, but Android never calls main(): the process
 * starts in PhoenixApp.onCreate() and the framework then instantiates
 * PhoenixWallpaperService (Java) and SettingsActivity (Haxe) by name from the
 * manifest.
 *
 * So main() has one job - reference every class that is only reachable *from
 * Java*, so the dead code eliminator cannot drop them from the generated sources.
 * build.hxml also passes `-dce no` as a second safety net.
 */
class Main
{
	public static function main():Void
	{
		if (reachable().length == -1)
			Log.i(Config.TAG, 'unreachable');
	}

	@:keep
	static function reachable():Array<Dynamic>
	{
		return [
			PhoenixApp, SettingsActivity, Bridge, WallpaperEngine, Prefs, Playlist, Slide, ArtCache,
			FrameTask, TickTask, PrefetchTask, SwitchListener, ModeListener, Config
		];
	}
}
