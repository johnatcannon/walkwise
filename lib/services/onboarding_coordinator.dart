import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:walkwise/pages/login_page.dart';
import 'package:walkwise/pages/venue_selection_page.dart';
import 'package:walkwise/pages/settings_page.dart';
import 'package:walkwise/pages/profile_webview_page.dart';
import 'package:walkwise/pages/walking_page.dart';
import 'package:walkwise/app_state.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:games_afoot_health/health_service.dart';
import 'package:walkwise/services/tour_state_service.dart';

/// Coordinates the onboarding flow for WalkWise
/// Determines where to send the user based on their current state
class OnboardingCoordinator {
  static const String _tag = '[OnboardingCoordinator]';

  /// Determine the next step in the onboarding process
  /// Returns the appropriate destination based on user state
  static Future<OnboardingDestination> determineNextStep() async {
    print('$_tag Starting onboarding check...');

    // Step 1: Check authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('$_tag User not authenticated -> Login');
      return OnboardingDestination.login();
    }
    print('$_tag User authenticated: ${user.email}');

    // Step 2: Check if profile exists and is complete
    final profileCheck = await _checkProfile(user.email!);
    if (!profileCheck.exists) {
      print('$_tag Profile does not exist -> Redirect to website');
      return OnboardingDestination.profileSetupRequired();
    }
    if (!profileCheck.isComplete) {
      print('$_tag Profile incomplete -> Redirect to website');
      return OnboardingDestination.profileSetupRequired();
    }
    print('$_tag Profile complete');

    // Step 3: Check permissions
    final permissionsGranted = await _checkPermissions();
    if (!permissionsGranted) {
      print('$_tag Permissions needed -> Settings');
      return OnboardingDestination.permissions();
    }
    print('$_tag Permissions granted');

    // Step 4: Check if user has a saved tour state
    final hasSavedTour = await TourStateService.hasSavedTourState();
    if (hasSavedTour) {
      print('$_tag Saved tour state found -> Resume Walk');
      return OnboardingDestination.resumeWalk();
    }

    // Step 5: All checks passed -> Venue Selection
    print('$_tag All checks passed -> Venue Selection');
    return OnboardingDestination.venueSelection();
  }

  /// Check if user profile exists and is complete
  /// Uses unified Games Afoot profile - checks for ANY profile with player_name/initials
  /// This allows WalkWise to use existing Agatha profiles (shared account system)
  static Future<ProfileCheckResult> _checkProfile(String email) async {
    try {
      final profileQuery = await FirebaseFirestore.instance
          .collection('player_profile')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (profileQuery.docs.isEmpty) {
        print('$_tag No profile found for $email');
        return ProfileCheckResult(exists: false, isComplete: false);
      }

      final profileData = profileQuery.docs.first.data();
      
      // Check required fields (shared across all Games Afoot apps)
      final hasName = profileData['player_name'] != null && 
                     (profileData['player_name'] as String).isNotEmpty;
      final hasInitials = profileData['player_initials'] != null && 
                         (profileData['player_initials'] as String).isNotEmpty;
      final hasHandicap = profileData['handicap'] != null;

      final isComplete = hasName && hasInitials && hasHandicap;
      
      // Log which app created this profile (for debugging)
      final createdByApp = profileData['app'] ?? 'Unknown';
      print('$_tag Profile check: exists=true, complete=$isComplete, created_by=$createdByApp');
      print('$_tag   name=$hasName, initials=$hasInitials, handicap=$hasHandicap');
      
      if (isComplete) {
        print('$_tag Using existing Games Afoot profile - no setup needed!');
      }
      
      return ProfileCheckResult(exists: true, isComplete: isComplete);
    } catch (e) {
      print('$_tag Error checking profile: $e');
      return ProfileCheckResult(exists: false, isComplete: false);
    }
  }

  /// Check / request required permissions
  /// On Android: Activity Recognition (pedometer)
  /// On iOS: Skip permission checks (pedometer handles automatically, matches Agatha)
  static Future<bool> _checkPermissions() async {
    try {
      if (Platform.isIOS) {
        // iOS pedometer doesn't require explicit permissions
        // NSMotionUsageDescription in Info.plist is sufficient
        print('$_tag iOS detected, skipping permission checks (matches Agatha)');
        return true;
      } else {
        // Android: Activity Recognition
        final status = await Permission.activityRecognition.status;
        print('$_tag Activity Recognition: $status');
        if (status.isDenied) {
          final req = await Permission.activityRecognition.request();
          print('$_tag Activity Recognition request result: $req');
          return req.isGranted;
        }
        return status.isGranted;
      }
    } catch (e) {
      print('$_tag Error checking permissions: $e');
      return false;
    }
  }
}

/// Result of profile check
class ProfileCheckResult {
  final bool exists;
  final bool isComplete;

  ProfileCheckResult({
    required this.exists,
    required this.isComplete,
  });
}

/// Represents where to navigate next in onboarding
class OnboardingDestination {
  final OnboardingStep step;
  final String? message;

  OnboardingDestination._(this.step, {this.message});

  factory OnboardingDestination.login() {
    return OnboardingDestination._(OnboardingStep.login);
  }

  factory OnboardingDestination.profileSetupRequired() {
    return OnboardingDestination._(
      OnboardingStep.profileSetup,
      message: 'Please complete your profile on GamesAfoot.co',
    );
  }

  factory OnboardingDestination.permissions() {
    return OnboardingDestination._(OnboardingStep.permissions);
  }

  factory OnboardingDestination.venueSelection() {
    return OnboardingDestination._(OnboardingStep.venueSelection);
  }

  factory OnboardingDestination.resumeWalk() {
    return OnboardingDestination._(OnboardingStep.resumeWalk);
  }

  /// Navigate to the appropriate page
  Future<void> navigate(BuildContext context) async {
    switch (step) {
      case OnboardingStep.login:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        break;
      
      case OnboardingStep.profileSetup:
        // Navigate to profile webview
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileWebViewPage()),
        );
        break;
      
      case OnboardingStep.permissions:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        break;
      
      case OnboardingStep.venueSelection:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const VenueSelectionPage()),
        );
        break;
      
      case OnboardingStep.resumeWalk:
        // Restore tour state and navigate to walking page
        final state = Provider.of<WalkWiseState>(context, listen: false);
        final restored = await state.restoreTourState();
        if (restored && state.isWalking) {
          // Resume walking if tour was active
          await state.resumeWalkingFromState();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WalkingPage()),
          );
        } else {
          // If restore failed or tour wasn't active, go to venue selection
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const VenueSelectionPage()),
          );
        }
        break;
    }
  }

  /// Show dialog prompting user to complete profile on website
  static void _showProfileSetupDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Your Profile'),
        content: const Text(
          'Please visit GamesAfoot.co to complete your profile setup.\n\n'
          'You\'ll need to provide:\n'
          '• Your name\n'
          '• Your initials\n'
          '• Your walking handicap\n\n'
          'Once complete, restart the app.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Open browser to GoWalkWise.com
              // For now, just close dialog and show login
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Steps in the onboarding process
enum OnboardingStep {
  login,
  profileSetup,
  permissions,
  venueSelection,
  resumeWalk,
}

