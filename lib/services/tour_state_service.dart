import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// WalkWise tour state persistence service
/// 
/// Saves and restores tour state so tours can survive app restarts.
/// Uses the same pattern as Agatha's GamePersistenceService.
class TourStateService {
  static const String _stateKey = 'walkwise_tour_state';
  static const String _lastSaveTimeKey = 'walkwise_last_save_time';
  static const int _currentStateVersion = 1; // Increment when state format changes

  /// Tour state model
  static Map<String, dynamic> createTourState({
    required String venue,
    required List<String> route,
    required int segmentIndex,
    required int funFactIndex,
    required int milestoneIndex,
    required int stepsRemaining,
    required int currentSteps,
    required int calculatedStepsForSegment,
    required int rawSegmentDistance,
    required int cityId,
    required bool isWalking,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return {
      'version': _currentStateVersion,
      'user_id': currentUser?.uid ?? '',
      'venue': venue,
      'route': route,
      'segmentIndex': segmentIndex,
      'funFactIndex': funFactIndex,
      'milestoneIndex': milestoneIndex,
      'stepsRemaining': stepsRemaining,
      'currentSteps': currentSteps,
      'calculatedStepsForSegment': calculatedStepsForSegment,
      'rawSegmentDistance': rawSegmentDistance,
      'cityId': cityId,
      'isWalking': isWalking,
      'saved_at': DateTime.now().toIso8601String(),
    };
  }

  /// Save tour state to local storage and Firestore
  static Future<void> saveTourState(Map<String, dynamic> state) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('[TourState] No user logged in, cannot save state');
        return;
      }

      print('[TourState] Saving tour state for venue: ${state['venue']}');

      // Save to SharedPreferences (local)
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state);
      await prefs.setString(_stateKey, jsonString);
      await prefs.setString(_lastSaveTimeKey, DateTime.now().toIso8601String());

      print('[TourState] ✓ Saved to local storage (${jsonString.length} bytes)');

      // Also save a minimal pointer to Firestore (player_profile)
      await FirebaseFirestore.instance
          .collection('player_profile')
          .doc(currentUser.uid)
          .update({
        'current_tour_venue': state['venue'],
        'tour_last_saved': FieldValue.serverTimestamp(),
      });

      print('[TourState] ✓ Saved pointer to Firestore');
    } catch (e) {
      print('[TourState] ❌ Error saving tour state: $e');
      // Don't throw - save failures shouldn't break the app
    }
  }

  /// Load tour state from local storage
  static Future<Map<String, dynamic>?> loadTourState() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('[TourState] No user logged in, cannot load state');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_stateKey);

      if (jsonString == null) {
        print('[TourState] No saved tour state found in local storage');
        return null;
      }

      Map<String, dynamic> stateSnapshot;
      try {
        stateSnapshot = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        print('[TourState] ❌ Invalid JSON format, clearing: $e');
        await clearTourState();
        return null;
      }

      // Check state version - clear if outdated
      final stateVersion = stateSnapshot['version'] as int?;
      if (stateVersion == null || stateVersion < _currentStateVersion) {
        print('[TourState] Saved state is old format (version $stateVersion), clearing for safety');
        await clearTourState();
        return null;
      }

      // Verify this state belongs to current user
      if (stateSnapshot['user_id'] != currentUser.uid) {
        print('[TourState] State belongs to different user, clearing');
        await clearTourState();
        return null;
      }

      // Check if state is from today (optional - tours might span days)
      // For now, we'll allow tours to resume across days
      final savedAt = stateSnapshot['saved_at'] as String?;
      if (savedAt != null) {
        try {
          final savedDate = DateTime.parse(savedAt);
          final daysSince = DateTime.now().difference(savedDate).inDays;
          if (daysSince > 7) {
            // Clear state older than 7 days
            print('[TourState] State is $daysSince days old, clearing');
            await clearTourState();
            return null;
          }
        } catch (e) {
          print('[TourState] Error parsing saved_at: $e');
        }
      }

      print('[TourState] ✓ Loaded tour state from local storage');
      return stateSnapshot;
    } catch (e) {
      print('[TourState] ❌ Error loading tour state: $e');
      return null;
    }
  }

  /// Check if there's a saved tour state available
  static Future<bool> hasSavedTourState() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_stateKey);

      if (jsonString == null) {
        return false;
      }

      // Quick check without full parsing
      Map<String, dynamic> stateSnapshot;
      try {
        stateSnapshot = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        await clearTourState();
        return false;
      }

      // Check version
      final stateVersion = stateSnapshot['version'] as int?;
      if (stateVersion == null || stateVersion < _currentStateVersion) {
        await clearTourState();
        return false;
      }

      // Verify user match
      if (stateSnapshot['user_id'] != currentUser.uid) {
        await clearTourState();
        return false;
      }

      return true;
    } catch (e) {
      print('[TourState] Error checking saved state: $e');
      return false;
    }
  }

  /// Clear saved tour state
  static Future<void> clearTourState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stateKey);
      await prefs.remove(_lastSaveTimeKey);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('player_profile')
            .doc(currentUser.uid)
            .update({
          'current_tour_venue': FieldValue.delete(),
          'tour_last_saved': FieldValue.delete(),
        });
      }

      print('[TourState] ✓ Cleared tour state');
    } catch (e) {
      print('[TourState] ❌ Error clearing tour state: $e');
    }
  }
}

