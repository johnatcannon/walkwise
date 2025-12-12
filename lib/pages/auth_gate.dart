import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:walkwise/pages/login_page.dart';
import 'package:walkwise/pages/venue_selection_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _permissionsRequested = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User is not signed in
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // User is signed in - request Health Connect permissions if not already done
        if (!_permissionsRequested) {
          // Schedule permission request for after build completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _requestHealthConnectPermissions();
          });
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up permissions...'),
                  SizedBox(height: 8),
                  Text(
                    'This helps personalize your walking experience\nand ensures you get milestone notifications',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'The app will work even without step data',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Permissions requested, show venue selection
        return const VenueSelectionPage();
      },
    );
  }

  Future<void> _requestHealthConnectPermissions() async {
    try {
      print('[AuthGate] User logged in successfully');
      // AWTY Engine will handle permission requests when tracking starts
    } catch (e) {
      print('[AuthGate] Error during login: $e');
    } finally {
      if (mounted) {
        setState(() {
          _permissionsRequested = true;
        });
      }
    }
  }
} 