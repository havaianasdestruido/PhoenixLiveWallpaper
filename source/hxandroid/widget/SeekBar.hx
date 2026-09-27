package hxandroid.widget;

import hxandroid.view.View;

/** android.widget.SeekBar */
@:native("android.widget.SeekBar")
extern class SeekBar extends View {
	function setMax(max:Int):Void;
	function getMax():Int;
	function setProgress(progress:Int):Void;
	function getProgress():Int;
	function setOnSeekBarChangeListener(l:SeekBarChangeListener):Void;
}
