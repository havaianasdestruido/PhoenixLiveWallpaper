package hxandroid.app;

import hxandroid.content.Context;
import hxandroid.os.Bundle;
import hxandroid.view.View;

/** android.app.Activity */
@:native("android.app.Activity")
extern class Activity extends Context {
	function new();
	function onCreate(savedInstanceState:Bundle):Void;
	function onStart():Void;
	function onResume():Void;
	function onPause():Void;
	function onDestroy():Void;
	function setContentView(layoutResID:Int):Void;
	function findViewById(id:Int):View;
	function finish():Void;
}
