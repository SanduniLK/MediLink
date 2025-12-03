import 'dart:async';

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
  State<DoctorUnifiedSearchScreen> createState() => _DoctorUnifiedSearchScreenState();
}

class _DoctorUnifiedSearchScreenState extends State<DoctorUnifiedSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showQueueProgress = false;
  List<Map<String, dynamic>> _queueAppointments = [];
  List<Map<String, dynamic>> _completedAppointments = [];
  int _totalQueuePatients = 0;
  int _completedPatients = 0;
  bool _isLoadingQueue = false;
  StreamSubscription? _queueSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
    _setupQueueStream();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ADD THIS METHOD: Toggle queue visibility
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
        
        if (data['status'] == 'completed') {
          completed.add(appointment);
        } else if (data['status'] == 'confirmed') {
          appointments.add(appointment);
        }
      }
    }
    
    // Sort by token number
    appointments.sort((a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int));
    completed.sort((a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int));
    
    if (mounted) {
      setState(() {
        _queueAppointments = appointments;
        _completedAppointments = completed;
        _totalQueuePatients = appointments.length + completed.length;
        _completedPatients = completed.length;
        _isLoadingQueue = false;
      });
    }
  }

  Widget _buildQueueProgress() {
    if (_isLoadingQueue && _queueAppointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF18A3B6),
          ),
        ),
      );
    }

    // Calculate progress correctly
    final totalForToday = _queueAppointments.length + _completedAppointments.length;
    final progress = totalForToday > 0 
        ? _completedAppointments.length / totalForToday 
        : 0.0;
    
    // Find current appointment (in_consultation)
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
                  Text(
                    'Consultation Queue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF18A3B6),
                    ),
                  ),
                  Text(
                    'Schedule: ${widget.scheduleId.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
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
          
          // Progress Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18A3B6).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF18A3B6).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // Progress Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROGRESS',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_completedAppointments.length}/$totalForToday',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18A3B6),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18A3B6),
                          ),
                        ),
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Progress Bar
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      // Background
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      
                      // Progress
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: MediaQuery.of(context).size.width * progress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF18A3B6),
                              Color(0xFF32BACD),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info,
                  color: Color(0xFF18A3B6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentAppointment.isNotEmpty
                            ? 'Consulting: ${currentAppointment['patientName']} (#${currentAppointment['tokenNumber']})'
                            : 'Next Patient: ${_queueAppointments.isNotEmpty ? _queueAppointments.first['patientName'] : "None"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_queueAppointments.length} patients waiting • ${_completedAppointments.length} completed',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
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
            
            // Patient List
            ..._queueAppointments.take(5).map((appointment) {
              final isCurrent = appointment['queueStatus'] == 'in_consultation';
              final isNext = _queueAppointments.indexOf(appointment) == 0 && !isCurrent;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF18A3B6).withOpacity(0.1) : 
                          isNext ? Colors.orange.withOpacity(0.05) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? const Color(0xFF18A3B6) : 
                            isNext ? Colors.orange : Colors.grey[200]!,
                    width: isCurrent ? 1.5 : isNext ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF18A3B6) : 
                                isNext ? Colors.orange : Colors.grey[400]!,
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
                              color: isCurrent ? const Color(0xFF18A3B6) : 
                                      isNext ? Colors.orange[800] : Colors.grey[800]!,
                            ),
                          ),
                          Text(
                            'Status: ${appointment['queueStatus']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrent ? Colors.blue[600] : 
                                      isNext ? Colors.orange[600] : Colors.grey[600]!,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'IN PROGRESS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isNext)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NEXT',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
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
          ] else if (_completedAppointments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All consultations completed! ${_completedAppointments.length} patients seen.',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No patients in queue for this schedule',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Status Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(Colors.green, 'In Progress'),
                _buildLegendItem(const Color(0xFF18A3B6), 'Current'),
                _buildLegendItem(Colors.orange, 'Next'),
                _buildLegendItem(Colors.grey, 'Waiting'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[700],
          ),
        ),
      ],
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
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.phone), text: 'Phone'),
          ],
        ),
        actions: [
          // Queue Status Badge
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _toggleQueueProgress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      '${_completedAppointments.length}/${_queueAppointments.length + _completedAppointments.length}',
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
          // Always show queue status at top
          if (!_showQueueProgress)
            GestureDetector(
              onTap: _toggleQueueProgress,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF18A3B6).withOpacity(0.05),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people,
                      color: Color(0xFF18A3B6),
                    ),
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
                                : '${_completedAppointments.length} completed • ${_queueAppointments.length} waiting',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF18A3B6),
                    ),
                  ],
                ),
              ),
            ),
          
          // Queue Progress Section (toggleable)
          if (_showQueueProgress)
            Expanded(
              child: SingleChildScrollView(
                child: _buildQueueProgress(),
              ),
            ),
          
          // Tab Content (only show when queue is collapsed)
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
                    onQueueUpdated: () {
                      // This will be called when queue needs refresh
                      _setupQueueStream();
                    },
                  ),
                  PhoneNumberTab(
                    doctorId: widget.doctorId,
                    doctorName: widget.doctorName,
                    scheduleId: widget.scheduleId,
                    appointmentType: widget.appointmentType,
                    checkAppointmentsMethod: _checkIfPatientHasAppointments,
                    currentAppointmentId: widget.currentAppointmentId,
                    onQueueUpdated: () {
                      // This will be called when queue needs refresh
                      _setupQueueStream();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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

  // ... rest of your existing methods (QRCodeTab and PhoneNumberTab classes should be below)
}
  


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
   this.onQueueUpdated
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
    final hasAppointments = await widget.checkAppointmentsMethod(patientId, widget.scheduleId);

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (!hasAppointments) {
      debugPrint('❌ Patient ${patientData['name']} has no appointment for schedule ${widget.scheduleId}');
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
            patientName: patientData?['name'] ?? patientData?['fullName'] ?? 'Patient',
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
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
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
          patientData = querySnapshot.docs.first.data() as Map<String, dynamic>?;
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
      final hasAppointments = await widget.checkAppointmentsMethod(patientId, widget.scheduleId);

      if (!hasAppointments) {
        debugPrint('❌ Patient ${patientData['name']} has no appointment for schedule ${widget.scheduleId}');
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
              patientName: patientData?['name'] ?? patientData?['fullName'] ?? 'Patient',
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
            Text('No Appointment Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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