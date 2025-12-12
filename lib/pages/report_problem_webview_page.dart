import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:walkwise/services/onboarding_coordinator.dart';

class ReportProblemWebViewPage extends StatefulWidget {
  const ReportProblemWebViewPage({super.key});

  @override
  State<ReportProblemWebViewPage> createState() => _ReportProblemWebViewPageState();
}

class _ReportProblemWebViewPageState extends State<ReportProblemWebViewPage> {
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
      final profileUrl = 'https://gamesafoot.co/report-problem/?app=walkwise&version=$version&email=$email';

      print('[ReportProblemWebView] Loading problem report form: $profileUrl');

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              print('[ReportProblemWebView] Page started loading: $url');
            },
            onPageFinished: (String url) async {
              print('[ReportProblemWebView] Page finished loading: $url');
              
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              print('[ReportProblemWebView] Error: ${error.description}');
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
          'ProblemReportChannel',
          onMessageReceived: (JavaScriptMessage message) {
            print('[ReportProblemWebView] Received message from web: ${message.message}');
            _handleProblemReport(message.message);
          },
        )
        ..loadRequest(Uri.parse(profileUrl));
    } catch (e) {
      print('[ReportProblemWebView] Error initializing: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleProblemReport(String messageJson) async {
    try {
      final data = jsonDecode(messageJson) as Map<String, dynamic>;
      
      // Check if this is a close action
      if (data['action'] == 'close') {
        print('[ReportProblemWebView] Closing webview');
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      print('[ReportProblemWebView] Saving problem report to Firestore: $data');

      // Save to Firestore problem_report collection
      await FirebaseFirestore.instance.collection('problem_report').add({
        ...data,
        'submitted_at': FieldValue.serverTimestamp(),
        'user_id': FirebaseAuth.instance.currentUser?.uid,
      });

      print('[ReportProblemWebView] Problem report saved successfully');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your report has been submitted.'),
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
      print('[ReportProblemWebView] Error handling problem report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
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
          'Report a Problem',
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
            'Loading problem report form...',
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

