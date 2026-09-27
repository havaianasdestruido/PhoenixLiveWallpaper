package hxandroid.graphics;

/** android.graphics.Color */
@:native("android.graphics.Color")
extern class Color {
	static function argb(alpha:Int, red:Int, green:Int, blue:Int):Int;
	static function rgb(red:Int, green:Int, blue:Int):Int;
	static function parseColor(colorString:String):Int;
	static var BLACK:Int;
	static var WHITE:Int;
	static var TRANSPARENT:Int;
}
