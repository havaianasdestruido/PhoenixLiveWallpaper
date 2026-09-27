package phoenix.wallpaper;

import hxandroid.lang.Runnable;

/** Redraws one frame; reposts itself while a crossfade is animating. */
@:keep
class FrameTask implements Runnable
{
	var engine:WallpaperEngine;

	public function new(engine:WallpaperEngine)
	{
		this.engine = engine;
	}

	public function run():Void
	{
		engine.onFrame();
	}
}
