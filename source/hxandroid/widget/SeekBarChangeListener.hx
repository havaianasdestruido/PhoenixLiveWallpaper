package hxandroid.widget;

/** android.widget.SeekBar.OnSeekBarChangeListener */
@:native("android.widget.SeekBar.OnSeekBarChangeListener")
extern interface SeekBarChangeListener {
	function onProgressChanged(seekBar:SeekBar, progress:Int, fromUser:Bool):Void;
	function onStartTrackingTouch(seekBar:SeekBar):Void;
	function onStopTrackingTouch(seekBar:SeekBar):Void;
}
