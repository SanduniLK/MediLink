// screens/doctor_screens/doctor_qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class DoctorQRScannerScreen extends StatefulWidget {
  const DoctorQRScannerScreen({super.key});

  @override
  State<DoctorQRScannerScreen> createState() => _DoctorQRScannerScreenState();
}

class _DoctorQRScannerScreenState extends State<DoctorQRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Patient QR Code'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
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
                  'Scan patient QR code for check-in/check-out',
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

    setState(() => isScanning = true);

    try {
      final scannedData = jsonDecode(rawValue);
      final appointmentId = scannedData['appointmentId'];
      final patientId = scannedData['patientId'];
      final tokenNumber = scannedData['tokenNumber'];
      final scanType = scannedData['type']; // 'checkin' or 'checkout'

      // Update appointment status
      await _updateAppointmentStatus(appointmentId, scanType);
      
      // Show success message
      _showSuccessDialog(tokenNumber, scanType);
      
    } catch (e) {
      _showErrorDialog('Invalid QR code: $e');
    } finally {
      setState(() => isScanning = false);
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String scanType) async {
    final appointmentRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId);

    final now = FieldValue.serverTimestamp();

    if (scanType == 'checkin') {
      await appointmentRef.update({
        'checkedIn': true,
        'checkInTime': now,
        'queueStatus': 'waiting',
      });
      
      // Update patient position in queue
      await _updatePatientPosition(appointmentId);
      
    } else if (scanType == 'checkout') {
      await appointmentRef.update({
        'consultationEndTime': now,
        'queueStatus': 'completed',
      });
    }
  }

  Future<void> _updatePatientPosition(String appointmentId) async {
    final appointment = await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get();

    if (appointment.exists) {
      final data = appointment.data()!;
      final doctorId = data['doctorId'];
      final date = data['date'];

      // Get all waiting patients for this doctor today
      final waitingPatients = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('queueStatus', isEqualTo: 'waiting')
          .where('checkedIn', isEqualTo: true)
          .orderBy('tokenNumber')
          .get();

      // Update positions
      int position = 1;
      for (var doc in waitingPatients.docs) {
        await doc.reference.update({
          'currentPosition': position,
        });
        position++;
      }
    }
  }

  void _showSuccessDialog(int tokenNumber, String scanType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: Text(
          'Token #$tokenNumber ${scanType == 'checkin' ? 'checked in' : 'checked out'} successfully!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Resume scanning after a delay
              Future.delayed(const Duration(seconds: 2), () {
                setState(() => isScanning = false);
              });
            },
            child: const Text('CONTINUE SCANNING'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.error, color: Colors.red, size: 50),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => isScanning = false);
            },
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}