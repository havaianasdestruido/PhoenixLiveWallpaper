package hxandroid.os;

/** android.os.Looper */
@:native("android.os.Looper")
extern class Looper {
	static function getMainLooper():Looper;
	static function myLooper():Looper;
}
