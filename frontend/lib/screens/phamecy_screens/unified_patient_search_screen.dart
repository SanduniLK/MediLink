import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_profile_screen.dart';

class UnifiedPatientSearchScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;
  final int initialTab;
  
  const UnifiedPatientSearchScreen({
    super.key, 
    required this.pharmacyId,
    required this.pharmacyName,
    this.initialTab = 0,
  });

  @override
  State<UnifiedPatientSearchScreen> createState() => _UnifiedPatientSearchScreenState();
}

class _UnifiedPatientSearchScreenState extends State<UnifiedPatientSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Patient'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.qr_code_scanner),
              text: 'Scan QR Code',
            ),
            Tab(
              icon: Icon(Icons.phone),
              text: 'Phone Number',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          QRCodeTab(pharmacyId: widget.pharmacyId, pharmacyName: widget.pharmacyName),
          PhoneNumberTab(pharmacyId: widget.pharmacyId, pharmacyName: widget.pharmacyName),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// QR Code Tab
class QRCodeTab extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;
  
  const QRCodeTab({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<QRCodeTab> createState() => _QRCodeTabState();
}

class _QRCodeTabState extends State<QRCodeTab> {
  final TextEditingController _qrController = TextEditingController();
  bool _isSearching = false;
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
      if (!status.isGranted) {
        await _requestCameraPermission();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
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
      
      if (qrData != null && qrData.isNotEmpty && qrData != _lastScannedData) {
        debugPrint('QR Code scanned: $qrData');
        
        setState(() {
          _hasScanned = true;
          _lastScannedData = qrData;
        });
        
        _stopCamera();
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

  Future<void> _stopCamera() async {
    try {
      await cameraController.stop();
      setState(() {
        _isCameraActive = false;
      });
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
  }

  Future<void> _startCamera() async {
    try {
      await cameraController.start();
      setState(() {
        _isCameraActive = true;
        _hasScanned = false;
      });
    } catch (e) {
      debugPrint('Error starting camera: $e');
    }
  }

  void _toggleCamera() {
    if (_isCameraActive) {
      _stopCamera();
    } else {
      _startCamera();
    }
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQRScannerSection(),
          const SizedBox(height: 12),
          _buildCameraControls(),
          const SizedBox(height: 12),
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
        children: _buildScannerStackChildren()
      ),
    ),
  );
}
List<Widget> _buildScannerStackChildren() {
  final children = <Widget>[
    // QR Scanner View
    _buildQRView(),
  ];

  // Add overlays based on state
  if (_isSearching) {
    children.add(_buildScanningOverlay('Processing QR Code...', Icons.hourglass_empty));
  } else if (_hasScanned) {
    children.add(_buildScanningOverlay('QR Code Scanned!\nTap "Scan Again" to rescan', Icons.check_circle, color: Colors.green));
  } else if (!_isCameraActive) {
    children.add(_buildScanningOverlay('Camera Paused\nTap Start to resume', Icons.videocam_off, color: Colors.orange));
  } else {
    children.add(
      Positioned.fill(
        child: CustomPaint(
          painter: ScannerOverlayPainter(),
        ),
      ),
    );
  }

  return children;
}
  Widget _buildQRView() {
    return MobileScanner(
      controller: cameraController,
      onDetect: _handleBarcode,
      fit: BoxFit.cover,
    );
  }

  Widget _buildScanningOverlay(String text, IconData icon, {Color color = Colors.white}) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 50),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
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
    );
  }

  Widget _buildCameraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: Icon(_isCameraActive ? Icons.pause : Icons.play_arrow),
          label: Text(_isCameraActive ? 'Pause' : 'Start'),
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
            HelpText('Ask patient to show their QR code'),
            HelpText('Point camera at the QR code'),
            HelpText('System will auto-detect and process'),
            HelpText('Or manually enter QR code below'),
          ],
        ),
      ),
    );
  }

  void _searchByQRManual() {
    final qrData = _qrController.text.trim();
    if (qrData.isEmpty) {
      _showError('Please enter QR code data');
      return;
    }
    
    _stopCamera();
    setState(() {
      _hasScanned = true;
      _lastScannedData = qrData;
    });
    
    _searchByQR(qrData);
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
          patientData = querySnapshot.docs.first.data() as Map<String, dynamic>?;
          patientId = querySnapshot.docs.first.id;
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

    // Navigate to PatientProfileScreen - fix null safety issues
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientProfileScreen(
            patientId: patientId!, // Use ! to assert non-null
            patientData: patientData!, // Use ! to assert non-null
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

  void _resetScanState() {
    if (mounted) {
      setState(() {
        _isSearching = false;
        _hasScanned = false;
        _lastScannedData = null;
      });
      _qrController.clear();
      if (_isCameraActive) {
        _startCamera();
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _qrController.dispose();
    super.dispose();
  }
}

// Phone Number Tab
class PhoneNumberTab extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;
  
  const PhoneNumberTab({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<PhoneNumberTab> createState() => _PhoneNumberTabState();
}

class _PhoneNumberTabState extends State<PhoneNumberTab> {
  final TextEditingController _mobileController = TextEditingController();
  bool _isSearching = false;

 Future<void> _searchByMobile() async {
  final mobileNumber = _mobileController.text.trim();
  if (mobileNumber.isEmpty) {
    _showError('Please enter mobile number');
    return;
  }

  setState(() => _isSearching = true);

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('patients')
        .where('mobile', isEqualTo: mobileNumber)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      _showError('Patient not found. Please check the number or register new patient.');
      return;
    }

    final patientData = querySnapshot.docs.first.data();
    final patientId = querySnapshot.docs.first.id;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientProfileScreen(
            patientId: patientId,
            patientData: patientData,
            pharmacyId: widget.pharmacyId,
            pharmacyName: widget.pharmacyName,
          ),
        ),
      );
    }

  } catch (e) {
    _showError('Error searching patient: $e');
  } finally {
    if (mounted) setState(() => _isSearching = false);
  }
}

  void _registerNewPatient() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register New Patient'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccess('Patient registration feature coming soon');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18A3B6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Register'),
          ),
        ],
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_iphone, size: 50, color: Color(0xFF18A3B6)),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter Patient Mobile Number',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _mobileController,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      hintText: 'Enter patient mobile number',
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _searchByMobile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF18A3B6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Search Patient', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Can't find patient?",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Register new patient in the system',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _registerNewPatient,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text(
                      'Register New Patient',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Using Phone Number:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
                  ),
                  SizedBox(height: 4),
                  HelpText('Enter the exact mobile number registered by patient'),
                  HelpText('System will search across all patient records'),
                  HelpText('View prescription history and issue medications'),
                  HelpText('For new patients, use the registration option'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }
}

// Helper widget for help text
class HelpText extends StatelessWidget {
  final String text;

  const HelpText(this.text, {super.key});

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

// Custom scanner overlay
class ScannerOverlayPainter extends CustomPainter {
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