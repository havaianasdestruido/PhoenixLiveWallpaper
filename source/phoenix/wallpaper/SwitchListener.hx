package phoenix.wallpaper;

import hxandroid.widget.CompoundButton;
import hxandroid.widget.CompoundButtonCheckListener;

/**
 * One listener class shared by the three switches.
 *
 * It cannot live inside SettingsActivity: CompoundButton.OnCheckedChangeListener
 * and RadioGroup.OnCheckedChangeListener are both called `onCheckedChanged`, and
 * Haxe has no method overloading.
 */
@:keep
class SwitchListener implements CompoundButtonCheckListener
{
	public static inline var SHUFFLE:Int = 1;
	public static inline var TAP:Int = 2;
	public static inline var PARALLAX:Int = 3;

	var activity:SettingsActivity;
	var kind:Int;

	public function new(activity:SettingsActivity, kind:Int)
	{
		this.activity = activity;
		this.kind = kind;
	}

	public function onCheckedChanged(buttonView:CompoundButton, isChecked:Bool):Void
	{
		activity.onSwitchChanged(kind, isChecked);
	}
}
