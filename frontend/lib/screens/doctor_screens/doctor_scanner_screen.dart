import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/screens/doctor_screens/doctor_patient_profile_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorUnifiedSearchScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorUnifiedSearchScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorUnifiedSearchScreen> createState() => _DoctorUnifiedSearchScreenState();
}

class _DoctorUnifiedSearchScreenState extends State<DoctorUnifiedSearchScreen> {
  // Control which view is shown
  bool _showQRScanner = true;
  
  bool _isSearching = false;

  // Mobile scanner controller
  MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false;

  // Text controller for manual search
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        await Permission.camera.request();
      }
    } catch (e) {
      debugPrint('Camera permission error: $e');
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (barcodes.barcodes.isNotEmpty && !_isSearching && !_hasScanned) {
      final String? qrData = barcodes.barcodes.first.rawValue;
      if (qrData != null && qrData.isNotEmpty) {
        setState(() {
          _hasScanned = true;
        });
        _searchPatient(qrData);
      }
    }
  }

Future<void> _searchPatient(String identifier) async {
  setState(() => _isSearching = true);
  
  try {
    String? patientId;
    Map<String, dynamic>? patientData;
    
    print('🔍 Searching for patient with identifier: $identifier');

    // First, try to find in patients collection by ID (most likely from QR)
    var patientDoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(identifier)
        .get();

    if (patientDoc.exists) {
      print('✅ Found as patient ID in patients collection');
      patientId = patientDoc.id;
      patientData = patientDoc.data();
    } 
    // If not found, try users collection by ID
    else {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(identifier)
          .get();

      if (userDoc.exists) {
        print('✅ Found as user ID in users collection');
        patientId = userDoc.id;
        
        // Now try to get patient data from patients collection using the same ID
        patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(identifier)
            .get();
        
        if (patientDoc.exists) {
          patientData = patientDoc.data();
        } else {
          // If no patient doc exists, use user data
          patientData = userDoc.data();
        }
      } 
      // Try phone number search
      else {
        // Try patients collection by phone
        final patientQuery = await FirebaseFirestore.instance
            .collection('patients')
            .where('phone', isEqualTo: identifier)
            .limit(1)
            .get();

        if (patientQuery.docs.isNotEmpty) {
          print('✅ Found as phone number in patients collection');
          patientId = patientQuery.docs.first.id;
          patientData = patientQuery.docs.first.data();
        } else {
          // Try users collection by phone
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: identifier)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            print('✅ Found as phone number in users collection');
            patientId = userQuery.docs.first.id;
            patientData = userQuery.docs.first.data();
          }
        }
      }
    }

    if (patientId != null && patientData != null) {
      print('🎯 Patient found: $patientId');
      print('📋 Patient data keys: ${patientData.keys}');
      _navigateToPatientProfile(patientId, patientData);
    } else {
      print('❌ Patient not found with identifier: $identifier');
      _showError('Patient not found. Please check the phone number or ID.');
    }
  } catch (e) {
    print('💥 Search error: $e');
    _showError('Search error: ${e.toString()}');
  } finally {
    setState(() => _isSearching = false);
  }
}

  void _navigateToPatientProfile(String patientId, Map<String, dynamic> patientData) {
    // Navigate to your existing DoctorPatientProfileScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorPatientProfileScreen(
          patientId: patientId,
          patientName: patientData['name'] ?? patientData['fullName'] ?? 'Patient',
          patientData: patientData,
          accessType: 'search',
          // You can pass doctorId if needed
        ),
      ),
    ).then((_) {
      // Reset state when returning from profile
      _resetSearch();
    });
  }

  void _handleManualSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showError('Please enter phone number or ID');
      return;
    }
    _searchPatient(query);
  }

  void _resetSearch() {
    setState(() {
      _hasScanned = false;
      _searchController.clear();
    });
    // Restart camera
    cameraController.start();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    _resetSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Patient'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          // Toggle between QR and manual search
          IconButton(
            icon: Icon(_showQRScanner ? Icons.phone : Icons.qr_code_scanner),
            onPressed: () {
              setState(() {
                _showQRScanner = !_showQRScanner;
                _resetSearch();
              });
            },
            tooltip: _showQRScanner ? 'Switch to Phone Search' : 'Switch to QR Scan',
          ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _showQRScanner
              ? _buildQRScannerView()
              : _buildManualSearchView(),
    );
  }

  Widget _buildQRScannerView() {
    return Column(
      children: [
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scan patient QR code or patient ID card',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        
        // Scanner view
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: cameraController,
                onDetect: _handleBarcode,
                fit: BoxFit.cover,
              ),
              
              // Overlay
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              // Instructions overlay
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.black54,
                  child: const Column(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Position QR code within frame',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualSearchView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Search Patient',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter patient phone number or ID',
            style: TextStyle(color: Colors.grey[600]),
          ),
          
          const SizedBox(height: 32),
          
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Phone Number or Patient ID',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: TextInputType.phone,
            onSubmitted: (_) => _handleManualSearch(),
          ),
          
          const SizedBox(height: 20),
          
          // Search button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handleManualSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'SEARCH PATIENT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Help text
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Tips:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildHelpItem('• Use patient registered phone number'),
                  _buildHelpItem('• Or scan patient QR code'),
                  _buildHelpItem('• Patient must be registered in system'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}