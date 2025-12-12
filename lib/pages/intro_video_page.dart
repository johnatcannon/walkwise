import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:walkwise/app_state.dart';

class IntroVideoPage extends StatefulWidget {
  const IntroVideoPage({super.key});

  @override
  State<IntroVideoPage> createState() => _IntroVideoPageState();
}

class _IntroVideoPageState extends State<IntroVideoPage> {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  String? _videoUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGreetingVideo();
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadGreetingVideo() async {
    try {
      final state = context.read<WalkWiseState>();
      final venueName = state.currentVenue;
      
      if (venueName == null) {
        setState(() {
          _error = 'No venue selected';
          _isLoading = false;
        });
        return;
      }

      // Fetch the venue document to get the greeting video URL
      final venueDoc = await FirebaseFirestore.instance
          .collection('cities')
          .where('name', isEqualTo: venueName)
          .get();

      if (venueDoc.docs.isEmpty) {
        setState(() {
          _error = 'Venue not found';
          _isLoading = false;
        });
        return;
      }

      final venueData = venueDoc.docs.first.data();
      // Try walkwise_greeting first, fall back to intro_video (Agatha greeting) if not available
      String? videoUrl = venueData['walkwise_greeting'] as String?;
      if (videoUrl == null || videoUrl.isEmpty) {
        videoUrl = venueData['intro_video'] as String?;
        if (videoUrl == null || videoUrl.isEmpty) {
          setState(() {
            _error = 'No greeting video available for this venue';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _videoUrl = videoUrl;
      });

      // Initialize video player
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();
      await _videoController!.setLooping(false);
      
      setState(() {
        _isLoading = false;
      });

      // Start playing the video
      _videoController!.play();
    } catch (e) {
      setState(() {
        _error = 'Error loading video: $e';
        _isLoading = false;
      });
    }
  }

  void _startTour() {
    _videoController?.pause();
    Navigator.pushNamed(context, '/walking');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to WalkWise'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final videoHeight = constraints.maxWidth * 16 / 9; // 9:16 portrait ratio
          return _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading greeting video...'),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _startTour,
                            child: const Text('Continue to Tour'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              // Video player (portrait, fills width, crops as needed)
                              Container(
                                width: double.infinity,
                                height: videoHeight,
                                color: Colors.black,
                                child: _videoController != null
                                    ? FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _videoController!.value.size.width,
                                          height: _videoController!.value.size.height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      )
                                    : const Center(
                                        child: Text(
                                          'Video not available',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                              ),
                              // Video controls
                              if (_videoController != null) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _videoController!.value.isPlaying
                                              ? _videoController!.pause()
                                              : _videoController!.play();
                                        });
                                      },
                                      icon: Icon(
                                        _videoController!.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        _videoController!.seekTo(Duration.zero);
                                        _videoController!.play();
                                      },
                                      icon: const Icon(Icons.replay),
                                    ),
                                  ],
                                ),
                              ],
                              const Spacer(),
                              // Start tour button
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _startTour,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: const Text(
                                      'Start Your Walking Tour',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
        },
      ),
    );
  }
} 