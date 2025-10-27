import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:frontend/screens/phamecy_screens/prescriptionImageScreen.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';

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
  late Reference _prescriptionsRootRef;

  // Search variables
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allPrescriptions = [];
  final List<Map<String, dynamic>> _dispensedPrescriptions = [];
  bool _isSearching = false;

  static const Color _deepTeal = Color(0xFF18A3B6);
  Timer? _searchDebounceTimer;
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _prescriptionsRootRef = _storage.ref().child('prescriptions');
    _fetchPharmacyData();
    _loadAllPrescriptions();
    _debugImageLoading();
    
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllPrescriptions() async {
    try {
      List<Map<String, dynamic>> allPrescriptions = [];
      final ListResult rootResult = await _prescriptionsRootRef.listAll();

      for (var doctorFolder in rootResult.prefixes) {
        try {
          final ListResult doctorFiles = await doctorFolder.listAll();

          for (var item in doctorFiles.items) {
            try {
              if (!item.name.toLowerCase().endsWith('.png') &&
                  !item.name.toLowerCase().endsWith('.jpg') &&
                  !item.name.toLowerCase().endsWith('.jpeg')) {
                continue;
              }

              final FullMetadata metadata = await item.getMetadata();
              final customMetadata = metadata.customMetadata ?? {};

              String patientName = customMetadata['patientName'] ?? 'Unknown Patient';
              String doctorId = doctorFolder.name;
              String medicalCenter = customMetadata['medicalCenter'] ?? 'Unknown Center';

              int dateTimestamp = _parseUploadedAt(customMetadata['uploadedAt'] ?? '');

              allPrescriptions.add({
                'fileName': item.name,
                'patientName': patientName,
                'doctorName': 'Doctor $doctorId',
                'diagnosis': 'From $medicalCenter',
                'date': dateTimestamp,
                'storagePath': item.fullPath,
                'status': 'new',
                'doctorId': doctorId,
                'medicalCenter': medicalCenter,
                'storageReference': item, // Store reference for fresh URLs
              });

            } catch (e) {
              print('Error processing file ${item.name}: $e');
            }
          }
        } catch (e) {
          print('Error accessing doctor folder ${doctorFolder.name}: $e');
        }
      }

      setState(() {
        _allPrescriptions = allPrescriptions;
        _newPrescriptionsCount = allPrescriptions.length;
        _dispensedPrescriptionsCount = _dispensedPrescriptions.length;
      });
    } catch (e) {
      print('Error loading all prescriptions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    _searchDebounceTimer?.cancel();
    _currentSearchQuery = query;

    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_currentSearchQuery != query) return;
      await _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    try {
      List<Map<String, dynamic>> searchResults = [];
      final searchQuery = query.toLowerCase().trim();

      for (var prescription in _allPrescriptions) {
        String patientName = prescription['patientName']?.toString() ?? '';
        String doctorName = prescription['doctorName']?.toString() ?? '';
        String diagnosis = prescription['diagnosis']?.toString() ?? '';
        
        bool matchesPatient = patientName.toLowerCase().contains(searchQuery);
        bool matchesDoctor = doctorName.toLowerCase().contains(searchQuery);
        bool matchesDiagnosis = diagnosis.toLowerCase().contains(searchQuery);
        
        if (matchesPatient || matchesDoctor || matchesDiagnosis) {
          searchResults.add({...prescription});
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = searchResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _debugImageLoading() async {
    try {
      print('🔍 DEBUG: Starting image loading debug...');
      
      final ListResult rootResult = await _prescriptionsRootRef.listAll();
      print('📁 Found ${rootResult.prefixes.length} doctor folders');
      
      for (var doctorFolder in rootResult.prefixes) {
        final ListResult doctorFiles = await doctorFolder.listAll();
        print('👨‍⚕️ Doctor ${doctorFolder.name} has ${doctorFiles.items.length} files');
        
        for (var item in doctorFiles.items) {
          print('\n🖼️ Testing file: ${item.name}');
          print('📍 Full path: ${item.fullPath}');
          
          try {
            // Test 1: Get metadata
            print('  1. Getting metadata...');
            final metadata = await item.getMetadata();
            print('     ✅ Metadata: ${metadata.name}');
            
            // Test 2: Get download URL
            print('  2. Getting download URL...');
            final url = await item.getDownloadURL();
            print('     ✅ URL obtained: ${url.substring(0, 80)}...');
            
            // Test 3: Test HTTP access
            print('  3. Testing HTTP access...');
            final client = HttpClient();
            final request = await client.getUrl(Uri.parse(url));
            final response = await request.close();
            print('     ✅ HTTP Status: ${response.statusCode}');
            client.close();
            
            // Test 4: Check current user authentication
            print('  4. Checking authentication...');
            final currentUser = FirebaseAuth.instance.currentUser;
            print('     ✅ Current user: ${currentUser?.uid}');
            print('     ✅ Pharmacy UID: ${widget.uid}');
            
            print('🎉 ALL TESTS PASSED for ${item.name}');
            
          } catch (e) {
            print('❌ FAILED at step: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Debug failed: $e');
    }
  }

  Future<void> _markAsDispensed(String storagePath, String fileName, Map<String, dynamic> prescription) async {
    try {
      setState(() {
        prescription['status'] = 'dispensed';
        prescription['dispensedAt'] = DateTime.now().millisecondsSinceEpoch;
        prescription['dispensedBy'] = widget.uid;
        
        _dispensedPrescriptions.add(prescription);
        _allPrescriptions.removeWhere((p) => p['storagePath'] == storagePath);
        _newPrescriptionsCount = _allPrescriptions.length;
        _dispensedPrescriptionsCount = _dispensedPrescriptions.length;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription marked as dispensed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to update prescription status');
      }
    }
  }

  int _parseUploadedAt(String uploadedAt) {
    try {
      if (uploadedAt.isEmpty) return DateTime.now().millisecondsSinceEpoch;
      final dateTime = DateTime.parse(uploadedAt);
      return dateTime.millisecondsSinceEpoch;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _viewPrescriptionImage(Map<String, dynamic> prescription) async {
    try {
      final storageRef = prescription['storageReference'];
      if (storageRef == null) {
        _showError('No image available');
        return;
      }

      final imageUrl = await storageRef.getDownloadURL();
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrescriptionImageScreen(
              imageUrl: imageUrl,
              prescription: prescription,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load prescription image: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
    }
  }

  // UPDATED: IMPROVED DASHBOARD SCREEN
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Improved Header Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                            "Manage prescriptions efficiently",
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
          ),

          const SizedBox(height: 20),

          // Improved Notification Card
          if (_newPrescriptionsCount > 0)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.orange.shade500, Colors.orange.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_newPrescriptionsCount new prescription${_newPrescriptionsCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Check the prescriptions tab',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Improved Quick Overview Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Quick Overview",
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF18A3B6)
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Improved Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            padding: EdgeInsets.zero,
            children: [
              _buildStatCard(
                icon: Icons.assignment_outlined,
                title: "New",
                value: _newPrescriptionsCount.toString(),
                color: Colors.orange.shade600,
                subtitle: "Pending",
              ),
              _buildStatCard(
                icon: Icons.check_circle_outline,
                title: "Dispensed", 
                value: _dispensedPrescriptionsCount.toString(),
                color: Colors.green.shade600,
                subtitle: "Completed",
              ),
              _buildStatCard(
                icon: Icons.medical_services_outlined,
                title: "Medicines",
                value: "0",
                color: Colors.blue.shade600,
                subtitle: "In stock",
              ),
              _buildStatCard(
                icon: Icons.people_outline,
                title: "Customers",
                value: "0",
                color: Colors.purple.shade600,
                subtitle: "Today",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // UPDATED: Improved Stat Card
  Widget _buildStatCard({
    required IconData icon, 
    required String title, 
    required String value, 
    required Color color,
    String subtitle = "",
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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

  // UPDATED: IMPROVED PRESCRIPTIONS SCREEN WITH TABS
  Widget _buildPrescriptions() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          
          backgroundColor: _deepTeal,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.search, size: 20),
                text: 'Search',
              ),
              Tab(
                icon: Icon(Icons.assignment_outlined, size: 20),
                text: 'New',
              ),
              Tab(
                icon: Icon(Icons.check_circle_outline, size: 20),
                text: 'Dispensed',
              ),
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

  // UPDATED: IMPROVED SEARCH TAB
  Widget _buildSearchTab() {
    return Column(
      children: [
        // Improved Search Section
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search Prescriptions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _deepTeal,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by patient name, doctor, or diagnosis...',
                            prefixIcon: Icon(Icons.search, color: _deepTeal),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                          onChanged: _performSearch,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search across all prescriptions',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Results
        Expanded(
          child: _isSearching
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Searching...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchController.text.isEmpty
                                  ? Icons.search_outlined
                                  : Icons.assignment_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? "Enter patient name to search prescriptions"
                                  : "No prescriptions found for '${_searchController.text}'",
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            if (_searchController.text.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Try searching by patient name, doctor name, or diagnosis",
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  // UPDATED: IMPROVED NEW PRESCRIPTIONS TAB
  Widget _buildNewPrescriptionsTab() {
    final newPrescriptions = _allPrescriptions
        .where((prescription) => prescription['status'] == 'new')
        .toList();

    return newPrescriptions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  "No new prescriptions",
                  style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  "All prescriptions have been processed",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: newPrescriptions.length,
            itemBuilder: (context, index) {
              final prescription = newPrescriptions[index];
              final storagePath = prescription['storagePath'] ?? '';
              final fileName = prescription['fileName'] ?? '';
              return _buildPrescriptionCard(prescription, storagePath, fileName);
            },
          );
  }

  // UPDATED: IMPROVED DISPENSED TAB
  Widget _buildDispensedTab() {
    return _dispensedPrescriptions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  "No dispensed prescriptions",
                  style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  "Dispensed prescriptions will appear here",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _dispensedPrescriptions.length,
            itemBuilder: (context, index) {
              final prescription = _dispensedPrescriptions[index];
              final storagePath = prescription['storagePath'] ?? '';
              final fileName = prescription['fileName'] ?? '';
              return _buildDispensedPrescriptionCard(prescription, storagePath, fileName);
            },
          );
  }

  // UPDATED: IMPROVED PRESCRIPTION CARD
  Widget _buildPrescriptionCard(Map<String, dynamic> prescription, String storagePath, String fileName) {
    final patientName = prescription['patientName'] ?? 'Unknown Patient';
    final doctorName = prescription['doctorName'] ?? 'Doctor';
    final diagnosis = prescription['diagnosis'] ?? 'Medical Prescription';
    final date = _formatTimestamp(prescription['date']);
    final medicalCenter = prescription['medicalCenter'] ?? 'Unknown Center';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with patient info and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: _deepTeal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              patientName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF18A3B6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.calendar_today, 'Date: $date'),
                      _buildInfoRow(Icons.medical_services, 'Doctor: $doctorName'),
                      _buildInfoRow(Icons.business, 'Center: $medicalCenter'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Image Preview
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: () => _viewPrescriptionImage(prescription),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImageWithStorageReference(prescription),
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            // Action Buttons
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.visibility, size: 18),
                      onPressed: () => _viewPrescriptionImage(prescription),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _deepTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      label: const Text('View Prescription'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.medical_services, size: 18),
                      onPressed: () => _markAsDispensed(storagePath, fileName, prescription),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.green.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      label: Text(
                        'Dispensed',
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for info rows
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: IMPROVED DISPENSED PRESCRIPTION CARD
  Widget _buildDispensedPrescriptionCard(Map<String, dynamic> prescription, String storagePath, String fileName) {
    final patientName = prescription['patientName'] ?? 'Unknown Patient';
    final doctorName = prescription['doctorName'] ?? 'Doctor';
    final date = _formatTimestamp(prescription['date']);
    final dispensedDate = _formatTimestamp(prescription['dispensedAt']);
    final medicalCenter = prescription['medicalCenter'] ?? 'Unknown Center';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with patient info and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              patientName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.calendar_today, 'Prescribed: $date'),
                      _buildInfoRow(Icons.check_circle, 'Dispensed: $dispensedDate'),
                      _buildInfoRow(Icons.medical_services, 'Doctor: $doctorName'),
                      _buildInfoRow(Icons.business, 'Center: $medicalCenter'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'DISPENSED',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Image Preview
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: () => _viewPrescriptionImage(prescription),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImageWithStorageReference(prescription),
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            // View Button
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.visibility, size: 18),
                onPressed: () => _viewPrescriptionImage(prescription),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: const Text('View Prescription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Image loading methods remain the same
  Widget _buildImageWithStorageReference(Map<String, dynamic> prescription) {
    final storageRef = prescription['storageReference'];
    final patientName = prescription['patientName'] ?? 'Unknown Patient';

    if (storageRef == null) {
      return _buildImagePlaceholder(patientName, 'No image');
    }

    return FutureBuilder<Uint8List?>(
      future: _loadImageWithHttp(storageRef, patientName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildImageLoading();
        }
        
        if (snapshot.hasError || snapshot.data == null) {
          return _buildImagePlaceholder(patientName, 'Load failed');
        }
        
        final imageBytes = snapshot.data!;
        
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }

  Future<Uint8List?> _loadImageWithHttp(Reference storageRef, String patientName) async {
    try {
      final url = await storageRef.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Widget _buildImageLoading() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _deepTeal),
            const SizedBox(height: 8),
            const Text(
              'Loading...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(String patientName, String message) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined, color: _deepTeal, size: 36),
            const SizedBox(height: 8),
            const Text(
              'Prescription',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF18A3B6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'For: ${patientName.split(' ').first}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 10, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  // DISPENSED HISTORY SCREEN
  Widget _buildDispensedHistory() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Dispensed History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
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
          // Improved Pharmacy Info Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                      child: Icon(Icons.local_pharmacy, size: 50, color: _deepTeal),
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
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text(
                "Sign Out",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              label: 'Home',
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