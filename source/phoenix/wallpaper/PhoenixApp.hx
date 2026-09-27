package phoenix.wallpaper;

import hxandroid.app.Application;
import hxandroid.content.Context;
import hxandroid.util.Log;

/**
 * android:name of the <application> tag.
 *
 * Exists so the Haxe runtime is warmed up (and the app context is on hand) before
 * either the WallpaperService or the settings Activity is instantiated.
 */
@:keep
class PhoenixApp extends Application
{
	public static var context:Context = null;

	@:keep
	override public function onCreate():Void
	{
		super.onCreate();
		context = this;
		Log.i(Config.TAG, 'PhoenixApp.onCreate - Haxe runtime up');
	}
}
