package hxandroid.widget;

/** android.widget.CompoundButton.OnCheckedChangedListener */
@:native("android.widget.CompoundButton.OnCheckedChangedListener")
extern interface CheckedChangedListener {
	function onCheckedChanged(buttonView:CompoundButton, isChecked:Bool):Void;
}
