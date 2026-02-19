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

  // Basic functionality for liking and setting as live wallpaper
  // Currently stubbed with UI feedback. For full Android live wallpaper:
  // - Extend with MethodChannel to native code
  // - Implement android/app/src/main/... WallpaperService for video
  // - Handle video file path from assets/media/
  // This keeps app offline and Android-focused
  Future<void> _setAsLiveWallpaper(Map<String, dynamic> video) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Liked! Setting "${video["data"]["dname"]}" as live wallpaper on Android'),
        duration: const Duration(seconds: 2),
      ),
    );
    // Future extension:
    // const platform = MethodChannel('com.example.goa_live_wallpaper/wallpaper');
    // await platform.invokeMethod('setLiveWallpaper', {'videoPath': video['data']['url']});
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
          // Action buttons overlay (right side like IG)
          Positioned(
            bottom: 80,
            right: 20,
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 40,
                  ),
                  onPressed: widget.onSetWallpaper,
                ),
                const Text(
                  'Like & Set',
                  style: TextStyle(color: Colors.white, backgroundColor: Colors.black54),
                ),
              ],
            ),
          ),
          // Video name/info overlay
          Positioned(
            bottom: 20,
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
