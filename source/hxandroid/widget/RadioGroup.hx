package hxandroid.widget;

import hxandroid.view.View;

/** android.widget.RadioGroup */
@:native("android.widget.RadioGroup")
extern class RadioGroup extends View {
	function check(id:Int):Void;
	function clearCheck():Void;
	function getCheckedRadioButtonId():Int;
	function setOnCheckedChangeListener(listener:RadioGroupCheckListener):Void;
}
