// lib/screens/admin_screens/admin_home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/admin_screens/admin_analyze.page.dart';
import 'package:frontend/screens/admin_screens/admin_appoinment_mng.dart';
import 'package:frontend/screens/admin_screens/admin_appoinment_mng.dart'
    as appointment_mng;
import 'package:frontend/screens/admin_screens/admin_doctor_manegment.dart'
    as doctor_management;
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/admin_screens/admin_schedule_approval_screen.dart';
import 'package:frontend/screens/admin_screens/admin_appointment_management.dart';
import 'package:frontend/screens/admin_screens/admin_settings_screen.dart';
import 'package:frontend/screens/admin_screens/admin_test_reports_screen.dart';
import 'package:frontend/screens/assistant_screens/assistant_management_page.dart';
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
              _medicalCenterName =
                  adminDoc.data()?['medicalCenterName'] ?? 'Medical Center';
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
    if (index == 1) {
      // Settings tab
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
                  MaterialPageRoute(builder: (context) => const SignInPage()),
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

  Widget _buildMainActions() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFD), Color(0xFFF0F4F9)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header - Elegant glass morphism
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF18A3B6), const Color(0xFF2AB7CC)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF18A3B6).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back, Admin!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _medicalCenterName ?? 'Medical Center',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Manage your medical center efficiently',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Stats - Elegant cards
            _buildQuickStats(),
            const SizedBox(height: 20),

            // Section Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard,
                    size: 18,
                    color: const Color(0xFF18A3B6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3, // Changed from 2 to 3
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9, // Adjust for square-ish buttons
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildCompactElegantButton(
                    icon: Icons.calendar_month_rounded,
                    label: 'Appointment\nmanagement',
                    color: Colors.blue,
                    onTap: () {
                      if (_medicalCenterId != null &&
                          _medicalCenterName != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminAppointmentManagement(
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
                  _buildCompactElegantButton(
                    icon: Icons.medical_services_rounded,
                    label: 'Doctor\nmanagement',
                    color: Colors.green,
                    onTap: () {
                      if (_medicalCenterName != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                doctor_management.DoctorManagementScreen(
                                  medicalCenterName: _medicalCenterName!,
                                  medicalCenterId: _medicalCenterId!,
                                ),
                          ),
                        );
                      } else {
                        _showSnackBar('Loading medical center information...');
                      }
                    },
                  ),
                  _buildCompactElegantButton(
                    icon: Icons.reviews_rounded,
                    label: 'Feedback\nmanagement',
                    color: Colors.orange,
                    onTap: () {
                      if (_medicalCenterId != null &&
                          _medicalCenterName != null) {
                        setState(() {
                          _selectedIndex = 2;
                        });
                      } else {
                        _showSnackBar('Loading medical center information...');
                      }
                    },
                  ),
                  _buildCompactElegantButton(
                    icon: Icons.schedule_send_rounded,
                    label: 'Schedule\napproval',
                    color: Colors.teal,
                    onTap: () {
                      if (_medicalCenterId != null &&
                          _medicalCenterName != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminScheduleApprovalScreen(
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
                  _buildCompactElegantButton(
                    icon: Icons.settings_suggest_rounded,
                    label: 'Settings',
                    color: Colors.grey,
                    onTap: () {
                      if (_medicalCenterId != null &&
                          _medicalCenterName != null) {
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
                  _buildCompactElegantButton(
                    icon: Icons.upload_file_outlined,
                    label: 'upload\nReports',
                    color: const Color(0xFFC135FF),
                    onTap: () {
                      if (_medicalCenterId != null &&
                          _medicalCenterName != null) {
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
                  _buildCompactElegantButton(
                    icon: Icons.analytics_rounded,
                    label: 'Revenue\nanalysis',
                    color: const Color(0xFFFF5252),
                    onTap: () {
                      if (_medicalCenterId != null &&
                          _medicalCenterName != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminRevenueAnalysisPage(),
                          ),
                        );
                      } else {
                        _showSnackBar('Loading medical center information...');
                      }
                    },
                  ),
                  _buildCompactElegantButton(
                    icon: Icons.medical_services_rounded,
                    label: 'Assistance\nmanagement',
                    color: const Color.fromARGB(255, 231, 77, 123),
                    onTap: () {
                      if (_medicalCenterName != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AssistantManagementPage(),
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
      ),
    );
  }

  Widget _buildCompactElegantButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Compact icon for 3-column layout
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.12),
                        color.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.2), width: 1),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16,
                  ), // Smaller icon for 3-column
                ),
                const SizedBox(height: 6),
                // Label
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalButton(String label, IconData icon, Color color) {
    return InkWell(
      onTap: () => _handleButtonTap(label),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleButtonTap(String label) {
    // Handle button taps based on label
    switch (label) {
      case 'Appointments\nmanagement':
        if (_medicalCenterId != null && _medicalCenterName != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminAppointmentManagement(
                medicalCenterId: _medicalCenterId!,
                medicalCenterName: _medicalCenterName!,
              ),
            ),
          );
        }
        break;
      case 'Doctors\nmanagement':
        if (_medicalCenterName != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => doctor_management.DoctorManagementScreen(
                medicalCenterName: _medicalCenterName!,
                medicalCenterId: _medicalCenterId!,
              ),
            ),
          );
        }
        break;
      case 'Feedback\nmanagement':
        if (_medicalCenterId != null && _medicalCenterName != null) {
          setState(() {
            _selectedIndex = 2;
          });
        }
        break;
      case 'Schedule\napproval':
        if (_medicalCenterId != null && _medicalCenterName != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminScheduleApprovalScreen(
                medicalCenterId: _medicalCenterId!,
                medicalCenterName: _medicalCenterName!,
              ),
            ),
          );
        }
        break;
      case 'Settings':
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
        }
        break;
      case 'Reports':
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
        }
        break;
      case 'Revenue\nanalysis':
        if (_medicalCenterId != null && _medicalCenterName != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminRevenueAnalysisPage()),
          );
        }
        break;
    }
  }

  Widget _buildMiniElegantButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.1), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumActionButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white,
                blurRadius: 0,
                offset: const Offset(0, 0),
                spreadRadius: 1,
              ),
            ],
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.15),
                            accentColor.withOpacity(0.08),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                // Label and description
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                        letterSpacing: 0.2,
                        height: 1.3,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with subtle gradient
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: color, size: 18), // Smaller icon
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10, // Smaller text
                        fontWeight: FontWeight.w600,
                        color: color,
                        letterSpacing: 0.2,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New compact action button widget
  Widget _buildCompactActionButton({
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
          borderRadius: BorderRadius.circular(12), // Reduced from 15
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // Lighter shadow
              blurRadius: 4, // Reduced from 5
              offset: const Offset(0, 2), // Reduced from 3
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10), // Reduced from 12
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24), // Reduced from 30
              ),
              const SizedBox(height: 8), // Reduced from 10
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, // Reduced from 14
                  fontWeight: FontWeight.w600, // Slightly lighter weight
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return FutureBuilder(
      future: _getQuickStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 60,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Color(0xFF18A3B6)),
            ),
          );
        }

        final stats =
            snapshot.data as Map<String, dynamic>? ??
            {
              'totalPatientFeedback': 0,
              'totalDoctorFeedback': 0,
              'totalReviews': 0,
              'patientAvgRating': 0.0,
              'doctorAvgRating': 0.0,
              'overallRating': 0.0,
            };

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _buildStatItem(
                'Total Reviews',
                stats['totalReviews'].toString(),
                Icons.reviews_rounded,
                Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildStatItem(
                'Overall Rating',
                stats['overallRating'].toStringAsFixed(1),
                Icons.star_rate_rounded,
                Colors.amber,
              ),
              const SizedBox(width: 8),
              _buildStatItem(
                'Patient Reviews',
                stats['totalPatientFeedback'].toString(),
                Icons.people_alt_rounded,
                Colors.green,
              ),
              const SizedBox(width: 8),
              _buildStatItem(
                'Doctor Reviews',
                stats['totalDoctorFeedback'].toString(),
                Icons.medical_services_rounded,
                Colors.purple,
              ),
            ],
          ),
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

      final patientFeedbackForCenter = patientFeedbackQuery.docs.where((doc) {
        final data = doc.data();
        final medicalCenterId = data['medicalCenterId'];
        final doctorId = data['doctorId'];
        final feedbackType = data['feedbackType'];

        // Only count patient->medical center feedback
        final isPatientToMedicalCenter =
            (doctorId == null || doctorId.toString().isEmpty) &&
            feedbackType == 'medical_center';

        return medicalCenterId == _medicalCenterId && isPatientToMedicalCenter;
      }).toList();

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
      int totalReviews =
          patientFeedbackForCenter.length + doctorFeedbackQuery.docs.length;

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

        overallRating = totalRatedCount > 0
            ? totalRatingSum / totalRatedCount
            : 0.0;
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

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    bool isRating = title.contains('Rating');
    double? numericValue = isRating ? double.tryParse(value) : null;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 10, color: color),
                ),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isRating ? 15 : 14,
                    fontWeight: FontWeight.w800,
                    color: isRating && numericValue != null
                        ? (numericValue >= 4.0
                              ? Colors.green
                              : numericValue >= 3.0
                              ? Colors.amber
                              : Colors.red)
                        : Colors.grey[900],
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (isRating && numericValue != null && numericValue > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    index < numericValue.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 8,
                    color: Colors.amber,
                  );
                }),
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
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1), // Color-tinted shadow
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with gradient background
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Icon(icon, color: color, size: 22), // Even smaller icon
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, // Even smaller
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.3, // Better readability
                ),
              ),
            ],
          ),
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
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Color(0xFF18A3B6)),
              ),
            )
          : _buildMainActions(),
      _buildSettingsScreen(),
      _buildFeedbackManagementScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.medical_services, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              _isLoading
                  ? 'Loading...'
                  : _medicalCenterName ?? 'Admin Dashboard',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF18A3B6),
        automaticallyImplyLeading: false,
        elevation: 4,
        shadowColor: const Color(0xFF18A3B6).withOpacity(0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: const Color(0xFF18A3B6),
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedIndex == 0
                        ? const Color(0xFF18A3B6).withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    _selectedIndex == 0
                        ? Icons.dashboard_rounded
                        : Icons.dashboard_outlined,
                    size: 22,
                  ),
                ),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedIndex == 1
                        ? const Color(0xFF18A3B6).withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    _selectedIndex == 1
                        ? Icons.settings_rounded
                        : Icons.settings_outlined,
                    size: 22,
                  ),
                ),
                label: 'Settings',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedIndex == 2
                        ? const Color(0xFF18A3B6).withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    _selectedIndex == 2
                        ? Icons.feedback_rounded
                        : Icons.feedback_outlined,
                    size: 22,
                  ),
                ),
                label: 'Feedback',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
