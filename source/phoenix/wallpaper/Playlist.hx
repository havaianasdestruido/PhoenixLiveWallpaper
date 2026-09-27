package phoenix.wallpaper;

import haxe.Json;
import hxandroid.content.Context;
import hxandroid.util.Log;

/**
 * The list of menu backgrounds, in the order they are shown.
 *
 * Loaded from `assets/fnf/slides.json` (which tools/fetch_assets.py keeps in
 * sync with the engine fork); falls back to the same list hardcoded below so the
 * wallpaper still works if the manifest is missing or unreadable.
 */
class Playlist
{
	public var slides:Array<Slide>;

	public function new(?slides:Array<Slide>)
	{
		this.slides = (slides == null) ? [] : slides;
	}

	public static function load(context:Context):Playlist
	{
		var list:Array<Slide> = [];

		if (context != null)
		{
			var text:String = null;
			try
			{
				text = Platform.readTextAsset(context, Config.PLAYLIST_ASSET);
			}
			catch (e:Dynamic)
			{
				Log.w(Config.TAG, 'cannot read ' + Config.PLAYLIST_ASSET + ': ' + e);
			}

			if (text != null && text.length > 0)
			{
				try
				{
					var data:Dynamic = Json.parse(text);
					var entries:Array<Dynamic> = data.slides;
					if (entries != null)
					{
						for (entry in entries)
						{
							var asset:String = entry.asset;
							if (asset == null || asset.length == 0)
								continue;
							var label:String = entry.label;
							var tint:String = entry.tint;
							list.push(new Slide(asset, label, tint));
						}
					}
				}
				catch (e:Dynamic)
				{
					Log.w(Config.TAG, 'cannot parse ' + Config.PLAYLIST_ASSET + ': ' + e);
					list = [];
				}
			}
		}

		if (list.length == 0)
		{
			Log.w(Config.TAG, 'using the built-in playlist');
			list = defaults();
		}

		Log.i(Config.TAG, 'playlist: ' + list.length + ' backgrounds');
		return new Playlist(list);
	}

	/** Mirror of assets/fnf/slides.json, used when the asset cannot be read. */
	public static function defaults():Array<Slide>
	{
		var img:String = Config.ASSET_ROOT + '/preload/images/';
		return [
			new Slide(img + 'menuBG.png', 'Main Menu (menuBG)'),
			new Slide(img + 'menuBGBlue.png', 'Blue Menu (menuBGBlue)'),
			new Slide(img + 'menuBGMagenta.png', 'Magenta Menu (menuBGMagenta)'),
			new Slide(img + 'menuDesat.png', 'Desat / magenta flash (menuDesat)', '#FFFD719B'),
			new Slide(img + 'menubackgrounds/menu_stage.png', 'Stage - Tutorial & Week 1 (Daddy Dearest)'),
			new Slide(img + 'menubackgrounds/menu_halloween.png', 'Halloween - Week 2 (Spooky Month)'),
			new Slide(img + 'menubackgrounds/menu_philly.png', 'Philly - Week 3 (Pico)'),
			new Slide(img + 'menubackgrounds/menu_limo.png', 'Limo - Week 4 (Mommy Must Murder)'),
			new Slide(img + 'menubackgrounds/menu_christmas.png', 'Christmas - Week 5 (Red Snow)'),
			new Slide(img + 'menubackgrounds/menu_school.png', 'School - Week 6 (Hating Simulator)'),
			new Slide(img + 'menubackgrounds/menu_tank.png', 'Tank - Week 7 (Tankman)'),
			new Slide(img + 'menubackgrounds/menu_phillystreets.png', 'Philly Streets - Weekend 1 (Due Debts)')
		];
	}

	public function count():Int
	{
		return slides.length;
	}

	public function at(index:Int):Slide
	{
		if (index < 0 || index >= slides.length)
			return null;
		return slides[index];
	}

	public function randomIndex(avoid:Int):Int
	{
		var n = slides.length;
		if (n <= 0)
			return 0;
		if (n == 1)
			return 0;
		var pick:Int = avoid;
		var guard:Int = 0;
		while (pick == avoid && guard < 32)
		{
			pick = Std.random(n);
			guard++;
		}
		return pick;
	}

	public function nextIndex(from:Int, shuffle:Bool):Int
	{
		var n = slides.length;
		if (n <= 0)
			return 0;
		if (shuffle)
			return randomIndex(from);
		return (from + 1) % n;
	}

	/** Where a fresh engine should start. */
	public function firstIndex(shuffle:Bool):Int
	{
		if (slides.length <= 0)
			return 0;
		return shuffle ? Std.random(slides.length) : 0;
	}
}
