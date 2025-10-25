import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/Sadmin_screens/SuperAdminPharmacyApprovalScreen.dart';
import 'package:intl/intl.dart';

// Screens
import 'package:frontend/screens/Sadmin_screens/analysisScreen.dart';
import 'package:frontend/screens/Sadmin_screens/mediclecenteManagement.dart' as sadmin;
import 'package:frontend/screens/Sadmin_screens/pharmacy_management.dart';

import 'package:frontend/screens/admin_screens/admin_doctor_manegment.dart';
import 'package:frontend/screens/admin_screens/admin_patient_management.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart' as enroll;

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Dashboard stats
  int _totalMedicalCenters = 0;
  int _totalDoctors = 0;
  int _totalPatients = 0;
  int _totalPharmacies = 0;
  int _pendingPharmacyRequests = 0;
  int _pendingDoctorRequests = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    // Listen to real-time updates for all stats
    _firestore.collection('medical_centers').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalMedicalCenters = snapshot.docs.length;
        });
      }
    });

    _firestore.collection('doctors').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalDoctors = snapshot.docs.length;
        });
      }
    });

    _firestore.collection('patients').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalPatients = snapshot.docs.length;
        });
      }
    });

    _firestore.collection('pharmacies').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalPharmacies = snapshot.docs.length;
        });
      }
    });

    _firestore
        .collection('pharmacy_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingPharmacyRequests = snapshot.docs.length;
        });
      }
    });

    _firestore
        .collection('doctor_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingDoctorRequests = snapshot.docs.length;
        });
      }
    });
  }

  List<Widget> get _screens {
  return [
    const SuperAdminHomePage(), // Home page at index 0
    sadmin.MedicalCenterManagementScreen(),
    const DoctorManagementScreen(medicalCenterName: 'All Centers'), // Fixed: Added AdminDoctorManagementScreen
    const PatientManagementScreen(), // Fixed: Only one instance
    const AnalysisScreen(),
    const PharmacyManagementScreen(),
    const SuperAdminPharmacyApprovalScreen(),
  ];
}
  final List<String> _titles = [
    'Super Admin Dashboard',
    'Medical Center Management',
    'Doctor Management',
    'Patient Management',
    'Analysis & Reports',
    'Pharmacy Management',
    'Pharmacy Approvals',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main content
          Expanded(
            child: Column(
              children: [
                AppBar(
                  title: Text(
                    _titles[_selectedIndex],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: const Color(0xFF18A3B6),
                  elevation: 0,
                  actions: _selectedIndex == 0 ? _buildAppBarActions() : null,
                ),
                Expanded(
                  child: _screens[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF18A3B6), Color(0xFF32BACD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(icon: Icons.dashboard, label: 'Dashboard', index: 0),
          _buildDrawerItem(icon: Icons.apartment, label: 'Medical Centers', index: 1),
          _buildDoctorManagementItem(),
          _buildDrawerItem(icon: Icons.people, label: 'Patients', index: 3),
          _buildDrawerItem(icon: Icons.analytics, label: 'Analysis', index: 4),
          _buildDrawerItem(icon: Icons.medication_outlined, label: 'Pharmacy Management', index: 5),
          _buildPharmacyApprovalItem(),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const enroll.SignInPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    String greeting;
    var hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good morning, Super Admin!';
    } else if (hour < 17) {
      greeting = 'Good afternoon, Super Admin!';
    } else {
      greeting = 'Good evening, Super Admin!';
    }

    return DrawerHeader(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.shield, size: 30, color: Color(0xFF18A3B6)),
          ),
          const SizedBox(height: 10),
          Text(
            greeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('MMM dd, yyyy').format(DateTime.now()),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String label, required int index}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: _selectedIndex == index,
      selectedTileColor: Colors.white.withOpacity(0.1),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  Widget _buildDoctorManagementItem() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('doctor_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        return ListTile(
          leading: Stack(
            children: [
              const Icon(Icons.medical_services, color: Colors.white),
              if (pendingCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          title: const Text(
            'Doctors',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: pendingCount > 0 
              ? Text(
                  '$pendingCount pending',
                  style: const TextStyle(color: Colors.yellow),
                )
              : null,
          selected: _selectedIndex == 2,
          selectedTileColor: Colors.white.withOpacity(0.1),
          onTap: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
        );
      },
    );
  }

  Widget _buildPharmacyApprovalItem() {
    return ListTile(
      leading: Stack(
        children: [
          const Icon(Icons.local_pharmacy, color: Colors.white),
          if (_pendingPharmacyRequests > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  _pendingPharmacyRequests > 9 ? '9+' : '$_pendingPharmacyRequests',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: const Text(
        'Pharmacy Approvals',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: _pendingPharmacyRequests > 0 
          ? Text(
              '$_pendingPharmacyRequests pending',
              style: const TextStyle(color: Colors.yellow),
            )
          : null,
      selected: _selectedIndex == 6,
      selectedTileColor: Colors.white.withOpacity(0.1),
      onTap: () {
        setState(() {
          _selectedIndex = 6;
        });
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Row(
          children: [
            const Icon(Icons.update, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Last updated: ${DateFormat('HH:mm').format(DateTime.now())}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    ];
  }
}

// Super Admin Home Page Widget
class SuperAdminHomePage extends StatelessWidget {
  const SuperAdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            
            // Stats Grid
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildStatsGrid(context),
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    
                    // Recent Activity (Optional)
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Card(
          elevation: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF18A3B6), Color(0xFF32BACD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back, Super Admin!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening in your healthcare system today',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  DateFormat('EEEE, MMMM dd, yyyy - HH:mm').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final state = context.findAncestorStateOfType<_SuperAdminDashboardState>();
    if (state == null) return const SizedBox();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Medical Centers',
          count: state._totalMedicalCenters,
          icon: Icons.apartment,
          color: Colors.blue,
          onTap: () => _navigateToScreen(context, 1),
        ),
        _buildStatCard(
          title: 'Doctors',
          count: state._totalDoctors,
          icon: Icons.medical_services,
          color: Colors.green,
          subtitle: '${state._pendingDoctorRequests} pending',
          onTap: () => _navigateToScreen(context, 2),
        ),
        _buildStatCard(
          title: 'Patients',
          count: state._totalPatients,
          icon: Icons.people,
          color: Colors.purple,
          onTap: () => _navigateToScreen(context, 3),
        ),
        _buildStatCard(
          title: 'Pharmacies',
          count: state._totalPharmacies,
          icon: Icons.local_pharmacy,
          color: Colors.orange,
          subtitle: '${state._pendingPharmacyRequests} pending',
          onTap: () => _navigateToScreen(context, 6),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  icon: Icons.add_business,
                  label: 'Add Medical Center',
                  onTap: () => _navigateToScreen(context, 1),
                ),
                _buildActionButton(
                  icon: Icons.medical_services,
                  label: 'Manage Doctors',
                  onTap: () => _navigateToScreen(context, 2),
                ),
                _buildActionButton(
                  icon: Icons.local_pharmacy,
                  label: 'Pharmacy Approvals',
                  onTap: () => _navigateToScreen(context, 6),
                ),
                _buildActionButton(
                  icon: Icons.analytics,
                  label: 'View Reports',
                  onTap: () => _navigateToScreen(context, 4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF18A3B6), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 2,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            // You can add a ListView of recent activities here
            // For now, it's a placeholder
            Center(
              child: Text(
                'Recent system activities will appear here',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_SuperAdminDashboardState>();
    state?.setState(() {
      state._selectedIndex = index;
    });
  }
}