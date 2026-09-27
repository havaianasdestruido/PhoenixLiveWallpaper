package phoenix.wallpaper;

import hxandroid.graphics.Color;
import hxandroid.graphics.ColorFilter;
import hxandroid.graphics.PorterDuffColorFilter;
import hxandroid.graphics.PorterDuffMode;
import hxandroid.util.Log;

/**
 * One background in the slideshow.
 *
 * Mirrors an entry of assets/fnf/slides.json. `tint` reproduces what
 * MainMenuState.hx does with the desaturated swirl:
 *
 *     magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
 *     magenta.color = 0xFFfd719b;
 *
 * Flixel multiplies the sprite by that colour, so we attach a MULTIPLY
 * PorterDuffColorFilter and get the same look on a Canvas.
 */
class Slide
{
	public var asset:String;
	public var label:String;
	public var tintHex:String;

	var filter:ColorFilter;
	var filterBuilt:Bool = false;

	public function new(asset:String, label:String, ?tintHex:String)
	{
		this.asset = asset;
		this.label = (label == null || label.length == 0) ? asset : label;
		this.tintHex = tintHex;
	}

	public var tinted(get, never):Bool;

	function get_tinted():Bool
	{
		return tintHex != null && tintHex.length > 0;
	}

	/** Lazily built once per slide, then reused on every frame. */
	public function colorFilter():ColorFilter
	{
		if (filterBuilt)
			return filter;
		filterBuilt = true;
		if (!tinted)
			return null;
		try
		{
			filter = new PorterDuffColorFilter(Color.parseColor(tintHex), PorterDuffMode.MULTIPLY);
		}
		catch (e:Dynamic)
		{
			Log.w(Config.TAG, 'bad tint "' + tintHex + '" on ' + asset);
			filter = null;
		}
		return filter;
	}

	public function toString():String
	{
		return label;
	}
}
