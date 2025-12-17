import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) return; // Prevent multiple taps
    
    setState(() {
      _isSigningOut = true;
    });

    try {
      print('🔄 Starting sign-out process...');
      
      // Get current user info for debugging
      final user = FirebaseAuth.instance.currentUser;
      print('👤 Current user: ${user?.uid}');
      print('📧 Current email: ${user?.email}');
      
      // Add a small delay to ensure any ongoing operations complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Perform sign out
      await FirebaseAuth.instance.signOut();
      
      print('✅ Firebase sign-out successful');
      
      // Verify sign out worked
      final userAfterSignOut = FirebaseAuth.instance.currentUser;
      if (userAfterSignOut == null) {
        print('✅ Verification: User is now null');
      } else {
        print('❌ Verification: User still exists: ${userAfterSignOut.uid}');
      }
      
      // Navigate to sign in page
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
      
      print('✅ Navigation completed');
      
    } catch (e, stackTrace) {
      print('❌ Sign out error: $e');
      print('📝 Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 30),
            
            if (_isSigningOut)
              Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF18A3B6)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Signing out...',
                    style: TextStyle(
                      color: const Color(0xFF18A3B6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            
            ElevatedButton.icon(
              icon: _isSigningOut 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.logout, color: Colors.white),
              label: Text(
                _isSigningOut ? 'Signing Out...' : 'Sign Out',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSigningOut 
                    ? Colors.grey 
                    : const Color(0xFF32BACD),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSigningOut ? null : _showSignOutConfirmation,
            ),
            
            // Debug button - remove in production
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                _debugAuthState();
              },
              child: const Text('Debug Auth State'),
            ),
          ],
        ),
      ),
    );
  }

  void _debugAuthState() {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auth Debug Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${user?.uid ?? "null"}'),
            Text('Email: ${user?.email ?? "null"}'),
            Text('Verified: ${user?.emailVerified ?? "null"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}