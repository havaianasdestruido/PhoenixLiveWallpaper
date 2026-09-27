package hxandroid.content;

/**
 * android.content.Intent
 *
 * Java overloads cannot be expressed in Haxe, so only the signature we actually
 * use is declared (`putExtra(String, Parcelable)` -> ComponentName).
 */
@:native("android.content.Intent")
extern class Intent {
	function new(action:String);
	function putExtra(name:String, value:ComponentName):Intent;
	function addFlags(flags:Int):Intent;
}
