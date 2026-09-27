package dev.phoenix.wallpaper;

import android.service.wallpaper.WallpaperService;
import android.util.Log;
import android.view.MotionEvent;
import android.view.SurfaceHolder;

import phoenix.wallpaper.Bridge;

/**
 * The only Java in the wallpaper.
 *
 * {@code WallpaperService.Engine} is a <em>non-static inner class</em>: JLS 8.1.4
 * only lets an inner class of WallpaperService (or of a subclass) extend it, so it
 * cannot be expressed by the Haxe -&gt; Java generator, which emits top level
 * classes. Everything else - the playlist, the 20 second timer, the crossfade, the
 * parallax, the tap-to-skip handling, the settings screen - lives in Haxe under
 * source/phoenix/wallpaper and is reached through {@link Bridge}.
 *
 * This class therefore owns nothing but the Android plumbing: it forwards the
 * engine lifecycle and never touches a Canvas. Drawing happens in Haxe, which
 * locks the surface itself (SurfaceHolder.lockCanvas / unlockCanvasAndPost).
 */
public class PhoenixWallpaperService extends WallpaperService {

    private static final String TAG = "PhoenixWallpaper";

    @Override
    public Engine onCreateEngine() {
        return new PhoenixEngine();
    }

    public class PhoenixEngine extends Engine implements SurfaceHolder.Callback {

        /** Haxe-side handle, allocated by Bridge.create(). 0 means "no engine". */
        private int id = 0;

        @Override
        public void onCreate(SurfaceHolder surfaceHolder) {
            super.onCreate(surfaceHolder);
            surfaceHolder.addCallback(this);
            // taps on empty home screen space reach the wallpaper, so Haxe can
            // implement "tap to skip to the next background"
            setTouchEventsEnabled(true);
            try {
                id = Bridge.create(getApplicationContext(), surfaceHolder);
            } catch (Throwable t) {
                id = 0;
                Log.e(TAG, "Haxe engine could not be created", t);
            }
            if (id <= 0) {
                Log.e(TAG, "wallpaper disabled: Bridge.create() returned " + id);
            }
        }

        @Override
        public void onDestroy() {
            try {
                if (id > 0) {
                    Bridge.destroy(id);
                }
            } catch (Throwable t) {
                Log.e(TAG, "destroy", t);
            } finally {
                id = 0;
            }
            super.onDestroy();
        }

        @Override
        public void onVisibilityChanged(boolean visible) {
            try {
                if (id > 0) {
                    Bridge.setVisible(id, visible);
                }
            } catch (Throwable t) {
                Log.e(TAG, "setVisible", t);
            }
        }

        @Override
        public void surfaceCreated(SurfaceHolder holder) {
            // nothing to do: Haxe starts drawing once it knows both the size
            // (surfaceChanged) and the visibility (onVisibilityChanged)
        }

        @Override
        public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            try {
                if (id > 0) {
                    Bridge.surfaceChanged(id, width, height);
                }
            } catch (Throwable t) {
                Log.e(TAG, "surfaceChanged", t);
            }
        }

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {
            try {
                if (id > 0) {
                    Bridge.surfaceDestroyed(id);
                }
            } catch (Throwable t) {
                Log.e(TAG, "surfaceDestroyed", t);
            }
        }

        @Override
        public void onOffsetsChanged(float xOffset, float yOffset, float xOffsetStep, float yOffsetStep,
                                     int xPixelOffset, int yPixelOffset) {
            try {
                if (id > 0) {
                    // Haxe Float is a Java double; float widens, so this is safe
                    Bridge.offsetsChanged(id, xOffset, yOffset, xPixelOffset, yPixelOffset);
                }
            } catch (Throwable t) {
                Log.e(TAG, "offsetsChanged", t);
            }
        }

        @Override
        public void onTouchEvent(MotionEvent event) {
            super.onTouchEvent(event);
            try {
                if (id > 0) {
                    Bridge.touch(id, event.getAction(), event.getX(), event.getY());
                }
            } catch (Throwable t) {
                Log.e(TAG, "touch", t);
            }
        }
    }
}
