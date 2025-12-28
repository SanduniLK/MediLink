import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/providers/queue_provider.dart';
import 'package:frontend/screens/Notifications/notification_service.dart';
import 'package:frontend/services/dio_service.dart';
import 'package:frontend/utils/firestore_setup.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Screens
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/doctor_screens/doctor_homeScreen.dart';
import 'package:frontend/screens/patient_screens/patient_home.dart';

// Providers
import 'package:frontend/providers/doctor_provider.dart';

// Firebase options
import 'firebase_options.dart';

void main() async {
    //debugDisableShadows = true;
  // Set error handler before anything else
  FlutterError.onError = (details) {
    debugPrint('🔥 Flutter Error: ${details.exception}');
    // Don't crash on shader errors
    if (details.exception.toString().contains('Impeller') ||
        details.exception.toString().contains('shader')) {
      debugPrint('⚠️ Ignoring graphics shader error');
      return;
    }
    FlutterError.presentError(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Handle Firebase initialization with proper duplicate app handling
    await _initializeFirebase();
    
    // Initialize notifications
    await NotificationService.initializeLocalNotifications();
    
    // Initialize Dio
    DioService.initialize();
    
    runApp(const MediLinkApp());
  } catch (e) {
    debugPrint('❌ Main initialization failed: $e');
    // Fallback app if Firebase fails
    runApp(const ErrorFallbackApp());
  }
}

Future<void> _initializeFirebase() async {
  try {
    debugPrint('🚀 Initializing Firebase...');
    
    // Handle hot restart - check if Firebase is already initialized
    try {
      // Get existing apps
      final existingApps = Firebase.apps;
      if (existingApps.isNotEmpty) {
        debugPrint('✅ Firebase already initialized with ${existingApps.length} app(s)');
        
        // For hot restart, we need to handle it differently
        if (existingApps.any((app) => app.name == '[DEFAULT]')) {
          debugPrint('⚠️ DEFAULT Firebase app already exists (hot restart detected)');
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking existing Firebase apps: $e');
    }
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    debugPrint('✅ Firebase initialized successfully');
    
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('⚠️ Duplicate Firebase app (hot restart) - continuing');
    } else {
      debugPrint('❌ Firebase initialization error: $e');
      rethrow;
    }
  }
}

// Fallback app if Firebase fails
class ErrorFallbackApp extends StatelessWidget {
  const ErrorFallbackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Initialization Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'There was an issue initializing the app. Please restart.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Try to reinitialize
                  runApp(const MediLinkApp());
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Initialize Firestore data
void initializeFirestoreData() {
  FirestoreSetup.initializeData();
}

class MediLinkApp extends StatelessWidget {
  const MediLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DoctorProvider()),
        ChangeNotifierProvider(create: (_) => QueueProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MediLink',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          primaryColor: const Color(0xFF18A3B6),
          // Try disabling some visual effects to help with shader issues
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: false, // Disable Material 3 if causing issues
        ),
        // Disable debug painting to reduce GPU load
        debugShowMaterialGrid: false,
        home: const EntryPoint(),
      ),
    );
  }
}

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Give Firebase time to settle
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'Connection Issue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeApp,
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Authentication error: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Text('Database error: ${userSnapshot.error}'),
                  ),
                );
              }

              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const SignInPage();
              }

              final userData = userSnapshot.data!.data();
              if (userData is! Map<String, dynamic>) {
                return const SignInPage();
              }

              final data = userData;
              final role = data['role'];

              // Simple routing - NO chat initialization
              if (role == 'patient') {
                return MedicalHomeScreen(uid: uid);
              } else if (role == 'doctor') {
                return DoctorHomeScreen();
              } else {
                return const SignInPage();
              }
            },
          );
        }

        return const SignInPage();
      },
    );
  }
}