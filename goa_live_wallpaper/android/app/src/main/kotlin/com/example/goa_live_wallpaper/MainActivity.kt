package com.example.goa_live_wallpaper

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.WallpaperManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.annotation.NonNull
import java.io.IOException
import java.io.InputStream
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.goa_live_wallpaper/wallpaper"

    // Configure MethodChannel to handle calls from Flutter (e.g., from "Set Live Wallpaper" button)
    // This integrates Android's WallpaperManager API for setting wallpaper from local thumbnail
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // Matches channel in _setAsLiveWallpaper (lib/main.dart)
            if (call.method == "setLiveWallpaper") {
                val thumbPath = call.argument<String>("thumbPath")
                val success = setWallpaperFromAsset(thumbPath)
                if (success) {
                    result.success(true)
                } else {
                    result.error("UNAVAILABLE", "Failed to set wallpaper", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // Uses Android WallpaperManager to set image-based wallpaper from local asset thumb
    // (webp thumbs from data/media/; video itself for "live" intent stubbed via image)
    // Keeps offline: loads via AssetManager, no network
    // For true animated/video live wallpaper, extend with WallpaperService + MP4 MediaPlayer
    private fun setWallpaperFromAsset(thumbPath: String?): Boolean {
        if (thumbPath == null) return false
        try {
            // Asset path in APK: e.g., flutter_assets/assets/media/12-hanuman-chalisa-thumb.webp
            // (Flutter assets prefixed; matches copied data/media/ thumbs)
            val assetPath = "flutter_assets/$thumbPath"
            val assetManager = applicationContext.assets
            val inputStream: InputStream = assetManager.open(assetPath)
            val bitmap: Bitmap = BitmapFactory.decodeStream(inputStream)
            inputStream.close()

            val wallpaperManager = WallpaperManager.getInstance(applicationContext)

            // Set for both home and lock screen using Android API (API 24+ for flags)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Convert Bitmap to InputStream for setStream (supports cropping/scrolling)
                val byteStream = bitmapToInputStream(bitmap)
                wallpaperManager.setStream(
                    byteStream,
                    null,  // visible rect
                    true,  // allow backup
                    WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                )
                byteStream.close()
            } else {
                // Fallback for older Android
                wallpaperManager.setBitmap(bitmap)
            }
            return true
        } catch (e: IOException) {
            e.printStackTrace()
            return false
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    // Helper: Bitmap to InputStream for WallpaperManager.setStream
    private fun bitmapToInputStream(bitmap: Bitmap): InputStream {
        val baos = ByteArrayOutputStream()
        // Compress as PNG for broad compatibility (thumbs are webp but output neutral)
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, baos)
        return ByteArrayInputStream(baos.toByteArray())
    }
}
