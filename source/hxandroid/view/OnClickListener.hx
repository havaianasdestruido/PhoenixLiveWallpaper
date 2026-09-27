package hxandroid.view;

/** android.view.View.OnClickListener (nested interfaces are implicitly static,
    so a top-level Haxe class can implement one - unlike WallpaperService.Engine) */
@:native("android.view.View.OnClickListener")
extern interface OnClickListener {
	function onClick(v:View):Void;
}
