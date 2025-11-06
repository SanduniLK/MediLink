import 'package:flutter/material.dart';
import 'package:frontend/providers/queue_provider.dart';
import 'package:frontend/screens/Notifications/notification_service.dart';
import 'package:frontend/services/dio_service.dart';
import 'package:frontend/utils/firestore_setup.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Screens
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/doctor_screens/doctor_homeScreen.dart';
import 'package:frontend/screens/patient_screens/patient_home.dart';

// Providers
import 'package:frontend/providers/doctor_provider.dart';

// Services
import 'package:frontend/services/chat_service.dart';

// Firebase options
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
    await NotificationService.initializeLocalNotifications();
  // Ultimate Firebase initialization that handles hot restart
  await _initializeFirebaseWithRetry();
  
  DioService.initialize();
  runApp(const MediLinkApp());
}

Future<void> _initializeFirebaseWithRetry() async {
  try {
    // Try to get existing Firebase app first
    try {
      Firebase.app();
      debugPrint('✅ Firebase app already exists, skipping initialization');
      return;
    } catch (e) {
      // No app exists, proceed with initialization
      debugPrint('🚀 Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
    }
    
    // Initialize Realtime Database
    _initializeRealtimeDatabase();
    
    // Test database connection
    await _testDatabaseConnection();
    
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('⚠️ Firebase duplicate app detected (hot restart), continuing...');
    } else {
      debugPrint('❌ Unexpected error during Firebase initialization: $e');
      rethrow;
    }
  }
}

void _initializeRealtimeDatabase() {
  try {
    final database = FirebaseDatabase.instance;
    
    if (!kIsWeb) {
      database.setPersistenceEnabled(true);
      database.setPersistenceCacheSizeBytes(10000000);
      debugPrint('✅ Realtime Database persistence enabled');
    } else {
      debugPrint('🌐 Web: Using Realtime Database without persistence');
    }
    
  } catch (e) {
    debugPrint('❌ Error initializing Realtime Database: $e');
  }
}

Future<void> _testDatabaseConnection() async {
  try {
    debugPrint('🧪 Testing Realtime Database connection...');
    
    final database = FirebaseDatabase.instance;
    final testRef = database.ref('connection_test');
    
    await testRef.set({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'connected'
    });
    
    final snapshot = await testRef.get();
    if (snapshot.exists) {
      debugPrint('✅ Realtime Database connection successful!');
    }
    
    await testRef.remove();
    
  } catch (e) {
    debugPrint('❌ Realtime Database connection failed: $e');
  }
}

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
        Provider(create: (_) => ChatService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MediLink',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          primaryColor: Color(0xFF18A3B6),
        ),
        home: const EntryPoint(),
      ),
    );
  }
}

class EntryPoint extends StatelessWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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

              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const SignInPage();
              }

              final userData = userSnapshot.data!.data();
              if (userData is! Map<String, dynamic>) {
                return const SignInPage();
              }
              final data = userData;
              final role = data['role'];

              // Initialize chat service for the user
              _initializeUserChatService(uid, role, data);

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
// In main.dart, update the initialization:
void _initializeUserChatService(String uid, String role, Map<String, dynamic> userData) {
  try {
    final chatService = ChatService();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Test database connection
      final isConnected = await chatService.testDatabaseConnection();
      
      if (isConnected) {
        debugPrint('✅ Realtime Database is connected!');
        
        // Sync with REAL data (not samples)
        await chatService.syncChatRoomsFromSessions(uid);
      } else {
        debugPrint('❌ Realtime Database connection failed');
      }
      
      debugPrint('✅ Chat service ready for $role: $uid');
    });
  } catch (e) {
    debugPrint('❌ Error initializing chat service: $e');
  }
}
}