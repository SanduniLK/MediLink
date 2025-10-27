// screens/doctor_screens/doctor_qr_scanner_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:frontend/screens/doctor_screens/doctor_medical_history_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

// Import your patient profile screen
import 'doctor_patient_profile_screen.dart';

class DoctorQRScannerScreen extends StatefulWidget {
  const DoctorQRScannerScreen({super.key});

  @override
  State<DoctorQRScannerScreen> createState() => _DoctorQRScannerScreenState();
}

class _DoctorQRScannerScreenState extends State<DoctorQRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('This app needs camera access to scan QR codes'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Patient QR Code'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              cameraController.toggleTorch();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (isScanning) return;
                    
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      _handleScannedData(barcode.rawValue);
                    }
                  },
                ),
                // Scanner overlay
                _buildScannerOverlay(),
                
                // Scanning indicator
                if (isScanning)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Processing QR Code...',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black.withOpacity(0.8),
            child: const Column(
              children: [
                Icon(Icons.qr_code_scanner, size: 40, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'Scan patient QR code to access medical profile',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  'Position the QR code within the frame',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Corner borders
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.green, width: 4),
                    left: BorderSide(color: Colors.green, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.green, width: 4),
                    right: BorderSide(color: Colors.green, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.green, width: 4),
                    left: BorderSide(color: Colors.green, width: 4),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.green, width: 4),
                    right: BorderSide(color: Colors.green, width: 4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleScannedData(String? rawValue) async {
    if (rawValue == null) return;
    if (isScanning) return;

    setState(() => isScanning = true);

    try {
      String patientId;
      
      debugPrint('📱 Raw QR data: $rawValue');
      
      // Try to parse as JSON first (enhanced QR)
      try {
        final scannedData = jsonDecode(rawValue);
        patientId = scannedData['uid'] ?? scannedData['patientId'] ?? scannedData['id'] ?? rawValue;
        debugPrint('🔍 Parsed JSON - Patient ID: $patientId');
      } catch (e) {
        // If not JSON, use raw value as patient ID
        patientId = rawValue;
        debugPrint('🔍 Using raw value as Patient ID: $patientId');
      }

      // Clean the patient ID - remove any invalid characters
      patientId = _cleanPatientId(patientId);
      debugPrint('🧹 Cleaned Patient ID: $patientId');

      // Validate patient ID
      if (patientId.isEmpty || patientId.contains('//')) {
        throw Exception('Invalid patient ID format');
      }

      // Try multiple collection names since we don't know the exact structure
      String? patientName;
      Map<String, dynamic>? patientData;

      // Try 'users' collection first (common for Firebase Auth users)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      if (userDoc.exists) {
        patientData = userDoc.data();
        patientName = patientData?['name'] ?? patientData?['displayName'] ?? 'Patient';
        debugPrint('✅ Found patient in "users" collection: $patientName');
      } else {
        // Try 'patients' collection
        final patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .get();

        if (patientDoc.exists) {
          patientData = patientDoc.data();
          patientName = patientData?['name'] ?? patientData?['patientName'] ?? 'Patient';
          debugPrint('✅ Found patient in "patients" collection: $patientName');
        } else {
          throw Exception('Patient not found in database. ID: $patientId');
        }
      }

      // Navigate to patient profile
      _navigateToPatientProfile(patientId, patientName ?? 'Patient', patientData ?? {});
      
    } catch (e) {
      debugPrint('❌ QR Scan Error: $e');
      _showErrorDialog('Failed to process QR code: ${e.toString()}');
    } finally {
      _resumeScanning();
    }
  }

  String _cleanPatientId(String patientId) {
    // Remove any invalid characters for Firestore document IDs
    return patientId
        .replaceAll('//', '/') // Remove double slashes
        .replaceAll(RegExp(r'[/*[]{}]'), '') // Remove other invalid chars
        .trim();
  }

// In your QR scanner screen, ensure it navigates to Patient Profile
void _navigateToPatientProfile(String patientId, String patientName, Map<String, dynamic> patientData) {
  Future.delayed(Duration(milliseconds: 500), () {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorPatientProfileScreen(
            patientId: patientId,
            patientName: patientName,
            patientData: patientData,
          ),
        ),
      );
    }
  });
}
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Scan Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  void _resumeScanning() {
    if (mounted) {
      setState(() => isScanning = false);
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}