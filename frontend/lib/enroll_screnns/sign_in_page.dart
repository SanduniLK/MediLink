import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Screens
import 'package:frontend/screens/Sadmin_screens/home_page.dart';
import 'package:frontend/screens/admin_screens/admin_homePage.dart';
import 'package:frontend/screens/assistant_screens/assistant_home_page.dart';
import 'package:frontend/screens/doctor_screens/doctor_homeScreen.dart';

import 'package:frontend/screens/doctor_screens/doctor_pending_approval.dart.dart';
import 'package:frontend/screens/patient_screens/patient_home.dart';
import 'package:frontend/enroll_screnns/pateint_sign_up.dart';
import 'package:frontend/screens/phamecy_screens/pharmacy_home.dart';
import 'package:frontend/screens/phamecy_screens/pharmacy_pending_approval.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;
 bool _obscurePassword = true;

  static const Color _deepTeal = Color(0xFF18A3B6);
  static const Color _brightCyan = Color(0xFF32BACD);
  static const Color _softAqua = Color(0xFFB2DEE6);

  // ✅ Super Admin UID
  static const String superAdminAuthUid = "T3vM7ps10lcwrmxdkLJ7lSllyha2";

 Future<void> _signin() async {
    if (!mounted) return;
    _safeSetState(() => isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        _showSnackBar('Please enter email and password.');
        _safeSetState(() => isLoading = false);
        return;
      }

      // 1️⃣ Sign in with Firebase Auth
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final String uid = cred.user!.uid;

      // 2️⃣ IMMEDIATE CHECKS (no email verification required)
      if (uid == superAdminAuthUid) {
        _navigateTo(SuperAdminDashboard());
        return;
      }

      // Medical Center check
      final medicalCenterQuery = await FirebaseFirestore.instance
          .collection("medical_centers")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();

      if (medicalCenterQuery.docs.isNotEmpty) {
        final medicalCenterDoc = medicalCenterQuery.docs.first;
        final medicalCenterId = medicalCenterDoc.id;
        final medicalCenterName = medicalCenterDoc['name'];
  
  _navigateTo(AdminHomePage(
 
  )); // AdminHomePage will fetch its own data
  return;
      }

      // 3️⃣ GET USER ROLE AND VERIFICATION STATUS
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        _showSnackBar('User account not found.');
        await FirebaseAuth.instance.signOut();
        _safeSetState(() => isLoading = false);
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role'];
      final isEmailVerified = userData['isEmailVerified'] ?? true;

      // 4️⃣ EMAIL VERIFICATION CHECK FOR ALL USERS EXCEPT MEDICAL CENTER
      if (role != "assistant" && role != "medical_center" && !isEmailVerified) {
        _showSnackBar('Please verify your email before signing in.', isError: true);
        await FirebaseAuth.instance.signOut();
        _safeSetState(() => isLoading = false);
        return;
      }

      // 5️⃣ ROLE-BASED NAVIGATION AFTER EMAIL VERIFICATION
      switch (role) {
        case 'patient':
          await _handlePatientNavigation(uid);
          break;
        
        case 'doctor':
          await _handleDoctorNavigation(uid);
          break;
        
        case 'pharmacy':
          await _handlePharmacyNavigation(uid);
          break;
        case 'assistant':
          await _handleAssistantNavigation(uid);
          break;
        default:
          _showSnackBar('Unknown user role: $role');
          await FirebaseAuth.instance.signOut();
          _safeSetState(() => isLoading = false);
      }

    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      _safeSetState(() => isLoading = false);
    }
  }

  // Safe state update method
  void _safeSetState(VoidCallback callback) {
    if (mounted) {
      setState(callback);
    }
  }
void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.orange : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }
   void _navigateTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
  // PATIENT FLOW: Register → Email Verification → Sign In → Home Page
  Future<void> _handlePatientNavigation(String uid) async {
    final patientDoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .get();

    if (patientDoc.exists) {
      Navigator.pushReplacement(                                                                                                                                                                                             
        context,
        MaterialPageRoute(builder: (_) => MedicalHomeScreen(uid: uid)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient profile not found.')),
      );
      await FirebaseAuth.instance.signOut();
    }
  } 

  // DOCTOR FLOW: Register → Email Verification → Sign In → Pending Approval → Home Page
  Future<void> _handleDoctorNavigation(String uid) async {
    // Check if doctor is approved
    final doctorDoc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(uid)
        .get();

    if (doctorDoc.exists) {
      // Approved doctor - go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DoctorHomeScreen()),
      );
    } else {
      // Check pending request
      final doctorRequestDoc = await FirebaseFirestore.instance
          .collection('doctor_requests')
          .doc(uid)
          .get();

      if (doctorRequestDoc.exists) {
        final status = doctorRequestDoc['status'] ?? 'pending';
        
        if (status == 'pending') {
          // Email verified but pending approval
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DoctorPendingApprovalScreen(uid: uid)),
          );
        } else if (status == 'approved') {
          // Should be in doctors collection - sync issue
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your doctor account is being activated. Please try again in a moment.')),
          );
          await FirebaseAuth.instance.signOut();
        } else if (status == 'rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your doctor registration has been rejected.')),
          );
          await FirebaseAuth.instance.signOut();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor profile not found.')),
        );
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  // PHARMACY FLOW: Register → Email Verification → Sign In → Pending Approval → Home Page
  Future<void> _handlePharmacyNavigation(String uid) async {
    // Check if pharmacy is approved
    final pharmacyDoc = await FirebaseFirestore.instance
        .collection('pharmacies')
        .doc(uid)
        .get();

    if (pharmacyDoc.exists) {
      // Approved pharmacy - go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PharmacyHomeScreen(uid: uid)),
      );
    } else {
      // Check pending request
      final pharmacyRequestDoc = await FirebaseFirestore.instance
          .collection('pharmacy_requests')
          .doc(uid)
          .get();

      if (pharmacyRequestDoc.exists) {
        final status = pharmacyRequestDoc['status'] ?? 'pending';
        
        if (status == 'pending') {
          // Email verified but pending approval
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PharmacyPendingApprovalScreen(uid: uid)),
          );
        } else if (status == 'approved') {
          // Should be in pharmacies collection - sync issue
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your pharmacy account is being activated. Please try again in a moment.')),
          );
          await FirebaseAuth.instance.signOut();
        } else if (status == 'rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your pharmacy registration has been rejected.')),
          );
          await FirebaseAuth.instance.signOut();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pharmacy profile not found.')),
        );
        await FirebaseAuth.instance.signOut();
      }
    }
  }
  Future<void> _handleAssistantNavigation(String uid) async {
  final assistantDoc = await FirebaseFirestore.instance
      .collection('assistants')
      .doc(uid)
      .get();

  if (assistantDoc.exists) {
    final assistantData = assistantDoc.data()!;
    final isActive = assistantData['isActive'] ?? true;
    
    if (!isActive) {
      _showSnackBar('Your assistant account has been deactivated.', isError: true);
      await FirebaseAuth.instance.signOut();
      return;
    }
    
    // Navigate to assistant home page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AssistantHomePage()),
    );
  } else {
    _showSnackBar('Assistant profile not found.');
    await FirebaseAuth.instance.signOut();
  }
}

  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-email':
      case 'user-disabled':
        message = 'Login failed. Please check your email and account status.';
        break;
      case 'wrong-password':
        message = 'Login failed. Incorrect password.';
        break;
      default:
        message = e.message ?? 'Authentication error occurred.';
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _deepTeal,
        title: const Text("Sign In", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.health_and_safety, color: _deepTeal, size: 30),
                const SizedBox(width: 8),
                Text("Welcome Back",
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: _deepTeal)),
                const SizedBox(width: 8),
                const Text("👋", style: TextStyle(fontSize: 30)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Sign in to your personalized medical portal",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email Address",
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brightCyan, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brightCyan, width: 2),
                ),
              ),
              obscureText: _obscurePassword,
            ),
            const SizedBox(height: 30),
            isLoading
                ? Center(child: CircularProgressIndicator(color: _deepTeal))
                : ElevatedButton(
                    onPressed: _signin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deepTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: const Text("Sign In",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 30),
            Divider(color: _softAqua, thickness: 1.5),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?",
                    style: TextStyle(fontSize: 16, color: Colors.black54)),
                TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()));
                  },
                  child: const Text("Register Now",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _brightCyan)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}