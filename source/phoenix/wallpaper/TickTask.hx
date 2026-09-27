package phoenix.wallpaper;

import hxandroid.lang.Runnable;

/**
 * Handler callbacks. Haxe has no SAM conversion for Java interfaces, so each
 * scheduled task is a tiny class implementing java.lang.Runnable (a nested
 * *interface*, which - unlike WallpaperService.Engine - a top level Haxe class is
 * allowed to implement).
 */
@:keep
class TickTask implements Runnable
{
	var engine:WallpaperEngine;

	public function new(engine:WallpaperEngine)
	{
		this.engine = engine;
	}

	public function run():Void
	{
		engine.onTick();
	}
}
