import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_patient_profile_screen.dart'; // Ensure this import is correct

class DoctorUnifiedSearchScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  final String? currentAppointmentId;

  const DoctorUnifiedSearchScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.scheduleId,
    required this.appointmentType,
    this.currentAppointmentId,
  });

  @override
  State<DoctorUnifiedSearchScreen> createState() =>
      _DoctorUnifiedSearchScreenState();
}

class _DoctorUnifiedSearchScreenState extends State<DoctorUnifiedSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showQueueProgress = false;

  // Lists to manage different states
  List<Map<String, dynamic>> _queueAppointments =
      []; // Waiting + In Consultation
  List<Map<String, dynamic>> _completedAppointments = []; // Done
  List<Map<String, dynamic>> _skippedAppointments = []; // Absent/Skipped

  bool _isLoadingQueue = false;
  StreamSubscription? _queueSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _setupQueueStream();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleQueueProgress() {
    setState(() {
      _showQueueProgress = !_showQueueProgress;
    });
  }

  void _setupQueueStream() {
    if (widget.scheduleId.isEmpty) return;

    setState(() => _isLoadingQueue = true);

    _queueSubscription = FirebaseFirestore.instance
        .collection('appointments')
        .where('scheduleId', isEqualTo: widget.scheduleId)
        .snapshots()
        .listen((snapshot) {
          _processQueueData(snapshot.docs);
        });
  }

  // --- FIXED LOGIC HERE ---
  void _processQueueData(List<DocumentSnapshot> docs) {
    final appointments = <Map<String, dynamic>>[];
    final completed = <Map<String, dynamic>>[];
    final skipped = <Map<String, dynamic>>[];
    final inConsultation = <Map<String, dynamic>>[];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        final appointment = {
          'id': doc.id,
          'patientName': data['patientName'] ?? 'Unknown',
          'tokenNumber': data['tokenNumber'] ?? 0,
          'queueStatus': data['queueStatus'] ?? 'waiting',
          'status': data['status'] ?? 'confirmed',
        };

        final status = data['status'];
        final queueStatus = data['queueStatus'];

        // 1. Handle Completed
        if (status == 'completed') {
          completed.add(appointment);
        }
        // 2. Handle Skipped/Absent/Cancelled (The Fix)
        else if (status == 'skipped' ||
            status == 'absent' ||
            status == 'cancelled' ||
            queueStatus == 'skipped') {
          skipped.add(appointment);
        }
        // 3. Handle Active Queue (Confirmed/Pending)
        else if (status == 'confirmed' || status == 'pending') {
          if (queueStatus == 'in_consultation') {
            inConsultation.add(appointment);
          } else if (queueStatus == 'waiting') {
            appointments.add(appointment); // Add to waiting list
          } else {
            // Fallback for weird states, put in waiting
            appointments.add(appointment);
          }
        }
      }
    }

    // Sort waiting appointments by token number
    appointments.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );
    completed.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );
    skipped.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );

    // Combine inConsultation + waiting for the active queue display
    final queue = [...inConsultation, ...appointments];

    if (mounted) {
      setState(() {
        _queueAppointments = queue;
        _completedAppointments = completed;
        _skippedAppointments = skipped;
        _isLoadingQueue = false;
      });
    }
  }

  Widget _buildQueueProgress() {
    if (_isLoadingQueue && _queueAppointments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF18A3B6)),
        ),
      );
    }

    // Calculate totals correctly including skipped
    final totalPatients =
        _queueAppointments.length +
        _completedAppointments.length +
        _skippedAppointments.length;
    // Progress based on Completed + Skipped (Work done) OR just Completed.
    // Here we show Completed vs Total
    final progress = totalPatients > 0
        ? _completedAppointments.length / totalPatients
        : 0.0;

    // Find current appointment
    final currentAppointment = _queueAppointments.firstWhere(
      (appt) => appt['queueStatus'] == 'in_consultation',
      orElse: () => {},
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consultation Queue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                  Text(
                    'Schedule: ${widget.scheduleId.substring(0, 8)}...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: _toggleQueueProgress,
                iconSize: 20,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Completed',
                '${_completedAppointments.length}',
                Colors.green,
              ),
              _buildStatItem(
                'Waiting',
                '${_queueAppointments.length}',
                const Color(0xFF18A3B6),
              ),
              _buildStatItem(
                'Skipped',
                '${_skippedAppointments.length}',
                Colors.orange,
              ), // Show Skipped explicitly
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 16),

          // Current Status Text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Color(0xFF18A3B6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentAppointment.isNotEmpty
                        ? 'Consulting: ${currentAppointment['patientName']} (#${currentAppointment['tokenNumber']})'
                        : _queueAppointments.isNotEmpty
                        ? 'Next: ${_queueAppointments.first['patientName']} (#${_queueAppointments.first['tokenNumber']})'
                        : 'Queue is clear',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Queue List
          if (_queueAppointments.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Upcoming Patients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ..._queueAppointments.take(5).map((appointment) {
              final isCurrent = appointment['queueStatus'] == 'in_consultation';
              return _buildQueueItem(appointment, isCurrent: isCurrent);
            }).toList(),
            if (_queueAppointments.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${_queueAppointments.length - 5} more patients',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],

          // Show Skipped List if any (To fix the confusion about "Patient 2")
          if (_skippedAppointments.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Absent / Skipped',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            ..._skippedAppointments.take(3).map((appointment) {
              return _buildQueueItem(appointment, isSkipped: true);
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildQueueItem(
    Map<String, dynamic> appointment, {
    bool isCurrent = false,
    bool isSkipped = false,
  }) {
    Color bgColor = Colors.grey[50]!;
    Color borderColor = Colors.grey[200]!;
    Color textColor = Colors.grey[800]!;
    String statusText = appointment['queueStatus'].toString();

    if (isCurrent) {
      bgColor = const Color(0xFF18A3B6).withOpacity(0.1);
      borderColor = const Color(0xFF18A3B6);
      textColor = const Color(0xFF18A3B6);
      statusText = 'IN PROGRESS';
    } else if (isSkipped) {
      bgColor = Colors.orange.withOpacity(0.05);
      borderColor = Colors.orange.withOpacity(0.3);
      textColor = Colors.orange[800]!;
      statusText = 'ABSENT';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF18A3B6)
                  : (isSkipped ? Colors.orange : Colors.grey[400]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${appointment['tokenNumber']}',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment['patientName'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Total count calculation for badge
    final totalCount =
        _queueAppointments.length +
        _completedAppointments.length +
        _skippedAppointments.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Patient'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.phone), text: 'Phone'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _toggleQueueProgress,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showQueueProgress ? Icons.visibility_off : Icons.people,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_completedAppointments.length}/$totalCount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsed Header
          if (!_showQueueProgress)
            GestureDetector(
              onTap: _toggleQueueProgress,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF18A3B6).withOpacity(0.05),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Color(0xFF18A3B6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Queue Status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18A3B6),
                            ),
                          ),
                          Text(
                            _isLoadingQueue
                                ? 'Loading...'
                                : '${_completedAppointments.length} done • ${_skippedAppointments.length} absent • ${_queueAppointments.length} waiting',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF18A3B6)),
                  ],
                ),
              ),
            ),

          // Expanded Queue
          if (_showQueueProgress)
            Expanded(
              child: SingleChildScrollView(child: _buildQueueProgress()),
            ),

          // Tab View
          if (!_showQueueProgress)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  QRCodeTab(
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                    scheduleId: widget.scheduleId,
                    appointmentType: widget.appointmentType,
                    checkAppointmentsMethod: _checkIfPatientHasAppointments,
                    currentAppointmentId: widget.currentAppointmentId,
                    onQueueUpdated: () => _setupQueueStream(),
                  ),
                  PhoneNumberTab(
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                    scheduleId: widget.scheduleId,
                    appointmentType: widget.appointmentType,
                    checkAppointmentsMethod: _checkIfPatientHasAppointments,
                    currentAppointmentId: widget.currentAppointmentId,
                    onQueueUpdated: () => _setupQueueStream(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<bool> _checkIfPatientHasAppointments(
    String patientId,
    String scheduleId,
  ) async {
    try {
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
        // Allow confirmed, pending, waiting.
        // NOTE: You might want to allow 'skipped' if you want to allow them to be "re-processed"
        if (status == 'confirmed' ||
            status == 'pending' ||
            status == 'waiting' ||
            status == 'skipped') {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking appointments: $e');
      return false;
    }
  }
}

// ... QRCodeTab, PhoneNumberTab, HelpText, ScannerOverlayPainter remain same as previous code

// QR Code Tab
class QRCodeTab extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  final Future<bool> Function(String, String) checkAppointmentsMethod;
  final String? currentAppointmentId;
  final VoidCallback? onQueueUpdated;
  const QRCodeTab({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.scheduleId,
    required this.appointmentType,
    required this.checkAppointmentsMethod,
    this.currentAppointmentId,
    this.onQueueUpdated,
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
        child: Stack(children: _buildScannerStackChildren()),
      ),
    );
  }

  List<Widget> _buildScannerStackChildren() {
    final children = <Widget>[
      // QR Scanner View
      _buildQRView(),
    ];

    if (_isSearching) {
      children.add(
        _buildScanningOverlay('Processing QR Code...', Icons.hourglass_empty),
      );
    } else if (_hasScanned) {
      children.add(
        _buildScanningOverlay(
          'QR Code Scanned!\nTap "Scan Again" to rescan',
          Icons.check_circle,
          color: Colors.green,
        ),
      );
    } else if (!_isCameraActive) {
      children.add(
        _buildScanningOverlay(
          'Camera Paused\nTap Start to resume',
          Icons.videocam_off,
          color: Colors.orange,
        ),
      );
    } else {
      children.add(
        Positioned.fill(child: CustomPaint(painter: ScannerOverlayPainter())),
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

  Widget _buildScanningOverlay(
    String text,
    IconData icon, {
    Color color = Colors.white,
  }) {
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
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
      debugPrint('🔍 Searching patient by QR: $qrData');
      debugPrint('📋 Schedule ID: ${widget.scheduleId}');
      debugPrint('🏥 Doctor ID: ${widget.doctorId}');
      debugPrint('📝 Current Appointment ID: ${widget.currentAppointmentId}');
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

      if (patientData == null || patientId == null) {
        _showError('Patient not found. Please check QR code and try again.');
        _resetScanState();
        return;
      }

      // Check if patient has appointments for THIS SPECIFIC SCHEDULE
      final hasAppointments = await widget.checkAppointmentsMethod(
        patientId,
        widget.scheduleId,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (!hasAppointments) {
        debugPrint(
          '❌ Patient ${patientData['name']} has no appointment for schedule ${widget.scheduleId}',
        );
        await _showNoAppointmentDialog(
          context,
          patientId,
          patientData,
          widget.scheduleId,
        );
        _resetScanState();
        return;
      }

      // ✅ PATIENT VERIFIED - Proceed to consultation
      debugPrint('✅ Patient verified: ${patientData['name']}');
      debugPrint('🎯 Proceeding to consultation...');

      if (context.mounted) {
        // Navigate to patient profile with appointment context
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorPatientProfileScreen(
              patientId: patientId!,
              patientName:
                  patientData?['name'] ?? patientData?['fullName'] ?? 'Patient',
              patientData: patientData ?? {},
              scheduleId: widget.scheduleId, // PASS SCHEDULE ID
              appointmentId: widget.currentAppointmentId, // PASS APPOINTMENT ID
            ),
          ),
        );

        // After returning from consultation, reset scanner
        debugPrint('🔁 Returning to search screen for next patient');
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
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
  void _showAccessDeniedDialog(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
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
                  _buildListPointRed(
                    'Patient must have a scheduled appointment',
                  ),
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

/// Phone Number Tab
class PhoneNumberTab extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  final Future<bool> Function(String, String) checkAppointmentsMethod;
  final String? currentAppointmentId;
  final VoidCallback? onQueueUpdated;
  const PhoneNumberTab({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.scheduleId,
    required this.appointmentType,
    required this.checkAppointmentsMethod,
    this.currentAppointmentId,
    this.onQueueUpdated,
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
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_iphone,
                    size: 50,
                    color: Color(0xFF18A3B6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter Patient Mobile Number',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
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
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Search Patient',
                              style: TextStyle(fontSize: 14),
                            ),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                  SizedBox(height: 4),
                  HelpText(
                    'Enter the exact mobile number registered by patient',
                  ),
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

  Future<void> _searchByMobile() async {
    final mobileNumber = _mobileController.text.trim();
    if (mobileNumber.isEmpty) {
      _showError('Please enter mobile number');
      return;
    }

    setState(() => _isSearching = true);

    try {
      debugPrint('🔍 Searching patient by mobile: $mobileNumber');
      debugPrint('📋 Schedule ID: ${widget.scheduleId}');
      debugPrint('🏥 Doctor ID: ${widget.doctorId}');
      debugPrint('📝 Current Appointment ID: ${widget.currentAppointmentId}');
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
          patientData =
              querySnapshot.docs.first.data() as Map<String, dynamic>?;
          patientId = querySnapshot.docs.first.id;
        }
      }

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (patientData == null || patientId == null) {
        _showError('Patient not found. Please check the number.');
        setState(() => _isSearching = false);
        return;
      }

      // Check if patient has appointments for THIS SPECIFIC SCHEDULE
      final hasAppointments = await widget.checkAppointmentsMethod(
        patientId,
        widget.scheduleId,
      );

      if (!hasAppointments) {
        debugPrint(
          '❌ Patient ${patientData['name']} has no appointment for schedule ${widget.scheduleId}',
        );
        await _showNoAppointmentDialog(
          context,
          patientId,
          patientData,
          widget.scheduleId,
        );
        setState(() => _isSearching = false);
        return;
      }

      debugPrint('✅ Patient verified: ${patientData['name']}');
      debugPrint('🎯 Proceeding to consultation...');

      if (context.mounted) {
        // Navigate to patient profile with appointment context
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorPatientProfileScreen(
              patientId: patientId!,
              patientName:
                  patientData?['name'] ?? patientData?['fullName'] ?? 'Patient',
              patientData: patientData ?? {},
              scheduleId: widget.scheduleId,
              appointmentId: widget.currentAppointmentId,
            ),
          ),
        );
        if (widget.onQueueUpdated != null) {
          widget.onQueueUpdated!();
        }
        debugPrint('🔁 Returning to search screen for next patient');
      }

      setState(() => _isSearching = false);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      _showError('Error searching patient: $e');
      setState(() => _isSearching = false);
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
            Text(
              'No Appointment Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
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
