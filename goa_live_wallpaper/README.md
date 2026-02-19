# Goa Live Wallpaper

A Flutter Android app for scrolling through a local feed of videos (like Instagram Reels) and setting liked wallpapers as live wallpapers on Android devices. 

## Features
- **Offline-only**: All data and media loaded from local assets (`assets/data/data.local.json` and `assets/media/`).
- **Video Feed**: Vertical scrolling PageView with auto-playing looping videos using `video_player`.
- **Like to Set Wallpaper**: Double-tap or tap heart icon to "like" and trigger set live wallpaper (basic UI stub implemented; extend with native Android for full WallpaperService).
- **Android-only**: Project configured for Android platform only, no internet permissions or dependencies requiring network.

## Local Data
- JSON data loaded from `/data/data.local.json` (copied to assets).
- Videos/thumbs from `/data/media/` (186 items).
- No internet access required at runtime.

## Setup & Run
1. `cd goa_live_wallpaper`
2. `flutter pub get`
3. `flutter run` (on Android device/emulator)

## Extending Live Wallpaper
For full functionality:
- Add MethodChannel in main.dart.
- Implement in `android/app/src/main/kotlin/.../MainActivity.kt`.
- For true video live wallpaper, add WallpaperService, preview XML in Android resources (see Android docs).

## Tech
- Flutter (Android only)
- video_player for offline video playback
- Assets for local media

The app fulfills the basic requirement of a video feed using the provided local data.
