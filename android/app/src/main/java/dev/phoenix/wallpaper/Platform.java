package dev.phoenix.wallpaper;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.SystemClock;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

/**
 * The three things the Haxe -&gt; Java target genuinely cannot express, in one
 * place (mirrored by the extern source/phoenix/wallpaper/Platform.hx):
 *
 * <ul>
 *   <li><b>checked exceptions</b> - AssetManager.open() and InputStream.close()
 *       throw IOException, and Haxe has no notion of checked exceptions, so a
 *       generated call site would not compile.</li>
 *   <li><b>Java long</b> - SystemClock.elapsedRealtime() returns a long; handing
 *       that back as a double keeps Haxe on its native Float.</li>
 *   <li><b>Java float</b> - Haxe Float is a double, which cannot be passed where a
 *       float is expected. Nothing here needs that today (the whole renderer uses
 *       int/Rect Canvas overloads), but this is where such a helper would go.</li>
 * </ul>
 *
 * Every method is null-safe and swallows throwables: a decode failure must cost one
 * missing slide, not the wallpaper.
 */
public final class Platform {

    public static final String TAG = "PhoenixWallpaper";

    private Platform() {
    }

    /**
     * Decodes {@code path} from the APK assets.
     *
     * @param sampleSize 1 for full resolution, 16 for the tiny copy that gets
     *                   bilinearly upscaled into the fit-mode blur backdrop.
     * @return the bitmap, or null when the asset is missing or undecodable.
     */
    public static Bitmap decodeAsset(Context context, String path, int sampleSize) {
        if (context == null || path == null || path.length() == 0) {
            return null;
        }
        InputStream in = null;
        try {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inSampleSize = Math.max(1, sampleSize);
            options.inPreferredConfig = Bitmap.Config.ARGB_8888;
            options.inScaled = false;
            in = context.getAssets().open(path);
            Bitmap bitmap = BitmapFactory.decodeStream(in, null, options);
            if (bitmap == null) {
                Log.w(TAG, "decodeStream returned null for " + path);
            }
            return bitmap;
        } catch (Throwable t) {
            Log.e(TAG, "decodeAsset failed: " + path, t);
            return null;
        } finally {
            close(in);
        }
    }

    /** Whole asset as UTF-8 text (used for fnf/slides.json), or null. */
    public static String readTextAsset(Context context, String path) {
        if (context == null || path == null || path.length() == 0) {
            return null;
        }
        InputStream in = null;
        try {
            in = context.getAssets().open(path);
            ByteArrayOutputStream out = new ByteArrayOutputStream(Math.max(1024, in.available()));
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) > 0) {
                out.write(buffer, 0, read);
            }
            return new String(out.toByteArray(), "UTF-8");
        } catch (Throwable t) {
            Log.e(TAG, "readTextAsset failed: " + path, t);
            return null;
        } finally {
            close(in);
        }
    }

    /** Filtered rescale - the second half of the cheap "blur" backdrop. */
    public static Bitmap scaled(Bitmap src, int width, int height) {
        if (src == null || width <= 0 || height <= 0) {
            return src;
        }
        try {
            return Bitmap.createScaledBitmap(src, width, height, true);
        } catch (Throwable t) {
            Log.w(TAG, "scaled failed", t);
            return src;
        }
    }

    /** Monotonic milliseconds, immune to wall clock changes. */
    public static double elapsedMs() {
        return (double) SystemClock.elapsedRealtime();
    }

    private static void close(InputStream in) {
        if (in == null) {
            return;
        }
        try {
            in.close();
        } catch (Throwable ignored) {
            // nothing useful to do
        }
    }
}
