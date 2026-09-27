package hxandroid.content;

/** android.content.SharedPreferences.Editor */
@:native("android.content.SharedPreferences.Editor")
extern class SharedPrefsEditor {
	function putInt(key:String, value:Int):SharedPrefsEditor;
	function putBoolean(key:String, value:Bool):SharedPrefsEditor;
	function putString(key:String, value:String):SharedPrefsEditor;
	function apply():Void;
	function commit():Bool;
}
