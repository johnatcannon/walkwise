import 'package:flutter/material.dart';
import 'package:walkwise/models/fun_fact.dart';
import 'package:audioplayers/audioplayers.dart';

class FunFactPage extends StatefulWidget {
  final FunFact funFact;
  final Future<void> Function()? onContinue;  // Changed to Future<void> Function()
  const FunFactPage({super.key, required this.funFact, this.onContinue});

  @override
  State<FunFactPage> createState() => _FunFactPageState();
}

class _FunFactPageState extends State<FunFactPage> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _audioFinished = false;
  bool _audioError = false;
  bool _continuePressed = false; // Guard to prevent duplicate continue presses
  int _audioRetryCount = 0;
  int _imageRetryKey = 0; // Key to force image rebuild on retry
  static const int _maxAudioRetries = 2;

  @override
  void initState() {
    super.initState();
    print('[FunFactPage] 🎬 initState called for ${widget.funFact.locationName}');
    _audioPlayer = AudioPlayer();
    // Wait 0.5 seconds after tone notification before playing audio
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _playAudio();
      }
    });
  }

  Future<void> _playAudio() async {
    print('[FunFactPage] 🔊 Starting audio playback');
    setState(() {
      _isPlaying = true;
      _audioFinished = false;
      _audioError = false;
    });
    
    try {
      // Add timeout for slow networks (30 seconds)
      await _audioPlayer.play(UrlSource(widget.funFact.audioUrl))
          .timeout(const Duration(seconds: 30));
      print('[FunFactPage] 🔊 Audio started: ${widget.funFact.audioUrl}');
      _audioPlayer.onPlayerComplete.listen((event) {
        print('[FunFactPage] ✅ Audio playback completed');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _audioFinished = true;
            _audioError = false;
            _audioRetryCount = 0;
          });
        }
      });
    } catch (e) {
      print('[FunFactPage] ❌ Error playing audio: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _audioError = true;
          // Allow continue even if audio fails (like location page)
          _audioFinished = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio unavailable. You can continue the tour.'),
            duration: const Duration(seconds: 3),
            action: _audioRetryCount < _maxAudioRetries
                ? SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      _audioRetryCount++;
                      _playAudio();
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _openImageViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header - WalkWise Green background (full width, square)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary, // WalkWise Green
            ),
            child: const Text(
              'Fun Fact!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'TimeBurner',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Content with horizontal padding (5% margins)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Fun Fact Card - 80% width with 5% margins on each side
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          spreadRadius: 1,
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.green[100]!,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Location Image - Fixed height with tap-to-zoom
                          Container(
                            height: MediaQuery.of(context).size.height * 0.35,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[100],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: GestureDetector(
                                onTap: () => _openImageViewer(widget.funFact.imageUrl),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      widget.funFact.imageUrl,
                                      key: ValueKey(_imageRetryKey),
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        print('[FunFactPage] ❌ Image load error: $error');
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported,
                                                size: 64,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Image unavailable',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _imageRetryKey++;
                                                  });
                                                },
                                                icon: const Icon(Icons.refresh, size: 18),
                                                label: const Text('Retry'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.45),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Location Name
                          Text(
                            widget.funFact.locationName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontFamily: 'TimeBurner',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Audio Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isPlaying ? Colors.blue[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isPlaying ? Colors.blue[100]! : Colors.green[100]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPlaying ? Icons.volume_up : (_audioFinished ? Icons.check_circle : Icons.headphones),
                                  size: 18,
                                  color: _isPlaying ? Colors.blue[700] : Colors.green[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isPlaying ? 'Playing audio...' : (_audioFinished ? 'Audio complete' : 'Audio ready'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isPlaying ? Colors.blue[700] : Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Audio controls
                          if (_audioFinished) ...[
                            if (!_audioError) ...[
                              TextButton.icon(
                                onPressed: _playAudio,
                                icon: const Icon(Icons.replay),
                                label: const Text('Replay Audio'),
                              ),
                            ] else ...[
                              TextButton.icon(
                                onPressed: _audioRetryCount < _maxAudioRetries
                                    ? () {
                                        _audioRetryCount++;
                                        _playAudio();
                                      }
                                    : null,
                                icon: const Icon(Icons.refresh),
                                label: Text(_audioRetryCount < _maxAudioRetries
                                    ? 'Retry Audio'
                                    : 'Audio unavailable'),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Continue Button - Outside the card, full width
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_audioFinished && widget.onContinue != null && !_continuePressed)
                          ? () async {  // Make this async
                              if (_continuePressed) {
                                print('[FunFactPage] ⚠️ Continue already pressed, ignoring duplicate');
                                return;
                              }
                              // Disable button immediately
                              setState(() {
                                _continuePressed = true;
                              });
                              print('[FunFactPage] Continue button pressed, calling callback');
                              try {
                                // Await the async callback
                                await widget.onContinue?.call();
                                print('[FunFactPage] ✅ Callback completed successfully');
                              } catch (e) {
                                print('[FunFactPage] ❌ Error in callback: $e');
                                // Re-enable button on error so user can try again
                                setState(() {
                                  _continuePressed = false;
                                });
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TimeBurner',
                        ),
                      ),
                      child: Text(
                        _audioFinished
                            ? 'Continue Walking'
                            : (_audioError
                                ? 'Continue Anyway'
                                : 'Listen to continue...'),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 