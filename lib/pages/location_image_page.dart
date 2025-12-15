import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:walkwise/app_state.dart';

class LocationImagePage extends StatefulWidget {
  final String locationName;
  final Future<void> Function()? onArrivedContinue;  // Changed to Future<void> Function()
  const LocationImagePage({super.key, required this.locationName, this.onArrivedContinue});

  @override
  State<LocationImagePage> createState() => _LocationImagePageState();
}

class _LocationImagePageState extends State<LocationImagePage> {
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;
  bool _isAudioLoaded = false;
  bool _audioFinished = false;
  bool _audioError = false;
  String? _locationImageUrl;
  String? _descriptionAudioUrl;
  bool _isLoadingData = true;
  bool _continuePressed = false; // Guard to prevent duplicate continue presses
  int _audioRetryCount = 0;
  int _imageRetryKey = 0; // Key to force image rebuild on retry
  static const int _maxAudioRetries = 2;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadLocationData() async {
    try {
      final state = context.read<WalkWiseState>();
      final cityId = state.currentCityId;
      
      // Query locations collection for this location
      final locationQuery = await FirebaseFirestore.instance
          .collection('locations')
          .where('city_id', isEqualTo: cityId)
          .where('name', isEqualTo: widget.locationName)
          .limit(1)
          .get();
      
      if (locationQuery.docs.isNotEmpty) {
        final locationData = locationQuery.docs.first.data();
        setState(() {
          _locationImageUrl = locationData['image'] as String?;
          // Prefer arrival_description (tour-friendly), fallback to description (game-specific)
          _descriptionAudioUrl = locationData['arrival_description'] as String? 
                               ?? locationData['description'] as String?;
          _isLoadingData = false;
        });
        // Auto-play audio when page loads (matches fun fact page behavior)
        if (_descriptionAudioUrl == null || _descriptionAudioUrl!.isEmpty) {
          print('[LocationImage] No arrival_description available for ${widget.locationName}');
          setState(() {
            _audioFinished = true; // Allow Continue when there is no audio
          });
        } else {
          // Wait 0.5 seconds after page loads before playing audio (matches fun fact page)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _playLocationDescription();
            }
          });
        }
      } else {
        setState(() {
          _isLoadingData = false;
          _audioFinished = true; // Allow Continue when no location data
        });
      }
    } catch (e) {
      print('[LocationImage] Error loading location data: $e');
      setState(() {
        _isLoadingData = false;
        _audioFinished = true; // Allow Continue when Firestore query fails
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load location data. You can continue the tour.'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _loadLocationData(),
          ),
        ),
      );
    }
  }

  Future<void> _playLocationDescription() async {
    if (_descriptionAudioUrl == null || _descriptionAudioUrl!.isEmpty) return;
    
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setSourceUrl(_descriptionAudioUrl!);
      
      setState(() {
        _isAudioLoaded = true;
        _isAudioPlaying = true;
        _audioFinished = false;
        _audioError = false;
      });
      
      // Add timeout for slow networks (30 seconds)
      await _audioPlayer!.play(UrlSource(_descriptionAudioUrl!))
          .timeout(const Duration(seconds: 30));
      
      // Listen for audio completion
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isAudioPlaying = false;
            _audioFinished = true;
            _audioError = false;
            _audioRetryCount = 0;
          });
        }
      });
    } catch (e) {
      print('[LocationImage] Error playing audio: $e');
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _audioFinished = true; // allow Continue even if audio failed (offline)
          _audioError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Audio unavailable. You can continue the tour.'),
            duration: const Duration(seconds: 3),
            action: _audioRetryCount < _maxAudioRetries
                ? SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      _audioRetryCount++;
                      _playLocationDescription();
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _replayAudio() async {
    if (_audioPlayer != null && _isAudioLoaded && !_audioError) {
      await _audioPlayer!.play(UrlSource(_descriptionAudioUrl!));
      setState(() {
        _isAudioPlaying = true;
        _audioFinished = false;
        _audioError = false;
      });
    } else if (_audioError) {
      // Retry from scratch if previous attempt failed
      _audioRetryCount++;
      _playLocationDescription();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header - WalkWise Green
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: SafeArea(
              bottom: false,
              child: Text(
                'Destination Reached!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'TimeBurner',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoadingData
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.05,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        
                        // Location Card - 80% width
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
                                // Location Image
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildLocationImage(),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Location Name
                                Text(
                                  widget.locationName,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontFamily: 'TimeBurner',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Audio Status Badge (if audio available)
                                if (_descriptionAudioUrl != null && _descriptionAudioUrl!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isAudioPlaying
                                          ? Colors.blue[50]
                                          : (_audioFinished ? Colors.green[50] : Colors.orange[50]),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _isAudioPlaying
                                            ? Colors.blue[100]!
                                            : (_audioFinished ? Colors.green[100]! : Colors.orange[100]!),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isAudioPlaying
                                              ? Icons.volume_up
                                              : (_audioFinished ? Icons.check_circle : Icons.play_circle_fill),
                                          size: 18,
                                          color: _isAudioPlaying
                                              ? Colors.blue[700]
                                              : (_audioFinished ? Colors.green[700] : Colors.orange[700]),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isAudioPlaying
                                              ? 'Playing description...'
                                              : (_audioFinished
                                                  ? 'Description ready'
                                                  : 'Tap play to listen'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _isAudioPlaying
                                                ? Colors.blue[700]
                                                : (_audioFinished ? Colors.green[700] : Colors.orange[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Play / Replay / Retry button
                                  if (!_audioError) ...[
                                    TextButton.icon(
                                      onPressed: _isAudioPlaying ? null : _playLocationDescription,
                                      icon: Icon(_audioFinished ? Icons.replay : Icons.play_arrow),
                                      label: Text(_audioFinished ? 'Replay Description' : 'Play Description'),
                                    ),
                                  ] else ...[
                                    TextButton.icon(
                                      onPressed: _audioRetryCount < _maxAudioRetries
                                          ? () {
                                              _audioRetryCount++;
                                              _playLocationDescription();
                                            }
                                          : null,
                                      icon: const Icon(Icons.refresh),
                                      label: Text(_audioRetryCount < _maxAudioRetries
                                          ? 'Retry Audio'
                                          : 'Audio unavailable'),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Audio unavailable. You can continue.',
                                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Continue Button - Outside card (disabled until audio finishes, like fun facts)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_audioFinished && !_continuePressed && widget.onArrivedContinue != null)
                                ? () async {
                                    if (_continuePressed) {
                                      print('[LocationImagePage] ⚠️ Continue already pressed, ignoring duplicate');
                                      return;
                                    }
                                    setState(() {
                                      _continuePressed = true;
                                    });
                                    print('[LocationImagePage] Continue button pressed, calling callback');
                                    try {
                                      await widget.onArrivedContinue?.call();
                                      print('[LocationImagePage] ✅ Callback completed successfully');
                                    } catch (e) {
                                      print('[LocationImagePage] ❌ Error in callback: $e');
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
                                  ? 'Continue Tour'
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

  Widget _buildLocationImage() {
    if (_locationImageUrl != null && _locationImageUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _openImageViewer(_locationImageUrl!),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _locationImageUrl!,
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
                print('[LocationImage] ❌ Image load error: $error');
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
      );
    } else {
      return Center(
        child: Icon(
          Icons.location_on,
          size: 80,
          color: Colors.grey[400],
        ),
      );
    }
  }

  void _openImageViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Stack(
              children: [
                // Full-screen InteractiveViewer that stretches to viewport so landscape images can fill height
                SizedBox.expand(
                  child: InteractiveViewer(
                    minScale: 0.1,
                    maxScale: 5.0,
                    child: Center(
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
                ),
                // Close button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 