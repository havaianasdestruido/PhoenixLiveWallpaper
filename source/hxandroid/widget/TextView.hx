package hxandroid.widget;

import hxandroid.view.View;

/** android.widget.TextView - setText(String) resolves to setText(CharSequence) */
@:native("android.widget.TextView")
extern class TextView extends View {
	function setText(text:String):Void;
	function setTextColor(color:Int):Void;
}
