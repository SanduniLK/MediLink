import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/Sadmin_screens/DoctorManagement.dart';
import 'package:frontend/screens/Sadmin_screens/SuperAdminPharmacyApprovalScreen.dart';
import 'package:frontend/screens/Sadmin_screens/patientManagement.dart';
import 'package:intl/intl.dart';


import 'package:frontend/screens/Sadmin_screens/mediclecenteManagement.dart' as sadmin;
import 'package:frontend/screens/Sadmin_screens/pharmacy_management.dart';

import 'package:frontend/screens/admin_screens/admin_patient_management.dart' hide PatientManagementScreen;
import 'package:frontend/enroll_screnns/sign_in_page.dart' as enroll;

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Dashboard stats
  int _totalMedicalCenters = 0;
  int _totalDoctors = 0;
  int _totalPatients = 0;
  int _totalPharmacies = 0;
  int _pendingPharmacyRequests = 0;
  int _pendingDoctorRequests = 0;

  // FIX: Define bottom navigation items count
  static const int _bottomNavItemsCount = 4;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
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

  // FIX: Updated screens list to match bottom navigation
  List<Widget> get _screens {
    return [
      SuperAdminHomePage(onNavigate: _navigateToScreen),
      const DoctorManagementScreenn(),
      const PatientManagementScreen(),
      const PharmacyManagementScreen(),
      // These screens are only accessible from drawer or quick actions
      sadmin.MedicalCenterManagementScreen(),
      
      const SuperAdminPharmacyApprovalScreen(),
    ];
  }

  final List<String> _titles = [
    'Dashboard',
    'Doctors',
    'Patients',
    'Pharmacies',
    'Medical Centers', // Only in drawer
    
    'Approvals', // Only in quick actions
  ];

  // FIX: Safe navigation method
  void _navigateToScreen(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      // Fallback to home if index is invalid
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  // FIX: Safe index getter for bottom navigation
  int get _safeBottomNavIndex {
    // Only allow indexes 0-3 for bottom navigation
    if (_selectedIndex < _bottomNavItemsCount) {
      return _selectedIndex;
    }
    // If current screen is not in bottom nav, return home
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        elevation: 0,
        actions: _selectedIndex == 0 ? _buildAppBarActions() : null,
        leading: _selectedIndex != 0 
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _safeBottomNavIndex, // FIX: Use safe index
      onTap: (index) {
        // FIX: Only navigate to bottom nav screens (0-3)
        if (index >= 0 && index < _bottomNavItemsCount) {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF18A3B6),
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services),
          label: 'Doctors',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Patients',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_pharmacy),
          label: 'Pharmacies',
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    String greeting;
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good morning!';
    } else if (hour < 17) {
      greeting = 'Good afternoon!';
    } else {
      greeting = 'Good evening!';
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF18A3B6), Color(0xFF32BACD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.shield, size: 25, color: Color(0xFF18A3B6)),
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
                const SizedBox(height: 4),
                const Text(
                  'Super Admin',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(icon: Icons.dashboard, label: 'Dashboard', index: 0),
          _buildDrawerItem(icon: Icons.apartment, label: 'Medical Centers', index: 4),
          _buildDrawerItem(icon: Icons.analytics, label: 'Analysis & Reports', index: 5),
          _buildDrawerItem(icon: Icons.settings, label: 'System Settings', index: 6),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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

  Widget _buildDrawerItem({required IconData icon, required String label, required int index}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF18A3B6)),
      title: Text(label),
      selected: _selectedIndex == index,
      selectedTileColor: const Color(0xFF18A3B6).withOpacity(0.1),
      onTap: () {
        _navigateToScreen(index);
        Navigator.pop(context); // Close drawer
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.white),
        onPressed: _loadDashboardStats,
        tooltip: 'Refresh',
      ),
    ];
  }
}

// HomePage remains the same as previous fix
class SuperAdminHomePage extends StatelessWidget {
  final Function(int) onNavigate;

  const SuperAdminHomePage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_SuperAdminDashboardState>();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildStatsGrid(state),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                      
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF18A3B6), Color(0xFF32BACD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Super Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('EEEE, MMM dd').format(DateTime.now()),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(DateTime.now()),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(_SuperAdminDashboardState? state) {
    if (state == null) return const SizedBox();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard(
          title: 'Medical Centers',
          count: state._totalMedicalCenters,
          icon: Icons.apartment,
          color: Colors.blue,
          onTap: () => onNavigate(4), // Medical Centers is at index 4
        ),
        _buildStatCard(
          title: 'Doctors',
          count: state._totalDoctors,
          icon: Icons.medical_services,
          color: Colors.green,
          badge: state._pendingDoctorRequests > 0 ? state._pendingDoctorRequests : null,
          onTap: () => onNavigate(1), // Doctors is at index 1
        ),
        _buildStatCard(
          title: 'Patients',
          count: state._totalPatients,
          icon: Icons.people,
          color: Colors.purple,
          onTap: () => onNavigate(2), // Patients is at index 2
        ),
        _buildStatCard(
          title: 'Pharmacies',
          count: state._totalPharmacies,
          icon: Icons.local_pharmacy,
          color: Colors.orange,
          badge: state._pendingPharmacyRequests > 0 ? state._pendingPharmacyRequests : null,
          onTap: () => onNavigate(6), // Pharmacy Approvals is at index 6
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    int? badge,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badge != null && badge > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3,
              children: [
                _buildActionChip(
                  icon: Icons.add_business,
                  label: 'Add Center',
                  onTap: () => onNavigate(4),
                ),
                _buildActionChip(
                  icon: Icons.medical_services,
                  label: 'Manage Doctors',
                  onTap: () => onNavigate(1),
                ),
                _buildActionChip(
                  icon: Icons.local_pharmacy,
                  label: 'Pharmacy Approvals',
                  onTap: () => onNavigate(5),
                ),
               
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF18A3B6)),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: onTap,
      backgroundColor: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  
}