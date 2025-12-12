import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:games_afoot_health/health_service.dart';
import 'package:walkwise/pages/venue_selection_page.dart';
import 'package:walkwise/pages/login_page.dart';
import 'package:walkwise/pages/delete_account_page.dart';
import 'package:walkwise/pages/report_problem_webview_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _activityRecognitionGranted = false;
  bool _isLoading = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  Permission get _activityPermission =>
      Platform.isIOS ? Permission.sensors : Permission.activityRecognition;

  String get _activityPermissionLabel =>
      Platform.isIOS ? 'Health Access (Motion & Fitness)' : 'Activity Recognition';

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    try {
      if (Platform.isIOS) {
        // iOS pedometer doesn't require explicit permissions (matches Agatha)
        // NSMotionUsageDescription in Info.plist is sufficient
        setState(() {
          _activityRecognitionGranted = true;
        });
        print('[SettingsPage] iOS detected, permissions ready (pedometer handles automatically)');
      } else {
        final status = await _activityPermission.status;
        
        setState(() {
          _activityRecognitionGranted = status.isGranted;
        });
        
        print('[SettingsPage] Activity Permission ($_activityPermissionLabel): $status');
      }
    } catch (e) {
      print('[SettingsPage] Error checking permissions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _requestActivityRecognitionPermission() async {
    setState(() => _isLoading = true);
    try {
      bool granted = false;
      if (Platform.isIOS) {
        // iOS pedometer doesn't require explicit permissions (matches Agatha)
        // NSMotionUsageDescription in Info.plist is sufficient
        granted = true;
        print('[SettingsPage] iOS - no permission request needed');
      } else {
        final status = await _activityPermission.request();
        granted = status.isGranted;
      }

      setState(() => _activityRecognitionGranted = granted);
      
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_activityPermissionLabel permission granted!')),
        );
        
        // If permissions are now granted, navigate to venue selection
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const VenueSelectionPage()),
          );
        }
      } else {
        // Show dialog to open settings (for permanently denied or not granted)
        _showOpenSettingsDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting permission: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          '$_activityPermissionLabel permission is required for step tracking.\n\n'
          'Please enable it in system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0),
              children: [
                // Permissions Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permissions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Activity Recognition Permission
                        _buildPermissionTile(
                          title: _activityPermissionLabel,
                          subtitle: 'Required for step tracking during walking tours',
                          isGranted: _activityRecognitionGranted,
                          onRequest: _requestActivityRecognitionPermission,
                          icon: Icons.directions_walk,
                        ),
                        
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        
                        Text(
                          'About Permissions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• $_activityPermissionLabel: Required for step tracking during walking tours',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Account Management Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Management',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? 'Not signed in',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Password Reset
                        ListTile(
                          leading: Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.primary),
                          title: const Text('Reset Password'),
                          subtitle: const Text('Send password reset email'),
                          onTap: _showPasswordResetDialog,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tileColor: Colors.grey[50],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Logout
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.orange[700]),
                          title: const Text('Logout'),
                          subtitle: const Text('Sign out of your account'),
                          onTap: _showLogoutDialog,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tileColor: Colors.grey[50],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Delete Account
                        ListTile(
                          leading: Icon(Icons.delete_forever, color: Colors.red[700]),
                          title: const Text('Delete Account'),
                          subtitle: const Text('Permanently delete your account'),
                          onTap: _navigateToDeleteAccount,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tileColor: Colors.red[50],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Report a Problem Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help & Support',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Icon(Icons.bug_report, color: Theme.of(context).colorScheme.primary),
                          title: const Text('Report a Problem'),
                          subtitle: const Text('Found a bug or have a suggestion? Let us know!'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReportProblemWebViewPage(),
                              ),
                            );
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tileColor: Colors.blue[50],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // About / Version Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WalkWise',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _appVersion.isEmpty
                                        ? 'Loading version...'
                                        : 'Version $_appVersion',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Patent Pending',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  void _showPasswordResetDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final emailController = TextEditingController(text: user?.email ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A password reset link will be sent to your email address.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: user?.email == null, // Disable if we already have email
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendPasswordResetEmail(emailController.text.trim());
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reset email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _navigateToDeleteAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeleteAccountPage(),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onRequest,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isGranted ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isGranted ? Colors.green[700] : Colors.orange[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isGranted ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isGranted ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isGranted ? 'Granted' : 'Required',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isGranted ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Grant'),
            ),
          ],
        ],
      ),
    );
  }
} 