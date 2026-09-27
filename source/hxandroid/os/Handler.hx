package hxandroid.os;

import hxandroid.lang.Runnable;

/**
 * android.os.Handler
 * `delayMillis` is a Java `long`; Haxe `Int` widens to `long` in the generated
 * Java, so this is safe (we never schedule anything above Int.MAX_VALUE ms).
 */
@:native("android.os.Handler")
extern class Handler {
	function new(looper:Looper);
	function post(r:Runnable):Bool;
	function postDelayed(r:Runnable, delayMillis:Int):Bool;
	function removeCallbacks(r:Runnable):Void;
}
