import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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
  int _newPrescriptionsCount = 0;
  int _dispensedPrescriptionsCount = 0;

  // Firebase Storage
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late Reference _prescriptionsRef;

  // Search variables
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  static const Color _deepTeal = Color(0xFF18A3B6);

  @override
  void initState() {
    super.initState();
    // Initialize storage reference to your specific path
    _prescriptionsRef = _storage.ref().child('prescriptions').child(widget.uid);
    _fetchPharmacyData();
    _loadPrescriptionsCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching pharmacy data: $e');
      setState(() => _isLoading = false);
    }
  }

  // FETCH PRESCRIPTIONS FROM FIREBASE STORAGE
  Future<List<Map<String, dynamic>>> _fetchPrescriptionsFromStorage({String? status}) async {
    try {
      List<Map<String, dynamic>> allPrescriptions = [];

      // List all files in the prescriptions folder
      final listResult = await _prescriptionsRef.listAll();
      
      for (var item in listResult.items) {
        try {
          final prescriptionData = await _downloadAndParsePrescription(item);
          if (prescriptionData != null) {
            allPrescriptions.add(prescriptionData);
          }
        } catch (e) {
          print('Error parsing prescription ${item.name}: $e');
        }
      }

      // Filter by status if provided
      if (status != null) {
        allPrescriptions = allPrescriptions.where((p) => p['status'] == status).toList();
      }

      // Sort by date (newest first)
      allPrescriptions.sort((a, b) {
        final dateA = a['date'] ?? 0;
        final dateB = b['date'] ?? 0;
        return dateB.compareTo(dateA);
      });

      return allPrescriptions;
    } catch (e) {
      print('Error fetching prescriptions from storage: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _downloadAndParsePrescription(Reference ref) async {
    try {
      // Download the file as string
      final String downloadedData = await ref.getData() as String;
      
      // Parse JSON data
      final Map<String, dynamic> prescriptionData = json.decode(downloadedData);
      
      // Add storage metadata
      prescriptionData['storagePath'] = ref.fullPath;
      prescriptionData['fileName'] = ref.name;
      prescriptionData['id'] = ref.name; // Use filename as ID
      
      return prescriptionData;
    } catch (e) {
      print('Error downloading prescription ${ref.fullPath}: $e');
      return null;
    }
  }

  Future<void> _loadPrescriptionsCounts() async {
    try {
      final allPrescriptions = await _fetchPrescriptionsFromStorage();
      
      final newPrescriptions = allPrescriptions.where((p) => p['status'] == 'shared').length;
      final dispensedPrescriptions = allPrescriptions.where((p) => p['status'] == 'dispensed').length;

      setState(() {
        _newPrescriptionsCount = newPrescriptions;
        _dispensedPrescriptionsCount = dispensedPrescriptions;
      });
    } catch (e) {
      print('Error loading prescriptions counts: $e');
    }
  }

  // SEARCH FUNCTION
  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final allPrescriptions = await _fetchPrescriptionsFromStorage();
      
      // Filter locally
      final filteredResults = allPrescriptions.where((prescription) {
        final patientName = prescription['patientName']?.toString().toLowerCase() ?? '';
        final doctorName = prescription['doctorName']?.toString().toLowerCase() ?? '';
        final diagnosis = prescription['diagnosis']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        
        return patientName.contains(searchQuery) || 
               doctorName.contains(searchQuery) ||
               diagnosis.contains(searchQuery);
      }).toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching prescriptions: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // MARK AS DISPENSED
  Future<void> _markAsDispensed(String storagePath, String fileName, Map<String, dynamic> prescription) async {
    try {
      // Update prescription data
      prescription['status'] = 'dispensed';
      prescription['dispensedAt'] = DateTime.now().millisecondsSinceEpoch;
      prescription['dispensedBy'] = widget.uid;
      
      // Convert to JSON
      final String updatedData = json.encode(prescription);
      
      // Upload back to storage
      final ref = _storage.ref().child(storagePath);
      await ref.putString(updatedData);

      // Reload counts
      _loadPrescriptionsCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription marked as dispensed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error marking as dispensed: $e');
      if (mounted) {
        _showError('Failed to update prescription status');
      }
    }
  }

  // DASHBOARD SCREEN (Keep your existing UI)
  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pharmacyName = _pharmacyData?['name'] ?? 'Pharmacy';
    
    String greeting;
    var hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_deepTeal, Color(0xFF32BACD)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.local_pharmacy, size: 30, color: _deepTeal),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting,',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pharmacyName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Manage patient prescriptions efficiently",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Notifications Section
          if (_newPrescriptionsCount > 0) ...[
            Card(
              elevation: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.orange, Colors.orange[700]!],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_newPrescriptionsCount new prescription${_newPrescriptionsCount > 1 ? 's' : ''} available',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Search by patient name to access',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Quick Stats
          const Text(
            "Quick Overview",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
          ),
          const SizedBox(height: 15),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            children: [
              _buildStatCard(
                icon: Icons.assignment,
                title: "New Prescriptions",
                value: _newPrescriptionsCount.toString(),
                color: Colors.orange,
              ),
              _buildStatCard(
                icon: Icons.check_circle,
                title: "Dispensed",
                value: _dispensedPrescriptionsCount.toString(),
                color: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.medical_services,
                title: "Total Medicines",
                value: "0",
                color: Colors.blue,
              ),
              _buildStatCard(
                icon: Icons.people,
                title: "Customers Today",
                value: "0",
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String title, required String value, required Color color}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PRESCRIPTIONS SCREEN WITH TABS
  Widget _buildPrescriptions() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFDDF0F5),
        appBar: AppBar(
          title: const Text('Prescriptions'),
          backgroundColor: _deepTeal,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.search), text: 'Search'),
              Tab(icon: Icon(Icons.assignment), text: 'New'),
              Tab(icon: Icon(Icons.history), text: 'Dispensed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSearchTab(),
            _buildNewPrescriptionsTab(),
            _buildDispensedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search Box
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter patient name, doctor, or diagnosis...',
                      prefixIcon: Icon(Icons.search, color: _deepTeal),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      _performSearch(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Search across all prescriptions',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Search Results
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator(color: _deepTeal))
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchController.text.isEmpty 
                                  ? Icons.search 
                                  : Icons.assignment_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _searchController.text.isEmpty
                                  ? "Enter patient name to search prescriptions"
                                  : "No prescriptions found for '${_searchController.text}'",
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final prescription = _searchResults[index];
                          final storagePath = prescription['storagePath'] ?? '';
                          final fileName = prescription['fileName'] ?? '';
                          return _buildPrescriptionCard(prescription, storagePath, fileName);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPrescriptionsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPrescriptionsFromStorage(status: 'shared'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _deepTeal));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  "No new prescriptions available",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final prescriptions = snapshot.data!;

        return RefreshIndicator(
          onRefresh: _loadPrescriptionsCounts,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prescriptions.length,
            itemBuilder: (context, index) {
              final prescription = prescriptions[index];
              final storagePath = prescription['storagePath'] ?? '';
              final fileName = prescription['fileName'] ?? '';
              return _buildPrescriptionCard(prescription, storagePath, fileName);
            },
          ),
        );
      },
    );
  }

  Widget _buildDispensedTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPrescriptionsFromStorage(status: 'dispensed'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _deepTeal));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  "No dispensed prescriptions yet",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final prescriptions = snapshot.data!;

        return RefreshIndicator(
          onRefresh: _loadPrescriptionsCounts,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prescriptions.length,
            itemBuilder: (context, index) {
              final prescription = prescriptions[index];
              final storagePath = prescription['storagePath'] ?? '';
              final fileName = prescription['fileName'] ?? '';
              return _buildDispensedPrescriptionCard(prescription, storagePath, fileName);
            },
          ),
        );
      },
    );
  }

  // PRESCRIPTION CARD WIDGETS
  Widget _buildPrescriptionCard(Map<String, dynamic> prescription, String storagePath, String fileName) {
    final medicines = List<Map<String, dynamic>>.from(prescription['medicines'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    prescription['patientName'] ?? 'Unknown Patient',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(prescription['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (prescription['status'] ?? 'shared').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatTimestamp(prescription['date'])}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Doctor: ${prescription['doctorName'] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Medicines: ${medicines.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (prescription['diagnosis'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Diagnosis: ${prescription['diagnosis']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.visibility, color: _deepTeal),
                    onPressed: () => _viewPrescriptionDetails(prescription),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _deepTeal),
                    ),
                    label: Text(
                      'View Prescription',
                      style: TextStyle(color: _deepTeal),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (prescription['status'] == 'shared')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      onPressed: () => _markAsDispensed(storagePath, fileName, prescription),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      label: const Text(
                        'Mark Dispensed',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDispensedPrescriptionCard(Map<String, dynamic> prescription, String storagePath, String fileName) {
    final medicines = List<Map<String, dynamic>>.from(prescription['medicines'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      prescription['patientName'] ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DISPENSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${_formatTimestamp(prescription['date'])}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Doctor: ${prescription['doctorName'] ?? 'Unknown'}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Medicines: ${medicines.length}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (prescription['diagnosis'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Diagnosis: ${prescription['diagnosis']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              if (prescription['dispensedAt'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Dispensed: ${_formatTimestamp(prescription['dispensedAt'])}',
                  style: TextStyle(color: Colors.green[600]),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.visibility, color: _deepTeal),
                  onPressed: () => _viewPrescriptionDetails(prescription),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _deepTeal),
                  ),
                  label: Text(
                    'View Prescription Details',
                    style: TextStyle(color: _deepTeal),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // DISPENSED HISTORY SCREEN
  Widget _buildDispensedHistory() {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('Dispensed History'),
        backgroundColor: _deepTeal,
      ),
      body: _buildDispensedTab(),
    );
  }

  // SETTINGS SCREEN
  Widget _buildSettings() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _deepTeal));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_deepTeal, Color(0xFF32BACD)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.local_pharmacy, size: 40, color: _deepTeal),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _pharmacyData?['name'] ?? 'Pharmacy Name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _pharmacyData?['licenseNumber'] ?? 'License not available',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text("Sign Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UTILITY METHODS
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'shared':
        return Colors.orange;
      case 'dispensed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _viewPrescriptionDetails(Map<String, dynamic> prescription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionDetailScreen(prescription: prescription),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SignInPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> screens = [
      _buildDashboard(),
      _buildPrescriptions(),
      _buildDispensedHistory(),
      _buildSettings(),
    ];

    List<String> titles = [
      'Dashboard',
      'Prescriptions', 
      'History',
      'Settings',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _deepTeal,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: _deepTeal,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Prescriptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
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



class PrescriptionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> prescription;
  
   static const Color prescriptionBlue = Color(0xFFB2DEE6);
  static const Color prescriptionLightBlue = Color(0xFFE3F2FD);
  
  const PrescriptionDetailScreen({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) {
    final medicines = List<Map<String, dynamic>>.from(prescription['medicines'] ?? []);
    final date = DateTime.fromMillisecondsSinceEpoch(prescription['date'] as int);
    final formattedDate = DateFormat('MMMM dd, yyyy').format(date);
    final formattedTime = DateFormat('hh:mm a').format(date);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 79, 173, 240),
      appBar: AppBar(
        title: const Text('Medical Prescription'),
        backgroundColor: prescriptionBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Print feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Prescription Header
            _buildPrescriptionHeader(formattedDate, formattedTime),
            
            const SizedBox(height: 24),
            
            // Patient Information
            _buildPatientInfoSection(),
            
            const SizedBox(height: 24),
            
            // Diagnosis Section
            if (prescription['diagnosis'] != null) ...[
              _buildDiagnosisSection(),
              const SizedBox(height: 24),
            ],
            
            // Medicines Section
            _buildMedicinesSection(medicines),
            
            const SizedBox(height: 24),
            
            // Additional Notes
            if (prescription['notes'] != null) ...[
              _buildNotesSection(),
              const SizedBox(height: 24),
            ],
            
            // Doctor's Signature Area
            _buildSignatureSection(),
            
            const SizedBox(height: 32),
            
            // Footer
            _buildPrescriptionFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionHeader(String formattedDate, String formattedTime) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRESCRIPTION',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: prescriptionBlue,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Medical Document',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: prescriptionLightBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.medical_services,
                  size: 32,
                  color: const Color.fromARGB(255, 186, 245, 255),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: $formattedDate',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Time: $formattedTime',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PATIENT INFORMATION',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 92, 195, 213),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoItem('Full Name', prescription['patientName'] ?? 'Not specified'),
              const SizedBox(width: 40),
              if (prescription['patientId'] != null)
                _buildInfoItem('Patient ID', prescription['patientId']!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIAGNOSIS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: prescriptionBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            prescription['diagnosis']!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicinesSection(List<Map<String, dynamic>> medicines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRESCRIBED MEDICATIONS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: prescriptionBlue,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: medicines.asMap().entries.map((entry) {
              final index = entry.key;
              final medicine = entry.value;
              return _buildMedicineItem(index + 1, medicine);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineItem(int number, Map<String, dynamic> medicine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: prescriptionLightBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: prescriptionLightBlue,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: prescriptionBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  medicine['name'] ?? 'Unknown Medicine',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _buildMedicineDetail('Dosage', medicine['dosage'] ?? 'Not specified'),
              _buildMedicineDetail('Duration', medicine['duration'] ?? 'Not specified'),
              if (medicine['frequency'] != null)
                _buildMedicineDetail('Frequency', medicine['frequency']!),
            ],
          ),
          if (medicine['instructions'] != null) ...[
            const SizedBox(height: 8),
            _buildMedicineDetail('Instructions', medicine['instructions']!),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicineDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADDITIONAL NOTES',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: prescriptionBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            prescription['notes']!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOCTOR\'S AUTHORIZATION',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: prescriptionBlue,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 200,
                    height: 2,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Authorized Medical Practitioner',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'This is a computer-generated prescription',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Valid for dispensing until ${DateFormat('MMMM dd, yyyy').format(DateTime.now().add(const Duration(days: 30)))}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
