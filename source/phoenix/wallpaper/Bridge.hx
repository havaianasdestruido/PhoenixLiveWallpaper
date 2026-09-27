package phoenix.wallpaper;

import hxandroid.content.Context;
import hxandroid.util.Log;
import hxandroid.view.SurfaceHolder;

/**
 * The static surface the Java shim calls into.
 *
 * Every method is `@:keep`: nothing in Haxe calls them, the callers are Java
 * (dev.phoenix.wallpaper.PhoenixWallpaperService), so the dead code eliminator would
 * otherwise strip them out of the generated sources.
 *
 * Every method is also wrapped in try/catch. A live wallpaper lives in a process the
 * launcher talks to; an exception escaping into the framework kills the wallpaper
 * and leaves the user staring at a black home screen.
 */
@:keep
class Bridge
{
	static var engines:Map<Int, WallpaperEngine> = new Map<Int, WallpaperEngine>();
	static var nextId:Int = 1;

	/** Returns >0 on success, <0 when the engine could not be built. */
	@:keep
	public static function create(context:Context, holder:SurfaceHolder):Int
	{
		var id:Int = nextId++;
		try
		{
			var engine = new WallpaperEngine(id, context, holder);
			engines.set(id, engine);
			return id;
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'create failed: ' + e);
			return -id;
		}
	}

	@:keep
	public static function destroy(id:Int):Void
	{
		try
		{
			var engine = find(id);
			if (engine != null)
			{
				engine.onDestroy();
				engines.remove(id);
			}
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'destroy failed: ' + e);
		}
	}

	@:keep
	public static function setVisible(id:Int, visible:Bool):Void
	{
		try
		{
			var engine = find(id);
			if (engine != null)
				engine.setVisible(visible);
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'setVisible failed: ' + e);
		}
	}

	@:keep
	public static function surfaceChanged(id:Int, width:Int, height:Int):Void
	{
		try
		{
			var engine = find(id);
			if (engine != null)
				engine.onSurfaceChanged(width, height);
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'surfaceChanged failed: ' + e);
		}
	}

	@:keep
	public static function surfaceDestroyed(id:Int):Void
	{
		try
		{
			var engine = find(id);
			if (engine != null)
				engine.onSurfaceDestroyed();
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'surfaceDestroyed failed: ' + e);
		}
	}

	@:keep
	public static function offsetsChanged(id:Int, x:Float, y:Float, xPixel:Int, yPixel:Int):Void
	{
		try
		{
			var engine = find(id);
			if (engine != null)
				engine.onOffsetsChanged(x, y, xPixel, yPixel);
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'offsetsChanged failed: ' + e);
		}
	}

	@:keep
	public static function touch(id:Int, action:Int, x:Float, y:Float):Void
	{
		try
		{
			var engine = find(id);
			if (engine != null)
				engine.onTouch(action, x, y);
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'touch failed: ' + e);
		}
	}

	/** logcat helper - dumps every engine the process is currently running. */
	@:keep
	public static function describeAll():String
	{
		var out:String = '';
		try
		{
			for (key in engines.keys())
			{
				var engine = engines.get(key);
				if (engine != null)
					out += engine.describe() + ' | ';
			}
		}
		catch (e:Dynamic)
		{
			out += 'describeAll failed: ' + e;
		}
		return (out.length == 0) ? 'no engines' : out;
	}

	static function find(id:Int):WallpaperEngine
	{
		if (id <= 0)
			return null;
		return engines.get(id);
	}
}
