import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/phamecy_screens/unified_patient_search_screen.dart';
import 'package:intl/intl.dart';
import 'patient_search_screen.dart';
import 'pharmacy_settings_screen.dart';

class PharmacyHomeScreen extends StatefulWidget {
  final String uid;
  const PharmacyHomeScreen({super.key, required this.uid});

  @override
  State<PharmacyHomeScreen> createState() => _PharmacyHomeScreenState();
}

class _PharmacyHomeScreenState extends State<PharmacyHomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _pharmacyData;
  bool _isLoading = true;
  
  // Dashboard statistics
  int _todayIssuances = 0;
  int _pendingPrescriptions = 0;
  int _activePatients = 0;
  int _totalMonthlyIssuances = 0;
  
  List<Map<String, dynamic>> _recentIssuances = [];
  
  static const Color _deepTeal = Color(0xFF18A3B6);

  @override
  void initState() {
    super.initState();
    _fetchPharmacyData();
    _loadDashboardData();
  }

  Future<void> _fetchPharmacyData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pharmacies')
          .doc(widget.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _pharmacyData = doc.data()!;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pharmacy data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      // Get today's issuances
      final todayIssuances = await FirebaseFirestore.instance
          .collection('issuanceRecords')
          .where('pharmacyId', isEqualTo: widget.uid)
          .where('issuanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      // Get monthly issuances
      final monthlyIssuances = await FirebaseFirestore.instance
          .collection('issuanceRecords')
          .where('pharmacyId', isEqualTo: widget.uid)
          .where('issuanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();

      // Get active prescriptions count (you might need to adjust this query)
      final activePrescriptions = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('status', isEqualTo: 'active')
          .limit(100)
          .get();

      // Get unique patients from issuances
      final patientSnapshot = await FirebaseFirestore.instance
          .collection('issuanceRecords')
          .where('pharmacyId', isEqualTo: widget.uid)
          .where('issuanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      final uniquePatients = patientSnapshot.docs.map((doc) => doc['patientId']).toSet();

      // Get recent issuances for activity feed
      final recentIssuancesQuery = await FirebaseFirestore.instance
          .collection('issuanceRecords')
          .where('pharmacyId', isEqualTo: widget.uid)
          .orderBy('issuanceDate', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> recentIssuances = [];
      for (var doc in recentIssuancesQuery.docs) {
        recentIssuances.add(doc.data());
      }

      setState(() {
        _todayIssuances = todayIssuances.docs.length;
        _totalMonthlyIssuances = monthlyIssuances.docs.length;
        _pendingPrescriptions = activePrescriptions.docs.length;
        _activePatients = uniquePatients.length;
        _recentIssuances = recentIssuances;
      });

    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  // UPDATED: IMPROVED DASHBOARD SCREEN
  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading Pharmacy Dashboard...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final pharmacyName = _pharmacyData?['name'] ?? 'Pharmacy';
    final String greeting = _getGreeting();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Card
            _buildWelcomeCard(pharmacyName, greeting),

            const SizedBox(height: 20),

            // Quick Actions Grid
            _buildQuickActionsGrid(pharmacyName),

            const SizedBox(height: 24),

            // Statistics Overview
            _buildStatisticsSection(),

            const SizedBox(height: 24),

            // Recent Activity
            _buildRecentActivitySection(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildWelcomeCard(String pharmacyName, String greeting) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_deepTeal, const Color(0xFF32BACD)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.9),
                child: Icon(Icons.local_pharmacy, size: 30, color: _deepTeal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pharmacyName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Track multi-month prescriptions efficiently",
                      style: TextStyle(
                        fontSize: 13, 
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(String pharmacyName) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18A3B6),
          ),
        ),
      ),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
        children: [
          _buildActionCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan QR Code',
            subtitle: 'Quick patient access',
            color: Colors.blue.shade600,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UnifiedPatientSearchScreen(
                    pharmacyId: widget.uid,
                    pharmacyName: pharmacyName,
                    initialTab: 0, // Start with QR Scanner tab
                  ),
                ),
              );
            },
          ),
          _buildActionCard(
            icon: Icons.phone,
            title: 'Phone Search',
            subtitle: 'By mobile number',
            color: Colors.green.shade600,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UnifiedPatientSearchScreen(
                    pharmacyId: widget.uid,
                    pharmacyName: pharmacyName,
                    initialTab: 1, // Start with Phone tab
                  ),
                ),
              );
            },
          ),
          _buildActionCard(
            icon: Icons.assignment,
            title: 'View Prescriptions',
            subtitle: 'All active prescriptions',
            color: Colors.orange.shade600,
            onTap: () {
              setState(() => _selectedIndex = 1);
            },
          ),
          _buildActionCard(
            icon: Icons.history,
            title: 'Issuance History',
            subtitle: 'Track all dispensations',
            color: Colors.purple.shade600,
            onTap: () {
              setState(() => _selectedIndex = 2);
            },
          ),
        ],
      ),
    ],
  );
}

  Widget _buildActionCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12), // Reduced padding
        constraints: const BoxConstraints(
          minHeight: 80, // Set minimum height
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6), // Reduced padding
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color), // Smaller icon
            ),
            const SizedBox(height: 6), // Reduced spacing
            Text(
              title,
              style: TextStyle(
                fontSize: 12, // Smaller font
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10, // Smaller font
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            "Today's Overview",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF18A3B6),
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard(
              icon: Icons.medical_services,
              title: "Today's Issuances",
              value: _todayIssuances.toString(),
              color: Colors.blue.shade600,
              subtitle: "Medications dispensed",
            ),
            _buildStatCard(
              icon: Icons.assignment,
              title: "Active Prescriptions", 
              value: _pendingPrescriptions.toString(),
              color: Colors.orange.shade600,
              subtitle: "Requiring attention",
            ),
            _buildStatCard(
              icon: Icons.people,
              title: "Patients Served",
              value: _activePatients.toString(),
              color: Colors.green.shade600,
              subtitle: "Today",
            ),
            _buildStatCard(
              icon: Icons.trending_up,
              title: "Monthly Total",
              value: _totalMonthlyIssuances.toString(),
              color: Colors.purple.shade600,
              subtitle: "This month",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String subtitle = "",
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            "Recent Activity",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF18A3B6),
            ),
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _recentIssuances.isEmpty
              ? _buildEmptyActivity()
              : _buildActivityList(),
        ),
      ],
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "No recent activity",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Issuances will appear here",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _recentIssuances.map((issuance) => _buildActivityItem(issuance)).toList(),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> issuance) {
    final patientName = issuance['patientName'] ?? 'Unknown Patient';
    final monthIssued = issuance['monthIssued'] ?? 1;
    final issuanceDate = issuance['issuanceDate'] is Timestamp 
        ? (issuance['issuanceDate'] as Timestamp).toDate()
        : DateTime.now();
    final timeAgo = _getTimeAgo(issuanceDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _deepTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.medical_services, size: 16, color: _deepTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Month $monthIssued issued • $timeAgo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _deepTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'M$monthIssued',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _deepTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM dd').format(date);
  }

  // Keep your existing methods for other tabs
  Widget _buildPrescriptions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Prescriptions Management",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "This feature is under development",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDispensedHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Issuance History",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "Track all medication issuances here",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PharmacySettingsScreen(uid: widget.uid),
                ),
              );
            },
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_deepTeal, const Color(0xFF32BACD)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        child: Text(
                          _getPharmacyFirstLetter,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _deepTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _pharmacyData?['name'] ?? 'Pharmacy Name',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _pharmacyData?['licenseNumber'] ?? 'License not available',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _getPharmacyFirstLetter {
    final pharmacyName = _pharmacyData?['name'] ?? 'P';
    if (pharmacyName.isEmpty) return 'P';
    return pharmacyName[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'Dashboard' : 
          _selectedIndex == 1 ? 'Prescriptions' :
          _selectedIndex == 2 ? 'History' : 'Settings',
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _deepTeal,
        elevation: 2,
        automaticallyImplyLeading: false,
      ),
      body: _selectedIndex == 0 ? _buildDashboard() :
             _selectedIndex == 1 ? _buildPrescriptions() :
             _selectedIndex == 2 ? _buildDispensedHistory() :
             _buildSettings(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: _deepTeal,
          unselectedItemColor: Colors.grey.shade600,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Prescriptions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}