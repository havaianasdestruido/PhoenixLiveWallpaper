package hxandroid.app;

import hxandroid.content.Context;

/** android.app.Application */
@:native("android.app.Application")
extern class Application extends Context {
	function new();
	function onCreate():Void;
}
