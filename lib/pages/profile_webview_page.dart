import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walkwise/services/onboarding_coordinator.dart';

class ProfileWebViewPage extends StatefulWidget {
  const ProfileWebViewPage({super.key});

  @override
  State<ProfileWebViewPage> createState() => _ProfileWebViewPageState();
}

class _ProfileWebViewPageState extends State<ProfileWebViewPage> {
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    // Load existing profile data first
    Map<String, dynamic>? existingProfile;
    try {
      final profileQuery = await FirebaseFirestore.instance
          .collection('player_profile')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      
      if (profileQuery.docs.isNotEmpty) {
        existingProfile = profileQuery.docs.first.data();
        print('[ProfileWebView] Found existing profile: ${existingProfile['player_name']}');
      } else {
        print('[ProfileWebView] No existing profile found, will create new one');
      }
    } catch (e) {
      print('[ProfileWebView] Error loading profile: $e');
      // Continue anyway - form will just be empty
    }

    // Build URL with user parameters - using unified Games Afoot form
    final email = Uri.encodeComponent(user.email ?? '');
    final uid = Uri.encodeComponent(user.uid);
    final profileUrl = 'https://gamesafoot.co/profile-setup/?app=walkwise&email=$email&uid=$uid';

    print('[ProfileWebView] Loading unified profile form: $profileUrl');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[ProfileWebView] Page started loading: $url');
          },
          onPageFinished: (String url) async {
            print('[ProfileWebView] Page finished loading: $url');
            
            // Pre-fill form with existing profile data if available
            if (existingProfile != null) {
              await _prefillForm(existingProfile);
            }
            
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('[ProfileWebView] Error: ${error.description}');
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
        'ProfileChannel',
        onMessageReceived: (JavaScriptMessage message) {
          print('[ProfileWebView] Received message from web: ${message.message}');
          _handleProfileData(message.message);
        },
      )
      ..loadRequest(Uri.parse(profileUrl));
  }

  Future<void> _prefillForm(Map<String, dynamic> profile) async {
    try {
      // Extract firstName and lastName - handle both formats
      String firstName = profile['firstName']?.toString() ?? '';
      String lastName = profile['lastName']?.toString() ?? '';
      
      // If we have player_name but not firstName/lastName, try to split it
      if (firstName.isEmpty && lastName.isEmpty) {
        final playerName = profile['player_name']?.toString() ?? '';
        if (playerName.isNotEmpty) {
          final parts = playerName.trim().split(' ');
          if (parts.length >= 2) {
            firstName = parts[0];
            lastName = parts.sublist(1).join(' ');
          } else if (parts.length == 1) {
            firstName = parts[0];
          }
        }
      }
      
      // Build JavaScript to pre-fill form fields with proper escaping
      final ageRange = profile['ageRange']?.toString() ?? '';
      final mobile = profile['mobile']?.toString() ?? '';
      final stepAverage = profile['userReportedStepAverage']?.toString() ?? '';
      final deviceType = profile['deviceType']?.toString() ?? '';
      final deviceModel = profile['deviceModel']?.toString() ?? '';
      
      // Escape single quotes for JavaScript
      String escapeJs(String? value) {
        if (value == null || value.isEmpty) return '';
        return value.replaceAll("'", "\\'").replaceAll('\n', '\\n');
      }
      
      final js = '''
        (function() {
          try {
            var firstNameEl = document.getElementById('firstName');
            var lastNameEl = document.getElementById('lastName');
            var ageRangeEl = document.getElementById('ageRange');
            var mobileEl = document.getElementById('mobile');
            var stepAverageEl = document.getElementById('userReportedStepAverage');
            var deviceTypeEl = document.getElementById('deviceType');
            var deviceModelEl = document.getElementById('deviceModel');
            
            ${firstName.isNotEmpty ? "if (firstNameEl) firstNameEl.value = '${escapeJs(firstName)}';" : ''}
            ${lastName.isNotEmpty ? "if (lastNameEl) lastNameEl.value = '${escapeJs(lastName)}';" : ''}
            ${ageRange.isNotEmpty ? "if (ageRangeEl) ageRangeEl.value = '${escapeJs(ageRange)}';" : ''}
            ${mobile.isNotEmpty ? "if (mobileEl) mobileEl.value = '${escapeJs(mobile)}';" : ''}
            ${stepAverage.isNotEmpty ? "if (stepAverageEl) stepAverageEl.value = '$stepAverage';" : ''}
            ${deviceType.isNotEmpty ? "if (deviceTypeEl) deviceTypeEl.value = '${escapeJs(deviceType)}';" : ''}
            ${deviceModel.isNotEmpty ? "if (deviceModelEl) deviceModelEl.value = '${escapeJs(deviceModel)}';" : ''}
            
            console.log('Profile form pre-filled successfully');
            return true;
          } catch (e) {
            console.error('Error pre-filling form:', e);
            return false;
          }
        })();
      ''';
      
      await _controller.runJavaScript(js);
      print('[ProfileWebView] Form pre-filled with existing profile data');
    } catch (e) {
      print('[ProfileWebView] Error pre-filling form: $e');
      // Don't show error to user - form will just be empty
    }
  }

  Future<void> _handleProfileData(String jsonData) async {
    try {
      final data = jsonDecode(jsonData);
      print('[ProfileWebView] Profile data received: $data');

      // Check if this is a close action
      if (data['action'] == 'close') {
        print('[ProfileWebView] Received close action from webview');
        if (mounted) {
          // Just close the WebView and go back
          Navigator.pop(context);
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('[ProfileWebView] User not authenticated');
        return;
      }

      // Save profile to Firestore
      await _saveProfile(user.email!, data);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Close WebView and return to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      print('[ProfileWebView] Error handling profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile(String email, Map<String, dynamic> data) async {
    print('[ProfileWebView] Saving profile for: $email');

    // Query for existing profile
    final profileQuery = await FirebaseFirestore.instance
        .collection('player_profile')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (profileQuery.docs.isEmpty) {
      // Create new profile - add WalkWise to apps_used
      print('[ProfileWebView] Creating new WalkWise profile');
      data['apps_used'] = ['WalkWise'];
      data['walkwise_first_opened'] = DateTime.now().toIso8601String();
      data['created_at'] = DateTime.now().toIso8601String();
      await FirebaseFirestore.instance.collection('player_profile').add(data);
    } else {
      // Update existing profile (likely from Agatha)
      print('[ProfileWebView] Updating existing Games Afoot profile');
      final existingData = profileQuery.docs.first.data();
      final appsUsed = List<String>.from(existingData['apps_used'] ?? []);
      
      // Add WalkWise to apps_used if not already there
      if (!appsUsed.contains('WalkWise')) {
        appsUsed.add('WalkWise');
        data['walkwise_first_opened'] = DateTime.now().toIso8601String();
      }
      data['apps_used'] = appsUsed;
      
      // Don't update created_at - preserve original
      data.remove('created_at');
      
      // Only update core fields, don't overwrite Agatha-specific data
      await profileQuery.docs.first.reference.update(data);
    }

    print('[ProfileWebView] Profile saved successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
            'Loading profile form...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
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
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Profile Form',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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

