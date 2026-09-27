package hxandroid.widget;

/** android.widget.RadioGroup.OnCheckedChangedListener */
@:native("android.widget.RadioGroup.OnCheckedChangedListener")
extern interface RadioGroupCheckedChangedListener {
	function onCheckedChanged(group:RadioGroup, checkedId:Int):Void;
}
