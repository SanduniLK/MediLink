import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/providers/doctor_provider.dart';
import 'package:frontend/screens/doctor_screens/create_schedule_screen.dart';
import 'package:frontend/screens/doctor_screens/doctor_appointments_page.dart';
import 'package:frontend/screens/doctor_screens/doctor_profile.dart';
import 'package:frontend/screens/doctor_screens/doctor_qr_scanner_screen.dart';
import 'package:frontend/screens/doctor_screens/doctor_queue_dashboard.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';


import 'package:frontend/screens/doctor_screens/settings_screen.dart';
import 'package:frontend/screens/doctor_screens/telemedicine_appointments_screen.dart';
import 'package:frontend/screens/patient_screens/notifications.dart';
import 'package:provider/provider.dart';

// ADD THESE IMPORT FOR CHAT SCREENS
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

  // Your exact theme colors
  final Color primaryColor = const Color(0xFF18A3B6);
  final Color secondaryColor = const Color(0xFF32BACD);
  final Color accentColor = const Color(0xFF85CEDA);
  final Color backgroundColor = const Color(0xFFDDF0F5);
  final Color lightBackground = const Color(0xFFF0F9FA);

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
    _loadTodayStats();
    _loadUnreadMessagesCount();
  }

  Future<void> _loadDoctorData() async {
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

  Future<void> _loadTodayStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .get();

      final waitingSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .where('queueStatus', whereIn: ['waiting', 'checked-in'])
          .get();

      setState(() {
        todayAppointmentsCount = appointmentsSnapshot.docs.length;
        waitingPatientsCount = waitingSnapshot.docs.length;
        hasActiveQueue = waitingPatientsCount > 0;
      });
    } catch (e) {
      // Error loading today stats
    }
  }

  Future<void> _loadUnreadMessagesCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .where('hasUnreadMessages', isEqualTo: true)
          .where('unreadFor', isEqualTo: user.uid)
          .get();

      setState(() {
        unreadMessagesCount = appointmentsSnapshot.docs.length;
      });
    } catch (e) {
      print('Error loading unread messages: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ==================== NAVIGATION METHODS ====================
  
  void _navigateToAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorAppointmentsScreen()),
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

  void _navigateToPatients() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorAppointmentsScreen()),
    );
  }

  void _navigateToPrescriptions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PrescriptionScreen()),
    );
  }

  void _navigateToLiveQueue() {
    final doctorProvider = Provider.of<DoctorProvider>(context, listen: false);
  
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: doctorProvider,
          child: const DoctorQueueDashboard(),
        ),
      ),
    );
  }

  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorQRScannerScreen()),
    );
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
      builder: (context) => TelemedicineAppointmentsScreen(),
    ),
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

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
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
          : IndexedStack(
              index: _selectedIndex,
              children: widgetOptions,
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
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
              // Chat Icon with Badge
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
              // Notifications Icon
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
                    icon: Icon(Icons.notifications_outlined, color: primaryColor),
                    onPressed: _navigateToNotifications,
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
          // Enhanced Doctor Avatar with better styling
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
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
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
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Waiting Patients',
              value: waitingPatientsCount.toString(),
              icon: Icons.people_outline,
              color: secondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Queue Status',
              value: hasActiveQueue ? 'Active' : 'Inactive',
              icon: hasActiveQueue ? Icons.play_circle_fill : Icons.pause_circle_filled,
              color: hasActiveQueue ? const Color(0xFF4CAF50) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: primaryColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    // Create color variations from your primary color
    final Color primaryDark = const Color(0xFF12899B); // Darker shade
    final Color primaryLight = const Color(0xFF5BC4D4); // Lighter shade
    
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
            children: [
              _buildQuickActionButton(
                icon: Icons.calendar_today_outlined,
                label: 'Appointments',
                color: primaryDark,
                onTap: _navigateToAppointments,
              ),
              _buildQuickActionButton(
                icon: Icons.schedule_outlined,
                label: 'Schedule',
                color: primaryColor,
                onTap: _navigateToSchedule,
              ),
              _buildQuickActionButton(
                icon: Icons.people_outlined,
                label: 'Patients',
                color: primaryDark,
                onTap: _navigateToPatients,
              ),
              _buildQuickActionButton(
                icon: Icons.assignment_outlined,
                label: 'Prescriptions',
                color: primaryDark,
                onTap: _navigateToPrescriptions,
              ),
              _buildQuickActionButton(
                icon: Icons.queue_play_next,
                label: 'Live Queue',
                color: primaryDark,
                onTap: _navigateToLiveQueue,
                badgeCount: hasActiveQueue ? waitingPatientsCount : 0,
              ),
              _buildQuickActionButton(
                icon: Icons.qr_code_scanner_outlined,
                label: 'QR Scanner',
                color: primaryDark,
                onTap: _navigateToQRScanner,
              ),
              // NEW CHAT ACTION BUTTON
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
                icon: Icons.medical_services_outlined,
                label: 'Medical Records',
                color: primaryDark,
                onTap: () => _showComingSoonSnackBar('Medical Records'),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
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
                  onTap: _navigateToAppointments,
                ),
                const Divider(height: 24, color: Color(0xFFDDF0F5)),
                _buildActivityItem(
                  icon: Icons.people,
                  title: 'Patients Waiting',
                  subtitle: '$waitingPatientsCount in queue',
                  color: secondaryColor,
                  onTap: _navigateToLiveQueue,
                ),
                const Divider(height: 24, color: Color(0xFFDDF0F5)),
                _buildActivityItem(
                  icon: Icons.chat,
                  title: 'Unread Messages',
                  subtitle: '$unreadMessagesCount new messages',
                  color: const Color(0xFFFF9800),
                  onTap: _navigateToChatList,
                ),
                const Divider(height: 24, color: Color(0xFFDDF0F5)),
                _buildActivityItem(
                  icon: Icons.access_time,
                  title: 'Queue Status',
                  subtitle: hasActiveQueue ? 'Active - Manage now' : 'No active queue',
                  color: hasActiveQueue ? const Color(0xFF4CAF50) : Colors.grey,
                  onTap: hasActiveQueue ? _navigateToLiveQueue : null,
                ),
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