import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walkwise/pages/login_page.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isDeleting = false;
  bool _confirmCheckbox = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning Icon and Title
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: Colors.red[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Delete Your Account',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Warning Message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This action cannot be undone!',
                        style: TextStyle(
                          color: Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Deleting your account will permanently remove:',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildWarningItem('Your profile and personal information'),
                      _buildWarningItem('All tour progress and history'),
                      _buildWarningItem('Your step tracking data'),
                      _buildWarningItem('Access to all Games Afoot apps (Agatha, WalkWise, etc.)'),
                      const SizedBox(height: 8),
                      Text(
                        'You will need to create a new account to use WalkWise or other Games Afoot apps again.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // User Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account to be deleted:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.email ?? 'Unknown email',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Confirmation Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _confirmCheckbox,
                      onChanged: (value) {
                        setState(() {
                          _confirmCheckbox = value ?? false;
                        });
                      },
                      activeColor: Colors.red[600],
                    ),
                    Expanded(
                      child: Text(
                        'I understand that this action cannot be undone and I want to permanently delete my account.',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isDeleting ? null : () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDeleting || !_confirmCheckbox
                            ? null
                            : _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Delete Account'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          Icon(
            Icons.remove,
            size: 16,
            color: Colors.red[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (!_confirmCheckbox) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Show final confirmation dialog
      final confirmed = await _showFinalConfirmationDialog();
      if (!confirmed) {
        setState(() {
          _isDeleting = false;
        });
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      final uid = currentUser.uid;
      print('[DeleteAccount] Starting account deletion for user: $uid');

      // Delete user data from Firestore
      await _deleteUserData(uid);

      // Delete Firebase Auth account
      await currentUser.delete();

      print('[DeleteAccount] Account deletion completed successfully');
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to login page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });
      
      print('[DeleteAccount] Error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteUserData(String uid) async {
    try {
      print('[DeleteAccount] Deleting user data for uid: $uid');

      // Delete from users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      // Delete user profile
      // Note: This deletes the unified Games Afoot profile used by all apps
      await FirebaseFirestore.instance
          .collection('player_profile')
          .doc(uid)
          .delete();

      print('[DeleteAccount] User data deletion completed for uid: $uid');
    } catch (e) {
      print('[DeleteAccount] Error deleting user data: $e');
      rethrow;
    }
  }

  Future<bool> _showFinalConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Final Confirmation'),
          content: const Text(
            'Are you absolutely sure you want to delete your account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }
}

