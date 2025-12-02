import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_patient_profile_screen.dart';

class DoctorUnifiedSearchScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  
  const DoctorUnifiedSearchScreen({
    super.key, 
    required this.doctorId,
    required this.doctorName,
    required this.scheduleId,
    required this.appointmentType,
  });

  @override
  State<DoctorUnifiedSearchScreen> createState() => _DoctorUnifiedSearchScreenState();
}

class _DoctorUnifiedSearchScreenState extends State<DoctorUnifiedSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
  }

  // In your main screen's shared methods, update this:
Future<bool> _checkIfPatientHasAppointments(String patientId, String scheduleId) async {
  try {
    // Check in appointments collection for this specific schedule
    final appointmentsQuery = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('scheduleId', isEqualTo: scheduleId)
        .where('doctorId', isEqualTo: widget.doctorId)
        .limit(1)
        .get();

    if (appointmentsQuery.docs.isNotEmpty) {
      final appointmentData = appointmentsQuery.docs.first.data();
      final status = appointmentData['status'] as String?;
      
      // Check if appointment is confirmed, pending, or waiting
      if (status == 'confirmed' || status == 'pending' || status == 'waiting') {
        return true;
      }
    }

    return false;
  } catch (e) {
    debugPrint('Error checking appointments: $e');
    return false;
  }
}

 Future<void> _showNoAppointmentDialog(
  BuildContext context,
  String patientId,
  Map<String, dynamic> patientData,
  String scheduleId,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('No Appointment Found'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🚫 Access Denied',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  'This patient does not have any scheduled appointments for this schedule.',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18A3B6),
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _showScheduleInfo(BuildContext context, String scheduleId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Schedule Information'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schedule ID: $scheduleId'),
          const SizedBox(height: 8),
          const Text('Only patients with appointments under this specific schedule can access their medical profiles.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

  Widget _buildListPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logProfileAccess(BuildContext context, String patientId, {String method = 'qr_scan'}) async {
    try {
      await FirebaseFirestore.instance.collection('profile_access_logs').add({
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorName,
        'patientId': patientId,
        'accessMethod': method,
        'timestamp': FieldValue.serverTimestamp(),
        'hasAppointment': false,
        'scheduleId': widget.scheduleId,
        'appointmentType': widget.appointmentType,
      });
    } catch (e) {
      debugPrint('Error logging access: $e');
    }
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
    QRCodeTab(
      doctorId: widget.doctorId,
      doctorName: widget.doctorName,
      scheduleId: widget.scheduleId,
      appointmentType: widget.appointmentType,
      checkAppointmentsMethod: _checkIfPatientHasAppointments,
    ),
    PhoneNumberTab(
      doctorId: widget.doctorId,
      doctorName: widget.doctorName,
      scheduleId: widget.scheduleId,
      appointmentType: widget.appointmentType,
      checkAppointmentsMethod: _checkIfPatientHasAppointments,
    ),
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
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  final Future<bool> Function(String, String) checkAppointmentsMethod;
 
  
  const QRCodeTab({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.scheduleId,
    required this.appointmentType,
    required this.checkAppointmentsMethod,
   
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
          onPressed: _toggleCamera,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18A3B6),
            foregroundColor: Colors.white,
          ),
          icon: Icon(_isCameraActive ? Icons.pause : Icons.play_arrow),
          label: Text(_isCameraActive ? 'Pause' : 'Start'),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _toggleFlash,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.flash_on),
          label: const Text('Flash'),
        ),
        const SizedBox(width: 10),
        if (_hasScanned)
          ElevatedButton.icon(
            onPressed: _resetScanState,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
          ),
      ],
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

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(qrData)
          .get();

      if (userDoc.exists) {
        patientData = userDoc.data();
        patientId = userDoc.id;
      }
    } catch (e) {
      debugPrint('Error searching in users: $e');
    }

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
        debugPrint('Error searching in patients: $e');
      }
    }

    if (context.mounted) Navigator.of(context).pop();

    if (patientData == null || patientId == null) {
      _showError('Patient not found. Please check QR code and try again.');
      _resetScanState();
      return;
    }

    // Check if patient has appointments for THIS SPECIFIC SCHEDULE
    final hasAppointments = await widget.checkAppointmentsMethod(patientId, widget.scheduleId);

    if (!hasAppointments) {
      // DENY ACCESS - Show error message
      // Call local method instead of widget.showNoAppointmentDialog
      await _showNoAppointmentDialog(
        context,
        patientId,
        patientData,
        widget.scheduleId,
      );
      _resetScanState();
      return;
    }

    // ALLOW ACCESS - Navigate to profile
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorPatientProfileScreen(
            patientId: patientId!,
            patientName: patientData?['name'] ?? patientData?['fullName'] ?? 'Patient',
            patientData: patientData ?? {},
          ),
        ),
      );
    }

    _resetScanState();

  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    _showError('Error: $e');
    _resetScanState();
  }
}

// Make sure this method exists in _QRCodeTabState
Future<void> _showNoAppointmentDialog(
  BuildContext context,
  String patientId,
  Map<String, dynamic> patientData,
  String scheduleId,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'No Appointment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚫 Access Denied',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This patient does not have any scheduled appointments for this schedule.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18A3B6),
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// Add this method to show access denied dialog
void _showAccessDeniedDialog(BuildContext context, Map<String, dynamic> patientData) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('Access Denied'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🚫 Cannot Access Medical Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This patient does not have any scheduled appointments with you.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'To access patient medical records:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                _buildListPointRed('Patient must have a scheduled appointment'),
                _buildListPointRed('Appointments can be scheduled via admin'),
                _buildListPointRed('Or patient can book through the app'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18A3B6),
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Widget _buildListPointRed(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.block, size: 14, color: Colors.red),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.red),
          ),
        ),
      ],
    ),
  );
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
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  final Future<bool> Function(String, String) checkAppointmentsMethod;
  
  
  const PhoneNumberTab({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.scheduleId,
    required this.appointmentType,
    required this.checkAppointmentsMethod,
    
  });

  @override
  State<PhoneNumberTab> createState() => _PhoneNumberTabState();
}

class _PhoneNumberTabState extends State<PhoneNumberTab> {
  final TextEditingController _mobileController = TextEditingController();
  bool _isSearching = false;

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

 Future<void> _searchByMobile() async {
  final mobileNumber = _mobileController.text.trim();
  if (mobileNumber.isEmpty) {
    _showError('Please enter mobile number');
    return;
  }

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

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('mobile', isEqualTo: mobileNumber)
        .limit(1)
        .get();

    Map<String, dynamic>? patientData;
    String? patientId;

    if (querySnapshot.docs.isNotEmpty) {
      patientData = querySnapshot.docs.first.data() as Map<String, dynamic>?;
      patientId = querySnapshot.docs.first.id;
    } else {
      querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('mobile', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        patientData = querySnapshot.docs.first.data() as Map<String, dynamic>?;
        patientId = querySnapshot.docs.first.id;
      }
    }

    if (context.mounted) Navigator.of(context).pop();

    if (patientData == null || patientId == null) {
      _showError('Patient not found. Please check the number.');
      setState(() => _isSearching = false);
      return;
    }

    // Check if patient has appointments for THIS SPECIFIC SCHEDULE
    final hasAppointments = await widget.checkAppointmentsMethod(patientId, widget.scheduleId);

    if (!hasAppointments) {
      // DENY ACCESS - Call local method
      await _showNoAppointmentDialog(
        context,
        patientId,
        patientData,
        widget.scheduleId,
      );
      setState(() => _isSearching = false);
      return;
    }

    // ALLOW ACCESS
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorPatientProfileScreen(
            patientId: patientId!,
            patientName: patientData?['name'] ?? patientData?['fullName'] ?? 'Patient',
            patientData: patientData ?? {},
          ),
        ),
      );
    }

    setState(() => _isSearching = false);

  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    _showError('Error searching patient: $e');
    setState(() => _isSearching = false);
  }
}

// Add this method to PhoneNumberTab
Future<void> _showNoAppointmentDialog(
  BuildContext context,
  String patientId,
  Map<String, dynamic> patientData,
  String scheduleId,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('No Appointment Found',style: const TextStyle(
            fontSize: 16, // Reduced from 24 to 16
            fontWeight: FontWeight.bold,
          ),),
          
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚫 Access Denied',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 8),
                Text(
                  'This patient does not have any scheduled appointments for this schedule.',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18A3B6),
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// Add this method to PhoneNumberTab
void _showAccessDeniedDialog(BuildContext context, Map<String, dynamic> patientData) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('Access Restricted'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient: ${patientData['name'] ?? patientData['fullName'] ?? 'Patient'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚫 Medical Profile Not Accessible',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 8),
                Text(
                  'Access to patient medical records is restricted to patients with scheduled appointments only.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Please ensure:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('• Patient has an appointment booked with you'),
                Text('• Appointment status is confirmed'),
                Text('• Appointment time is within schedule'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Optional: Navigate to appointment booking screen
            _showAppointmentBookingInfo();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Schedule Appointment'),
        ),
      ],
    ),
  );
}

void _showAppointmentBookingInfo() {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Please use the appointment booking system to schedule'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
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
                  HelpText('View medical history and start consultation'),
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

class HelpText extends StatelessWidget {
  final String text;

  const HelpText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('•', style: TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.left,
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

    const cornerLength = 20.0;
    
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