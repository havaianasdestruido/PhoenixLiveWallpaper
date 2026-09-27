package hxandroid.view;

import hxandroid.content.Context;

/** android.view.View */
@:native("android.view.View")
extern class View {
	function getId():Int;
	function getContext():Context;
	function setVisibility(visibility:Int):Void;
	function setPadding(left:Int, top:Int, right:Int, bottom:Int):Void;
	function setBackgroundColor(color:Int):Void;
	function setOnClickListener(l:OnClickListener):Void;
	function setEnabled(enabled:Bool):Void;
	static var VISIBLE:Int;
	static var INVISIBLE:Int;
	static var GONE:Int;
}
