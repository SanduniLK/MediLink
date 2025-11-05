import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import all necessary screens
import 'package:frontend/screens/doctor_screens/doctors_list.dart';
import 'package:frontend/screens/patient_screens/PatientProfileScreen.dart';
import 'package:frontend/screens/patient_screens/ai_predications.dart';
import 'package:frontend/screens/patient_screens/analysis_report.dart';
import 'package:frontend/screens/patient_screens/feedback_form_screen.dart';
import 'package:frontend/screens/patient_screens/information.dart';
import 'package:frontend/screens/patient_screens/medical_records_screen.dart';
import 'package:frontend/screens/patient_screens/my_appointments_page.dart';
import 'package:frontend/screens/patient_screens/patient_prescriptions.dart';
import 'package:frontend/screens/patient_screens/patient_queue_status.dart';
import 'package:frontend/screens/patient_screens/patient_test_reports_screen.dart';

import 'package:frontend/telemedicine/patient_telemedicine_page.dart';

// --- Dedicated Color Palette ---
const Color kBackgroundColor = Color(0xFFDDF0F5); 
const Color kSoftAqua = Color(0xFFB2DEE6); 
const Color kTealBlue = Color(0xFF85CEDA); 
const Color kBrightCyan = Color(0xFF32BACD); 
const Color kDeepTeal = Color(0xFF18A3B6); 

class MedicalHomeScreen extends StatefulWidget {
  final String uid;
  const MedicalHomeScreen({super.key, required this.uid});

  @override
  State<MedicalHomeScreen> createState() => _MedicalHomeScreenState();
}

class _MedicalHomeScreenState extends State<MedicalHomeScreen> {
  int _selectedIndex = 0;
  String? patientId;
  String? patientName;

  @override
  void initState() {
    super.initState();
    _getPatientId();
    _getPatientInfo();
  }
void _getPatientInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        patientId = user.uid;
        patientName = user.displayName ?? 'Patient'; // Get name from Firebase or default
      });
    }
  }

  void _getPatientId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        patientId = user.uid;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      _buildHomePage(context),
      PatientProfileScreen(uid: FirebaseAuth.instance.currentUser!.uid),
      _buildSettingsPage(),
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: null, 
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: kBrightCyan,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Medical Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }

  // --- Settings Page ---
  Widget _buildSettingsPage() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kDeepTeal,
                ),
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSettingsOption(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        subtitle: 'Manage your notifications',
                        onTap: () {},
                      ),
                      const Divider(),
                      _buildSettingsOption(
                        icon: Icons.security,
                        title: 'Privacy & Security',
                        subtitle: 'Control your privacy settings',
                        onTap: () {},
                      ),
                      const Divider(),
                      _buildSettingsOption(
                        icon: Icons.help,
                        title: 'Help & Support',
                        subtitle: 'Get help and contact support',
                        onTap: () {},
                      ),
                      const Divider(),
                      _buildSettingsOption(
                        icon: Icons.info,
                        title: 'About',
                        subtitle: 'Learn more about MediLink',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'MediLink v1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: kDeepTeal, size: 30),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // --- Home Page with Layered Background Style ---
  Widget _buildHomePage(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // 1. Layered Abstract Background Shapes 
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: kTealBlue.withOpacity(0.5), 
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -200,
          right: -200,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              color: kSoftAqua.withOpacity(0.5), 
              shape: BoxShape.circle,
            ),
          ),
        ),
        
        // 2. Main Content (Header and Scrollable Body)
        SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(screenWidth),
              _buildGridButtons(),
              _buildHealthReportSummary(), 
              _buildInfoBar(),
              _buildAiSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildHeader(double screenWidth) {
  const Color kDeepTeal = Color(0xFF18A3B6);
  
  return Container(
    width: double.infinity,
    height: 300, 
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF00BCD4).withOpacity(0.8),  // Light Cyan
          const Color(0xFF0097A7).withOpacity(0.7),  // Medium Cyan
          Colors.white.withOpacity(0.4),             // White blur
          kDeepTeal.withOpacity(0.9),                // Main teal
          const Color(0xFF006064).withOpacity(0.8),  // Dark teal
          Colors.black.withOpacity(0.3),             // Black blur
        ],
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0], 
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(50),
        bottomRight: Radius.circular(50),
      ),
    ),
    child: Stack(
      children: [
        // First blur layer
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.2,
                colors: [
                  const Color(0xFF80DEEA).withOpacity(0.3),  // Very light cyan
                  const Color.fromARGB(255, 48, 122, 175).withOpacity(0.2),             // White
                  const Color(0xFF26C6DA).withOpacity(0.4),  // Bright cyan
                  kDeepTeal.withOpacity(0.6),               // Main teal
                  const Color(0xFF00838F).withOpacity(0.5), // Dark cyan
                ],
              ),
            ),
          ),
        ),
        
        // Second blur layer for depth
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),           // Top black blur
                  Colors.transparent,
                  const Color(0xFF4DD0E1).withOpacity(0.2), // Middle cyan
                  Colors.transparent,
                  Colors.black.withOpacity(0.15),          // Bottom black blur
                ],
              ),
            ),
          ),
        ),
        
        // Third gradient layer for highlights
        Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
               kDeepTeal, 
          kBrightCyan.withOpacity(0.1), 
          Colors.transparent,
          kTealBlue.withOpacity(0.15), 
          Colors.transparent,
              ],
            ),
          ),
        ),

        // Blue Circle on Right Side
        Positioned(
          right: -50,
          top: 50,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 227, 238, 243).withOpacity(0.4),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(189, 41, 181, 246).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ),

        // Second Smaller Blue Circle
        Positioned(
          right: 30,
          top: 100,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 60, 120, 147).withOpacity(0.3),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 91, 160, 192).withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        ),

        // Third Blue Circle
        Positioned(
          right: -20,
          bottom: 80,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF81D4FA).withOpacity(0.25),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF81D4FA).withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(20, 60, 20, 0), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MediLink',
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 8.0,
                      color: Colors.black45,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Hello, Patient!',
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 32, 
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black54,
                      offset: Offset(2.0, 2.0),
                    ),
                    Shadow(
                      blurRadius: 5.0,
                      color: Color(0xFF004D40),
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0, 
          right: 70, 
          child: SizedBox(
            width: 200, 
            height: 150,
            child: Image.asset(
              'assets/images/medilink_1.png', 
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight, 
            ),
          ),
        ),
      ],
    ),
  );
}
  // --- Grid Buttons ---
  Widget _buildGridButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorsListScreen()));
            },
            child: _buildActionButton(Icons.calendar_today_outlined, 'Book Appointment', kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              // FIXED: Check if patientId and patientName are available
              if (patientId != null && patientName != null) {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => PatientTelemedicinePage(
                      patientId: patientId!,
                      patientName: patientName!,
                    )
                  )
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please wait while we load your information'),
                    backgroundColor: Colors.orange,
                  )
                );
              }
            },
            child: _buildActionButton(Icons.video_call_outlined, 'Telemedicine', kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisReportScreen()));
            },
            child: _buildActionButton(Icons.show_chart_outlined, 'Health Analysis', kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              if (patientId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MyAppointmentsPage(patientId: patientId!)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to load appointments. Please try again.'), backgroundColor: Colors.red));
              }
            },
            child: _buildActionButton(Icons.schedule, "My Appointments", kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientQueueStatus()));
            },
            child: _buildActionButton(Icons.queue_play_next, "Queue", kBrightCyan),
          ),
          GestureDetector(
             onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MedicalRecordsScreen()));
              },
            child: _buildActionButton(Icons.medical_services, "Medical History", kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              if (patientId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PatientPrescriptionsScreen(patientId: patientId!)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to load prescriptions. Please try again.'), backgroundColor: Colors.red));
              }
            },
            child: _buildActionButton(Icons.medication, "Prescriptions", kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MedicalRecordsScreen()));
            },
            child: _buildActionButton(Icons.upload_file_outlined, "Upload past\nrecords", kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackFormScreen(patientId: patientId ?? '',)));
            },
            child: _buildActionButton(Icons.star_border, "feedback", kBrightCyan),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PatientTestReportsScreen()));
            },
            child: _buildActionButton(Icons.science_outlined, "Test Reports", kBrightCyan),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2), 
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12, 
              color: kDeepTeal,
              fontWeight: FontWeight.w500
            ), 
          ),
        ],
      ),
    );
  }

  // --- Summary/Info Sections ---
  Widget _buildHealthReportSummary() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AnalysisReportScreen()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kTealBlue, borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Latest Health Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InformationScreen()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kSoftAqua, borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDeepTeal)),
            Icon(Icons.arrow_forward_ios, color: kDeepTeal),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSection() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AiPredictionScreen()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kTealBlue, borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Icon(Icons.psychology_outlined, size: 40, color: Colors.white),
            Text('AI Prediction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}