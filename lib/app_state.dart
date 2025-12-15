import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awty_engine/awty_engine.dart';
import 'package:walkwise/models/fun_fact.dart';
import 'package:walkwise/services/fun_fact_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:walkwise/services/walkwise_logger.dart';
import 'package:games_afoot_health/health_average_service.dart';
import 'package:walkwise/services/tour_state_service.dart';
import 'package:games_afoot_framework/services/awty_notification_service.dart';

/// WalkWise App State - manages all app-wide data
/// This replaces passing variables through multiple screens
class WalkWiseState extends ChangeNotifier {
  // Session state (in-memory during walk)
  String? _currentVenue;
  List<String>? _currentRoute;
  int _currentSegmentIndex = 0;
  int _stepsRemaining = 0;
  int _funFactIndex = 0;
  bool _isWalking = false;
  bool _awtyActive = false;
  int _currentSteps = 0;
  
  // Persistent data
  double _handicap = 1.0;
  double? _calculatedHandicap;
  String? _lastVenue;
  final int _lastSegmentIndex = 0;
  final int _stepsAtLastCheckpoint = 0;
  final List<String> _completedVenues = [];
  String? _userRole; // e.g., ADMIN, PLAYER
  
  // Fun facts
  List<FunFact> _currentFunFacts = [];
  int _currentCityId = 0;
  
  // Services
  
  // New fields
  int? _rawSegmentDistance;
  int? _funFactInterval;
  int? _calculatedStepsForSegment;
  double? _averageSteps;
  bool _isTracking = false;
  
  // Audio player
  AudioPlayer? _audioPlayer;
  
  // Add a new field to track the current milestone (0=FF1, 1=FF2, 2=FF3, 3=Arrival)
  int _milestoneIndex = 0;
  static const int _milestonesPerSegment = 4;
  
  // Add flag to prevent multiple rapid milestone triggers
  bool _milestoneInProgress = false;
  
  // Track steps accumulated across completed milestones in current segment
  int _accumulatedSteps = 0;
  
  // Constructor - reset state on app startup
  WalkWiseState() {
    _resetAppState();
  }
  
  /// Reset all session variables to initial state
  /// Called at app startup and before venue selection, but NOT during active walks
  void _resetAppState() {
    print('[RESET] Resetting app state to initial values');
    WalkWiseLogger().log('STARTED', 'App state reset to initial values');
    
    // Session state (in-memory during walk)
    _currentVenue = null;
    _currentRoute = null;
    _currentSegmentIndex = 0;
    _stepsRemaining = 0;
    _funFactIndex = 0;
    _isWalking = false;
    _awtyActive = false;
    _currentSteps = 0;
    
    // Fun facts
    _currentFunFacts = [];
    _currentCityId = 0;
    
    // New fields
    _rawSegmentDistance = null;
    _funFactInterval = null;
    _calculatedStepsForSegment = null;
    _averageSteps = null;
    _userRole = null;
    
    // Audio player
    _audioPlayer?.stop();
    _audioPlayer = null;
    
    // Milestone tracking
    _milestoneIndex = 0;
    _milestoneInProgress = false;
    _accumulatedSteps = 0;
    
    print('[RESET] App state reset complete');
  }
  
  // Getters (any widget can access these)
  String? get currentVenue => _currentVenue;
  List<String>? get currentRoute => _currentRoute;
  int get currentSegmentIndex => _currentSegmentIndex;
  int get stepsRemaining {
    if (_calculatedStepsForSegment != null) {
      final stepsTaken = _currentSteps;
      final remaining = _calculatedStepsForSegment! - stepsTaken;
      return remaining > 0 ? remaining : 0;
    }
    return 0;
  }
  int get funFactsShown => _funFactIndex;
  int get totalFunFacts => 3;
  bool get isWalking => _isWalking;
  bool get awtyActive => _awtyActive;
  int get currentSteps => _currentSteps;
  double get handicap => _handicap;
  double? get calculatedHandicap => _calculatedHandicap;
  List<String> get completedVenues => _completedVenues;
  List<FunFact> get currentFunFacts => _currentFunFacts;
  int get currentCityId => _currentCityId;
  int? get rawSegmentDistance => _rawSegmentDistance;
  int? get funFactInterval => _funFactInterval;
  int? get calculatedStepsForSegment => _calculatedStepsForSegment;
  double? get averageSteps => _averageSteps;
  String? get userRole => _userRole;
  
  
  /// Select a venue and set up for walking
  Future<void> selectVenue(String venue) async {
    // Reset state before starting a new venue
    _resetAppState();
    WalkWiseLogger().log('VENUE_SELECTED', 'Venue selected: $venue');
    
    _currentVenue = venue;
    print('[selectVenue] Venue selected: $venue');
    
    // Fetch the user's profile and attempt to recalculate handicap
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profileQuery = await FirebaseFirestore.instance
          .collection('player_profile')
          .where('email', isEqualTo: user.email)
          .get();
      
      if (profileQuery.docs.isNotEmpty) {
        final profileDoc = profileQuery.docs.first;
        final profileData = profileDoc.data();
        final existingHandicap = (profileData['handicap'] as num?)?.toDouble() ?? 1.0;
        _userRole = profileData['user_role'] as String?;
        print('[selectVenue] Loaded user_role from profile: $_userRole');
        
        // Attempt to recalculate handicap from device health data (matches Agatha)
        print('[selectVenue] Attempting to recalculate handicap from device health data...');
        try {
          final healthResult = await HealthAverageService.getDailyAverage(days: 30);
          
          if (healthResult.success && healthResult.dataQuality == 'good') {
            // Calculate new handicap from system average
            final newHandicap = _calculateHandicap(healthResult.dailyAverage);
            print('[selectVenue] Recalculated handicap: $newHandicap (from ${healthResult.dailyAverage} steps/day)');
            
            // Update profile with new system data
            await profileDoc.reference.update({
              'system_daily_average': healthResult.dailyAverage,
              'daily_average_source': 'system',
              'handicap': newHandicap,
              'last_updated': FieldValue.serverTimestamp(),
            });
            
            _handicap = newHandicap;
            print('[selectVenue] Updated player profile with new handicap: $newHandicap');
            WalkWiseLogger().log('HANDICAP_RECALCULATED', 'New handicap: $newHandicap from ${healthResult.dailyAverage} steps/day');
          } else {
            // Use existing profile handicap if health data not available
            _handicap = existingHandicap;
            print('[selectVenue] Health data not available (quality: ${healthResult.dataQuality}), using profile handicap: $_handicap');
            WalkWiseLogger().log('HANDICAP_PROFILE', 'Using profile handicap: $_handicap (health data unavailable)');
          }
        } catch (e) {
          // Use existing profile handicap if recalculation fails
          _handicap = existingHandicap;
          print('[selectVenue] Error recalculating handicap: $e, using profile handicap: $_handicap');
          WalkWiseLogger().log('HANDICAP_PROFILE', 'Using profile handicap: $_handicap (recalculation failed)');
        }
      } else {
        // No profile found, use default
        _handicap = 1.0;
        print('[selectVenue] No profile found, using default handicap: $_handicap');
      }
    } else {
      // No user, use default
      _handicap = 1.0;
      print('[selectVenue] No user, using default handicap: $_handicap');
    }
    
    // Use the calculated handicap
    _calculatedHandicap = _handicap;
    print('[selectVenue] Using handicap: $_handicap');
    
    // Apply minimum handicap limit (0.5x, matches Agatha)
    const double minHandicap = 0.5;
    if (_calculatedHandicap! < minHandicap) {
      print('[selectVenue] Handicap ${_calculatedHandicap!.toStringAsFixed(3)} below minimum, using $minHandicap');
      _calculatedHandicap = minHandicap;
    }
    if (_handicap < minHandicap) {
      print('[selectVenue] Profile handicap ${_handicap.toStringAsFixed(3)} below minimum, using $minHandicap');
      _handicap = minHandicap;
    }
    
    // If you want to update the profile with the new value, uncomment below:
    // if (user != null && _calculatedHandicap != null) {
    //   await FirebaseFirestore.instance
    //       .collection('player_profile')
    //       .doc(profileDoc.docs.first.id)
    //       .update({'handicap': _calculatedHandicap});
    //   _handicap = _calculatedHandicap!;
    // }
    
    // Load route for this venue
    _currentRoute = await _loadRouteForVenue(venue);
    print('[selectVenue] Loaded route: $_currentRoute');
    WalkWiseLogger().log('ROUTE_LOADED', 'Route: $_currentRoute');
    _currentSegmentIndex = 0;
    _funFactIndex = 0;
    
    // Get city ID for this venue
    _currentCityId = await _getCityId(venue);
    
    // Load fun facts for the first location
    await _loadFunFactsForCurrentLocation();
    WalkWiseLogger().log('FUN_FACTS_LOADED', 'Loaded fun facts for location');
    
    // Save handicap to persistent storage
    await _saveHandicap(_handicap);
    
    // Notify all widgets that state changed
    notifyListeners();
  }
  
  /// Calculate handicap from daily step average (matches Agatha's formula)
  /// Uses: stepAverage / 10000, with minimum of 0.5
  double _calculateHandicap(int stepAverage) {
    if (stepAverage <= 0) {
      return 0.5; // Minimum handicap
    }
    
    const int handicapDivisor = 10000;
    const double minHandicap = 0.5;
    
    final calculatedHandicap = stepAverage / handicapDivisor;
    final finalHandicap = calculatedHandicap > minHandicap ? calculatedHandicap : minHandicap;
    
    print('[selectVenue] Calculated handicap: $finalHandicap for step average: $stepAverage');
    return finalHandicap;
  }
  
  /// Start walking to next location
  Future<void> startWalking() async {
    print('[DEBUG] startWalking called');
    // Platform-specific permissions (matches Agatha's approach)
    if (Platform.isIOS) {
      // iOS pedometer doesn't require explicit permissions
      // NSMotionUsageDescription in Info.plist is sufficient
      print('[PERMISSION] iOS detected, skipping permission checks (pedometer handles automatically)');
    } else {
      // Android: Activity Recognition + Notification (for foreground service)
      var status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        status = await Permission.activityRecognition.request();
        if (!status.isGranted) {
          print('[PERMISSION] Activity Recognition permission not granted!');
          return;
        }
      }
      print('[PERMISSION] Activity Recognition permission granted.');

      var notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        print('[PERMISSION] Requesting notification permission for foreground service...');
        notificationStatus = await Permission.notification.request();
        if (!notificationStatus.isGranted) {
          print('[PERMISSION] Notification permission not granted - notification may not appear');
          // don't block
        } else {
          print('[PERMISSION] Notification permission granted');
        }
      } else {
        print('[PERMISSION] Notification permission already granted');
      }
    }
    
    print('[startWalking] Called. Route: $_currentRoute, Segment: $_currentSegmentIndex');
    if (_currentRoute == null || _currentRoute!.isEmpty) {
      print('[startWalking] ERROR: Route is null or empty!');
      return;
    }

    // Reset per-segment step counters
    _currentSteps = 0;
    _stepsRemaining = 0;
    _accumulatedSteps = 0; // Reset accumulated steps for new segment

    _isWalking = true;
    _awtyActive = true;
    _milestoneIndex = 0;
    _funFactIndex = 0;
    _milestoneInProgress = false; // Reset flag when starting new segment
    notifyListeners();

    // Get from/to locations for this segment
    final fromLocation = _currentRoute![_currentSegmentIndex];
    final toLocation = _currentRoute!.length > _currentSegmentIndex + 1
        ? _currentRoute![_currentSegmentIndex + 1]
        : null;
    print('[startWalking] Segment $_currentSegmentIndex: From: $fromLocation, To: $toLocation');

    // Query the distances collection for the segment
    int baseSteps = 1000; // fallback default
    if (toLocation != null) {
      final query = await FirebaseFirestore.instance
          .collection('distances')
          .where('city_id', isEqualTo: _currentCityId)
          .where('from_location', isEqualTo: fromLocation)
          .where('to_location', isEqualTo: toLocation)
          .get();
      if (query.docs.isNotEmpty) {
        baseSteps = (query.docs.first.data()['steps'] as num?)?.toInt() ?? 1000;
        print('[startWalking] Found distance in database: $baseSteps steps');
      } else {
        print('[startWalking] WARNING: No distance found for $fromLocation -> $toLocation, using default 1000');
      }
    } else {
      print('[startWalking] WARNING: No destination location, using default 1000');
    }
    _rawSegmentDistance = baseSteps;
    print('[startWalking] Base steps: $baseSteps, Handicap: $_handicap');

    // Calculate steps needed for this segment
    _calculatedStepsForSegment = (baseSteps * _handicap).round();
    _stepsRemaining = _calculatedStepsForSegment!;
    print('[startWalking] Calculated steps: $_calculatedStepsForSegment');

    // Calculate steps per milestone (no need to handle remainder)
    int stepsPerMilestone = (_calculatedStepsForSegment! / _milestonesPerSegment).round();
    print('[startWalking] Steps per milestone: $stepsPerMilestone');
    
    // Step updates are now handled by callback registered in walking_page.dart
    // No need to register here - prevents duplicate callbacks
    
    // Start AWTY for the first milestone
    await _startNextMilestone(stepsPerMilestone);
    
    // Save state when starting a walk
    await saveTourState();
    
    notifyListeners();
  }
  
  /// OLD METHOD - NO LONGER USED
  /// Fun fact delivery now handled by handleMilestoneReached() callback
  /// Keeping this for reference during refactoring
  
  /// OLD METHOD - NO LONGER USED
  /// Audio is now played by FunFactPage, not by app_state
  
  /// Called when AWTY reaches the destination
  Future<void> _onArrivalReached() async {
    print('[AWTY] _onArrivalReached called: segment=$_currentSegmentIndex');
    _isWalking = false;
    _awtyActive = false;
    _milestoneInProgress = false; // Reset flag
    print('[AWTY] Arrival reached at segment $_currentSegmentIndex');
    _isTracking = false;
    await AwtyEngine.stopGoal();
    await _showLocationAndMap();
    if (_currentSegmentIndex >= _currentRoute!.length - 1) {
      print('[AWTY] Tour complete!');
      _completeTour();
    } else {
      _currentSegmentIndex++;
      print('[AWTY] Loading fun facts for next location: segment=$_currentSegmentIndex');
      await _loadFunFactsForCurrentLocation();
    }
    notifyListeners();
  }
  
  /// Update current step count (called by step stream)
  void updateStepCount(int steps) {
    _currentSteps = steps;
    _stepsRemaining = _calculateRemainingSteps();
    notifyListeners();
  }
  
  /// Resume walk from saved state
  Future<void> resumeWalk() async {
    if (_lastVenue != null) {
      await selectVenue(_lastVenue!);
      _currentSegmentIndex = _lastSegmentIndex;
      _currentSteps = _stepsAtLastCheckpoint;
      
      if (_isWalking) {
        await startWalking();
      }
    }
  }
  
  /// Load fun facts for the destination location (where we're heading TO)
  Future<void> _loadFunFactsForCurrentLocation() async {
    if (_currentRoute == null || _currentSegmentIndex >= _currentRoute!.length) return;
    
    // Fun facts are for the DESTINATION (next location), not current location
    // currentSegmentIndex is where we ARE, so destination is index + 1
    final destinationIndex = _currentSegmentIndex + 1;
    if (destinationIndex >= _currentRoute!.length) return;
    
    final locationName = _currentRoute![destinationIndex];
    print('[FunFacts] Loading fun facts for DESTINATION: $locationName (index $destinationIndex)');
    _currentFunFacts = await FunFactService.fetchFunFacts(_currentCityId, locationName);
  }
  
  // Helper methods
  Future<List<String>> _loadRouteForVenue(String venue) async {
    // First, get the venue_id from the cities collection
    final cityQuery = await FirebaseFirestore.instance
        .collection('cities')
        .where('name', isEqualTo: venue)
        .get();

    if (cityQuery.docs.isEmpty) {
      throw Exception('City not found: $venue');
    }

    final cityData = cityQuery.docs.first.data();
    final venueId = cityData['city_id'] as num?;
    if (venueId == null) {
      throw Exception('City ID missing for: $venue');
    }

    // Query all route segments for this venue_id
    final routeQuery = await FirebaseFirestore.instance
        .collection('venue_routes')
        .where('venue_id', isEqualTo: venueId)
        .get();

    if (routeQuery.docs.isEmpty) {
      throw Exception('No route found for venue: $venue');
    }

    // Build the route array by sorting by route_order
    final segments = routeQuery.docs
        .map((doc) => doc.data())
        .where((data) => data['location_name'] != null && data['route_order'] != null)
        .toList();
    segments.sort((a, b) => (a['route_order'] as num).compareTo(b['route_order'] as num));
    final route = segments.map((data) => (data['location_name'] as String).replaceAll('"', '').trim()).toList();

    if (route.isEmpty) {
      throw Exception('Route data is empty for venue: $venue');
    }

    return route;
  }
  
  Future<int> _getStepsForSegment(int segmentIndex) async {
    if (_currentRoute == null || segmentIndex >= _currentRoute!.length - 1) {
      throw Exception('Invalid segment index: $segmentIndex');
    }
    
    final fromLocation = _currentRoute![segmentIndex];
    final toLocation = _currentRoute![segmentIndex + 1];
    
    final query = await FirebaseFirestore.instance
        .collection('distances')
        .where('city_id', isEqualTo: _currentCityId)
        .where('from_location', isEqualTo: fromLocation)
        .where('to_location', isEqualTo: toLocation)
        .get();
    
    if (query.docs.isEmpty) {
      throw Exception('No distance data found for segment: $fromLocation -> $toLocation');
    }
    
    final distanceData = query.docs.first.data();
    final steps = distanceData['steps'] as num?;
    
    if (steps == null) {
      throw Exception('Steps data missing for segment: $fromLocation -> $toLocation');
    }
    
    return steps.toInt();
  }
  
  Future<int> _getCityId(String venue) async {
    final query = await FirebaseFirestore.instance
        .collection('cities')
        .where('name', isEqualTo: venue)
        .get();
    
    if (query.docs.isEmpty) {
      throw Exception('City not found: $venue');
    }
    
    final cityData = query.docs.first.data();
    final cityId = cityData['city_id'] as num?;
    
    if (cityId == null) {
      throw Exception('City ID missing for: $venue');
    }
    
    return cityId.toInt();
  }
  
  Future<void> _startNextMilestone(int steps) async {
    print('[DEBUG] _startNextMilestone called with steps: $steps, milestoneIndex=$_milestoneIndex');
    try {
      await AwtyEngine.startGoal(
        goalSteps: steps,
        appName: 'WalkWise',
        goalId: 'walkwise_segment_$_milestoneIndex',
        iconName: 'barefoot',
        testMode: false,
      );
      _isTracking = true;
      print('[DEBUG] AwtyEngine.startGoal called successfully');
    } catch (e) {
      print('[ERROR] Failed to start AWTY engine: $e');
    }
    // Step updates now handled by AWTY callback (onStepUpdate), no polling needed
    notifyListeners();
  }
  
  void _showFunFact() {
    print('[AWTY] _showFunFact called: funFactIndex=$_funFactIndex');
    // Navigate to FunFactPage with the current fun fact
    if (_currentFunFacts.isNotEmpty && _funFactIndex - 1 < _currentFunFacts.length) {
      final funFact = _currentFunFacts[_funFactIndex - 1];
      print('[AWTY] Showing fun fact for location: ${funFact.locationName}');
      // Use a global navigator key or callback to trigger navigation from state
      // For now, use a callback if set
      if (onShowFunFact != null) {
        onShowFunFact!(funFact);
      }
    } else {
      print('[AWTY] No fun fact available to show. Index: ${_funFactIndex - 1}, Available: ${_currentFunFacts.length}');
    }
  }
  
  Future<void> _showLocationAndMap() async {
    // Show the DESTINATION (where we just arrived TO), not current location
    final destinationIndex = _currentSegmentIndex + 1;
    if (_currentRoute == null || destinationIndex >= _currentRoute!.length) {
      print('[AWTY] ERROR: Invalid destination index $destinationIndex');
      return;
    }
    
    final locationName = _currentRoute![destinationIndex];
    print('[AWTY] Showing arrival page for DESTINATION: $locationName (index $destinationIndex)');
    
    // Send notification with sound for arrival (works even when phone is locked)
    await AwtyNotificationService.sendGoalReachedNotification(
      title: '🎉 Destination Reached!',
      body: 'Tap to see your destination and continue your tour!',
    );
    
    // Navigate to LocationImagePage
    if (onShowLocationAndMap != null) {
      onShowLocationAndMap!(locationName);
    }
  }
  
  void _completeTour() async {
    _completedVenues.add(_currentVenue!);
    print('[AWTY] Tour completed for: $_currentVenue');
    
    // Stop AWTY tracking to prevent any further milestones
    if (_isTracking || _awtyActive) {
      await AwtyEngine.stopGoal();
      AwtyEngine.clearStepUpdateCallback();
      AwtyEngine.clearGoalReachedCallback();
      _isTracking = false;
      _awtyActive = false;
      _isWalking = false;
      print('[AWTY] Stopped AWTY tracking on tour completion');
    }
    
    // Navigate to TourCompletionPage
    if (onShowCompletionVideo != null) {
      onShowCompletionVideo!(_currentVenue ?? '');
    }
  }
  
  int _calculateRemainingSteps() {
    // Calculate remaining steps in the segment
    if (_calculatedStepsForSegment != null) {
      final stepsTaken = _currentSteps;
      final remaining = _calculatedStepsForSegment! - stepsTaken;
      return remaining > 0 ? remaining : 0;
    }
    return _stepsRemaining;
  }
  
  Future<void> _saveHandicap(double handicap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('handicap', handicap);
  }
  
  @override
  void dispose() {
    // Clear AWTY callbacks
    AwtyEngine.clearStepUpdateCallback();
    AwtyEngine.clearGoalReachedCallback();
    super.dispose();
  }

  // Navigation callbacks for UI to set
  void Function(FunFact funFact)? onShowFunFact;
  void Function(String locationName)? onShowLocationAndMap;
  void Function(String venueName)? onShowCompletionVideo;

  /// Test method to manually trigger AWTY for testing
  Future<void> testAWTY() async {
    print('[TEST] Starting AWTY test with 100 steps');
    await AwtyEngine.startGoal(
      goalSteps: 100,
      appName: 'WalkWise',
      goalId: 'walkwise_test',
      iconName: 'barefoot',
      testMode: false,
    );
    // Step updates now handled by AWTY callback (onStepUpdate), no polling needed
  }
  
  /// Stop AWTY tracking
  Future<void> stopAWTY() async {
    print('[TEST] Stopping AWTY');
    _isTracking = false;
    await AwtyEngine.stopGoal();
    AwtyEngine.clearStepUpdateCallback();
    _awtyActive = false;
    _isWalking = false;
    notifyListeners();
  }

  /// Abandon current tour and reset state
  /// Called when user wants to select a different venue
  Future<void> abandonTour() async {
    print('[ABANDON] Abandoning current tour');
    WalkWiseLogger().log('TOUR_ABANDONED', 'User abandoned tour: $_currentVenue');
    
    // Stop AWTY if running
    if (_isTracking || _awtyActive) {
      await AwtyEngine.stopGoal();
      AwtyEngine.clearStepUpdateCallback();
      AwtyEngine.clearGoalReachedCallback();
    }
    
    // Clear saved tour state
    await TourStateService.clearTourState();
    
    // Reset all state
    _resetAppState();
    
    notifyListeners();
  }

  /// Handle milestone callback from AWTY
  /// This is called when AWTY reaches a milestone and notifies WalkWise
  Future<void> handleMilestoneReached() async {
    print('[AWTY] handleMilestoneReached called: milestoneIndex=$_milestoneIndex, funFactIndex=$_funFactIndex, _milestoneInProgress=$_milestoneInProgress');
    
    // Check if tour is already complete - prevent milestones after completion
    if (_currentRoute == null || _currentSegmentIndex >= _currentRoute!.length - 1) {
      print('[AWTY] ⚠️ Tour already complete, ignoring milestone callback');
      return;
    }
    
    // Prevent duplicate triggers - check and set atomically
    if (_milestoneInProgress) {
      print('[AWTY] ⚠️ Milestone already in progress, ignoring duplicate trigger');
      return;
    }
    
    // Set flag immediately to prevent race conditions
    _milestoneInProgress = true;
    print('[AWTY] ✅ Milestone flag set to true, proceeding with milestone handling');
    
    WalkWiseLogger().log('MILESTONE_REACHED', 'Milestone index: $_milestoneIndex, Fun fact index: $_funFactIndex');
    
    // Send notification with sound (works even when phone is locked)
    await AwtyNotificationService.sendGoalReachedNotification(
      title: '🎉 Milestone Reached!',
      body: 'Tap to see your fun fact and continue your tour!',
    );
    
    // Vibrate to alert user
    Vibration.vibrate(duration: 2000);
    
    // NOTE: Do NOT call stopGoal() here - AWTY already stopped itself
    _isTracking = false;
    
    // Show fun fact page (if we haven't shown all 3 yet)
    if (_funFactIndex < _currentFunFacts.length && _funFactIndex < 3) {
      final funFact = _currentFunFacts[_funFactIndex];
      print('[AWTY] Showing fun fact ${_funFactIndex + 1} of 3: ${funFact.locationName}');
      if (onShowFunFact != null) {
        onShowFunFact!(funFact);
      }
      _funFactIndex++; // Increment for next time
    } else if (_milestoneIndex >= _milestonesPerSegment - 1) {
      // Last milestone = arrival
      print('[AWTY] Last milestone reached, showing arrival');
      await _showLocationAndMap();
    }
    
    // NOTE: _milestoneInProgress will be reset in:
    // - handleFunFactContinue() for fun fact milestones
    // - handleArrivalContinue() for arrival milestone
    // This prevents duplicate triggers while user is viewing the page
    
    notifyListeners();
  }

  /// Called when user presses Continue after a fun fact
  Future<void> handleFunFactContinue() async {
    print('[AWTY] ========== handleFunFactContinue START ==========');
    print('[AWTY] milestoneIndex=$_milestoneIndex, funFactIndex=$_funFactIndex');
    print('[AWTY] _milestoneInProgress=$_milestoneInProgress');
    
    // Reset milestone in progress flag now that user has pressed Continue
    _milestoneInProgress = false;
    
    // Accumulate steps from completed milestone
    int stepsPerMilestone = (_calculatedStepsForSegment! / _milestonesPerSegment).round();
    _accumulatedSteps += stepsPerMilestone;
    print('[AWTY] Accumulated steps: $_accumulatedSteps (completed milestone $_milestoneIndex)');
    
    _milestoneIndex++;
    
    // Check if we've shown all fun facts (0-indexed: 0, 1, 2 = 3 facts)
    if (_milestoneIndex < _milestonesPerSegment - 1) {
      // Start next fun fact milestone
      print('[AWTY] Starting next fun fact milestone ($stepsPerMilestone steps)');
      await _startNextMilestone(stepsPerMilestone);
      _isWalking = true;
    } else {
      // All fun facts shown, now walk to arrival
      print('[AWTY] All fun facts shown, walking to arrival milestone');
      int stepsToArrival = _calculatedStepsForSegment! - (_milestonesPerSegment - 1) * stepsPerMilestone;
      await _startNextMilestone(stepsToArrival);
      _isWalking = true;
    }
    
    // Save state after milestone
    await saveTourState();
    
    notifyListeners();
  }

  /// Called after arrival page - user pressed Continue
  Future<void> handleArrivalContinue() async {
    print('[AWTY] handleArrivalContinue: segment=$_currentSegmentIndex');
    
    // Reset milestone in progress flag now that user has pressed Continue
    _milestoneInProgress = false;
    
    // We just arrived at DESTINATION index = _currentSegmentIndex + 1.
    // If that destination is the LAST entry in the route, the tour is complete.
    final int lastIndex = _currentRoute!.length - 1;
    final int justArrivedIndex = _currentSegmentIndex + 1;
    if (justArrivedIndex >= lastIndex) {
      print('[AWTY] Tour complete!');
      // Clear saved state on tour completion
      await TourStateService.clearTourState();
      _completeTour();
      return;
    }
    _currentSegmentIndex++;
    _milestoneIndex = 0;
    _funFactIndex = 0;
    await _loadFunFactsForCurrentLocation();
    
    // Recalculate distance for the NEW segment (not the previous one)
    final fromLocation = _currentRoute![_currentSegmentIndex];
    final toLocation = _currentRoute!.length > _currentSegmentIndex + 1
        ? _currentRoute![_currentSegmentIndex + 1]
        : null;
    print('[handleArrivalContinue] New segment $_currentSegmentIndex: From: $fromLocation, To: $toLocation');
    
    // Query the distances collection for the new segment
    int baseSteps = 1000; // fallback default
    if (toLocation != null) {
      final query = await FirebaseFirestore.instance
          .collection('distances')
          .where('city_id', isEqualTo: _currentCityId)
          .where('from_location', isEqualTo: fromLocation)
          .where('to_location', isEqualTo: toLocation)
          .get();
      if (query.docs.isNotEmpty) {
        baseSteps = (query.docs.first.data()['steps'] as num?)?.toInt() ?? 1000;
        print('[handleArrivalContinue] Found distance for new segment: $baseSteps steps');
      } else {
        print('[handleArrivalContinue] WARNING: No distance found for $fromLocation -> $toLocation, using default 1000');
      }
    } else {
      print('[handleArrivalContinue] WARNING: No destination location, using default 1000');
    }
    _rawSegmentDistance = baseSteps;
    
    // Recalculate steps needed for this NEW segment (apply handicap)
    _calculatedStepsForSegment = (baseSteps * _handicap).round();
    _currentSteps = 0; // Reset step counter for new segment
    _accumulatedSteps = 0; // Reset accumulated steps for new segment
    _stepsRemaining = _calculatedStepsForSegment!;
    print('[handleArrivalContinue] Recalculated steps for new segment: $_calculatedStepsForSegment (base: $baseSteps, handicap: $_handicap)');
    
    // Start first milestone for new segment with correct step count
    int stepsPerMilestone = (_calculatedStepsForSegment! / _milestonesPerSegment).round();
    print('[handleArrivalContinue] Steps per milestone: $stepsPerMilestone');
    await _startNextMilestone(stepsPerMilestone);
    _isWalking = true;
    
    // Save state after segment change
    await saveTourState();
    
    notifyListeners();
  }

  set currentSteps(int value) {
    _currentSteps = value;
    WalkWiseLogger().log('STEP_COUNT', 'Step count updated: $value');
    notifyListeners();
  }
  
  /// Update steps from AWTY step update callback
  /// Called from walking_page.dart when AWTY reports step count changes
  /// stepsRemaining is for the CURRENT milestone only, not the entire segment
  void updateStepsFromAWTY(int stepsRemaining) {
    _stepsRemaining = stepsRemaining;
    
    // Calculate steps taken in current milestone
    int stepsPerMilestone = 0;
    if (_calculatedStepsForSegment != null) {
      stepsPerMilestone = (_calculatedStepsForSegment! / _milestonesPerSegment).round();
    }
    
    // Steps taken in current milestone = milestone goal - remaining
    int stepsInCurrentMilestone = (stepsPerMilestone - stepsRemaining).clamp(0, stepsPerMilestone);
    
    // Total steps = accumulated from previous milestones + current milestone progress
    _currentSteps = _accumulatedSteps + stepsInCurrentMilestone;
    
    // Calculate remaining steps for entire segment
    if (_calculatedStepsForSegment != null) {
      _stepsRemaining = (_calculatedStepsForSegment! - _currentSteps).clamp(0, _calculatedStepsForSegment!);
    }
    
    notifyListeners();
  }

  /// Save current tour state
  /// Called at milestones and when app goes to background
  Future<void> saveTourState() async {
    if (_currentVenue == null || _currentRoute == null || !_isWalking) {
      // Only save if we have an active tour
      return;
    }

    final state = TourStateService.createTourState(
      venue: _currentVenue!,
      route: _currentRoute!,
      segmentIndex: _currentSegmentIndex,
      funFactIndex: _funFactIndex,
      milestoneIndex: _milestoneIndex,
      stepsRemaining: _stepsRemaining,
      currentSteps: _currentSteps,
      calculatedStepsForSegment: _calculatedStepsForSegment ?? 0,
      rawSegmentDistance: _rawSegmentDistance ?? 0,
      cityId: _currentCityId,
      isWalking: _isWalking,
    );

    await TourStateService.saveTourState(state);
    print('[TourState] ✓ Tour state saved');
  }

  /// Restore tour state from saved data
  /// Called on app startup if saved state exists
  Future<bool> restoreTourState() async {
    final savedState = await TourStateService.loadTourState();
    if (savedState == null) {
      print('[TourState] No saved state to restore');
      return false;
    }

    try {
      print('[TourState] Restoring tour state: ${savedState['venue']}');
      
      // Restore basic state
      _currentVenue = savedState['venue'] as String?;
      _currentRoute = List<String>.from(savedState['route'] as List? ?? []);
      _currentSegmentIndex = savedState['segmentIndex'] as int? ?? 0;
      _funFactIndex = savedState['funFactIndex'] as int? ?? 0;
      _milestoneIndex = savedState['milestoneIndex'] as int? ?? 0;
      _stepsRemaining = savedState['stepsRemaining'] as int? ?? 0;
      _currentSteps = savedState['currentSteps'] as int? ?? 0;
      _calculatedStepsForSegment = savedState['calculatedStepsForSegment'] as int?;
      _rawSegmentDistance = savedState['rawSegmentDistance'] as int?;
      _currentCityId = savedState['cityId'] as int? ?? 0;
      _isWalking = savedState['isWalking'] as bool? ?? false;

      // Reload fun facts for current location
      await _loadFunFactsForCurrentLocation();

      print('[TourState] ✓ Tour state restored: venue=$_currentVenue, segment=$_currentSegmentIndex, walking=$_isWalking');
      WalkWiseLogger().log('TOUR_RESTORED', 'Restored tour: $_currentVenue');
      
      notifyListeners();
      return true;
    } catch (e) {
      print('[TourState] ❌ Error restoring tour state: $e');
      await TourStateService.clearTourState();
      return false;
    }
  }

  /// Resume walking from restored state
  /// Called after restoreTourState() if isWalking was true
  Future<void> resumeWalkingFromState() async {
    if (_currentRoute == null || _currentSegmentIndex >= _currentRoute!.length - 1) {
      print('[TourState] Cannot resume - invalid route or segment');
      return;
    }

    print('[TourState] Resuming walking from saved state');
    
    // Recalculate steps for current segment if needed
    if (_calculatedStepsForSegment == null && _rawSegmentDistance != null) {
      _calculatedStepsForSegment = (_rawSegmentDistance! * _handicap).round();
      _stepsRemaining = _calculatedStepsForSegment!;
    }

    // Calculate steps per milestone
    int stepsPerMilestone = 0;
    if (_calculatedStepsForSegment != null) {
      stepsPerMilestone = (_calculatedStepsForSegment! / _milestonesPerSegment).round();
    }

    // Start AWTY for current milestone
    if (stepsPerMilestone > 0) {
      _isWalking = true;
      _awtyActive = true;
      await _startNextMilestone(stepsPerMilestone);
      print('[TourState] ✓ Resumed walking - milestone $_milestoneIndex, $stepsPerMilestone steps');
    }

    notifyListeners();
  }

} 