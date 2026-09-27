package hxandroid.lang;

/**
 * java.lang.Runnable
 * Declared under our own package (with @:native) so it can never collide with
 * anything hxjava ships.
 */
@:native("java.lang.Runnable")
extern interface Runnable {
	function run():Void;
}
