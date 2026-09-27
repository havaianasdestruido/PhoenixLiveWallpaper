package hxandroid.widget;

/** android.widget.CompoundButton.OnCheckedChangeListener */
@:native("android.widget.CompoundButton.OnCheckedChangeListener")
extern interface CompoundButtonCheckListener {
	function onCheckedChanged(buttonView:CompoundButton, isChecked:Bool):Void;
}
