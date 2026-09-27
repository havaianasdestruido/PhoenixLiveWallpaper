package hxandroid.view;

/**
 * android.view.MotionEvent
 * getX()/getY() return Java `float`; assigning them to a Haxe `Float` (double) is
 * a widening conversion, so this direction is safe.
 */
@:native("android.view.MotionEvent")
extern class MotionEvent {
	function getAction():Int;
	function getX():Float;
	function getY():Float;
	function getPointerCount():Int;
	static var ACTION_DOWN:Int;
	static var ACTION_UP:Int;
	static var ACTION_MOVE:Int;
	static var ACTION_CANCEL:Int;
	static var ACTION_MASK:Int;
}
