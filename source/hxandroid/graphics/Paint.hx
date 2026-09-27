package hxandroid.graphics;

/** android.graphics.Paint (only the int/boolean setters we need) */
@:native("android.graphics.Paint")
extern class Paint {
	function new();
	function setAlpha(a:Int):Void;
	function getAlpha():Int;
	function setColor(color:Int):Void;
	function setAntiAlias(aa:Bool):Void;
	function setFilterBitmap(filter:Bool):Void;
	function setDither(dither:Bool):Void;
	function setColorFilter(filter:ColorFilter):Void;
}
