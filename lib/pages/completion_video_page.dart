import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walkwise/pages/venue_selection_page.dart';

class CompletionVideoPage extends StatefulWidget {
  final String venueName;
  const CompletionVideoPage({super.key, required this.venueName});

  @override
  State<CompletionVideoPage> createState() => _CompletionVideoPageState();
}

class _CompletionVideoPageState extends State<CompletionVideoPage> {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  String? _videoUrl;
  bool _hasVideo = false;

  @override
  void initState() {
    super.initState();
    _loadCompletionVideo();
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadCompletionVideo() async {
    try {
      // Fetch the venue document to get the completion video URL
      final venueDoc = await FirebaseFirestore.instance
          .collection('cities')
          .where('name', isEqualTo: widget.venueName)
          .get();

      if (venueDoc.docs.isEmpty) {
        setState(() {
          _hasVideo = false;
          _isLoading = false;
        });
        return;
      }

      final venueData = venueDoc.docs.first.data();
      // Try walkwise_completion first, fall back to completion_video if not available
      String? videoUrl = venueData['walkwise_completion'] as String?;
      if (videoUrl == null || videoUrl.isEmpty) {
        videoUrl = venueData['completion_video'] as String?;
      }

      if (videoUrl == null || videoUrl.isEmpty) {
        setState(() {
          _hasVideo = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _videoUrl = videoUrl;
        _hasVideo = true;
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
      print('[CompletionVideoPage] Error loading video: $e');
      setState(() {
        _hasVideo = false;
        _isLoading = false;
      });
    }
  }

  void _goToVenueSelection() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const VenueSelectionPage()),
      (route) => false,
    );
  }

  Future<void> _goToGamesAfoot() async {
    final url = Uri.parse('https://GamesAfoot.co');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Games Afoot website')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tour Complete!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Video player (if available)
                  if (_hasVideo && _videoController != null) ...[
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Video controls
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
                    const SizedBox(height: 24),
                  ],
                  
                  // Message
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.emoji_events, size: 64, color: Colors.amber[700]),
                        const SizedBox(height: 16),
                        Text(
                          'I hope you enjoyed your WalkWise tour!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'TimeBurner',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Select another venue button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _goToVenueSelection,
                            icon: const Icon(Icons.location_city),
                            label: const Text('Select Another Venue to Tour'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'TimeBurner',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Games Afoot button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _goToGamesAfoot,
                            icon: const Icon(Icons.explore),
                            label: const Text('Learn About Our Other Walking Apps at Games Afoot'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'TimeBurner',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 