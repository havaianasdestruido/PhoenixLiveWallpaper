package phoenix.wallpaper;

import hxandroid.app.Activity;
import hxandroid.content.ComponentName;
import hxandroid.content.Intent;
import hxandroid.os.Bundle;
import hxandroid.util.Log;
import hxandroid.view.OnClickListener;
import hxandroid.view.View;
import hxandroid.widget.RadioGroup;
import hxandroid.widget.SeekBar;
import hxandroid.widget.SeekBarChangeListener;
import hxandroid.widget.Switch;
import hxandroid.widget.TextView;
import hxandroid.widget.Toast;

/**
 * The settings screen (android:name in the manifest, also reachable from the
 * system wallpaper picker through <meta-data android:settingsActivity>).
 *
 * Layout comes from res/layout/activity_settings.xml; this class only wires the
 * widgets to Prefs. Saving is live (onPause + when a slider is released), and the
 * running wallpaper picks the values up on its next slide change or the next time
 * it becomes visible - no restart, no IPC.
 */
@:keep
class SettingsActivity extends Activity implements OnClickListener implements SeekBarChangeListener
{
	/** must match the <service android:name> in AndroidManifest.xml */
	public static inline var SERVICE_CLASS:String = "dev.phoenix.wallpaper.PhoenixWallpaperService";

	/** WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER (API 16+) */
	static inline var ACTION_CHANGE_LIVE_WALLPAPER:String = "android.service.wallpaper.CHANGE_LIVE_WALLPAPER";

	/** WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT */
	static inline var EXTRA_LIVE_WALLPAPER_COMPONENT:String = "android.service.wallpaper.extra.LIVE_WALLPAPER_COMPONENT";

	/** Intent.ACTION_SET_WALLPAPER (the generic chooser) */
	static inline var ACTION_SET_WALLPAPER:String = "android.intent.action.SET_WALLPAPER";

	static inline var MIN_SECONDS:Int = 5;
	static inline var MAX_SECONDS:Int = 120;

	var prefs:Prefs;
	var playlist:Playlist;

	var nowPlaying:TextView;
	var playlistList:TextView;
	var intervalLabel:TextView;
	var intervalSeek:SeekBar;
	var fadeLabel:TextView;
	var fadeSeek:SeekBar;
	var dimLabel:TextView;
	var dimSeek:SeekBar;
	var modeLabel:TextView;
	var modeGroup:RadioGroup;
	var shuffleSwitch:Switch;
	var tapSwitch:Switch;
	var parallaxSwitch:Switch;

	@:keep
	override public function onCreate(savedInstanceState:Bundle):Void
	{
		super.onCreate(savedInstanceState);
		setContentView(RLayout.activity_settings);

		prefs = Prefs.load(this);
		playlist = Playlist.load(this);

		nowPlaying = text(RId.nowPlaying);
		playlistList = text(RId.playlistList);
		intervalLabel = text(RId.intervalLabel);
		fadeLabel = text(RId.fadeLabel);
		dimLabel = text(RId.dimLabel);
		modeLabel = text(RId.modeLabel);

		intervalSeek = seek(RId.intervalSeek);
		intervalSeek.setMax(MAX_SECONDS - MIN_SECONDS);
		intervalSeek.setProgress(Prefs.clamp(Prefs.secondsFromMs(prefs.intervalMs), MIN_SECONDS, MAX_SECONDS) - MIN_SECONDS);
		intervalSeek.setOnSeekBarChangeListener(this);

		fadeSeek = seek(RId.fadeSeek);
		fadeSeek.setMax(Std.int(Config.MAX_FADE_MS / Config.FADE_STEP_MS));
		fadeSeek.setProgress(Std.int(Prefs.clamp(prefs.fadeMs, 0, Config.MAX_FADE_MS) / Config.FADE_STEP_MS));
		fadeSeek.setOnSeekBarChangeListener(this);

		dimSeek = seek(RId.dimSeek);
		dimSeek.setMax(90);
		dimSeek.setProgress(Prefs.clamp(prefs.dimPct, 0, 90));
		dimSeek.setOnSeekBarChangeListener(this);

		modeGroup = cast(view(RId.modeGroup), RadioGroup);
		modeGroup.check(idForMode(prefs.mode));
		modeGroup.setOnCheckedChangedListener(new ModeListener(this));

		shuffleSwitch = toggle(RId.shuffleSwitch);
		shuffleSwitch.setChecked(prefs.shuffle);
		shuffleSwitch.setOnCheckedChangedListener(new SwitchListener(this, SwitchListener.SHUFFLE));

		tapSwitch = toggle(RId.tapSwitch);
		tapSwitch.setChecked(prefs.tapToSkip);
		tapSwitch.setOnCheckedChangedListener(new SwitchListener(this, SwitchListener.TAP));

		parallaxSwitch = toggle(RId.parallaxSwitch);
		parallaxSwitch.setChecked(prefs.parallax);
		parallaxSwitch.setOnCheckedChangedListener(new SwitchListener(this, SwitchListener.PARALLAX));

		view(RId.applyButton).setOnClickListener(this);

		refreshLabels();
		refreshPlaylist();
		refreshNowPlaying();
	}

	@:keep
	override public function onResume():Void
	{
		super.onResume();
		// the engine writes these while it runs, so re-read on every resume
		refreshNowPlaying();
	}

	@:keep
	override public function onPause():Void
	{
		commit();
		super.onPause();
	}

	// ---------------------------------------------------------------- callbacks

	public function onSwitchChanged(kind:Int, checked:Bool):Void
	{
		if (kind == SwitchListener.SHUFFLE)
			prefs.shuffle = checked;
		else if (kind == SwitchListener.TAP)
			prefs.tapToSkip = checked;
		else if (kind == SwitchListener.PARALLAX)
			prefs.parallax = checked;
		commit();
	}

	public function onModeChanged(checkedId:Int):Void
	{
		prefs.mode = modeForId(checkedId);
		refreshLabels();
		commit();
	}

	public function onProgressChanged(seekBar:SeekBar, progress:Int, fromUser:Bool):Void
	{
		refreshLabels();
	}

	public function onStartTrackingTouch(seekBar:SeekBar):Void {}

	public function onStopTrackingTouch(seekBar:SeekBar):Void
	{
		commit();
	}

	public function onClick(v:View):Void
	{
		if (v == null)
			return;
		if (v.getId() == RId.applyButton)
			openWallpaperPicker();
	}

	// ---------------------------------------------------------------- ui -> prefs

	function commit():Void
	{
		if (prefs == null || intervalSeek == null || fadeSeek == null || dimSeek == null || modeGroup == null)
			return;
		prefs.intervalMs = Prefs.msFromSeconds(MIN_SECONDS + intervalSeek.getProgress());
		prefs.fadeMs = Prefs.clamp(fadeSeek.getProgress() * Config.FADE_STEP_MS, 0, Config.MAX_FADE_MS);
		prefs.dimPct = Prefs.clamp(dimSeek.getProgress(), 0, 90);
		prefs.mode = modeForId(modeGroup.getCheckedRadioButtonId());
		prefs.shuffle = shuffleSwitch.isChecked();
		prefs.tapToSkip = tapSwitch.isChecked();
		prefs.parallax = parallaxSwitch.isChecked();
		prefs.save(this);
		refreshLabels();
		Log.i(Config.TAG, 'settings: ' + prefs.describe());
	}

	function refreshLabels():Void
	{
		if (intervalSeek == null || fadeSeek == null || dimSeek == null || modeGroup == null)
			return;
		if (intervalLabel != null)
		{
			var seconds:Int = MIN_SECONDS + intervalSeek.getProgress();
			intervalLabel.setText('Switch every ' + seconds + (seconds == 1 ? ' second' : ' seconds'));
		}
		if (fadeLabel != null)
			fadeLabel.setText('Crossfade: ' + (fadeSeek.getProgress() * Config.FADE_STEP_MS) + ' ms');
		if (dimLabel != null)
			dimLabel.setText('Dim behind icons: ' + dimSeek.getProgress() + '%');
		if (modeLabel != null)
			modeLabel.setText('Scaling: ' + Prefs.modeName(modeForId(modeGroup.getCheckedRadioButtonId())));
	}

	function refreshPlaylist():Void
	{
		if (playlistList == null)
			return;
		var out:String = '';
		for (i in 0...playlist.count())
		{
			var slide = playlist.at(i);
			if (slide == null)
				continue;
			if (out.length > 0)
				out += '\n';
			out += '' + (i + 1) + '. ' + slide.label;
			if (slide.tinted)
				out += '  (tinted ' + slide.tintHex + ')';
		}
		playlistList.setText(out);
	}

	function refreshNowPlaying():Void
	{
		if (nowPlaying == null)
			return;
		var p = Prefs.load(this);
		var line:String;
		if (p.lastLabel == null || p.lastLabel.length == 0)
			line = 'The wallpaper has not drawn a slide yet.';
		else
			line = 'Now showing: ' + p.lastLabel + '\nslide ' + p.lastIndex + ' of ' + playlist.count() + ' - ' + p.swaps
				+ ' swaps since the service started';
		nowPlaying.setText(line);
	}

	function openWallpaperPicker():Void
	{
		try
		{
			var intent = new Intent(ACTION_CHANGE_LIVE_WALLPAPER);
			intent.putExtra(EXTRA_LIVE_WALLPAPER_COMPONENT, new ComponentName(getPackageName(), SERVICE_CLASS));
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			startActivity(intent);
			return;
		}
		catch (e:Dynamic)
		{
			Log.w(Config.TAG, 'CHANGE_LIVE_WALLPAPER unavailable: ' + e);
		}

		// some OEM builds do not export the shortcut: fall back to the plain chooser
		try
		{
			startActivity(new Intent(ACTION_SET_WALLPAPER));
		}
		catch (e:Dynamic)
		{
			toast(getString(RString.picker_unavailable));
		}
	}

	function toast(message:String):Void
	{
		try
		{
			Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
		}
		catch (e:Dynamic)
		{
			Log.w(Config.TAG, 'toast failed: ' + e);
		}
	}

	// ---------------------------------------------------------------- helpers

	function view(id:Int):View
	{
		var v:View = findViewById(id);
		if (v == null)
			Log.e(Config.TAG, 'layout is missing view id ' + id);
		return v;
	}

	function text(id:Int):TextView
	{
		return cast(view(id), TextView);
	}

	function seek(id:Int):SeekBar
	{
		return cast(view(id), SeekBar);
	}

	function toggle(id:Int):Switch
	{
		return cast(view(id), Switch);
	}

	function idForMode(mode:Int):Int
	{
		if (mode == Config.MODE_COVER)
			return RId.modeCover;
		if (mode == Config.MODE_FIT)
			return RId.modeFit;
		if (mode == Config.MODE_STRETCH)
			return RId.modeStretch;
		return RId.modeAuto;
	}

	function modeForId(id:Int):Int
	{
		if (id == RId.modeCover)
			return Config.MODE_COVER;
		if (id == RId.modeFit)
			return Config.MODE_FIT;
		if (id == RId.modeStretch)
			return Config.MODE_STRETCH;
		return Config.MODE_AUTO;
	}
}
