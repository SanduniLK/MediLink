import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/providers/doctor_provider.dart';
import 'package:frontend/screens/Notifications/DoctorNotificationPage.dart';
import 'package:frontend/screens/doctor_screens/allschedule.dart';
import 'package:frontend/screens/doctor_screens/create_schedule_screen.dart';
import 'package:frontend/screens/doctor_screens/doctor_appointments_page.dart';
import 'package:frontend/screens/doctor_screens/doctor_feedback_dashboard.dart';
import 'package:frontend/screens/doctor_screens/doctor_profile.dart';
import 'package:frontend/screens/doctor_screens/doctor_qr_scanner_screen.dart';

import 'package:frontend/screens/doctor_screens/doctor_revenue_analyze.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';


import 'package:frontend/screens/doctor_screens/settings_screen.dart';
import 'package:frontend/screens/doctor_screens/today_appointments_screen.dart';
import 'package:frontend/screens/doctor_screens/written_prescribe.dart';

import 'package:frontend/screens/patient_screens/notifications.dart';
import 'package:frontend/screens/phamecy_screens/prescriptionImageScreen.dart';
import 'package:frontend/telemedicine/doctor_telemedicine_page.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


import 'package:frontend/screens/doctor_screens/doctor_chat_screen.dart';
import 'package:frontend/screens/doctor_screens/doctor_chat_list_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? doctorData;
  bool isLoading = true;
  int todayAppointmentsCount = 0;
  int waitingPatientsCount = 0;
  bool hasActiveQueue = false;
  int unreadMessagesCount = 0;
    int todaySessionsCount = 0;
  bool hasActiveSession = false;
   String? doctorId;
  String? doctorName;

  double doctorFeedbackScore = 0.0;
  int totalFeedbackCount = 0;

  // Your exact theme colors
  final Color primaryColor = const Color(0xFF18A3B6);
  final Color secondaryColor = const Color(0xFF32BACD);
  final Color accentColor = const Color(0xFF85CEDA);
  final Color backgroundColor = const Color(0xFFDDF0F5);
  final Color lightBackground = const Color(0xFFF0F9FA);


final Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
    _loadTodayStats();
    _loadUnreadMessagesCount();
     _getDoctorInfo();
     _startMessageListener();
     _loadDoctorProfileImage(); 
     _loadTodaySessions();
     _loadDoctorFeedback();
  }
  StreamSubscription? _messageSubscription;

@override
void dispose() {
  _messageSubscription?.cancel();
  super.dispose();
}
void _startMessageListener() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  _messageSubscription = FirebaseFirestore.instance
      .collection('chat_rooms')
      .where('doctorId', isEqualTo: user.uid)
      .snapshots()
      .listen((snapshot) {
    _loadUnreadMessagesCount();
  });
}
void _getDoctorInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        doctorId = user.uid;
        doctorName = user.displayName ?? 'Doctor'; 
      });
    }
  }
  Future<void> _loadDoctorData() async {
    Future<void> _loadDoctorFeedback() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get all feedback for this doctor
    final feedbackSnapshot = await FirebaseFirestore.instance
        .collection('feedback')
        .where('doctorId', isEqualTo: user.uid)
        .where('feedbackType', isEqualTo: 'doctor')
        .get();

    if (feedbackSnapshot.docs.isEmpty) {
      setState(() {
        doctorFeedbackScore = 0.0;
        totalFeedbackCount = 0;
      });
      return;
    }

    double totalRating = 0;
    int count = 0;

    for (final doc in feedbackSnapshot.docs) {
      final feedback = doc.data();
      final rating = feedback['rating'];
      
      if (rating != null && rating is int && rating > 0) {
        totalRating += rating.toDouble();
        count++;
      }
    }

    if (count > 0) {
      setState(() {
        doctorFeedbackScore = totalRating / count;
        totalFeedbackCount = count;
      });
    } else {
      setState(() {
        doctorFeedbackScore = 0.0;
        totalFeedbackCount = 0;
      });
    }
  } catch (e) {
    print('Error loading doctor feedback: $e');
    setState(() {
      doctorFeedbackScore = 0.0;
      totalFeedbackCount = 0;
    });
  }
}
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .get();

      if (doctorDoc.exists) {
        final data = doctorDoc.data()!;
        setState(() {
          doctorData = {
            'uid': user.uid,
            'id': user.uid,
            'fullname': data['fullname'] ?? 'Dr. Silva',
            'name': data['fullname'] ?? 'Dr. Silva',
            'specialization': data['specialization'] ?? 'General Practitioner',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'medicalCenters': data['medicalCenters'] ?? [],
          };
        });
      }
    } catch (e) {
      // Error loading doctor data
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
final FirebaseStorage _storage = FirebaseStorage.instance;
String? _doctorProfileImageUrl;

Future<void> _loadDoctorFeedback() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get all feedback for this doctor
    final feedbackSnapshot = await FirebaseFirestore.instance
        .collection('feedback')
        .where('doctorId', isEqualTo: user.uid)
        .where('feedbackType', isEqualTo: 'doctor')
        .get();

    if (feedbackSnapshot.docs.isEmpty) {
      setState(() {
        doctorFeedbackScore = 0.0;
        totalFeedbackCount = 0;
      });
      return;
    }

    double totalRating = 0;
    int count = 0;

    for (final doc in feedbackSnapshot.docs) {
      final feedback = doc.data();
      final rating = feedback['rating'];
      
      if (rating != null && rating is int && rating > 0) {
        totalRating += rating.toDouble();
        count++;
      }
    }

    if (count > 0) {
      setState(() {
        doctorFeedbackScore = totalRating / count;
        totalFeedbackCount = count;
      });
    } else {
      setState(() {
        doctorFeedbackScore = 0.0;
        totalFeedbackCount = 0;
      });
    }
  } catch (e) {
    print('Error loading doctor feedback: $e');
    setState(() {
      doctorFeedbackScore = 0.0;
      totalFeedbackCount = 0;
    });
  }
}
Future<void> _loadDoctorProfileImage() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('🔄 Loading profile image for doctor UID: ${user.uid}');

    // First, check if we have a profile image URL in Firestore
    final doctorDoc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(user.uid)
        .get();

    if (doctorDoc.exists) {
      final profileImageUrl = doctorDoc.data()?['profileImage'];
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        print('✅ Found profile image URL in Firestore: $profileImageUrl');
        setState(() {
          _doctorProfileImageUrl = profileImageUrl;
        });
        return;
      }
    }

    // If no URL in Firestore, search in Storage
    try {
      final doctorFolderRef = FirebaseStorage.instance.ref().child('doctor_profile_images/${user.uid}');
      final result = await doctorFolderRef.listAll();
      
      print('📁 Found ${result.items.length} items in doctor folder');
      
      // Sort by name to get the most recent one
      result.items.sort((a, b) => b.name.compareTo(a.name));
      
      for (final item in result.items) {
        print('📄 File: ${item.name}');
        try {
          final imageUrl = await item.getDownloadURL();
          print('✅ Found profile image: $imageUrl');
          
          // Save this URL to Firestore for future use
          await FirebaseFirestore.instance
              .collection('doctors')
              .doc(user.uid)
              .update({
                'profileImage': imageUrl,
              });
              
          setState(() {
            _doctorProfileImageUrl = imageUrl;
          });
          return;
        } catch (e) {
          print('❌ Failed to get download URL for ${item.name}: $e');
        }
      }
    } catch (e) {
      print('❌ Error listing doctor folder: $e');
    }

    print('❌ No suitable profile image found');
    
  } catch (e) {
    print('💥 CRITICAL ERROR in _loadDoctorProfileImage: $e');
  }
}
Future<void> _testSpecificImage() async {
  try {
    print('🔄 Testing specific image loading...');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    // Get the current user's profile image from Firestore first
    final doctorDoc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(user.uid)
        .get();

    if (doctorDoc.exists) {
      final profileImageUrl = doctorDoc.data()?['profileImage'];
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        print('✅ Found profile image in Firestore: $profileImageUrl');
        setState(() {
          _doctorProfileImageUrl = profileImageUrl;
        });
        return;
      }
    }

    // If no profile image in Firestore, try to find one in Storage
    print('🔍 No profile image in Firestore, checking Storage...');
    _loadDoctorProfileImage(); // Fall back to other methods
    
  } catch (e) {
    print('💥 SPECIFIC IMAGE FAILED: $e');
    _loadDoctorProfileImage(); // Fall back to other methods
  }
}

 Future<void> _loadTodayStats() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final todayFormatted = DateFormat('dd/MM/yyyy').format(now);
    
    // Get all appointments for this doctor
    final appointmentsSnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .get();

    int todayCount = 0;
    int waitingCount = 0;

    for (final doc in appointmentsSnapshot.docs) {
      final appointment = doc.data();
      final appointmentDate = appointment['date']?.toString() ?? '';
      
      // Check if appointment is for today
      if (_isDateToday(appointmentDate, now)) {
        todayCount++;
        
        // Check if waiting/checked-in
        final status = appointment['status']?.toString() ?? '';
        final queueStatus = appointment['queueStatus']?.toString() ?? '';
        
        if (status == 'confirmed' || status == 'pending' || 
            queueStatus == 'waiting' || queueStatus == 'checked-in') {
          waitingCount++;
        }
      }
    }

    setState(() {
      todayAppointmentsCount = todayCount;
      waitingPatientsCount = waitingCount;
      hasActiveQueue = waitingCount > 0;
    });
  } catch (e) {
    print('Error loading today stats: $e');
  }
}


bool _isDateToday(String dateString, DateTime today) {
  try {
    // Try to extract date from formats like "Tomorrow (10/10/2025)"
    final regex = RegExp(r'(\d{1,2}/\d{1,2}/\d{4})');
    final match = regex.firstMatch(dateString);
    if (match != null) {
      final datePart = match.group(1);
      final date = DateFormat('dd/MM/yyyy').parse(datePart!);
      return date.year == today.year && 
             date.month == today.month && 
             date.day == today.day;
    }
    
    // Check if it says "Today" or "tomorrow"
    if (dateString.toLowerCase().contains('today')) {
      return true;
    }
    
    if (dateString.toLowerCase().contains('tomorrow')) {
      final tomorrow = today.add(Duration(days: 1));
      // Extract the date part from "Tomorrow (10/10/2025)"
      final regex = RegExp(r'\((\d{1,2}/\d{1,2}/\d{4})\)');
      final match = regex.firstMatch(dateString);
      if (match != null) {
        final datePart = match.group(1);
        final date = DateFormat('dd/MM/yyyy').parse(datePart!);
        return date.year == tomorrow.year && 
               date.month == tomorrow.month && 
               date.day == tomorrow.day;
      }
    }
    
    // Try other date formats
    List<String> formats = ['dd/MM/yyyy', 'yyyy-MM-dd', 'MM/dd/yyyy'];
    for (final format in formats) {
      try {
        final date = DateFormat(format).parse(dateString);
        return date.year == today.year && 
               date.month == today.month && 
               date.day == today.day;
      } catch (e) {
        continue;
      }
    }
    
    return false;
  } catch (e) {
    print('Error parsing date: $e');
    return false;
  }
}
Future<void> _loadTodaySessions() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    
    // Get today's sessions
    final sessionsSnapshot = await FirebaseFirestore.instance
        .collection('doctorSchedules')
        .where('doctorId', isEqualTo: user.uid)
        .where('availableDate', isEqualTo: today)
        .get();

    int activeSessions = 0;
    
    for (final doc in sessionsSnapshot.docs) {
      final session = doc.data();
      
      // Check if session is active (not ended)
      final sessionEnded = session['sessionEnded'] ?? true;
      if (!sessionEnded) {
        activeSessions++;
      }
    }

    setState(() {
      todaySessionsCount = sessionsSnapshot.docs.length;
      hasActiveSession = activeSessions > 0;
    });
  } catch (e) {
    print('Error loading today sessions: $e');
  }
}

 // Get unread message counts for each chat room
Future<void> _loadUnreadMessagesCount() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print('📥 Loading unread messages count...');

    // Reset count
    setState(() {
      unreadMessagesCount = 0;
      _unreadCounts.clear();
    });

    // Get all chat rooms for this doctor
    final chatRoomsSnapshot = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('doctorId', isEqualTo: user.uid)
        .get();

    int totalUnread = 0;
    
    print('Found ${chatRoomsSnapshot.docs.length} chat rooms');

    // Check each chat room for unread messages
    for (final chatRoom in chatRoomsSnapshot.docs) {
      final chatRoomId = chatRoom.id;
      final chatData = chatRoom.data();
      
      print('Checking chat room: ${chatRoomId}');
      
      try {
        // Query for unread messages where:
        // 1. The message is not read (read == false)
        // 2. The sender is NOT the doctor (patient sent it)
        final unreadSnapshot = await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .where('read', isEqualTo: false)
            .where('senderId', isNotEqualTo: user.uid)
            .get();

        final roomUnread = unreadSnapshot.docs.length;
        totalUnread += roomUnread;

        if (roomUnread > 0) {
          print(' Found ${roomUnread} unread messages in room ${chatRoomId}');
        }

        // Store individual patient unread counts if needed
        final patientId = chatData['patientId'];
        if (patientId != null) {
          setState(() {
            _unreadCounts[patientId] = roomUnread;
          });
        }
      } catch (e) {
        print('❌ Error checking chat room ${chatRoomId}: $e');
      }
    }

    print('🎯 Total unread messages: ${totalUnread}');

    setState(() {
      unreadMessagesCount = totalUnread;
    });
  } catch (e) {
    print('❌ Error loading unread messages count: $e');
    setState(() {
      unreadMessagesCount = 0;
    });
  }
}
 void _onItemTapped(int index) {
  if (index == 1) { 
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
    ).then((_) {
    
      _loadDoctorData();
      _loadDoctorProfileImage();
    });
  } else {
    
    setState(() {
      _selectedIndex = index;
    });
  }
}

  
  
  void _navigateToAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorAppointmentsScreen()),
    );
  }
  void _navigateToTodayAppointments() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const TodayAppointmentsScreen()),
  );
}

  void _navigateToSchedule() {
    if (doctorData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CreateScheduleScreen(doctor: doctorData!)),
      );
    } else {
      _showErrorSnackBar('Doctor data not loaded');
    }
  }

 

  

  

  

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationScreen()),
    );
  }

  // ADD THESE NEW NAVIGATION METHODS FOR CHAT
  void _navigateToChatList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorChatListScreen()),
    );
  }

  void _navigateToVideoCalls() {
    Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DoctorTelemedicinePage(
        doctorId: doctorId!,
        doctorName: doctorName!,),
    ),
  );
  }
void _navigateTOfeedbackscreen(){
  Navigator.push(context,
  MaterialPageRoute(builder: (context) => DoctorFeedbackDashboard(),)
  );
}
void _navigateTowrittenPrescriptions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AllPrescriptionsScreen())
    );
  }
  void _navigatetosessions(){
    Navigator.push(
      context,
       MaterialPageRoute(builder:(context) =>Allschedule())
      );
  }
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
void _navigatetoAmmountAnalysis(){
  Navigator.push(context, MaterialPageRoute(builder: (context) => const DoctorRevenueAnalysisPage()));
}
  
  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      _buildHomePage(context),
      const EditProfileScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingState()
          : _buildCurrentScreen(),
          
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
Widget _buildCurrentScreen() {
  switch (_selectedIndex) {
    case 0:
      return _buildHomePage(context);
    case 1:
      return EditProfileScreen();
    case 2:
      return const SettingsScreen();
    default:
      return _buildHomePage(context);
  }
}
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      
      title: Text(
        _selectedIndex == 0 
          ? 'Doctor Dashboard' 
          : _selectedIndex == 1 
            ? 'My Profile' 
            : 'Settings',
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        if (_selectedIndex == 0)
          Row(
            children: [
              
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chat_outlined, color: primaryColor),
                        onPressed: _navigateToChatList,
                      ),
                    ),
                    if (unreadMessagesCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            unreadMessagesCount > 9 ? '9+' : '$unreadMessagesCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
             
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                      icon: const Icon(Icons.notifications),
                       onPressed: () {
                      Navigator.push(
                      context,
                       MaterialPageRoute(
                        builder: (context) => DoctorNotificationPage(
                        doctorId: doctorId!,
                        doctorName: doctorName!,
        ),
      ),
    );
  },
),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your dashboard...',
            style: TextStyle(
              fontSize: 16,
              color: primaryColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: primaryColor,
          unselectedItemColor: accentColor.withOpacity(0.6),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
          unselectedLabelStyle: TextStyle(fontSize: 12, color: accentColor.withOpacity(0.6)),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _selectedIndex == 0
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.home_outlined, size: 24, color: _selectedIndex == 0 ? primaryColor : accentColor.withOpacity(0.6)),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.home_filled, size: 24, color: primaryColor),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _selectedIndex == 1
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.person_outline, size: 24, color: _selectedIndex == 1 ? primaryColor : accentColor.withOpacity(0.6)),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person, size: 24, color: primaryColor),
              ),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: _selectedIndex == 2
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.settings_outlined, size: 24, color: _selectedIndex == 2 ? primaryColor : accentColor.withOpacity(0.6)),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.settings, size: 24, color: primaryColor),
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage(BuildContext context) {
    return RefreshIndicator(
      backgroundColor: backgroundColor,
      color: primaryColor,
      onRefresh: () async {
        await _loadDoctorData();
        await _loadTodayStats();
        await _loadUnreadMessagesCount();
         await _loadDoctorProfileImage();
         await _loadTodaySessions();
         await _loadDoctorFeedback();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: <Widget>[
            _buildWelcomeHeader(),
            const SizedBox(height: 20),
            _buildStatsSection(),
            const SizedBox(height: 24),
            _buildQuickActionsSection(),
            const SizedBox(height: 24),
            _buildRecentActivitySection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

 Widget _buildWelcomeHeader() {
  final doctorName = doctorData?['fullname'] ?? 'Dr. Silva';
  final firstName = doctorName.split(' ').first;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor,
          secondaryColor,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_getGreeting()},',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dr. $firstName! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                doctorData?['specialization'] ?? 'General Practitioner',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Ready for your consultations',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _buildProfileAvatar(),
        ),
      ],
    ),
  );
}
Widget _buildProfileAvatar() {
  print('🖼️ Building profile avatar. Image URL: $_doctorProfileImageUrl');
  
  if (_doctorProfileImageUrl != null && _doctorProfileImageUrl!.isNotEmpty) {
    return ClipOval(
      child: Image.network(
        _doctorProfileImageUrl!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Profile image loaded successfully');
            return child;
          }
          print('⏳ Loading profile image...');
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading profile image: $error');
          return _buildDefaultAvatar();
        },
      ),
    );
  } else {
    print('ℹ️ No profile image URL, using default avatar');
    return _buildDefaultAvatar();
  }
}

Widget _buildDefaultAvatar() {
  return const Icon(
    Icons.person,
    color: Colors.white,
    size: 40,
  );
}

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  
Widget _buildStatsSection() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Today\'s Appointments',
            value: todayAppointmentsCount.toString(),
            icon: Icons.calendar_today_outlined,
            color: primaryColor, // Use your primary theme color
            onTap: _navigateToTodayAppointments,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFeedbackCard(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Today\'s Sessions',
            value: todaySessionsCount.toString(),
            icon: hasActiveSession ? Icons.play_circle_fill : Icons.schedule,
            color: hasActiveSession ? Colors.green : Colors.orange, // Keep these as they're status indicators
            //onTap: _navigateToTodaySessions,
          ),
        ),
      ],
    ),
  );
}


Widget _buildFeedbackCard() {
  final feedbackColor = _getFeedbackColor(doctorFeedbackScore);
  
  return GestureDetector(
    
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: backgroundColor,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: feedbackColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_rate,
              color: feedbackColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          // Display stars for rating
          if (doctorFeedbackScore > 0)
            Column(
              children: [
                Text(
                  doctorFeedbackScore.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: feedbackColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '/5',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            )
          else
            Text(
              'No Rating',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            totalFeedbackCount > 0 
                ? '$totalFeedbackCount ${totalFeedbackCount == 1 ? 'review' : 'reviews'}'
                : 'Be the first',
            style: TextStyle(
              fontSize: 11,
              color: primaryColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Color _getFeedbackColor(double score) {
  if (score == 0) return Colors.grey;
  if (score < 2.5) return Colors.redAccent;
  if (score < 3.5) return Colors.orange;
  if (score < 4.0) return secondaryColor; // Use your secondary color for medium ratings
  return Colors.green; // Keep green for excellent ratings
}

  Widget _buildStatCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: backgroundColor,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          // Title (now used for rating)
          Text(
            title,
            style: TextStyle(
              fontSize: title.contains('/5') ? 14 : 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Value (now used for review count)
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: primaryColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

  Widget _buildQuickActionsSection() {
  
  final Color primaryDark = const Color(0xFF12899B); 
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85, 
          children: [
            _buildQuickActionButton(
              icon: Icons.calendar_today_outlined,
              label: 'All Appointments',
              color: primaryDark,
              onTap: _navigateToAppointments,
            ),
            _buildQuickActionButton(
              icon: Icons.schedule_outlined,
              label: 'Create Session',
              color: primaryColor,
              onTap: _navigateToSchedule,
            ),
            
            
           
           
            _buildQuickActionButton(
              icon: Icons.chat_outlined,
              label: 'Messages',
              color: primaryDark,
              onTap: _navigateToChatList,
              badgeCount: unreadMessagesCount,
            ),
            _buildQuickActionButton(
              icon: Icons.video_call_outlined,
              label: 'Telemedicine',
              color: primaryDark,
              onTap: _navigateToVideoCalls,
            ),
           
            _buildQuickActionButton(
              icon: Icons.star_rate, 
              label: 'Feedback',
              onTap: _navigateTOfeedbackscreen, 
              color: primaryDark
            ),
            _buildQuickActionButton(
              icon: Icons.description, 
              label: 'Written Prescriptions',
              onTap: _navigateTowrittenPrescriptions, 
              color: primaryDark
            ),
            _buildQuickActionButton(
              icon: Icons.medical_information, 
              label: 'My consultation',
              onTap: _navigatetosessions, 
              color: primaryDark
            ),
            _buildQuickActionButton(
              icon: Icons.show_chart, 
              label: 'anlysis ammount',
              onTap: _navigatetoAmmountAnalysis, 
              color: primaryDark
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildQuickActionButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
  int badgeCount = 0,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: backgroundColor,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              
              Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
              const SizedBox(height: 6),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Badge
          if (badgeCount > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
  Widget _buildRecentActivitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  // View all activity
                  _navigateToAppointments();
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: backgroundColor,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildActivityItem(
                  icon: Icons.calendar_today,
                  title: 'Appointments Today',
                  subtitle: '$todayAppointmentsCount scheduled',
                  color: primaryColor,
                  onTap: _navigateToTodayAppointments,
                ),
                const Divider(height: 24, color: Color(0xFFDDF0F5)),
                
                const Divider(height: 24, color: Color(0xFFDDF0F5)),
                _buildActivityItem(
                  icon: Icons.chat,
                  title: 'Unread Messages',
                  subtitle: '$unreadMessagesCount new messages',
                  color: const Color(0xFFFF9800),
                  onTap: _navigateToChatList,
                ),
                const Divider(height: 24, color: Color(0xFFDDF0F5)),
               
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: accentColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}