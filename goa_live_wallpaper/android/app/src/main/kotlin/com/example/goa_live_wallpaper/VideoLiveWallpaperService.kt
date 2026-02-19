package com.example.goa_live_wallpaper

import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import android.media.MediaPlayer
import android.content.SharedPreferences
import android.util.Log
import java.io.IOException

/**
 * Native Android WallpaperService for video live wallpaper.
 * Uses MediaPlayer + SurfaceHolder to play MP4 video as live wallpaper.
 * Called via system chooser when user selects "Video Live Wallpaper" type.
 * All offline using local (copied) video files; pure Android APIs.
 */
class VideoLiveWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine {
        return VideoEngine()
    }

    inner class VideoEngine : Engine() {
        private var mediaPlayer: MediaPlayer? = null
        private val prefs: SharedPreferences = getSharedPreferences("wallpaper_prefs", MODE_PRIVATE)

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            mediaPlayer = MediaPlayer()
            mediaPlayer?.isLooping = true  // Loop like feed videos
        }

        // Set up video when surface ready (MP4 from internal storage)
        // Mute audio for wallpaper use (no sound on home/lock screen; per product requirement)
        // Uses Android MediaPlayer API; keeps offline
        override fun onSurfaceCreated(holder: SurfaceHolder?) {
            super.onSurfaceCreated(holder)
            try {
                // Video path set by MainActivity (copied asset for service access)
                val videoPath = prefs.getString("current_video_path", null)
                if (videoPath != null) {
                    mediaPlayer?.setDataSource(videoPath)
                    mediaPlayer?.setSurface(holder?.surface)
                    mediaPlayer?.prepare()
                    mediaPlayer?.setVolume(0f, 0f)  // Mute audio
                    mediaPlayer?.start()
                    Log.d("VideoLiveWP", "Started silent live video wallpaper: $videoPath")
                }
            } catch (e: IOException) {
                Log.e("VideoLiveWP", "Error setting up video live wallpaper", e)
            }
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder?) {
            super.onSurfaceDestroyed(holder)
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        }

        // Handle visibility (pause when not visible to save battery)
        override fun onVisibilityChanged(visible: Boolean) {
            super.onVisibilityChanged(visible)
            if (visible) {
                mediaPlayer?.start()
            } else {
                mediaPlayer?.pause()
            }
        }
    }
}