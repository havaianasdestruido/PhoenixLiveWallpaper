package phoenix.wallpaper;

import hxandroid.widget.RadioGroup;
import hxandroid.widget.RadioGroupCheckListener;

/** RadioGroup.OnCheckedChangeListener -> SettingsActivity.onModeChanged() */
@:keep
class ModeListener implements RadioGroupCheckListener
{
	var activity:SettingsActivity;

	public function new(activity:SettingsActivity)
	{
		this.activity = activity;
	}

	public function onCheckedChanged(group:RadioGroup, checkedId:Int):Void
	{
		activity.onModeChanged(checkedId);
	}
}
