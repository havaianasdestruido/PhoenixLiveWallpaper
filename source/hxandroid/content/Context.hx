package hxandroid.content;

/** android.content.Context */
@:native("android.content.Context")
extern class Context {
	function new();
	function getApplicationContext():Context;
	function getPackageName():String;
	function getSharedPreferences(name:String, mode:Int):SharedPreferences;
	function startActivity(intent:Intent):Void;
	function getString(resId:Int):String;
	static var MODE_PRIVATE:Int;
}
