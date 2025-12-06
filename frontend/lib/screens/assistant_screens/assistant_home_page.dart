import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/admin_screens/admin_test_reports_screen.dart';
import 'package:frontend/screens/assistant_screens/Assistance_queue_screen.dart';

class AssistantHomePage extends StatefulWidget {
  const AssistantHomePage({super.key});

  @override
  State<AssistantHomePage> createState() => _AssistantHomePageState();
}

class _AssistantHomePageState extends State<AssistantHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _assistantName = '';
  String _medicalCenterId = ''; // ADD THIS
  String _medicalCenterName = '';
  bool _isLoading = true;
  int _selectedIndex = 0; // For bottom navigation
  String? scheduleId = '';
  
  @override
  void initState() {
    super.initState();
    _loadAssistantData();
  }
  
  Future<void> _loadAssistantData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final assistantDoc = await _firestore
          .collection('assistants')
          .doc(user.uid)
          .get();
          
      if (assistantDoc.exists) {
        final data = assistantDoc.data()!;
        setState(() {
          _assistantName = data['name'] ?? 'Assistant';
          _medicalCenterId = data['medicalCenterId'] ?? ''; // ADD THIS
          _medicalCenterName = data['medicalCenterName'] ?? 'Medical Center';
        });
      }
    } catch (e) {
      print('Error loading assistant data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $_assistantName',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Medical Center: $_medicalCenterName',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 16),
                  Chip(
                    label: Text('Assistant Role'),
                    backgroundColor: Color(0xFF18A3B6).withOpacity(0.1),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionCard(
                icon: Icons.calendar_today,
                label: 'Access patients',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => AssistantViewOnlyQueueScreen(scheduleId: scheduleId!)
                      ),
                    );
                },
              ),
              _buildActionCard(
                icon: Icons.people,
                label: 'Upload test reports',
                color: Colors.green,
                onTap: () {
                  // Check if medicalCenterId is available
                  if (_medicalCenterId.isNotEmpty) {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => AdminTestReportsScreen(
                          medicalCenterId: _medicalCenterId, // Use state variable
                          medicalCenterName: _medicalCenterName, // Use state variable
                        )
                      ),
                    );
                  } else {
                    // Show error or reload data
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Medical center information not available. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _loadAssistantData(); // Reload data
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF18A3B6),
                    child: Text(
                      _assistantName.isNotEmpty
                          ? _assistantName.substring(0, 1).toUpperCase()
                          : 'A',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _assistantName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _assistantName.isNotEmpty ? 'Assistant' : '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _medicalCenterName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ID: ${_medicalCenterId.isNotEmpty ? _medicalCenterId.substring(0, 8) + '...' : 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: Colors.grey),
                  title: Text(
                    'Profile Settings',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('Update your personal information'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {},
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.security, color: Colors.grey),
                  title: Text(
                    'Security',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('Change password and security settings'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {},
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.help, color: Colors.grey),
                  title: Text(
                    'Help & Support',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('Get help and contact support'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {},
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: Text('Sign out from your account'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _auth.signOut();
            // Navigate directly to SignInScreen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => SignInPage()),
              (route) => false,
            );
          },
          child: const Text(
            'Sign Out',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}
  
  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Assistant Dashboard' : 'Settings'),
        backgroundColor: Color(0xFF18A3B6),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _selectedIndex == 0
              ? _buildHomePage()
              : _buildSettingsPage(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF18A3B6),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}