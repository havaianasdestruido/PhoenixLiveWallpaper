package phoenix.wallpaper;

import hxandroid.lang.Runnable;

/** Decodes the next background shortly before the slideshow needs it. */
@:keep
class PrefetchTask implements Runnable
{
	var engine:WallpaperEngine;

	public function new(engine:WallpaperEngine)
	{
		this.engine = engine;
	}

	public function run():Void
	{
		engine.onPrefetch();
	}
}
