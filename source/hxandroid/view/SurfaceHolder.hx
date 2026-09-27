package hxandroid.view;

import hxandroid.graphics.Canvas;
import hxandroid.graphics.Rect;

/**
 * android.view.SurfaceHolder
 * lockCanvas()/unlockCanvasAndPost() is the whole rendering surface contract of a
 * live wallpaper - the Haxe side owns it, the Java shim only forwards lifecycle.
 */
@:native("android.view.SurfaceHolder")
extern class SurfaceHolder {
	function lockCanvas():Canvas;
	function unlockCanvasAndPost(canvas:Canvas):Void;
	function getSurfaceFrame():Rect;
	function setFormat(format:Int):Void;
}
