import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';


import 'package:frontend/screens/doctor_screens/doctor_pending_approval.dart.dart';
import 'package:frontend/screens/patient_screens/patient_home.dart';
import 'package:frontend/screens/phamecy_screens/pharmacy_pending_approval.dart';


class OtpVerificationPage extends StatefulWidget {
  final String email;

  const OtpVerificationPage({super.key, required this.email});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = false;
  bool _isEmailVerified = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
  }

  void _startEmailVerificationCheck() {
    // Periodically check every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkEmailVerificationStatus();
      if (_isEmailVerified) timer.cancel();
    });
  }

  Future<void> _checkEmailVerificationStatus() async {
    setState(() => _loading = true);
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await user.reload();
      user = _auth.currentUser;

      if (user!.emailVerified) {
        setState(() => _isEmailVerified = true);
        await _navigateAfterVerification();
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateAfterVerification() async {
  User? user = _auth.currentUser;
  if (user == null) return;

  final uid = user.uid;

  // Get the role from Firestore safely
  final userDoc = await _firestore.collection('users').doc(uid).get();
  if (!userDoc.exists || !userDoc.data()!.containsKey('role')) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("User role not found!")));
    return;
  }

  final role = userDoc['role'];

  // Update verification status in respective collections
  if (role == 'patient') {
    await _firestore.collection('patients').doc(uid).update({
      'isEmailVerified': true,
    });
    await _firestore.collection('users').doc(uid).update({
      'isEmailVerified': true,
    });
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MedicalHomeScreen(uid: uid)),
    );
  } else if (role == 'doctor') {
    // Update doctor_requests with verification status
    await _firestore.collection('doctor_requests').doc(uid).update({
      'isEmailVerified': true,
    });
    await _firestore.collection('users').doc(uid).update({
      'isEmailVerified': true,
    });
    
    // For doctors, go to pending approval screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DoctorPendingApprovalScreen(uid: uid)),
    );
  } else if (role == 'pharmacy') {
    // ✅ ADDED PHARMACY VERIFICATION
    await _firestore.collection('pharmacy_requests').doc(uid).update({
      'isEmailVerified': true,
    });
    await _firestore.collection('users').doc(uid).update({
      'isEmailVerified': true,
    });
    
    // For pharmacies, go to pending approval screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PharmacyPendingApprovalScreen(uid: uid)),
    );
  }
}

  Future<void> _resendVerificationEmail() async {
    setState(() => _loading = true);
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent! Check your inbox.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFDDF0F5),
    body: SafeArea(
      child: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.email, size: 80, color: Color(0xFF18A3B6)),
                    const SizedBox(height: 20),
                    const Text(
                      "Verify Your Email",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "A verification link has been sent to ${widget.email}. Please click the link to verify your account.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(height: 30),
                    !_isEmailVerified
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _checkEmailVerificationStatus,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF18A3B6),
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          "I have verified my email",
                                          style: TextStyle(fontSize: 16, color: Colors.white),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _loading ? null : _resendVerificationEmail,
                                child: Text(
                                  "Resend Verification Link",
                                  style: TextStyle(color: const Color(0xFF32BACD)),
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            "Email verified! Redirecting...",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        _auth.signOut();
                        Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (_) => const SignInPage()));
                      },
                      child: const Text(
                        "Go to Sign In",
                        style: TextStyle(color: Color(0xFF32BACD)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}