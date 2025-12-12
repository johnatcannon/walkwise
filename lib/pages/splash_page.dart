import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:walkwise/services/onboarding_coordinator.dart';
import 'package:walkwise/pages/venue_selection_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _walkwiseVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    // Show splash for 2 seconds, then check onboarding state
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _checkOnboardingState();
      }
    });
  }

  Future<void> _checkOnboardingState() async {
    try {
      print('[SplashPage] Checking onboarding state...');
      final destination = await OnboardingCoordinator.determineNextStep();
      
      if (mounted) {
        print('[SplashPage] Navigating to: ${destination.step}');
        await destination.navigate(context);
      }
    } catch (e) {
      print('[SplashPage] Error during onboarding check: $e');
      // On error, just go to login to be safe
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const VenueSelectionPage()),
        );
      }
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _walkwiseVersion = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A896), // WalkWise primary green
      body: SafeArea(
        child: Stack(
          children: [
            // Centered content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/WalkWise-Green-logo.png', width: 150),
                  const SizedBox(height: 24),
                  const Text(
                    'WalkWise',
                    style: TextStyle(
                      fontFamily: 'TimeBurner',
                      fontWeight: FontWeight.bold,
                      fontSize: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '#Every Step a Story',
                    style: TextStyle(
                      fontFamily: 'TimeBurner',
                      fontSize: 22,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Version info at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                children: [
                  Text(
                    _walkwiseVersion.isEmpty
                        ? 'Loading version...'
                        : 'WalkWise v$_walkwiseVersion',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Patent Pending',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
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