import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walkwise/pages/venue_selection_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class TourCompletionPage extends StatefulWidget {
  final String venueName;
  const TourCompletionPage({super.key, required this.venueName});

  @override
  State<TourCompletionPage> createState() => _TourCompletionPageState();
}

class _TourCompletionPageState extends State<TourCompletionPage> {
  AudioPlayer? _audioPlayer;
  bool _isLoadingAudio = false;
  bool _audioFinished = false;
  bool _hasAudio = false;
  String? _completionAudioUrl;

  @override
  void initState() {
    super.initState();
    _loadCompletionAudio();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadCompletionAudio() async {
    try {
      // Fetch the venue document to get the completion audio URL
      final venueDoc = await FirebaseFirestore.instance
          .collection('cities')
          .where('name', isEqualTo: widget.venueName)
          .get();

      if (venueDoc.docs.isEmpty) {
        setState(() {
          _hasAudio = false;
          _audioFinished = true; // Allow interaction even without audio
        });
        return;
      }

      final venueData = venueDoc.docs.first.data();
      // Try walkwise_completion_audio first, fall back to completion_audio if not available
      String? audioUrl = venueData['walkwise_completion_audio'] as String?;
      if (audioUrl == null || audioUrl.isEmpty) {
        audioUrl = venueData['completion_audio'] as String?;
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        setState(() {
          _hasAudio = false;
          _audioFinished = true; // Allow interaction even without audio
        });
        return;
      }

      setState(() {
        _completionAudioUrl = audioUrl;
        _hasAudio = true;
        _isLoadingAudio = true;
      });

      // Initialize audio player
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.play(UrlSource(audioUrl));
      
      setState(() {
        _isLoadingAudio = false;
      });

      // Listen for audio completion
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _audioFinished = true;
          });
        }
      });
    } catch (e) {
      print('[TourCompletionPage] Error loading audio: $e');
      setState(() {
        _hasAudio = false;
        _audioFinished = true; // Allow interaction even if audio failed
      });
    }
  }

  Future<void> _replayAudio() async {
    if (_audioPlayer != null && _completionAudioUrl != null) {
      try {
        await _audioPlayer!.play(UrlSource(_completionAudioUrl!));
        setState(() {
          _audioFinished = false;
        });
        _audioPlayer!.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _audioFinished = true;
            });
          }
        });
      } catch (e) {
        print('[TourCompletionPage] Error replaying audio: $e');
      }
    }
  }

  void _goToVenueSelection() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const VenueSelectionPage()),
      (route) => false,
    );
  }

  void _goToFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackWebViewPage(),
      ),
    );
  }

  Future<void> _shareOnSocialMedia() async {
    final shareText = 'Enjoyed your tour of ${widget.venueName}?\n\n'
        'Give your friends the gift of adventure!\n\n'
        'Visit goWalkWise.com to start your own walking tour!\n\n'
        '<<SHARE>>';
    
    try {
      await Share.share(shareText);
    } catch (e) {
      print('[TourCompletionPage] Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
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
      backgroundColor: const Color(0xFFF0F0F0), // Light gray with similar saturation to green
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Foot Logo
              Image.asset(
                'assets/images/WalkWise-Green-logo.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 32),
              
              // Completion Message
              Text(
                'Tour Complete!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'TimeBurner',
                  color: const Color(0xFF00A896), // WalkWise green
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Audio Player (if available)
              if (_hasAudio && _completionAudioUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A896).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00A896).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoadingAudio)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A896)),
                          ),
                        )
                      else
                        IconButton(
                          onPressed: _audioFinished ? _replayAudio : null,
                          icon: Icon(
                            _audioFinished ? Icons.replay : Icons.volume_up,
                            color: const Color(0xFF00A896),
                            size: 32,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isLoadingAudio
                            ? 'Loading audio...'
                            : _audioFinished
                                ? 'Audio complete'
                                : 'Playing completion message...',
                        style: const TextStyle(
                          color: Color(0xFF00A896),
                          fontFamily: 'TimeBurner',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Thank You Message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _hasAudio
                          ? 'Thank you for taking a WalkWise tour of ${widget.venueName}!'
                          : 'Thank you for taking a WalkWise tour of ${widget.venueName}!\n\n'
                              'Please explore other venues, send us feedback, share on social media, and explore our Games Afoot games.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'TimeBurner',
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              _buildActionButton(
                icon: Icons.location_city,
                label: 'Select Another Venue',
                onPressed: _goToVenueSelection,
                isPrimary: true,
              ),
              const SizedBox(height: 16),
              
              _buildActionButton(
                icon: Icons.feedback,
                label: 'Submit Feedback',
                onPressed: _goToFeedback,
                isPrimary: false,
              ),
              const SizedBox(height: 16),
              
              _buildActionButton(
                icon: Icons.share,
                label: 'Share on Social Media',
                onPressed: _shareOnSocialMedia,
                isPrimary: false,
              ),
              const SizedBox(height: 16),
              
              _buildActionButton(
                icon: Icons.explore,
                label: 'Explore Games Afoot',
                onPressed: _goToGamesAfoot,
                isPrimary: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF00A896),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'TimeBurner',
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00A896),
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Color(0xFF00A896), width: 2),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'TimeBurner',
            ),
          ),
        ),
      );
    }
  }
}

/// Feedback WebView Page (similar to ReportProblemWebViewPage)
class FeedbackWebViewPage extends StatefulWidget {
  const FeedbackWebViewPage({super.key});

  @override
  State<FeedbackWebViewPage> createState() => _FeedbackWebViewPageState();
}

class _FeedbackWebViewPageState extends State<FeedbackWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      // Build URL with app and version parameters
      final email = Uri.encodeComponent(FirebaseAuth.instance.currentUser?.email ?? '');
      final version = Uri.encodeComponent(appVersion);
      final feedbackUrl = 'https://gowalkwise.com/feedback.html?app=walkwise&version=$version&email=$email';

      print('[FeedbackWebView] Loading feedback form: $feedbackUrl');

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              print('[FeedbackWebView] Page started loading: $url');
            },
            onPageFinished: (String url) async {
              print('[FeedbackWebView] Page finished loading: $url');
              
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              print('[FeedbackWebView] Error: ${error.description}');
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..addJavaScriptChannel(
          'FeedbackChannel',
          onMessageReceived: (JavaScriptMessage message) {
            print('[FeedbackWebView] Received message from web: ${message.message}');
            _handleFeedback(message.message);
          },
        )
        ..loadRequest(Uri.parse(feedbackUrl));
    } catch (e) {
      print('[FeedbackWebView] Error initializing: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleFeedback(String messageJson) async {
    try {
      final data = jsonDecode(messageJson) as Map<String, dynamic>;
      
      // Check if this is a close action
      if (data['action'] == 'close') {
        print('[FeedbackWebView] Closing webview');
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      print('[FeedbackWebView] Saving feedback to Firestore: $data');

      // Save to Firestore feedback collection
      await FirebaseFirestore.instance.collection('feedback').add({
        ...data,
        'submitted_at': FieldValue.serverTimestamp(),
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'app': 'walkwise',
      });

      print('[FeedbackWebView] Feedback saved successfully');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Close after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      print('[FeedbackWebView] Error handling feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Submit Feedback',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'TimeBurner',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _hasError
            ? _buildErrorState()
            : _isLoading
                ? _buildLoadingState()
                : WebViewWidget(controller: _controller),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading feedback form...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontFamily: 'TimeBurner',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load form',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _initializeWebView();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

