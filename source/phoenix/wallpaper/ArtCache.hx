package phoenix.wallpaper;

import hxandroid.content.Context;
import hxandroid.graphics.Bitmap;
import hxandroid.util.Log;

/**
 * Tiny LRU of decoded backgrounds.
 *
 * Only Config.MAX_CACHED full-size bitmaps are kept alive (a 1286x730 ARGB_8888
 * frame is ~3.6 MB, and a live wallpaper process is long lived). Entries that
 * fall out of the window are simply dropped - we never call Bitmap.recycle(),
 * because a recycled bitmap that is still referenced by an in-flight frame would
 * crash the draw call. Modern Android puts bitmap pixels on the Java heap, so the
 * GC reclaims them on its own.
 *
 * Each slide also gets a "blur" copy: the same PNG decoded 16x smaller and then
 * bilinearly upscaled. Drawing that stretched across the screen behind the
 * letterboxed artwork gives the fit-mode backdrop without a single shader.
 */
class ArtCache
{
	var context:Context;
	var full:Map<String, Bitmap>;
	var blur:Map<String, Bitmap>;
	var order:Array<String>;

	var targetW:Int = 0;
	var targetH:Int = 0;

	public var decodes:Int = 0;
	public var misses:Int = 0;

	public function new(context:Context)
	{
		this.context = context;
		this.full = new Map<String, Bitmap>();
		this.blur = new Map<String, Bitmap>();
		this.order = [];
	}

	public function setTarget(width:Int, height:Int):Void
	{
		if (width == targetW && height == targetH)
			return;
		targetW = width;
		targetH = height;
		// the blurred backdrops are derived from the screen size, so drop them
		blur = new Map<String, Bitmap>();
	}

	public function getFull(slide:Slide):Bitmap
	{
		if (slide == null)
			return null;
		var bmp = full.get(slide.asset);
		if (bmp != null)
		{
			touch(slide.asset);
			return bmp;
		}
		misses++;
		bmp = decode(slide.asset, 1);
		if (bmp != null)
		{
			full.set(slide.asset, bmp);
			push(slide.asset);
		}
		return bmp;
	}

	public function getBlur(slide:Slide):Bitmap
	{
		if (slide == null)
			return null;
		var bmp = blur.get(slide.asset);
		if (bmp != null)
			return bmp;

		var tiny = decode(slide.asset, Config.BLUR_SAMPLE);
		if (tiny == null)
			return null;

		var w = tiny.getWidth();
		var h = tiny.getHeight();
		if (targetW > 0 && targetH > 0 && w > 0 && h > 0)
		{
			var bw:Int = Std.int(Math.max(8, Math.round(targetW / Config.BLUR_DIVISOR)));
			var bh:Int = Std.int(Math.max(8, Math.round(targetH / Config.BLUR_DIVISOR)));
			try
			{
				var up = Platform.scaled(tiny, bw, bh);
				if (up != null)
					bmp = up;
				else
					bmp = tiny;
			}
			catch (e:Dynamic)
			{
				bmp = tiny;
			}
		}
		else
		{
			bmp = tiny;
		}

		blur.set(slide.asset, bmp);
		return bmp;
	}

	/** Decode the slide (and its backdrop) before the crossfade needs it. */
	public function warm(slide:Slide):Void
	{
		if (slide == null)
			return;
		getFull(slide);
		getBlur(slide);
	}

	public function clear():Void
	{
		full = new Map<String, Bitmap>();
		blur = new Map<String, Bitmap>();
		order = [];
	}

	public function stats():String
	{
		var bytes:Int = 0;
		for (key in full.keys())
		{
			var b = full.get(key);
			if (b != null)
				bytes += b.getByteCount();
		}
		return '' + order.length + ' cached, ' + Math.round(bytes / 1048576) + ' MB, ' + decodes + ' decodes';
	}

	// ---- internals -------------------------------------------------------

	function decode(asset:String, sampleSize:Int):Bitmap
	{
		var bmp:Bitmap = null;
		try
		{
			bmp = Platform.decodeAsset(context, asset, sampleSize);
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'decode threw for ' + asset + ': ' + e);
		}
		if (bmp == null)
			Log.e(Config.TAG, 'decode returned null for ' + asset);
		else
			decodes++;
		return bmp;
	}

	function touch(asset:String):Void
	{
		var i = order.indexOf(asset);
		if (i >= 0 && i != order.length - 1)
		{
			order.splice(i, 1);
			order.push(asset);
		}
	}

	function push(asset:String):Void
	{
		touch(asset);
		if (order.indexOf(asset) < 0)
			order.push(asset);
		while (order.length > Config.MAX_CACHED)
		{
			var oldest = order.shift();
			full.remove(oldest);
			blur.remove(oldest);
		}
	}
}
