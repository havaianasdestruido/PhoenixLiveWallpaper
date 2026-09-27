package hxandroid.widget;

/** android.widget.CompoundButton */
@:native("android.widget.CompoundButton")
extern class CompoundButton extends Button {
	function isChecked():Bool;
	function setChecked(checked:Bool):Void;
	function setOnCheckedChangedListener(listener:CheckedChangedListener):Void;
}
