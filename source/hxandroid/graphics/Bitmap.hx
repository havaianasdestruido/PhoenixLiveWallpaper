package hxandroid.graphics;

/** android.graphics.Bitmap */
@:native("android.graphics.Bitmap")
extern class Bitmap {
	function getWidth():Int;
	function getHeight():Int;
	function getByteCount():Int;
	function isRecycled():Bool;
	function recycle():Void;
}
