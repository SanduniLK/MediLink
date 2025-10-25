import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/phamecy_screens/pharmacy_home.dart';

// Import your sign-in page
import 'package:frontend/enroll_screnns/sign_in_page.dart';

class PharmacyPendingApprovalScreen extends StatelessWidget {
  final String uid;
  
  const PharmacyPendingApprovalScreen({super.key, required this.uid});

  // Sign out method with navigation
  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to sign-in page and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    } catch (e) {
      // Show error message if sign out fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_pharmacy, size: 80, color: Colors.orange[700]),
                const SizedBox(height: 20),
                const Text(
                  "Pending Approval",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Your pharmacy registration is under review by our admin team.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                const Text(
                  "You will be notified once your account is approved and activated.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pharmacy_requests')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      final status = data?['status'] ?? 'pending';
                      
                      if (status == 'approved') {
                        // Auto-redirect if approved
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PharmacyHomeScreen(uid: uid),
                            ),
                          );
                        });
                      }
                      
                      return Column(
                        children: [
                          Chip(
                            label: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: status == 'approved' 
                                ? Colors.green 
                                : status == 'rejected'
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                          const SizedBox(height: 10),
                          if (status == 'rejected')
                            const Text(
                              'Your registration has been rejected.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      );
                    }
                    return const CircularProgressIndicator();
                  },
                ),
                const SizedBox(height: 25),
                
                // Sign Out Button
                ElevatedButton(
                  onPressed: () => _signOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18A3B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: const Text("Sign Out"),
                ),
                
                // Optional: Add a "Check Status" button
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    // Refresh the stream
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Checking for updates...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text(
                    'Check Status',
                    style: TextStyle(color: Color(0xFF18A3B6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}