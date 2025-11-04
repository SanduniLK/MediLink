import 'dart:io'; // ✅ ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';

class TelemedicineAppointmentsScreen extends StatefulWidget {
  const TelemedicineAppointmentsScreen({super.key});

  @override
  State<TelemedicineAppointmentsScreen> createState() =>
      _TelemedicineAppointmentsScreenState();
}

class _TelemedicineAppointmentsScreenState
    extends State<TelemedicineAppointmentsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VideoCallService _videoCallService = VideoCallService(); 
  String? _doctorId;
  String? _doctorName;
  bool _isCallServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _getDoctorInfo();
    _initializeCallService();
  }

  Future<void> _initializeCallService() async {
    try {
      debugPrint('🔄 Initializing call service...');
      await _videoCallService.initialize();
      setState(() {
        _isCallServiceInitialized = true;
      });
      debugPrint('✅ Call service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize call service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call service error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getDoctorInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doctorDoc = await _firestore.collection('doctors').doc(user.uid).get();
      if (doctorDoc.exists) {
        final data = doctorDoc.data()!;
        setState(() {
          _doctorId = user.uid;
          _doctorName = data['fullName'] ?? data['name'] ?? 'Doctor';
        });
      } else {
        setState(() {
          _doctorId = user.uid;
          _doctorName = user.displayName ?? 'Doctor';
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching doctor info: $e');
    }
  }

  // ✅ ADD THIS MISSING METHOD
  Future<bool> _checkServerStatus() async {
    try {
      debugPrint('🔍 Checking if server is running at 192.168.1.126:5001...');
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      final request = await client.getUrl(Uri.parse('http://192.168.1.126:5001/health'));
      final response = await request.close();
      
      final isRunning = response.statusCode == 200;
      debugPrint(isRunning ? '✅ Server is running!' : '❌ Server returned status: ${response.statusCode}');
      
      return isRunning;
    } catch (e) {
      debugPrint('❌ Server is NOT reachable: $e');
      return false;
    }
  }

  // ✅ ADD TEST METHOD
  void _testServerConnection() async {
    final isRunning = await _checkServerStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRunning ? '✅ Server is running!' : '❌ Server is NOT running'),
          backgroundColor: isRunning ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_doctorId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        title: Text(
          _doctorName == null
              ? 'Loading...'
              : 'Dr. $_doctorName - Telemedicine Sessions',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: _isCallServiceInitialized ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isCallServiceInitialized ? Icons.check_circle : Icons.sync,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isCallServiceInitialized ? 'Ready' : 'Connecting',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // ✅ ADD TEST BUTTON
          IconButton(
            icon: const Icon(Icons.wifi_find, color: Colors.white),
            onPressed: _testServerConnection,
            tooltip: 'Test Server Connection',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isCallServiceInitialized)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Initializing call service...',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('telemedicine_sessions')
                  .where('doctorId', isEqualTo: _doctorId)
                  .where('status', whereIn: ['Scheduled', 'confirmed', 'In-Progress'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data?.docs ?? [];
                if (sessions.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final sessionDoc = sessions[index];
                    final data = sessionDoc.data() as Map<String, dynamic>;
                    return _buildSessionCard(sessionDoc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // ✅ ADD FLOATING ACTION BUTTON FOR TESTING
      floatingActionButton: FloatingActionButton(
        onPressed: _testServerConnection,
        backgroundColor: const Color(0xFF18A3B6),
        child: const Icon(Icons.wifi, color: Colors.white),
      ),
    );
  }

  Widget _buildSessionCard(String sessionId, Map<String, dynamic> data) {
    final patientName = data['patientName'] ?? 'Patient';
    final date = data['date'] ?? '';
    final timeSlot = data['timeSlot'] ?? '';
    final status = data['status'] ?? 'Scheduled';
    final tokenNumber = data['tokenNumber'] ?? '';
    final consultationType = data['consultationType'] ?? 'video';
    final isVideoCall = consultationType == 'video';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Token: #$tokenNumber',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Date: $date'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Time: $timeSlot'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isVideoCall ? Icons.videocam : Icons.call,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(isVideoCall ? 'Video Consultation' : 'Audio Consultation'),
              ],
            ),
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              icon: Icon(
                isVideoCall ? Icons.video_call : Icons.call,
                color: Colors.white,
              ),
              label: Text(
                status == 'In-Progress'
                    ? 'Join ${isVideoCall ? 'Video' : 'Audio'} Call'
                    : 'Start ${isVideoCall ? 'Video' : 'Audio'} Consultation',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCallServiceInitialized 
                    ? _getButtonColor(status) 
                    : Colors.grey,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _isCallServiceInitialized
                  ? () => _startConsultation(sessionId, data)
                  : null,
            ),
            
            if (status == 'In-Progress') ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.medical_services, color: Colors.white),
                label: const Text('Write Prescription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => _writePrescription(sessionId, data),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startConsultation(String sessionId, Map<String, dynamic> data) async {
    // ✅ CHECK MOUNTED AT START
    if (!mounted) return;
    
    if (!_isCallServiceInitialized) {
      debugPrint('❌ Call service not ready yet');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call service is still initializing. Please wait...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // ✅ CHECK SERVER STATUS FIRST
      final isServerRunning = await _checkServerStatus();
      if (!isServerRunning) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call server is not running. Please start the server first.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final patientId = data['patientId'] ?? '';
      final patientName = data['patientName'] ?? 'Patient';
      final doctorName = _doctorName ?? 'Doctor';
      final consultationType = data['consultationType'] ?? 'video';
      final isVideoCall = consultationType == 'video';

      debugPrint('🎯 Starting $consultationType consultation with $patientName');

      // Update session to In-Progress
      if (data['status'] == 'Scheduled' || data['status'] == 'confirmed') {
        await _firestore.collection('telemedicine_sessions').doc(sessionId).update({
          'status': 'In-Progress',
          'startedAt': FieldValue.serverTimestamp(),
        });
      }

      // ✅ ADD MOUNTED CHECK BEFORE NETWORK OPERATIONS
      if (!mounted) return;

      // Join room as doctor
      await _videoCallService.joinRoom(
        sessionId, 
        _doctorId!,
        doctorName,
        true
      );

      // ✅ ADD MOUNTED CHECK
      if (!mounted) return;

      // Notify patient
      await _videoCallService.notifyPatientCallStarted(
        patientId, 
        sessionId, 
        doctorName,
        consultationType: consultationType
      );

      debugPrint('✅ Doctor started $consultationType call and notified patient $patientName');

      // ✅ FINAL MOUNTED CHECK BEFORE NAVIGATION
      if (!mounted) return;

      // Navigate to appropriate call screen
      if (isVideoCall) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              callId: sessionId,
              otherUserName: patientName,
              otherUserId: patientId,
              currentUserId: _doctorId!,
              currentUserName: _doctorName!,
              isDoctor: true,
              isIncomingCall: false,
              isVideoCall: true, 
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AudioCallScreen(
              callId: sessionId,
              otherUserName: patientName,
              otherUserId: patientId,
              currentUserId: _doctorId!,
              currentUserName: _doctorName!,
              isDoctor: true,
              isIncomingCall: false,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error starting consultation: $e');
      // ✅ CHECK MOUNTED BEFORE SHOWING SNACKBAR
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _writePrescription(String sessionId, Map<String, dynamic> data) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionScreen(),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error navigating to prescription screen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening prescription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No Telemedicine Sessions Found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your scheduled telemedicine sessions will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (!_isCallServiceInitialized)
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              onPressed: _initializeCallService,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'in-progress':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getButtonColor(String status) {
    if (status.toLowerCase() == 'in-progress') return Colors.green;
    return const Color(0xFF18A3B6);
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
}