import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:walkwise/app_state.dart';
import 'package:walkwise/services/awty_service.dart';
import 'package:walkwise/app/theme.dart';
import 'package:games_afoot_framework/games_afoot_framework.dart';
import 'firebase_options.dart';
import 'app/walkwise_app_config.dart';
import 'app/walkwise_app_routes.dart';

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
  late final AppConfig _config;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _config = WalkWiseAppConfig.build();
    _router = FrameworkRouter.createRouter(
      config: _config,
      appRoutes: WalkWiseAppRoutes.routes(),
    );
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
      child: MaterialApp.router(
        title: _config.appName,
        theme: WalkWiseTheme.lightTheme.copyWith(
          colorScheme: WalkWiseTheme.lightTheme.colorScheme.copyWith(
            primary: _config.primaryColor,
          ),
        ),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
