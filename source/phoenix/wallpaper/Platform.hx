package phoenix.wallpaper;

import hxandroid.content.Context;
import hxandroid.graphics.Bitmap;

/**
 * Externs for the hand written Java helper at
 * `android/app/src/main/java/dev/phoenix/wallpaper/Platform.java`.
 *
 * Only three things genuinely have to be Java:
 *   - AssetManager.open() / InputStream.close() throw *checked* exceptions, and
 *     Haxe has no concept of those.
 *   - Java `long` returns (SystemClock.elapsedRealtime) would need a narrowing
 *     cast to become a Haxe `Int`.
 *   - Java `float` parameters: Haxe `Float` is a `double`, and a double cannot
 *     be passed where a float is expected.
 */
@:native("dev.phoenix.wallpaper.Platform")
extern class Platform
{
	/** Decode `path` from the APK assets. sampleSize>1 decodes a smaller copy. */
	static function decodeAsset(context:Context, path:String, sampleSize:Int):Bitmap;

	/** Whole asset as UTF-8 text, or null when it cannot be read. */
	static function readTextAsset(context:Context, path:String):String;

	/** Filtered (bilinear) rescale used to build the blurred backdrop. */
	static function scaled(src:Bitmap, width:Int, height:Int):Bitmap;

	/** Monotonic milliseconds (SystemClock.elapsedRealtime) as a double. */
	static function elapsedMs():Float;
}
