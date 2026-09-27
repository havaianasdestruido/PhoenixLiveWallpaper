package hxandroid.content;

/** android.content.SharedPreferences */
@:native("android.content.SharedPreferences")
extern class SharedPreferences {
	function getInt(key:String, defValue:Int):Int;
	function getBoolean(key:String, defValue:Bool):Bool;
	function getString(key:String, defValue:String):String;
	function edit():SharedPrefsEditor;
}
