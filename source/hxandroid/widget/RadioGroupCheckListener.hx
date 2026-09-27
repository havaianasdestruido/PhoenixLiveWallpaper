package hxandroid.widget;

/** android.widget.RadioGroup.OnCheckedChangeListener */
@:native("android.widget.RadioGroup.OnCheckedChangeListener")
extern interface RadioGroupCheckListener {
	function onCheckedChanged(group:RadioGroup, checkedId:Int):Void;
}
