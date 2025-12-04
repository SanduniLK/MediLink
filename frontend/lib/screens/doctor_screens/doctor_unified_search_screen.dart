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
  List<Map<String, dynamic>> _queueAppointments = [];
  List<Map<String, dynamic>> _completedAppointments = [];
  List<Map<String, dynamic>> _skippedAppointments = [];

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

  // --- START SESSION LOGIC (Batch Update) ---
  Future<void> _startQueueSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Consultation Session?'),
        content: const Text(
          'This will mark all confirmed appointments for this schedule as "Waiting" in the queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18A3B6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoadingQueue = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('scheduleId', isEqualTo: widget.scheduleId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'];
        final currentQueueStatus = data['queueStatus'];

        // Only update appointments that are NOT completed, cancelled, or skipped
        if (status != 'completed' &&
            status != 'cancelled' &&
            status != 'skipped' &&
            currentQueueStatus != 'in_consultation') {
          batch.update(doc.reference, {
            'queueStatus': 'waiting',
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Queue initialized. $updateCount patients set to Waiting.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No appointments needed updating.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingQueue = false);
    }
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

        if (status == 'completed') {
          completed.add(appointment);
        } else if (status == 'skipped' ||
            status == 'absent' ||
            status == 'cancelled' ||
            queueStatus == 'skipped') {
          skipped.add(appointment);
        } else if (status == 'confirmed' ||
            status == 'pending' ||
            status == 'waiting') {
          if (queueStatus == 'in_consultation') {
            inConsultation.add(appointment);
          } else {
            appointments.add(appointment);
          }
        }
      }
    }

    appointments.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );
    completed.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );
    skipped.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );

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

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            tooltip: 'Start Session',
            onPressed: _startQueueSession,
          ),
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
          if (_showQueueProgress)
            Expanded(
              child: SingleChildScrollView(child: _buildQueueProgress()),
            ),
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
                    // Updated to use the ID-returning method
                    checkAppointmentsMethod: _getPatientAppointmentId,
                    currentAppointmentId: widget.currentAppointmentId,
                    onQueueUpdated: () => _setupQueueStream(),
                  ),
                  PhoneNumberTab(
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                    scheduleId: widget.scheduleId,
                    appointmentType: widget.appointmentType,
                    // Updated to use the ID-returning method
                    checkAppointmentsMethod: _getPatientAppointmentId,
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

  // --- UPDATED CHECK METHOD: Returns String? (Appointment ID) ---
  Future<String?> _getPatientAppointmentId(
    String patientId,
    String scheduleId,
  ) async {
    try {
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .where('scheduleId', isEqualTo: scheduleId)
          .where('doctorId', isEqualTo: widget.doctorId)
          // We allow active statuses. We do NOT filter by 'queueStatus' here
          // because we want to find the doc regardless of whether they are 'waiting' or 'skipped'
          .limit(1)
          .get();

      if (appointmentsQuery.docs.isNotEmpty) {
        final doc = appointmentsQuery.docs.first;
        final data = doc.data();
        final status = data['status'] as String?;

        if (status == 'confirmed' ||
            status == 'pending' ||
            status == 'waiting' ||
            status == 'skipped') {
          return doc.id; // Return the exact Document ID
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking appointments: $e');
      return null;
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

    final totalPatients =
        _queueAppointments.length +
        _completedAppointments.length +
        _skippedAppointments.length;
    final progress = totalPatients > 0
        ? _completedAppointments.length / totalPatients
        : 0.0;

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
              ),
            ],
          ),
          const SizedBox(height: 12),
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
            ..._skippedAppointments
                .take(3)
                .map(
                  (appointment) =>
                      _buildQueueItem(appointment, isSkipped: true),
                )
                .toList(),
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
}

// =========================================================
// QR CODE TAB - UPDATED TO USE APPOINTMENT ID
// =========================================================
class QRCodeTab extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  // Updated Signature: Returns String? (Appointment ID)
  final Future<String?> Function(String, String) checkAppointmentsMethod;
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
      _showError('Error requesting camera permission');
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (barcodes.barcodes.isNotEmpty && !_isSearching && !_hasScanned) {
      final String? qrData = barcodes.barcodes.first.rawValue;
      if (qrData != null && qrData.isNotEmpty && qrData != _lastScannedData) {
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
    setState(() => _isSearching = true);
    _qrController.text = qrData;
    _searchByQR(qrData);
  }

  Future<void> _stopCamera() async {
    try {
      await cameraController.stop();
      setState(() => _isCameraActive = false);
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
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _searchByQR(String qrData) async {
    setState(() => _isSearching = true);

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(qrData)
          .get();

      Map<String, dynamic>? patientData;
      String? patientId;

      if (userDoc.exists) {
        patientData = userDoc.data() as Map<String, dynamic>?;
        patientId = userDoc.id;
      } else {
        final patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(qrData)
            .get();
        if (patientDoc.exists) {
          patientData = patientDoc.data();
          patientId = patientDoc.id;
        }
      }

      if (patientData == null || patientId == null) {
        _showError('Patient not found.');
        _resetScanState();
        return;
      }

      // CHECK AND GET APPOINTMENT ID
      final String? appointmentId = await widget.checkAppointmentsMethod(
        patientId,
        widget.scheduleId,
      );

      if (appointmentId == null) {
        if (mounted) await _showNoAppointmentDialog(context);
        _resetScanState();
        return;
      }

      // MARK IN CONSULTATION IMMEDIATELY
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'queueStatus': 'in_consultation',
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorPatientProfileScreen(
              patientId: patientId!,
              patientName:
                  patientData?['name'] ?? patientData?['fullName'] ?? 'Patient',
              patientData: patientData ?? {},
              scheduleId: widget.scheduleId,
              appointmentId: appointmentId, // Pass the specific ID
            ),
          ),
        );
        if (widget.onQueueUpdated != null) widget.onQueueUpdated!();
      }
      _resetScanState();
    } catch (e) {
      _showError('Error: $e');
      _resetScanState();
    }
  }

  Future<void> _showNoAppointmentDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text(
          'This patient does not have an appointment for this schedule.',
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

  void _resetScanState() {
    if (mounted) {
      setState(() {
        _isSearching = false;
        _hasScanned = false;
        _lastScannedData = null;
      });
      _qrController.clear();
      if (_isCameraActive) _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: cameraController,
                    onDetect: _handleBarcode,
                    fit: BoxFit.cover,
                  ),
                  if (_isSearching)
                    const Center(child: CircularProgressIndicator())
                  else
                    CustomPaint(
                      painter: ScannerOverlayPainter(),
                      child: Container(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
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
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    _qrController.dispose();
    super.dispose();
  }
}

// =========================================================
// PHONE NUMBER TAB - UPDATED TO USE APPOINTMENT ID
// =========================================================
class PhoneNumberTab extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String scheduleId;
  final String appointmentType;
  // Updated Signature
  final Future<String?> Function(String, String) checkAppointmentsMethod;
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

  Future<void> _searchByMobile() async {
    final mobileNumber = _mobileController.text.trim();
    if (mobileNumber.isEmpty) {
      _showError('Please enter mobile number');
      return;
    }

    setState(() => _isSearching = true);

    try {
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

      if (patientData == null || patientId == null) {
        _showError('Patient not found.');
        setState(() => _isSearching = false);
        return;
      }

      // CHECK AND GET APPOINTMENT ID
      final String? appointmentId = await widget.checkAppointmentsMethod(
        patientId,
        widget.scheduleId,
      );

      if (appointmentId == null) {
        _showError('No appointment found for this schedule');
        setState(() => _isSearching = false);
        return;
      }

      // MARK IN CONSULTATION
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'queueStatus': 'in_consultation',
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorPatientProfileScreen(
              patientId: patientId!,
              patientName: patientData?['name'] ?? 'Patient',
              patientData: patientData ?? {},
              scheduleId: widget.scheduleId,
              appointmentId: appointmentId, // Pass the specific ID
            ),
          ),
        );
        if (widget.onQueueUpdated != null) widget.onQueueUpdated!();
      }

      setState(() => _isSearching = false);
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _mobileController,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _searchByMobile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
              ),
              child: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text('Search'),
            ),
          ),
          const SizedBox(height: 20),
          const HelpText('Enter the patient\'s registered mobile number.'),
          const HelpText('System will find the appointment for this schedule.'),
        ],
      ),
    );
  }
}

// =========================================================
// HELPERS
// =========================================================
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
            ),
          ),
        ],
      ),
    );
  }
}

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
