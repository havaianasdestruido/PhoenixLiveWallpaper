package hxandroid.graphics;

/**
 * android.graphics.Canvas
 *
 * Only int / Rect overloads are declared on purpose: the Haxe Java target maps
 * `Float` to Java `double`, and a `double` cannot be passed where a `float` is
 * expected. drawBitmap(bmp, Rect, Rect, Paint) and drawRect(int,int,int,int,Paint)
 * keep every coordinate integral, which is all a wallpaper slideshow needs.
 */
@:native("android.graphics.Canvas")
extern class Canvas {
	function getWidth():Int;
	function getHeight():Int;
	function save():Int;
	function restore():Void;
	function drawColor(color:Int):Void;
	function drawRect(left:Int, top:Int, right:Int, bottom:Int, paint:Paint):Void;
	function drawBitmap(bitmap:Bitmap, src:Rect, dst:Rect, paint:Paint):Void;
	function clipRect(left:Int, top:Int, right:Int, bottom:Int):Bool;
}
