// lib/screens/admin_screens/admin_home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/admin_screens/admin_appoinment_mng.dart';
import 'package:frontend/screens/admin_screens/admin_appoinment_mng.dart' as appointment_mng;
import 'package:frontend/screens/admin_screens/admin_doctor_manegment.dart' as doctor_management;
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/admin_screens/admin_schedule_approval_screen.dart';
import 'package:frontend/screens/admin_screens/admin_appointment_management.dart';
import 'package:frontend/screens/admin_screens/admin_settings_screen.dart';
import 'package:frontend/screens/admin_screens/admin_test_reports_screen.dart';
import 'admin_feedback_management.dart'; // Import the new feedback management

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
        
        final querySnapshot = await FirebaseFirestore.instance
            .collection('medical_centers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          setState(() {
            _medicalCenterName = doc['name'];
            _medicalCenterId = doc.id;
            _isLoading = false;
          });
        } else {
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
    if (index == 1) { // Settings tab
      if (_medicalCenterId != null && _medicalCenterName != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminSettingsScreen(
              medicalCenterId: _medicalCenterId!,
              medicalCenterName: _medicalCenterName!,
            ),
          ),
        );
      } else {
        _showSnackBar('Loading medical center information...');
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Settings screen
  Widget _buildSettingsScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Account Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
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
          ],
        ),
      ),
    );
  }

  // Feedback Management Screen - Now uses the separate file
  Widget _buildFeedbackManagementScreen() {
    return AdminFeedbackManagement(
      medicalCenterId: _medicalCenterId ?? '',
      medicalCenterName: _medicalCenterName ?? 'Medical Center',
    );
  }

  // Main actions on home page
  Widget _buildMainActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF18A3B6),
                  const Color(0xFF18A3B6).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _medicalCenterName ?? 'Medical Center',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Manage your medical center efficiently',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Quick Stats
          _buildQuickStats(),
          const SizedBox(height: 20),
          
          // Main Actions Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                _buildActionButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Manage Appointments',
                  color: Colors.blue,
                  onTap: () {
                    if (_medicalCenterId != null && _medicalCenterName != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminAppointmentManagement(
                            medicalCenterId: _medicalCenterId!,
                            medicalCenterName: _medicalCenterName!
                          ),
                        ),
                      );
                    } else {
                      _showSnackBar('Loading medical center information...');
                    }
                  }, 
                ),
                _buildActionButton(
                  icon: Icons.person,
                  label: 'Manage Doctors',
                  color: Colors.green,
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
                      _showSnackBar('Loading medical center information...');
                    }
                  },
                ),
                _buildActionButton(
                  icon: Icons.feedback,
                  label: 'Feedback Management',
                  color: Colors.orange,
                  onTap: () {
                    if (_medicalCenterId != null && _medicalCenterName != null) {
                      setState(() {
                        _selectedIndex = 2;
                      });
                    } else {
                      _showSnackBar('Loading medical center information...');
                    }
                  },
                ),
                
                _buildActionButton(
                  icon: Icons.schedule,
                  label: 'Schedule Approval',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminScheduleApprovalScreen(
                          medicalCenterId: _medicalCenterId!,
                          medicalCenterName: _medicalCenterName!
                        ),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  color: Colors.grey,
                  onTap: () {
                    if (_medicalCenterId != null && _medicalCenterName != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminSettingsScreen(
                            medicalCenterId: _medicalCenterId!,
                            medicalCenterName: _medicalCenterName!,
                          ),
                        ),
                      );
                    } else {
                      _showSnackBar('Loading medical center information...');
                    }
                  },
                ),
                _buildActionButton(
                  icon: Icons.assignment,
                  label: 'Test Reports',
                  color: const Color.fromARGB(255, 255, 36, 229),
                  onTap: () {
                    if (_medicalCenterId != null && _medicalCenterName != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminTestReportsScreen(
                            medicalCenterId: _medicalCenterId!,
                            medicalCenterName: _medicalCenterName!,
                          ),
                        ),
                      );
                    } else {
                      _showSnackBar('Loading medical center information...');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
  return FutureBuilder(
    future: _getQuickStats(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final stats = snapshot.data as Map<String, dynamic>? ?? {
        'totalPatientFeedback': 0,
        'totalDoctorFeedback': 0,
        'totalReviews': 0,
        'patientAvgRating': 0.0,
        'doctorAvgRating': 0.0,
        'overallRating': 0.0,
      };

      return Row(
        children: [
          _buildStatItem('Total Reviews', stats['totalReviews'].toString(), Icons.reviews, Colors.blue),
          const SizedBox(width: 10),
          _buildStatItem('Overall Rating', stats['overallRating'].toStringAsFixed(1), Icons.star, Colors.amber),
          const SizedBox(width: 10),
          _buildStatItem('Patient Reviews', stats['totalPatientFeedback'].toString(), Icons.person, Colors.green),
          const SizedBox(width: 10),
          _buildStatItem('Doctor Reviews', stats['totalDoctorFeedback'].toString(), Icons.medical_services, Colors.purple),
        ],
      );
    },
  );
}

Future<Map<String, dynamic>> _getQuickStats() async {
  try {
    // Get patient->medical center feedback
    final patientFeedbackQuery = await FirebaseFirestore.instance
        .collection('feedback')
        .get();

    final patientFeedbackForCenter = patientFeedbackQuery.docs
        .where((doc) {
          final data = doc.data();
          final medicalCenterId = data['medicalCenterId'];
          final doctorId = data['doctorId'];
          final feedbackType = data['feedbackType'];
          
          // Only count patient->medical center feedback
          final isPatientToMedicalCenter = (doctorId == null || doctorId.toString().isEmpty) && 
                                       feedbackType == 'medical_center';
          
          return medicalCenterId == _medicalCenterId && isPatientToMedicalCenter;
        })
        .toList();

    // Get doctor feedback
    final doctorFeedbackQuery = await FirebaseFirestore.instance
        .collection('doctorMedicalCenterFeedback')
        .where('medicalCenterId', isEqualTo: _medicalCenterId)
        .get();

    // Calculate average ratings
    double patientAvgRating = 0.0;
    if (patientFeedbackForCenter.isNotEmpty) {
      double totalRating = 0;
      int ratedCount = 0;
      for (final doc in patientFeedbackForCenter) {
        final rating = doc['rating'] ?? 0;
        if (rating > 0) {
          totalRating += rating;
          ratedCount++;
        }
      }
      patientAvgRating = ratedCount > 0 ? totalRating / ratedCount : 0.0;
    }

    double doctorAvgRating = 0.0;
    if (doctorFeedbackQuery.docs.isNotEmpty) {
      double totalRating = 0;
      int ratedCount = 0;
      for (final doc in doctorFeedbackQuery.docs) {
        final rating = doc['rating'] ?? 0;
        if (rating > 0) {
          totalRating += rating;
          ratedCount++;
        }
      }
      doctorAvgRating = ratedCount > 0 ? totalRating / ratedCount : 0.0;
    }

    // Calculate overall combined rating (weighted average)
    double overallRating = 0.0;
    int totalReviews = patientFeedbackForCenter.length + doctorFeedbackQuery.docs.length;
    
    if (totalReviews > 0) {
      // Simple average of all individual ratings
      double totalRatingSum = 0;
      int totalRatedCount = 0;
      
      // Add patient ratings
      for (final doc in patientFeedbackForCenter) {
        final rating = doc['rating'] ?? 0;
        if (rating > 0) {
          totalRatingSum += rating;
          totalRatedCount++;
        }
      }
      
      // Add doctor ratings
      for (final doc in doctorFeedbackQuery.docs) {
        final rating = doc['rating'] ?? 0;
        if (rating > 0) {
          totalRatingSum += rating;
          totalRatedCount++;
        }
      }
      
      overallRating = totalRatedCount > 0 ? totalRatingSum / totalRatedCount : 0.0;
    }

    return {
      'totalPatientFeedback': patientFeedbackForCenter.length,
      'totalDoctorFeedback': doctorFeedbackQuery.docs.length,
      'totalReviews': totalReviews,
      'patientAvgRating': patientAvgRating,
      'doctorAvgRating': doctorAvgRating,
      'overallRating': overallRating,
    };
  } catch (e) {
    debugPrint('Error getting quick stats: $e');
    return {
      'totalPatientFeedback': 0,
      'totalDoctorFeedback': 0,
      'totalReviews': 0,
      'patientAvgRating': 0.0,
      'doctorAvgRating': 0.0,
      'overallRating': 0.0,
    };
  }
}

Widget _buildStatItem(String title, String value, IconData icon, Color color) {
  bool isRating = title.contains('Rating');
  double? numericValue = isRating ? double.tryParse(value) : null;
  
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isRating ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: isRating && numericValue != null
                  ? (numericValue >= 4.0 ? Colors.green : 
                     numericValue >= 3.0 ? Colors.orange : Colors.red)
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (isRating && numericValue != null && numericValue > 0) ...[
            const SizedBox(height: 3),
            // FIXED: Use text stars that fit in any space
            Text(
              '★' * numericValue.round() + '☆' * (5 - numericValue.round()),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 11, // Very small
                height: 1.0, // Tight line height
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF18A3B6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildMainActions(),
      _buildSettingsScreen(),
      _buildFeedbackManagementScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _isLoading ? 'Loading...' : _medicalCenterName ?? 'Admin Dashboard',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: const Color(0xFF18A3B6),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Feedback',
          ),
        ],
      ),
    );
  }
}