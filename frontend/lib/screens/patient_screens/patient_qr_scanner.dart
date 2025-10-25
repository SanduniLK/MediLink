import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PatientQRScannerScreen extends StatefulWidget {
  const PatientQRScannerScreen({Key? key}) : super(key: key);

  @override
  State<PatientQRScannerScreen> createState() => _PatientQRScannerScreenState();
}

class _PatientQRScannerScreenState extends State<PatientQRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isLoading = false;
  String scanResult = '';
  bool isScanning = true;

  void _processQRCode(String qrCodeData) async {
    if (!isScanning) return;
    
    setState(() {
      isLoading = true;
      isScanning = false;
      scanResult = 'Processing QR code...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please log in first');
        return;
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/queue/scan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'qrCodeData': qrCodeData,
          'doctorId': 'current_doctor_id',
          'date': _getTodayDate(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showSuccess(
          'Checked in successfully!\n'
          'Patient: ${data['patientName']}\n'
          'Token: ${data['tokenNumber']}'
        );
      } else {
        final errorData = json.decode(response.body);
        _showError(errorData['error'] ?? 'Failed to check in');
      }
    } catch (e) {
      _showError('Network error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
      
      // Resume scanning after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            isScanning = true;
            scanResult = 'Ready to scan again';
          });
        }
      });
    }
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code to Check In'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                if (!isScanning) return;
                
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null && isScanning) {
                    _processQRCode(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    CircularProgressIndicator()
                  else
                    Icon(
                      isScanning ? Icons.qr_code_scanner : Icons.check_circle,
                      color: isScanning ? Colors.blue : Colors.green,
                      size: 32,
                    ),
                  SizedBox(height: 8),
                  Text(
                    scanResult.isEmpty 
                      ? 'Point camera at QR code to check in' 
                      : scanResult,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isScanning ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !isScanning
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  isScanning = true;
                  scanResult = 'Ready to scan';
                });
              },
              child: Icon(Icons.refresh),
            )
          : null,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}