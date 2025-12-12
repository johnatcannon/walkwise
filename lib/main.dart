import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:walkwise/pages/splash_page.dart';
import 'package:walkwise/pages/venue_selection_page.dart';
import 'package:walkwise/pages/walking_page.dart';
import 'package:walkwise/pages/intro_video_page.dart';
import 'package:walkwise/pages/location_image_page.dart';
import 'package:walkwise/pages/tour_completion_page.dart';
import 'package:walkwise/app_state.dart';
import 'package:walkwise/services/awty_service.dart';
import 'package:walkwise/app/theme.dart';
import 'package:games_afoot_framework/services/awty_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize AWTY callback system
  AwtyService.initialize();
  
  runApp(const WalkWiseApp());
}

class WalkWiseApp extends StatefulWidget {
  const WalkWiseApp({super.key});

  @override
  State<WalkWiseApp> createState() => _WalkWiseAppState();
}

class _WalkWiseAppState extends State<WalkWiseApp> with WidgetsBindingObserver {
  WalkWiseState? _walkWiseState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background - save tour state
      _walkWiseState?.saveTourState();
      print('[APP_LIFECYCLE] App paused - tour state saved');
    } else if (state == AppLifecycleState.resumed) {
      // App became active - AWTY Engine handles step updates automatically
      print('[APP_LIFECYCLE] App resumed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        _walkWiseState = WalkWiseState();
        return _walkWiseState!;
      },
      child: Builder(
        builder: (context) {
          // Initialize notification service when we have a context
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AwtyNotificationService.initialize(
              context,
              () {
                // Notification tapped callback - could navigate to walking page
                // For now, just log it
                print('[WalkWise] Notification tapped - user can open app to see milestone');
              },
            );
          });
          
          return MaterialApp(
            title: 'WalkWise',
            theme: WalkWiseTheme.lightTheme,
            home: const SplashPage(),
            routes: {
              '/venue-selection': (context) => const VenueSelectionPage(),
              '/walking': (context) => const WalkingPage(),
              '/intro-video': (context) => const IntroVideoPage(),
              '/location-image': (context) => const LocationImagePage(locationName: ''),
              '/completion-video': (context) => const TourCompletionPage(venueName: ''),
            },
          );
        },
      ),
    );
  }
}
