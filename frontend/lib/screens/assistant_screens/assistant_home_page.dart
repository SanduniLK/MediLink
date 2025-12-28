import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/admin_screens/admin_test_reports_screen.dart';


class AssistantHomePage extends StatefulWidget {
  const AssistantHomePage({super.key});

  @override
  State<AssistantHomePage> createState() => _AssistantHomePageState();
}

class _AssistantHomePageState extends State<AssistantHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _assistantName = '';
  String _medicalCenterId = '';
  String _medicalCenterName = '';
  bool _isLoading = true;
  int _selectedIndex = 0;
  
  // Report Summary Stats (like admin screen)
  Map<String, int> _reportStats = {
    'total': 0,
    'normal': 0,
    'abnormal': 0,
    'critical': 0,
  };
  bool _isStatsLoading = true;
  
  // Color Scheme
  final Color _primaryColor = Color(0xFF18A3B6);
  final Color _primaryLight = Color(0xFFB2DEE6);
  final Color _primaryDark = Color(0xFF12899B);
  final Color _accentColor = Color(0xFF32BACD);
  final Color _backgroundColor = Color(0xFFF8FBFD);
  final Color _cardColor = Colors.white;
  final Color _textPrimary = Color(0xFF2C3E50);
  final Color _textSecondary = Color(0xFF7F8C8D);
  final Color _successColor = Color(0xFF27AE60);
  final Color _warningColor = Color(0xFFE67E22);
  final Color _dangerColor = Color(0xFFE74C3C);
  
  @override
  void initState() {
    super.initState();
    _loadAssistantData();
  }
  
  Future<void> _loadAssistantData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      print('🟡 Loading assistant data for user: ${user.uid}');
      
      final assistantDoc = await _firestore
          .collection('assistants')
          .doc(user.uid)
          .get();
          
      if (assistantDoc.exists) {
        final data = assistantDoc.data()!;
        print('🟢 Assistant data found: $data');
        
        setState(() {
          _assistantName = data['name'] ?? 'Assistant';
          _medicalCenterId = data['medicalCenterId'] ?? '';
          _medicalCenterName = data['medicalCenterName'] ?? 'Medical Center';
        });
        
        print('🟡 Medical Center ID: $_medicalCenterId');
        print('🟡 Medical Center Name: $_medicalCenterName');
        
        // Load report summary stats
        if (_medicalCenterId.isNotEmpty) {
          await _loadReportStats();
        } else {
          print('⚠️ Medical Center ID is empty');
        }
      } else {
        print('⚠️ Assistant document does not exist');
      }
    } catch (e) {
      print('🔴 Error loading assistant data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadReportStats() async {
    try {
      setState(() {
        _isStatsLoading = true;
      });
      
      print('🟡 Loading report summary stats...');
      
      final snapshot = await _firestore
          .collection('test_reports')
          .where('medicalCenterId', isEqualTo: _medicalCenterId)
          .get();

      print('🟢 Firestore query completed, ${snapshot.docs.length} documents found');
      
      int total = snapshot.docs.length;
      int normal = snapshot.docs.where((doc) => doc['status'] == 'normal').length;
      int abnormal = snapshot.docs.where((doc) => doc['status'] == 'abnormal').length;
      int critical = snapshot.docs.where((doc) => doc['status'] == 'critical').length;
      
      print('🟢 Report stats - Total: $total, Normal: $normal, Abnormal: $abnormal, Critical: $critical');
      
      setState(() {
        _reportStats = {
          'total': total,
          'normal': normal,
          'abnormal': abnormal,
          'critical': critical,
        };
        _isStatsLoading = false;
      });
      
    } catch (e) {
      print('🔴 Error loading report stats: $e');
      setState(() {
        _isStatsLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomePage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_backgroundColor, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 48, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primaryColor, _primaryDark],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 25,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.medical_services, color: Colors.white, size: 28),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back,',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _assistantName,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.white, _primaryLight],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            child: Text(
                              _assistantName.isNotEmpty
                                  ? _assistantName.substring(0, 1).toUpperCase()
                                  : 'A',
                              style: TextStyle(
                                fontSize: 20,
                                color: _primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_hospital, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _medicalCenterName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Medical Center',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Assistant',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Main Content
            Transform.translate(
              offset: Offset(0, -20),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Reports Summary Section (like admin screen)
                    _buildReportsSummarySection(),
                    
                    SizedBox(height: 32),
                    
                    // Quick Actions Title
                    Row(
                      children: [
                        Container(
                          height: 24,
                          width: 4,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        Spacer(),
                        TextButton.icon(
                          onPressed: _refreshStats,
                          icon: Icon(Icons.refresh, size: 18, color: _primaryColor),
                          label: Text(
                            'Refresh',
                            style: TextStyle(
                              fontSize: 14,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Actions Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(
                          icon: Icons.cloud_upload,
                          title: 'Upload Reports',
                          subtitle: 'Upload test results',
                          color: Colors.green,
                          onTap: () {
                            if (_medicalCenterId.isNotEmpty) {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (context) => AdminTestReportsScreen(
                                    medicalCenterId: _medicalCenterId,
                                    medicalCenterName: _medicalCenterName,
                                  )
                                ),
                              ).then((_) {
                                // Refresh statistics when returning from upload screen
                                _refreshStats();
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Medical center information not available. Please try again.'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              _loadAssistantData();
                            }
                          },
                        ),
                        
                        _buildActionCard(
                          icon: Icons.assignment,
                          title: 'View All Reports',
                          subtitle: 'See all uploaded reports',
                          color: Colors.purple,
                          onTap: () {
                            if (_medicalCenterId.isNotEmpty) {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (context) => AdminTestReportsScreen(
                                    medicalCenterId: _medicalCenterId,
                                    medicalCenterName: _medicalCenterName,
                                  )
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Info Card
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.info_outline, color: _primaryColor, size: 24),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Real-time Statistics',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Report counts are fetched from Firestore database in real-time. '
                                  'Tap refresh to update the latest statistics.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsSummarySection() {
    if (_isStatsLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.summarize, color: _primaryColor, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reports Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.summarize, color: _primaryColor, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reports Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 12, color: _primaryColor),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 11,
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.7,
            children: [
              _buildCompactStatCard(_reportStats['total'] ?? 0, 'Total', Icons.assignment_outlined, _primaryColor),
              _buildCompactStatCard(_reportStats['normal'] ?? 0, 'Normal', Icons.check_circle_outlined, _successColor),
              _buildCompactStatCard(_reportStats['abnormal'] ?? 0, 'Abnormal', Icons.warning_amber_outlined, _warningColor),
              _buildCompactStatCard(_reportStats['critical'] ?? 0, 'Critical', Icons.error_outline, _dangerColor),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Showing all test reports for $_medicalCenterName',
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(int count, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildActionCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 140, // FIXED: Set a fixed height
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(16), // FIXED: Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              padding: EdgeInsets.all(10), // FIXED: Reduced padding
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 22), // FIXED: Reduced icon size
            ),
            SizedBox(height: 12), // FIXED: Reduced spacing
            Text(
              title,
              style: TextStyle(
                fontSize: 15, // FIXED: Reduced font size
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              maxLines: 2, // FIXED: Limit to 2 lines
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4), // FIXED: Reduced spacing
            Expanded( // FIXED: Use Expanded for subtitle
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12, // FIXED: Reduced font size
                  color: _textSecondary,
                ),
                maxLines: 2, // FIXED: Limit to 2 lines
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: EdgeInsets.all(5), // FIXED: Reduced padding
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 14, // FIXED: Reduced icon size
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Future<void> _refreshStats() async {
    setState(() {
      _isStatsLoading = true;
    });
    
    await _loadReportStats();
    
    setState(() {
      _isStatsLoading = false;
    });
    
   
  }


  Widget _buildSettingsPage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_backgroundColor, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primaryColor, _primaryDark],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.white, _primaryLight],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          _assistantName.isNotEmpty
                              ? _assistantName.substring(0, 1).toUpperCase()
                              : 'A',
                          style: TextStyle(
                            fontSize: 36,
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _assistantName,
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Medical Assistant',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _medicalCenterName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Verified Assistant',
                            style: TextStyle(
                              fontSize: 13,
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
            
            // Settings Cards
            Transform.translate(
              offset: Offset(0, -20),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Account Settings
                    _buildSettingsCard(
                      title: 'Account Settings',
                      icon: Icons.person_outline,
                      children: [
                        
                       
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // App Settings
                    _buildSettingsCard(
                      title: 'App Settings',
                      icon: Icons.settings_outlined,
                      children: [
                       
                        _buildSettingsItem(
                          icon: Icons.info_outline,
                          title: 'About',
                          subtitle: 'App version and info',
                          onTap: () {},
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Sign Out Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.logout, color: Colors.red),
                        ),
                        title: Text(
                          'Sign Out',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        subtitle: Text('Sign out from your account'),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _signOut,
                      ),
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _primaryColor, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0),
          Column(
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _textPrimary, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: Colors.red),
            ),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: Text('Are you sure you want to sign out?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _auth.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => SignInPage()),
                  (route) => false,
                );
              },
              child: Text(
                'Sign Out',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading Dashboard...',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _selectedIndex == 0
              ? _buildHomePage()
              : _buildSettingsPage(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedIndex == 0 ? _primaryColor.withOpacity(0.1) : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.home,
                    color: _selectedIndex == 0 ? _primaryColor : _textSecondary,
                  ),
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedIndex == 1 ? _primaryColor.withOpacity(0.1) : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.settings,
                    color: _selectedIndex == 1 ? _primaryColor : _textSecondary,
                  ),
                ),
                label: 'Settings',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
            selectedItemColor: _primaryColor,
            unselectedItemColor: _textSecondary,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}