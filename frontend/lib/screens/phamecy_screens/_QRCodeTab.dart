import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_profile_screen.dart';

// Add this helper widget
class _HelpText extends StatelessWidget {
  final String text;
  const _HelpText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 11)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _QRCodeTab extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;
  
  const _QRCodeTab({
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<_QRCodeTab> createState() => __QRCodeTabState();
}

class __QRCodeTabState extends State<_QRCodeTab> {
  final TextEditingController _qrController = TextEditingController();
  bool _isSearching = false;
  bool _hasCameraPermission = false;
  bool _isCameraActive = true;
  MobileScannerController cameraController = MobileScannerController();
    bool _hasScanned = false; 
  String? _lastScannedData;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.status;
      setState(() {
        _hasCameraPermission = status.isGranted;
      });
      
      if (!_hasCameraPermission) {
        await _requestCameraPermission();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }
 void _searchByQRManual() { 
    final qrData = _qrController.text.trim();
    if (qrData.isEmpty) {
      _showError('Please enter QR code data');
      return;
    }
    _processScannedQRCode(qrData);
  }
   void _resetScanState() { 
    if (mounted) {
      setState(() {
        _isSearching = false;
        _hasScanned = false;
        _lastScannedData = null;
      });
      if (_isCameraActive) {
        _startCamera();
      }
    }
  }
  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      setState(() {
        _hasCameraPermission = status.isGranted;
      });
      
      if (!_hasCameraPermission) {
        _showError('Camera permission is required to scan QR codes');
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
      _showError('Error requesting camera permission');
    }
  }

 void _handleBarcode(BarcodeCapture barcodes) {
  if (barcodes.barcodes.isNotEmpty && !_isSearching && !_hasScanned) {
    final String? qrData = barcodes.barcodes.first.rawValue;
    if (qrData != null && qrData.isNotEmpty) {
      debugPrint('QR Code scanned: $qrData');
      setState(() {
        _hasScanned = true;
        _lastScannedData = qrData;
      });
      cameraController.stop();
      _processScannedQRCode(qrData);
    }
  }
}

  void _processScannedQRCode(String qrData) {
    setState(() {
      _isSearching = true;
    });
    _qrController.text = qrData;
    _searchByQR(qrData);
  }

  void _toggleCamera() {
    setState(() {
      _isCameraActive = !_isCameraActive;
    });
    if (_isCameraActive) {
      cameraController.start();
    } else {
      cameraController.stop();
    }
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasCameraPermission) ...[
            _buildQRScannerSection(),
            const SizedBox(height: 12),
            _buildCameraControls(),
          ] else ...[
            _buildPermissionRequestSection(),
            const SizedBox(height: 12),
          ],
          _buildManualInputSection(),
          const SizedBox(height: 12),
          _buildHelpSection(),
        ],
      ),
    );
  }

  Widget _buildQRScannerSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // QR Scanner View
            _buildQRView(),
            
            // Scanning Indicator
            if (_isSearching)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing QR Code...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Scanner overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRView() {
    if (!_hasCameraPermission) {
      return const Center(
        child: Text(
          'Camera permission required',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return MobileScanner(
      controller: cameraController,
      onDetect: _handleBarcode,
      fit: BoxFit.cover,
    );
  }

 Widget _buildCameraControls() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ElevatedButton.icon(
        icon: Icon(_isCameraActive ? Icons.pause : Icons.play_arrow),
        label: Text(_isCameraActive ? 'Pause Camera' : 'Start Camera'),
        onPressed: _toggleCamera,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF18A3B6),
          foregroundColor: Colors.white,
        ),
      ),
      const SizedBox(width: 10),
      ElevatedButton.icon(
        icon: const Icon(Icons.flash_on),
        label: const Text('Flash'),
        onPressed: _toggleFlash,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      ),
      const SizedBox(width: 10),
      if (_hasScanned)
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Scan Again'),
          onPressed: _resetScanState,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
    ],
  );
}

  Widget _buildPermissionRequestSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Camera Access Required',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap below to enable camera for QR scanning',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestCameraPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enable Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualInputSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Manual QR Input',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qrController,
              decoration: const InputDecoration(
                labelText: 'QR Code Data',
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
                hintText: 'Paste or type QR code here',
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: _isSearching ? null : _searchByQRManual,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Search Patient', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How to scan QR Code:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
            ),
            const SizedBox(height: 4),
            _HelpText('Ask patient to show their QR code'),
            _HelpText('Point camera at the QR code'),
            _HelpText('System will auto-detect and process'),
            _HelpText('Or manually enter QR code below'),
          ],
        ),
      ),
    );
  }

Future<void> _searchByQR(String qrData) async {
  setState(() => _isSearching = true);

  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for patient...'),
          ],
        ),
      ),
    );

    Map<String, dynamic>? patientData;
    String? patientId;

    // Search by UID
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(qrData)
          .get();

      if (doc.exists) {
        patientData = doc.data();
        patientId = doc.id;
        debugPrint('Found patient by UID: ${patientData?['fullname']}');
      }
    } catch (e) {
      debugPrint('Error searching by UID: $e');
    }

    // Search by mobile
    if (patientData == null) {
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('patients')
            .where('mobile', isEqualTo: qrData)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          patientData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          patientId = querySnapshot.docs.first.id;
          debugPrint('Found patient by mobile: ${patientData['fullname']}');
        }
      } catch (e) {
        debugPrint('Error searching by mobile: $e');
      }
    }

    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    if (patientData == null || patientId == null) {
      _showError('Patient not found. Please check QR code and try again.');
      _resetScanState();
      return;
    }

    // Navigate to PatientProfileScreen with the patient data
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientProfileScreen(
            patientId: patientId!,
            patientData: patientData!,
            pharmacyId: widget.pharmacyId,
            pharmacyName: widget.pharmacyName,
          ),
        ),
      );
      
      _resetScanState();
    }

  } catch (e) {
    if (mounted) Navigator.of(context).pop();
    _showError('Error: $e');
    _resetScanState();
  }
}
Future<void> _startCamera() async {
  try {
    await cameraController.start();
    setState(() {
      _isCameraActive = true;
      _hasScanned = false; // Reset scan flag when starting camera
    });
  } catch (e) {
    debugPrint('Error starting camera: $e');
  }
}

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _qrController.dispose();
    super.dispose();
  }
}

// Custom scanner overlay
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const squareSize = 150.0;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: squareSize,
      height: squareSize,
    );

    canvas.drawRect(rect, paint);

    // Draw corner lines
    const cornerLength = 20.0;
    
    // Top left
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLength),
      paint,
    );

    // Top right
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLength, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom left
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      paint,
    );

    // Bottom right
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}