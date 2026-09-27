package hxandroid.content;

/** android.content.ComponentName */
@:native("android.content.ComponentName")
extern class ComponentName {
	function new(pkg:String, cls:String);
	function getClassName():String;
	function getPackageName():String;
	function flattenToShortString():String;
}
