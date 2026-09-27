package hxandroid.graphics;

/**
 * android.graphics.Rect
 * Haxe has no overloaded constructors, so only Rect() is declared - use set().
 */
@:native("android.graphics.Rect")
extern class Rect {
	function new();
	function set(left:Int, top:Int, right:Int, bottom:Int):Bool;
	function width():Int;
	function height():Int;
	function isEmpty():Bool;
	var left:Int;
	var top:Int;
	var right:Int;
	var bottom:Int;
}
