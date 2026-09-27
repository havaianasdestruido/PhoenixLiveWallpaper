package hxandroid.widget;

import hxandroid.content.Context;

/** android.widget.Toast */
@:native("android.widget.Toast")
extern class Toast {
	static function makeText(context:Context, text:String, duration:Int):Toast;
	function show():Void;
	static var LENGTH_SHORT:Int;
	static var LENGTH_LONG:Int;
}
