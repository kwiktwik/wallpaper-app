package com.example.goa_live_wallpaper

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.annotation.NonNull
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.goa_live_wallpaper/wallpaper"

    // Configure MethodChannel to handle calls from Flutter ("Set Live Wallpaper" button)
    // Supports static/video live + screen choices from dialogs
    // Uses Android APIs: WallpaperManager for static, ACTION_CHANGE_LIVE_WALLPAPER Intent + custom service for video live
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // Matches params from _setAsLiveWallpaper in lib/main.dart
            if (call.method == "setLiveWallpaper") {
                val videoPath = call.argument<String>("videoPath")  // asset path for video
                val thumbPath = call.argument<String>("thumbPath")
                val type = call.argument<String>("type")  // 'static' or 'live'
                val screen = call.argument<String>("screen")  // 'home', 'lock', 'both'
                val success = setWallpaper(videoPath, thumbPath, type, screen)
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

    // Main handler using Android wallpaper APIs based on user choices
    // Handles static (image) or live (video via service + chooser)
    // Includes copy for offline video access
    private fun setWallpaper(videoPath: String?, thumbPath: String?, type: String?, screen: String?): Boolean {
        if (videoPath == null || thumbPath == null || type == null || screen == null) return false
        return try {
            when (type) {
                "static" -> setStaticWallpaper(thumbPath, screen)
                "live" -> setVideoLiveWallpaper(videoPath, screen)
                else -> false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Static image wallpaper using WallpaperManager API (from thumb)
    private fun setStaticWallpaper(thumbPath: String, screen: String): Boolean {
        // Copy/ load asset thumb (similar to prior)
        val assetPath = "flutter_assets/$thumbPath"
        val assetManager = applicationContext.assets
        val inputStream: InputStream = assetManager.open(assetPath)
        val bitmap: Bitmap = BitmapFactory.decodeStream(inputStream)
        inputStream.close()

        val wallpaperManager = WallpaperManager.getInstance(applicationContext)
        val flags = when (screen) {
            "home" -> WallpaperManager.FLAG_SYSTEM
            "lock" -> WallpaperManager.FLAG_LOCK
            else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK  // both
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val byteStream = bitmapToInputStream(bitmap)
            wallpaperManager.setStream(byteStream, null, true, flags)
            byteStream.close()
        } else {
            wallpaperManager.setBitmap(bitmap)
        }
        return true
    }

    // Video live wallpaper using Android APIs:
    // - Copy video asset to internal storage (for MediaPlayer access)
    // - Save to prefs for VideoLiveWallpaperService
    // - Launch system Intent.ACTION_CHANGE_LIVE_WALLPAPER chooser (prompts user for home/lock screen)
    // - System dialog handles final confirmation; our service provides video
    // This fulfills video live WP requirement using native APIs
    private fun setVideoLiveWallpaper(videoPath: String, screen: String): Boolean {
        // Step: Copy asset to app's internal files dir (offline, accessible to service)
        // (task for video file path; assets not direct file:// for service)
        val internalVideoFile = copyAssetToInternalStorage(videoPath)
        if (internalVideoFile == null) return false

        // Save path to SharedPreferences for VideoLiveWallpaperService.kt to read
        val prefs: SharedPreferences = getSharedPreferences("wallpaper_prefs", MODE_PRIVATE)
        prefs.edit().putString("current_video_path", internalVideoFile.absolutePath).apply()

        // Use Android WallpaperManager Intent to launch live wallpaper chooser
        // Prompts user for screen (home/lock/both) + confirms live WP set
        // Ties to our registered service in Manifest + XML
        val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
        intent.putExtra(
            WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
            ComponentName(this, VideoLiveWallpaperService::class.java)
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)  // System UI handles user prompt/choice for screen
        return true
    }

    // Helper: Copy asset video to internal storage (e.g., /data/data/.../files/media/xxx.mp4)
    // Ensures offline access by service (no assets direct); called for live WP
    private fun copyAssetToInternalStorage(assetPath: String): File? {
        return try {
            val cleanPath = assetPath.removePrefix("assets/")  // e.g., media/xxx.mp4
            val assetFullPath = "flutter_assets/$assetPath"
            val assetManager = applicationContext.assets
            val inputStream: InputStream = assetManager.open(assetFullPath)

            // Target internal file (persistent, private)
            val internalDir = applicationContext.filesDir
            val targetFile = File(internalDir, cleanPath)
            targetFile.parentFile?.mkdirs()  // Create media/ subdir if needed

            val outputStream = FileOutputStream(targetFile)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            targetFile
        } catch (e: IOException) {
            e.printStackTrace()
            null
        }
    }

    // Helper: Bitmap to InputStream for static WallpaperManager.setStream
    private fun bitmapToInputStream(bitmap: Bitmap): InputStream {
        val baos = ByteArrayOutputStream()
        // PNG for compatibility (from webp thumb)
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, baos)
        return ByteArrayInputStream(baos.toByteArray())
    }
}
