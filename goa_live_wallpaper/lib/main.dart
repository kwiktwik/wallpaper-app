import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goa Live Wallpaper',
      theme: ThemeData(
        // This is the theme of your application.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VideoFeedPage(),
    );
  }
}

class VideoFeedPage extends StatefulWidget {
  const VideoFeedPage({super.key});

  @override
  State<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  List<dynamic> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  // Load videos from local JSON data - no internet required
  Future<void> _loadVideos() async {
    try {
      // Use rootBundle for loading assets/data/data.local.json
      final String jsonString = await rootBundle.loadString('assets/data/data.local.json');
      final List<dynamic> videos = json.decode(jsonString);
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ignore: avoid_print for basic error logging
      print('Error loading videos: $e');
    }
  }

  // Platform channel for communicating with native Android code to set wallpaper
  // Channel name matches the one in MainActivity.kt
  static const platform = MethodChannel('com.example.goa_live_wallpaper/wallpaper');

  // Functionality for "Set Live Wallpaper" button (at bottom with breathing space)
  // Prompts user via Flutter dialog for:
  // - Type: static (image/thumb via WallpaperManager) or video live (via custom WallpaperService)
  // - Then delegates to native Android APIs for screen choice (home/lock/both via system chooser)
  // Uses Android APIs: WallpaperManager + Intent.ACTION_CHANGE_LIVE_WALLPAPER for live
  // Keeps offline (local assets); Android-only
  // Breathing space in UI ensures button visibility
  Future<void> _setAsLiveWallpaper(Map<String, dynamic> video) async {
    if (!mounted) return;

    // Construct paths from JSON (local assets only)
    final String videoUrl = video['data']['url'] as String;  // e.g., media/xxx.mp4
    final String videoPath = 'assets/$videoUrl';
    final String thumbUrl = video['data']['thumb'] as String;
    final String thumbPath = 'assets/$thumbUrl';
    final String dname = video['data']['dname'] ?? 'Wallpaper';

    // Step 1: Flutter dialog to choose static vs video live wallpaper (per request)
    final wallpaperType = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Set Wallpaper for "$dname"'),
        content: const Text('Choose type:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'static'),
            child: const Text('Static Image'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'live'),
            child: const Text('Video Live Wallpaper'),
          ),
        ],
      ),
    );

    if (wallpaperType == null || !mounted) return;  // User cancelled

    // Step 2: Optional screen choice dialog (home/lock/both); native chooser will also prompt
    final screenChoice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Choose Screen'),
        content: const Text('Where to set the wallpaper?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'home'),
            child: const Text('Home Screen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'lock'),
            child: const Text('Lock Screen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'both'),
            child: const Text('Both'),
          ),
        ],
      ),
    );

    if (screenChoice == null || !mounted) return;

    try {
      // Invoke native Android method with choices + paths
      // Native handles: static=WallpaperManager, live=system live chooser + service
      // Uses pure Android APIs; offline via assets/internal files
      final bool success = await platform.invokeMethod<bool>(
        'setLiveWallpaper',
        {
          'videoPath': videoPath,
          'thumbPath': thumbPath,
          'type': wallpaperType,  // 'static' or 'live'
          'screen': screenChoice,  // 'home', 'lock', 'both'
        },
      ) ?? false;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Wallpaper set for "$dname" ($wallpaperType on $screenChoice screen)!'
                : 'Failed to set $wallpaperType wallpaper for "$dname"',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting wallpaper: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      // ignore: avoid_print for basic logging
      print('Platform error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_videos.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No videos found')),
      );
    }
    // Use vertical PageView for Instagram-like scrolling feed of videos
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goa Live Wallpaper Feed'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];
          // Construct asset path: json "media/xxx.mp4" -> "assets/media/xxx.mp4"
          // This uses local files from data/media/ copied to assets
          final String mediaUrl = video['data']['url'] as String;
          final String videoPath = 'assets/$mediaUrl';
          return VideoFeedItem(
            videoPath: videoPath,
            videoData: video,
            onSetWallpaper: () => _setAsLiveWallpaper(video),
          );
        },
      ),
    );
  }
}

class VideoFeedItem extends StatefulWidget {
  final String videoPath;
  final Map<String, dynamic> videoData;
  final VoidCallback onSetWallpaper;

  const VideoFeedItem({
    super.key,
    required this.videoPath,
    required this.videoData,
    required this.onSetWallpaper,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset(widget.videoPath);
    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      await _controller.play();
      await _controller.setLooping(true);
    } catch (e) {
      // ignore: avoid_print for basic error logging in feed
      print('Error initializing video ${widget.videoPath}: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    // Fullscreen video like reels, cover fit for different aspect ratios
    return GestureDetector(
      // Double-tap to like/set wallpaper like Instagram
      onDoubleTap: widget.onSetWallpaper,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // VideoPlayer with FittedBox to cover screen
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          // Like icon remains on right (subtle, like IG)
          Positioned(
            bottom: 120,  // Adjusted up to make space for bottom button
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 40,
              ),
              onPressed: widget.onSetWallpaper,
            ),
          ),
          // Video name/info overlay (left side)
          Positioned(
            bottom: 100,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                widget.videoData['data']['dname'] ?? 'Wallpaper',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          // New prominent "Set Live Wallpaper" button at bottom center
          // With breathing space: padding/margins (20px from edges, elevated above play/info overlays)
          // Calls the wallpaper setter for Android
          Positioned(
            bottom: 20,  // Bottom positioning with space
            left: 20,
            right: 20,   // Full width breathing from sides
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),  // Extra breathing space
              child: ElevatedButton.icon(
                onPressed: widget.onSetWallpaper,
                icon: const Icon(Icons.wallpaper),
                label: const Text(
                  'Set Live Wallpaper',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),  // Internal padding for button
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ),
          // Center play/pause control
          Center(
            child: IconButton(
              iconSize: 60,
              // Use withAlpha instead of deprecated withOpacity for Flutter compatibility
              color: Colors.white.withAlpha(178), // approx 0.7 opacity (178/255)
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
              ),
              onPressed: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
