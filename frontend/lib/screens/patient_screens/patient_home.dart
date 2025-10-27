import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/screens/doctor_screens/doctors_list.dart';
import 'package:frontend/screens/patient_screens/PatientProfileScreen.dart';
import 'package:frontend/screens/patient_screens/ai_predications.dart';
import 'package:frontend/screens/patient_screens/analysis_report.dart';
import 'package:frontend/screens/patient_screens/information.dart';
import 'package:frontend/screens/patient_screens/medical_records_screen.dart';
import 'package:frontend/screens/patient_screens/my_appointments_page.dart';
import 'package:frontend/screens/patient_screens/patient_prescriptions.dart';
import 'package:frontend/screens/patient_screens/patient_queue_status.dart';
import 'package:frontend/screens/patient_screens/telemedicine.dart';

class MedicalHomeScreen extends StatefulWidget {
  final String uid;
  const MedicalHomeScreen({super.key, required this.uid});

  @override
  State<MedicalHomeScreen> createState() => _MedicalHomeScreenState();
}

class _MedicalHomeScreenState extends State<MedicalHomeScreen> {
  int _selectedIndex = 0;
  String? patientId;

  @override
  void initState() {
    super.initState();
    _getPatientId();
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

  // Sign out function
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to login screen or initial screen after sign out
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
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text(
          'Medical Home',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF32BACD),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Medical Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }

  // New Settings Page with Sign Out Button
  Widget _buildSettingsPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 30),
            
            // Settings Options Card
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
                      onTap: () {
                        // Add notification settings functionality
                      },
                    ),
                    const Divider(),
                    _buildSettingsOption(
                      icon: Icons.security,
                      title: 'Privacy & Security',
                      subtitle: 'Control your privacy settings',
                      onTap: () {
                        // Add privacy settings functionality
                      },
                    ),
                    const Divider(),
                    _buildSettingsOption(
                      icon: Icons.help,
                      title: 'Help & Support',
                      subtitle: 'Get help and contact support',
                      onTap: () {
                        // Add help & support functionality
                      },
                    ),
                    const Divider(),
                    _buildSettingsOption(
                      icon: Icons.info,
                      title: 'About',
                      subtitle: 'Learn more about MediLink',
                      onTap: () {
                        // Add about functionality
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Sign Out Button
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
            
            // App Version Info
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
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF18A3B6), size: 30),
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

  Widget _buildHomePage(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
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
    );
  }

  Widget _buildHeader(double screenWidth) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF18A3B6),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MediLink',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hello, Patient!',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: screenWidth * 0.7,
              height: screenWidth * 0.45,
              child: Image.asset(
                'assets/images/medilink_1.png',
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DoctorsListScreen()),
            );
          },
          child: _buildActionButton(
              Icons.calendar_today_outlined, 'Book Appointment', const Color(0xFF32BACD)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelemedicineScreen()),
            );
          },
          child: _buildActionButton(
              Icons.video_call_outlined, 'Telemedicine', const Color(0xFF32BACD)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalysisReportScreen()),
            );
          },
          child: _buildActionButton(
              Icons.show_chart_outlined, 'Health Analysis', const Color(0xFF32BACD)),
        ),
        GestureDetector(
          onTap: () {
            if (patientId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MyAppointmentsPage(patientId: patientId!)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to load appointments. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: _buildActionButton(
              Icons.schedule, "My Appointments", const Color(0xFF32BACD)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PatientQueueStatus()),
            );
          },
          child: _buildActionButton(
              Icons.queue_play_next, "Queue", const Color(0xFF32BACD)),
        ),
        _buildActionButton(
            Icons.medical_services, "Medical History", const Color(0xFF32BACD)),
        // ✅ CORRECTED: Prescriptions button with proper GestureDetector
        GestureDetector(
          onTap: () {
            if (patientId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientPrescriptionsScreen(patientId: patientId!),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to load prescriptions. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: _buildActionButton(
            Icons.medication, 
            "Prescriptions", 
            const Color(0xFF32BACD),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(context, 
            MaterialPageRoute(builder: (_)=> MedicalRecordsScreen()),
            );
          },
          child: _buildActionButton(Icons.upload_file_outlined,
          "Upload past\nrecords",const Color(0xFF32BACD)), 
          ),
            
        
      ],
    ),
  );
}

  Widget _buildHealthReportSummary() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AnalysisReportScreen()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF85CEDA), borderRadius: BorderRadius.circular(15)),
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
        decoration: BoxDecoration(color: const Color(0xFFB2DEE6), borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6))),
            Icon(Icons.arrow_forward_ios, color: Color(0xFF18A3B6)),
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
        decoration: BoxDecoration(color: const Color(0xFF85CEDA), borderRadius: BorderRadius.circular(15)),
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

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(height: 8),
          Text(
            label, 
            textAlign: TextAlign.center, 
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}