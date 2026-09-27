package phoenix.wallpaper;

import hxandroid.content.Context;
import hxandroid.graphics.Bitmap;
import hxandroid.graphics.Canvas;
import hxandroid.graphics.Color;
import hxandroid.graphics.Paint;
import hxandroid.graphics.Rect;
import hxandroid.os.Handler;
import hxandroid.os.Looper;
import hxandroid.util.Log;
import hxandroid.view.MotionEvent;
import hxandroid.view.SurfaceHolder;
import hxandroid.widget.Toast;

/**
 * One live wallpaper engine, written entirely in Haxe.
 *
 * The Android side (dev.phoenix.wallpaper.PhoenixWallpaperService) is a ~80 line
 * shim: WallpaperService.Engine is a *non-static inner class* and the Haxe -> Java
 * generator can only emit top level classes, so the shim owns the surface
 * lifecycle and forwards everything here through Bridge.
 *
 * Rendering model
 *   - software Canvas from SurfaceHolder.lockCanvas(), drawn on the main thread
 *   - event driven: no frame is produced unless something changed, so an idle
 *     home screen costs nothing (one draw per slide change, plus ~60fps for the
 *     length of the crossfade)
 *   - all geometry is integral: android.graphics.Rect + drawBitmap(bmp, src, dst)
 *     so Haxe Floats (Java doubles) never have to cross into float parameters
 */
@:keep
class WallpaperEngine
{
	public var id:Int;

	var context:Context;
	var holder:SurfaceHolder;
	var handler:Handler;

	var cache:ArtCache;
	var playlist:Playlist;
	var prefs:Prefs;

	var width:Int = 0;
	var height:Int = 0;
	var visible:Bool = false;
	var alive:Bool = false;

	// slideshow state
	var index:Int = 0;
	var prevIndex:Int = -1;
	var fadeStart:Float = -1;
	var nextAt:Float = 0;
	var swaps:Int = 0;
	var appliedIntervalMs:Int = -1;

	// home screen parallax
	var xOffset:Float = 0.5;
	var yOffset:Float = 0.0;
	var lastXPixel:Int = 0;
	var lastYPixel:Int = 0;
	var haveOffset:Bool = false;

	// tap to skip
	var downX:Float = 0;
	var downY:Float = 0;
	var downAt:Float = 0;
	var downSeen:Bool = false;

	var framePending:Bool = false;
	var tickTask:TickTask;
	var frameTask:FrameTask;
	var prefetchTask:PrefetchTask;

	// reused drawing objects (no per-frame allocation)
	var paint:Paint;
	var blurPaint:Paint;
	var dimPaint:Paint;
	var srcRect:Rect;
	var dstRect:Rect;
	var blurRect:Rect;

	public function new(id:Int, context:Context, holder:SurfaceHolder)
	{
		this.id = id;
		this.context = context;
		this.holder = holder;
		this.alive = true;

		this.handler = new Handler(Looper.getMainLooper());
		this.prefs = Prefs.load(context);
		this.playlist = Playlist.load(context);
		this.cache = new ArtCache(context);

		this.paint = new Paint();
		paint.setFilterBitmap(true);
		paint.setDither(true);
		paint.setAntiAlias(false);

		this.blurPaint = new Paint();
		blurPaint.setFilterBitmap(true);
		blurPaint.setDither(true);

		this.dimPaint = new Paint();
		dimPaint.setDither(false);

		this.srcRect = new Rect();
		this.dstRect = new Rect();
		this.blurRect = new Rect();

		this.index = playlist.firstIndex(prefs.shuffle);

		this.tickTask = new TickTask(this);
		this.frameTask = new FrameTask(this);
		this.prefetchTask = new PrefetchTask(this);

		Log.i(Config.TAG, 'engine ' + id + ' created: ' + playlist.count() + ' backgrounds, ' + prefs.describe());
	}

	// ---------------------------------------------------------------- lifecycle

	public function onSurfaceChanged(w:Int, h:Int):Void
	{
		if (!alive)
			return;
		if (w <= 0 || h <= 0)
			return;

		if (w != width || h != height)
		{
			width = w;
			height = h;
			cache.setTarget(w, h);
			Log.i(Config.TAG, 'engine ' + id + ' surface ' + w + 'x' + h);
		}

		applyPrefs();
		// a recreated surface must not stall the slideshow: onSurfaceDestroyed()
		// cancelled the timers and setVisible() will not run again while the engine
		// stays visible. nextAt is untouched, so the current deadline survives.
		if (visible)
		{
			scheduleTick();
			schedulePrefetch();
		}
		requestFrame();
	}

	public function onSurfaceDestroyed():Void
	{
		if (!alive)
			return;
		cancelAll();
		width = 0;
		height = 0;
		Log.i(Config.TAG, 'engine ' + id + ' surface destroyed');
	}

	public function setVisible(v:Bool):Void
	{
		if (!alive || visible == v)
			return;
		visible = v;

		if (v)
		{
			applyPrefs();
			nextAt = Platform.elapsedMs() + prefs.intervalMs;
			scheduleTick();
			schedulePrefetch();
			requestFrame();
			Log.i(Config.TAG, 'engine ' + id + ' visible: ' + playlist.count() + ' backgrounds, ' + prefs.describe());
		}
		else
		{
			cancelAll();
			Log.i(Config.TAG, 'engine ' + id + ' hidden (' + cache.stats() + ')');
		}
	}

	public function onOffsetsChanged(x:Float, y:Float, xPixel:Int, yPixel:Int):Void
	{
		if (!alive)
			return;
		xOffset = x;
		yOffset = y;
		if (!prefs.parallax)
			return;
		// only redraw when the launcher actually moved us by a whole pixel
		if (haveOffset && xPixel == lastXPixel && yPixel == lastYPixel)
			return;
		haveOffset = true;
		lastXPixel = xPixel;
		lastYPixel = yPixel;
		requestFrame();
	}

	public function onTouch(action:Int, x:Float, y:Float):Void
	{
		if (!alive || !prefs.tapToSkip || !visible)
			return;

		var masked:Int = action & MotionEvent.ACTION_MASK;
		if (masked == MotionEvent.ACTION_DOWN)
		{
			downX = x;
			downY = y;
			downAt = Platform.elapsedMs();
			downSeen = true;
		}
		else if (masked == MotionEvent.ACTION_UP && downSeen)
		{
			downSeen = false;
			var dx:Float = x - downX;
			var dy:Float = y - downY;
			var dt:Float = Platform.elapsedMs() - downAt;
			if (dt >= 0 && dt <= Config.TAP_MS && dx * dx + dy * dy <= Config.TAP_SLOP * Config.TAP_SLOP)
				advance(true);
		}
		else if (masked == MotionEvent.ACTION_CANCEL)
		{
			downSeen = false;
		}
	}

	public function onDestroy():Void
	{
		if (!alive)
			return;
		alive = false;
		visible = false;
		cancelAll();
		cache.clear();
		Log.i(Config.TAG, 'engine ' + id + ' destroyed after ' + swaps + ' swaps');
	}

	// ---------------------------------------------------------------- slideshow

	/** Called by TickTask when the interval elapsed. */
	public function onTick():Void
	{
		if (!alive)
			return;
		applyPrefs();
		advance(false);
	}

	/** Decode the slide we are about to need so the fade never stutters. */
	public function onPrefetch():Void
	{
		if (!alive || !visible)
			return;
		cache.warm(playlist.at(playlist.nextIndex(index, prefs.shuffle)));
	}

	/** Called by FrameTask. */
	public function onFrame():Void
	{
		framePending = false;
		if (!alive || !visible || width <= 0 || height <= 0)
			return;
		draw();
		// keep the animation going while a crossfade is running
		if (fadeStart >= 0)
		{
			framePending = true;
			handler.postDelayed(frameTask, Config.FRAME_MS);
		}
	}

	public function advance(announce:Bool):Void
	{
		if (!alive || playlist.count() <= 0)
			return;

		var from:Int = index;
		var to:Int = playlist.nextIndex(from, prefs.shuffle);

		if (to != from && prefs.fadeMs > 0 && cache.getFull(playlist.at(from)) != null)
		{
			prevIndex = from;
			fadeStart = Platform.elapsedMs();
		}
		else
		{
			prevIndex = -1;
			fadeStart = -1;
		}

		index = to;
		swaps++;
		nextAt = Platform.elapsedMs() + prefs.intervalMs;

		scheduleTick();
		schedulePrefetch();
		requestFrame();

		var slide = playlist.at(index);
		var label:String = (slide == null) ? '(none)' : slide.label;
		Log.i(Config.TAG, 'engine ' + id + ' -> ' + (index + 1) + '/' + playlist.count() + ' ' + label);
		Prefs.noteSlide(context, label, index + 1, swaps);

		if (announce)
		{
			try
			{
				Toast.makeText(context, label, Toast.LENGTH_SHORT).show();
			}
			catch (e:Dynamic)
			{
				// toasts can be suppressed for background processes; ignore
			}
		}
	}

	function applyPrefs():Void
	{
		var p = Prefs.load(context);
		var intervalChanged = (p.intervalMs != appliedIntervalMs);
		prefs = p;
		if (intervalChanged)
		{
			appliedIntervalMs = p.intervalMs;
			if (visible)
			{
				nextAt = Platform.elapsedMs() + p.intervalMs;
				scheduleTick();
				schedulePrefetch();
			}
		}
	}

	function scheduleTick():Void
	{
		if (!alive || !visible)
			return;
		handler.removeCallbacks(tickTask);
		var delay:Float = nextAt - Platform.elapsedMs();
		if (delay < 100)
			delay = 100;
		var max:Float = prefs.intervalMs * 2 + 1000;
		if (delay > max)
			delay = prefs.intervalMs;
		handler.postDelayed(tickTask, Std.int(delay));
	}

	function schedulePrefetch():Void
	{
		if (!alive || !visible)
			return;
		handler.removeCallbacks(prefetchTask);
		var delay:Float = nextAt - Platform.elapsedMs() - Config.PREFETCH_LEAD_MS;
		if (delay < 0)
			delay = 0;
		handler.postDelayed(prefetchTask, Std.int(delay));
	}

	function cancelAll():Void
	{
		if (handler == null)
			return;
		handler.removeCallbacks(tickTask);
		handler.removeCallbacks(frameTask);
		handler.removeCallbacks(prefetchTask);
		framePending = false;
		fadeStart = -1;
		prevIndex = -1;
	}

	function requestFrame():Void
	{
		if (!alive || !visible || width <= 0 || height <= 0)
			return;
		if (framePending)
			return;
		framePending = true;
		handler.post(frameTask);
	}

	// ---------------------------------------------------------------- rendering

	function draw():Void
	{
		var canvas:Canvas = null;
		try
		{
			canvas = holder.lockCanvas();
		}
		catch (e:Dynamic)
		{
			canvas = null;
		}
		if (canvas == null)
			return;

		try
		{
			render(canvas);
		}
		catch (e:Dynamic)
		{
			Log.e(Config.TAG, 'render failed: ' + e);
		}

		// once lockCanvas() succeeds the frame must always be handed back
		try
		{
			holder.unlockCanvasAndPost(canvas);
		}
		catch (e:Dynamic)
		{
			Log.w(Config.TAG, 'unlockCanvasAndPost failed: ' + e);
		}
	}

	function render(canvas:Canvas):Void
	{
		canvas.drawColor(Color.BLACK);
		if (width <= 0 || height <= 0)
			return;

		var t:Float = 1;
		var fading:Bool = false;
		if (fadeStart >= 0)
		{
			fading = true;
			t = (prefs.fadeMs <= 0) ? 1 : (Platform.elapsedMs() - fadeStart) / prefs.fadeMs;
			if (t < 0)
				t = 0;
			if (t >= 1)
			{
				t = 1;
				fading = false;
				fadeStart = -1;
				prevIndex = -1;
			}
		}

		if (fading && prevIndex >= 0)
			drawSlide(canvas, playlist.at(prevIndex), 1 - t);

		drawSlide(canvas, playlist.at(index), t);

		if (prefs.dimPct > 0)
		{
			var a:Int = Std.int(prefs.dimPct * 2.55);
			if (a > 255)
				a = 255;
			dimPaint.setColor(Color.argb(a, 0, 0, 0));
			canvas.drawRect(0, 0, width, height, dimPaint);
		}
	}

	function drawSlide(canvas:Canvas, slide:Slide, alpha:Float):Void
	{
		if (slide == null)
			return;
		var bmp:Bitmap = cache.getFull(slide);
		if (bmp == null || bmp.isRecycled())
			return;

		var bw:Int = bmp.getWidth();
		var bh:Int = bmp.getHeight();
		if (bw <= 0 || bh <= 0)
			return;

		var a:Float = alpha;
		if (a < 0)
			a = 0;
		if (a > 1)
			a = 1;

		var mode:Int = effectiveMode(bw, bh);

		// letterboxed slides sit on a blurred, screen filling copy of themselves
		if (mode == Config.MODE_FIT)
		{
			var back:Bitmap = cache.getBlur(slide);
			if (back != null && !back.isRecycled())
			{
				var bbw:Int = back.getWidth();
				var bbh:Int = back.getHeight();
				if (bbw > 0 && bbh > 0)
				{
					coverRect(bbw, bbh, blurRect, false);
					srcRect.set(0, 0, bbw, bbh);
					blurPaint.setAlpha(Std.int(a * 235));
					blurPaint.setColorFilter(slide.colorFilter());
					canvas.drawBitmap(back, srcRect, blurRect, blurPaint);
					blurPaint.setAlpha(255);
					blurPaint.setColorFilter(null);
				}
			}
			// a hair of darkening keeps the artwork readable over its own blur
			dimPaint.setColor(Color.argb(90, 0, 0, 0));
			canvas.drawRect(0, 0, width, height, dimPaint);
		}

		srcRect.set(0, 0, bw, bh);
		applyRect(bw, bh, mode, dstRect);
		paint.setAlpha(Std.int(a * 255));
		paint.setColorFilter(slide.colorFilter());
		canvas.drawBitmap(bmp, srcRect, dstRect, paint);
		paint.setAlpha(255);
		paint.setColorFilter(null);
	}

	/** AUTO: cover the screen unless that would crop the art away too hard. */
	function effectiveMode(bw:Int, bh:Int):Int
	{
		var m:Int = prefs.mode;
		if (m != Config.MODE_AUTO)
			return m;
		if (bw <= 0 || bh <= 0 || width <= 0 || height <= 0)
			return Config.MODE_COVER;
		var cover:Float = Math.max(width / bw, height / bh);
		var fit:Float = Math.min(width / bw, height / bh);
		if (fit <= 0)
			return Config.MODE_COVER;
		return (cover / fit > Config.AUTO_CROP_LIMIT) ? Config.MODE_FIT : Config.MODE_COVER;
	}

	function applyRect(bw:Int, bh:Int, mode:Int, out:Rect):Void
	{
		if (mode == Config.MODE_STRETCH)
		{
			out.set(0, 0, width, height);
			return;
		}
		if (mode == Config.MODE_FIT)
		{
			var s:Float = Math.min(width / bw, height / bh);
			var dw:Int = Math.round(bw * s);
			var dh:Int = Math.round(bh * s);
			var fx:Int = Math.round((width - dw) / 2);
			var fy:Int = Math.round((height - dh) / 2);
			out.set(fx, fy, fx + dw, fy + dh);
			return;
		}
		coverRect(bw, bh, out, prefs.parallax);
	}

	/** Fill the screen, keeping the aspect ratio, honouring the launcher pan. */
	function coverRect(bw:Int, bh:Int, out:Rect, parallax:Bool):Void
	{
		var s:Float = Math.max(width / bw, height / bh);
		var dw:Int = Math.round(bw * s);
		var dh:Int = Math.round(bh * s);
		if (dw < width)
			dw = width;
		if (dh < height)
			dh = height;

		var dx:Int = Math.round((width - dw) / 2);
		var dy:Int = Math.round((height - dh) / 2);

		if (parallax)
		{
			// xOffset is 0..1 across the launcher's pages: 0.5 means "centred"
			var x:Float = xOffset;
			if (x < 0)
				x = 0;
			if (x > 1)
				x = 1;
			var y:Float = yOffset;
			if (y < 0)
				y = 0;
			if (y > 1)
				y = 1;
			dx = -Math.round((dw - width) * x);
			dy = -Math.round((dh - height) * y);
		}

		out.set(dx, dy, dx + dw, dy + dh);
	}

	public function describe():String
	{
		var slide = playlist.at(index);
		return 'engine ' + id + ' [' + width + 'x' + height + (visible ? ' visible' : ' hidden') + '] '
			+ (slide == null ? 'no slides' : slide.label) + ' | ' + cache.stats();
	}
}
