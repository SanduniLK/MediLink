import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/admin_screens/admin_appoinment_mng.dart'; // Add this import
import 'package:frontend/screens/admin_screens/admin_appoinment_mng.dart' as appointment_mng;
import 'package:frontend/screens/admin_screens/admin_doctor_manegment.dart' as doctor_management;
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/admin_screens/admin_schedule_approval_screen.dart';
import 'package:frontend/screens/admin_screens/appoinment_management.dart'; // This might be the wrong one
import 'package:frontend/screens/admin_screens/admin_appointment_management.dart';

// If AdminAppointmentManagement is in a different file, import it:
// import 'package:frontend/screens/admin_screens/admin_appointment_management.dart';
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  String? _medicalCenterName;
  String? _medicalCenterId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMedicalCenterData();
  }

  Future<void> _fetchMedicalCenterData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final email = currentUser.email;
        
        // Query medical_centers collection by email
        final querySnapshot = await FirebaseFirestore.instance
            .collection('medical_centers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          setState(() {
            _medicalCenterName = doc['name'];
            _medicalCenterId = doc.id; // Get the document ID as medicalCenterId
            _isLoading = false;
          });
        } else {
          // If not found in medical_centers, check if it's a regular admin
          final adminDoc = await FirebaseFirestore.instance
              .collection('admin')
              .doc(currentUser.uid)
              .get();
              
          if (adminDoc.exists) {
            setState(() {
              _medicalCenterId = adminDoc.data()?['medicalCenterId'];
              _medicalCenterName = adminDoc.data()?['medicalCenterName'] ?? 'Medical Center';
              _isLoading = false;
            });
          } else {
            setState(() {
               _medicalCenterId = 'default_medical_center_id';
              _medicalCenterName = 'Medical Center';
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
         _medicalCenterId = 'default_medical_center_id';
        _medicalCenterName = 'Medical Center';
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Settings screen
  Widget _buildSettingsScreen() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const SignInPage(),
            ),
            (route) => false,
          );
        },
        icon: const Icon(Icons.logout),
        label: const Text("Sign Out"),
      ),
    );
  }

  // Main actions on home page - FIXED: No parameters needed
  Widget _buildMainActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _buildActionButton(
            icon: Icons.calendar_today_outlined,
            label: 'Manage Appointments',
            onTap: () {
              if (_medicalCenterId != null && _medicalCenterName != null) {
                if (_medicalCenterId != null && _medicalCenterName != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Use the prefix to specify which one you want
                    builder: (context) => AdminAppointmentManagement(medicalCenterId: _medicalCenterId!, medicalCenterName: _medicalCenterName!)
                  ),
                );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loading medical center information...')),
                );
              }
            }, 
          ),
          _buildActionButton(
            icon: Icons.person,
            label: 'Manage Doctors',
            onTap: () {
              if (_medicalCenterName != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => doctor_management.DoctorManagementScreen(
                      medicalCenterName: _medicalCenterName!,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loading medical center information...')),
                );
              }
            },
          ),
          _buildActionButton(
            icon: Icons.people,
            label: 'Manage Patients',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manage Patients - Coming Soon')),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF32BACD), size: 35),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF32BACD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(child: _buildMainActions()),
      _buildSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: Text(
          _isLoading ? 'Loading...' : _medicalCenterName ?? 'Admin Dashboard',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        automaticallyImplyLeading: false,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 5,
        selectedItemColor: const Color(0xFF32BACD),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}