import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walkwise/app_state.dart';
import 'package:walkwise/pages/fun_fact_page.dart';
import 'package:walkwise/pages/location_image_page.dart';
import 'package:walkwise/pages/tour_completion_page.dart';
import 'package:walkwise/pages/venue_selection_page.dart';
import 'package:walkwise/pages/debug_page.dart';
import 'package:walkwise/pages/route_map_page.dart';
import 'package:walkwise/app/walkwise_app_config.dart';
import 'package:awty_engine/awty_engine.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:games_afoot_framework/games_afoot_framework.dart';
import 'package:go_router/go_router.dart';

class WalkingPage extends StatefulWidget {
  const WalkingPage({super.key});

  @override
  State<WalkingPage> createState() => _WalkingPageState();
}

class _WalkingPageState extends State<WalkingPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _callbackRegistered = false;
  bool _funFactShowing = false; // Guard to prevent duplicate fun fact displays
  bool _arrivalShowing = false; // Guard to prevent duplicate arrival displays

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<WalkWiseState>();
      
      // Check if we need to restore tour state (e.g., when navigating back from Ready to Play)
      if (state.currentVenue == null || state.currentRoute == null) {
        print('[WalkingPage] No active tour state, checking for saved state...');
        final restored = await state.restoreTourState();
        if (restored && state.isWalking) {
          print('[WalkingPage] Tour state restored, resuming walking...');
          await state.resumeWalkingFromState();
        } else {
          // No tour state available - redirect to venue selection
          print('[WalkingPage] No tour state available, redirecting to venue selection...');
          if (mounted) {
            context.go('/venue-selection');
            return; // Exit early to prevent further initialization
          }
        }
      }
      
      // Update notification service context
      AwtyNotificationService.updateContext(context);
      
      // Initialize AWTY and set up callbacks (only once)
      await AwtyEngine.initialize();
      if (!_callbackRegistered) {
        // Set up goal reached callback
        print('[WalkingPage] 🔔 Registering AWTY onGoalReached callback');
        AwtyEngine.onGoalReached(() async {
          print('[WalkingPage] 🎯 AWTY callback fired! Calling handleMilestoneReached');
          await state.handleMilestoneReached();
          print('[WalkingPage] 🎯 handleMilestoneReached returned');
        });
        
        // Set up step update callback (for UI display)
        AwtyEngine.onStepUpdate((stepsRemaining) {
          print('[WalkingPage] Step update callback: $stepsRemaining steps remaining');
          state.updateStepsFromAWTY(stepsRemaining);
        });
        
        _callbackRegistered = true;
      }
      
      // Set up navigation callbacks
      state.onShowFunFact = (funFact) {
        // Guard: prevent duplicate fun fact displays
        if (_funFactShowing) {
          print('[WalkingPage] ⚠️ Fun fact already showing, ignoring duplicate call');
          return;
        }
        _funFactShowing = true;
        print('[WalkingPage] ✅ Showing fun fact: ${funFact.locationName}');
        
        // Vibrate to alert user
        Vibration.vibrate(duration: 1000);
        
        // Play notification tone to alert player
        try {
          _audioPlayer.play(AssetSource('sounds/tone.mp3'));
        } catch (e) {
          print('Could not play notification sound: $e');
        }
        
        print('[WalkingPage] 🚀 Calling Navigator.push for FunFactPage');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              print('[WalkingPage] 🏗️ Building FunFactPage widget for ${funFact.locationName}');
              return FunFactPage(
                funFact: funFact,
                onContinue: () async {
                  print('[WalkingPage] Continue button pressed for fun fact');
                  _funFactShowing = false; // Reset flag when user continues
                  print('[WalkingPage] Fun fact flag reset, calling handleFunFactContinue');
                  await state.handleFunFactContinue();
                  print('[WalkingPage] handleFunFactContinue completed, closing page');
                  if (mounted) Navigator.pop(context); // Close FunFactPage AFTER async work
                },
              );
            },
          ),
        );
        print('[WalkingPage] ✅ Navigator.push completed');
      };
      state.onShowLocationAndMap = (locationName) {
        // Guard: prevent duplicate arrival displays
        if (_arrivalShowing) {
          print('[WalkingPage] Arrival already showing, ignoring duplicate call');
          return;
        }
        _arrivalShowing = true;
        
        // Vibrate to alert user (same as fun facts)
        Vibration.vibrate(duration: 1000);
        
        // Play notification sound (same as fun facts)
        try {
          _audioPlayer.play(AssetSource('sounds/tone.mp3'));
        } catch (e) {
          print('Could not play notification sound: $e');
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationImagePage(
              locationName: locationName,
              onArrivedContinue: () async {
                print('[WalkingPage] Continue button pressed for arrival');
                _arrivalShowing = false; // Reset flag when user continues
                print('[WalkingPage] Arrival flag reset, calling handleArrivalContinue');
                await state.handleArrivalContinue();
                print('[WalkingPage] handleArrivalContinue completed, closing page');
                if (mounted) Navigator.pop(context); // Close LocationImagePage AFTER async work
              },
            ),
          ),
        );
      };
      state.onShowCompletionVideo = (venueName) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TourCompletionPage(venueName: venueName),
          ),
        );
      };
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // Clear callback registration flag
    _callbackRegistered = false;
    // Clear AWTY callback by setting empty callback
    AwtyEngine.onGoalReached(() {
      // Empty callback - prevents old callbacks from firing
    });
    super.dispose();
  }

  /// Handle logout with confirmation and AWTY cleanup
  Future<void> _handleLogoutWithCleanup(BuildContext context, WalkWiseState state) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? This will stop your current tour.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Stop any active AWTY tracking
      await state.stopAWTY();
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Navigate to login page
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _abandonTour(BuildContext context, WalkWiseState state) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Tour'),
        content: const Text('Are you sure you want to abandon this tour? You will be able to select a different venue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('Abandon Tour'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Abandon the tour (stops AWTY and resets state)
      await state.abandonTour();
      
      // Navigate to venue selection page
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const VenueSelectionPage()),
          (route) => false,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<WalkWiseState>(
      builder: (context, state, child) {
        final bool isAdmin = (state.userRole ?? '').toUpperCase() == 'ADMIN';
        final config = WalkWiseAppConfig.build();
        
        // Build app-specific menu items
        final appMenuItems = <FrameworkMenuItem>[
          // Route Map (tour-specific)
          FrameworkMenuItem(
            title: 'Route Map',
            subtitle: 'View current tour route',
            icon: Icons.map,
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RouteMapPage(),
                ),
              );
            },
          ),
          // Resume/Abandon tour (tour-specific)
          if (state.currentVenue != null) ...[
            FrameworkMenuItem(
              title: 'Resume Tour',
              subtitle: '${state.currentVenue}',
              icon: Icons.tour,
              onTap: () {
                Navigator.pop(context); // Already on walking page
              },
            ),
            FrameworkMenuItem(
              title: 'Abandon Tour',
              subtitle: 'Select a different venue',
              icon: Icons.cancel,
              onTap: () async {
                Navigator.pop(context);
                await _abandonTour(context, state);
              },
            ),
          ],
          // Profile
          FrameworkMenuItem(
            title: 'Profile',
            icon: Icons.person,
            onTap: () {
              Navigator.pop(context);
              context.go('/profile-setup');
            },
          ),
          // Debug menu (admin only)
          if (isAdmin)
            FrameworkMenuItem(
              title: 'Debug',
              subtitle: 'Diagnostics & logs',
              icon: Icons.build,
              isBetaOnly: true,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugPage(),
                  ),
                );
              },
            ),
        ];
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Walking Tour'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          drawer: FrameworkNavigationMenu(
            config: config,
            appMenuItems: appMenuItems,
            isBetaTester: isAdmin,
            onClose: () {
              // Save tour state before closing drawer (in case user navigates away)
              state.saveTourState();
              Navigator.pop(context);
            },
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top block: Venue and Target Location
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Tour:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.currentVenue ?? '',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (state.currentRoute != null && state.currentRoute!.length > state.currentSegmentIndex + 1) ...[
                          Text(
                            state.currentRoute![state.currentSegmentIndex + 1],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue),
                          ),
                        ],
                        if (!state.isWalking) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.directions_walk),
                            label: const Text('Start Walking'),
                            onPressed: () => context.read<WalkWiseState>().startWalking(),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              textStyle: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Currently Walking block
                if (state.isWalking) ...[
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_walk, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Currently Walking',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Steps remaining to ${state.currentRoute != null && state.currentRoute!.length > state.currentSegmentIndex + 1 ? state.currentRoute![state.currentSegmentIndex + 1] : 'destination'}: ${state.stepsRemaining}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            'Fun facts shown: ${state.funFactsShown} of ${state.totalFunFacts}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Tour Route block (vertical, scrollable)
                if (state.currentRoute != null && state.currentRoute!.isNotEmpty) ...[
                  Card(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 320), // Make scrollable if long
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.currentRoute!.length,
                        itemBuilder: (context, idx) {
                          final isAtLocation = idx == state.currentSegmentIndex;
                          final isNextDestination = idx == state.currentSegmentIndex + 1;
                          final isPastLocation = idx < state.currentSegmentIndex;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                            decoration: isNextDestination
                                ? BoxDecoration(
                                    color: Colors.lightBlueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue, width: 2),
                                  )
                                : null,
                            child: ListTile(
                              leading: isPastLocation
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                              title: Text(
                                state.currentRoute![idx],
                                style: TextStyle(
                                  fontWeight: isNextDestination ? FontWeight.bold : FontWeight.normal,
                                  color: isPastLocation
                                      ? Colors.grey
                                      : isNextDestination
                                          ? Colors.blue
                                          : Colors.black,
                                ),
                              ),
                              subtitle: isNextDestination
                                  ? const Text('← heading here', style: TextStyle(color: Colors.blue))
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32), // Add some bottom padding instead of Spacer
                // Completed Venues
                if (state.completedVenues.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completed Tours:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.completedVenues.join(', '),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
} 