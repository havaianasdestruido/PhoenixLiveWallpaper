package hxandroid.util;

/** android.util.Log - `adb logcat -s PhoenixWallpaper` */
@:native("android.util.Log")
extern class Log {
	static function d(tag:String, msg:String):Int;
	static function i(tag:String, msg:String):Int;
	static function w(tag:String, msg:String):Int;
	static function e(tag:String, msg:String):Int;
}
