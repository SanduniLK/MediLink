// screens/patient_telemedicine_screen.dart - FIXED
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/incoming_call_screen.dart';
import 'package:socket_io_client/socket_io_client.dart'; // Keep this import

class PatientTelemedicineScreen extends StatefulWidget {
  const PatientTelemedicineScreen({super.key});

  @override
  State<PatientTelemedicineScreen> createState() => _PatientTelemedicineScreenState();
}

class _PatientTelemedicineScreenState extends State<PatientTelemedicineScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VideoCallService _videoCallService = VideoCallService();
  String? _patientName;
  String? _patientId;
  bool _isPatientRoomJoined = false;

  @override
  void initState() {
    super.initState();
    _getPatientInfo();
  }

  void _getPatientInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _patientId = user.uid;
      });
      
      // Get patient name from patients collection
      try {
        final patientDoc = await _firestore.collection('patients').doc(user.uid).get();
        if (patientDoc.exists) {
          final data = patientDoc.data();
          setState(() {
            _patientName = data?['fullName'] ?? data?['name'] ?? user.displayName ?? 'Patient';
          });
          debugPrint('🟢 PATIENT: Found in patients collection: $_patientName');
        } else {
          setState(() {
            _patientName = user.displayName ?? 'Patient';
          });
          debugPrint('🟡 PATIENT: Using user profile name: $_patientName');
        }
      } catch (e) {
        setState(() {
          _patientName = user.displayName ?? 'Patient';
        });
        debugPrint('🔴 PATIENT: Error fetching patient info: $e');
      }

      // Setup call listener after getting patient info
      _setupCallListener();
    }
  }

  void _setupCallListener() async {
    debugPrint('🎧 PATIENT: Setting up call listener...');
    
    try {
      // Initialize service first
      await _videoCallService.initialize();
      debugPrint('🟢 PATIENT: VideoCallService initialized');

      // Set up event listeners
      _videoCallService.onConnected = () {
        debugPrint('🟢 PATIENT: Connected to signaling server');
        if (mounted) {
          _joinPatientRoom();
        }
      };

      _videoCallService.onDisconnected = () {
        debugPrint('🔴 PATIENT: Disconnected from signaling server');
        if (mounted) {
          setState(() {
            _isPatientRoomJoined = false;
          });
        }
      };

      _videoCallService.onError = (error) {
        debugPrint('🔴 PATIENT: Error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection error: $error'), backgroundColor: Colors.red),
          );
        }
      };

      // ✅ FIXED: Add the incoming call handler
      _videoCallService.onIncomingCall = (callData) {
        final consultationType = callData['consultationType'] ?? 'video';
        final roomId = callData['roomId'] ?? '';
        final doctorName = callData['doctorName'] ?? 'Doctor';
        final doctorId = callData['doctorId'] ?? '';

        debugPrint('🎉 PATIENT: INCOMING CALL RECEIVED!');
        debugPrint('   - Doctor: $doctorName');
        debugPrint('   - Room ID: $roomId');
        debugPrint('   - Doctor ID: $doctorId');
        debugPrint('   - Consultation Type: $consultationType');

        if (mounted) {
          // Show incoming call screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                callId: roomId,
                doctorName: doctorName,
                doctorId: doctorId,
                patientId: _patientId!,
                patientName: _patientName!,
                consultationType: consultationType,
              ),
            ),
          );
        }
      };

      // ✅ FIXED: Use the public socket getter instead of private _socket
      _videoCallService.socket.onConnect((_) {
        debugPrint('🟢 PATIENT: Socket connected - ready for calls');
      });

      _videoCallService.socket.onDisconnect((_) {
        debugPrint('🔴 PATIENT: Socket disconnected');
      });

    } catch (e) {
      debugPrint('🔴 PATIENT: Error initializing call listener: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize call service'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _joinPatientRoom() async {
    if (_patientId == null || _patientName == null) {
      debugPrint('🔴 PATIENT: Cannot join room - missing patient info');
      return;
    }

    try {
      await _videoCallService.joinPatientRoom(_patientId!);
      if (mounted) {
        setState(() {
          _isPatientRoomJoined = true;
        });
      }
      debugPrint('🟢 PATIENT: Successfully joined patient room');
    } catch (e) {
      debugPrint('🔴 PATIENT: Error joining patient room: $e');
      if (mounted) {
        setState(() {
          _isPatientRoomJoined = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Telemedicine Appointments'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          // Connection status indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: _getConnectionStatusColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getConnectionStatusText(),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Panel
          _buildConnectionStatusPanel(),
          Expanded(
            child: _buildAppointmentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connection Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(_getConnectionStatusIcon(), size: 16, color: _getConnectionStatusColor()),
              SizedBox(width: 8),
              Expanded(child: Text(_getConnectionStatusText())),
            ],
          ),
          SizedBox(height: 4),
          Text('Patient: $_patientName', style: TextStyle(fontSize: 12)),
          Text('ID: ${_patientId ?? 'Unknown'}', style: TextStyle(fontSize: 10, color: Colors.grey)),
          SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _testConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Test Connection'),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _reconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Reconnect'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_patientId == null) {
      return Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('telemedicine_sessions')
          .where('patientId', isEqualTo: _patientId)
          .where('status', whereIn: ['Scheduled', 'confirmed', 'In-Progress'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final sessions = snapshot.data?.docs ?? [];
        debugPrint('📋 PATIENT: Found ${sessions.length} sessions');

        if (sessions.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final sessionDoc = sessions[index];
            final sessionData = sessionDoc.data() as Map<String, dynamic>;
            return _buildAppointmentCard(sessionDoc.id, sessionData);
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(String sessionId, Map<String, dynamic> sessionData) {
    final doctorName = sessionData['doctorName'] ?? 'Doctor';
    final date = sessionData['date'] ?? '';
    final timeSlot = sessionData['timeSlot'] ?? '';
    final status = sessionData['status'] ?? 'Scheduled';
    final tokenNumber = sessionData['tokenNumber'] ?? '';
    final doctorSpecialty = sessionData['doctorSpecialty'] ?? '';
    final consultationType = sessionData['consultationType'] ?? 'video';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. $doctorName',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      doctorSpecialty.isNotEmpty ? doctorSpecialty : 'Doctor',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('Date: $date'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('Time: $timeSlot'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(consultationType == 'video' ? Icons.videocam : Icons.call, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(consultationType == 'video' ? 'Video Consultation' : 'Audio Consultation'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.confirmation_number, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('Token: #$tokenNumber'),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _joinConsultation(sessionId, sessionData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(status),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_getButtonText(status, consultationType)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _joinConsultation(String sessionId, Map<String, dynamic> sessionData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doctorName = sessionData['doctorName'] ?? 'Doctor';
    final consultationType = sessionData['consultationType'] ?? 'video';

    debugPrint('🎬 PATIENT: Manually joining consultation');
    debugPrint('   - Session ID: $sessionId');
    debugPrint('   - Doctor: $doctorName');
    debugPrint('   - Patient: $_patientName');
    debugPrint('   - Type: $consultationType');

    // Navigate to appropriate call screen as PATIENT
    if (consultationType == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            callId: sessionId,
            otherUserName: doctorName,
            otherUserId: sessionData['doctorId'] ?? '',
            currentUserId: user.uid,
            currentUserName: _patientName!,
            isDoctor: false,
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
            otherUserName: doctorName,
            otherUserId: sessionData['doctorId'] ?? '',
            currentUserId: user.uid,
            currentUserName: _patientName!,
            isDoctor: false,
            isIncomingCall: false,
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Telemedicine Appointments',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Your scheduled video consultations will appear here',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _testConnection,
            child: Text('Check Connection Status'),
          ),
        ],
      ),
    );
  }

  void _testConnection() {
    debugPrint('🧪 PATIENT: Testing connection...');
    debugPrint('   - Socket connected: ${_videoCallService.isConnected}');
    debugPrint('   - Current room: ${_videoCallService.currentRoomId}');
    debugPrint('   - User ID: ${_videoCallService.userId}');
    debugPrint('   - User Name: ${_videoCallService.userName}');
    debugPrint('   - Patient room joined: $_isPatientRoomJoined');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPatientRoomJoined 
            ? '✅ Ready for incoming calls' 
            : '🟡 Connecting to server...'),
        backgroundColor: _isPatientRoomJoined ? Colors.green : Colors.orange,
      ),
    );
  }

  void _reconnect() {
    setState(() {
      _isPatientRoomJoined = false;
    });
    _setupCallListener();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reconnecting...'), backgroundColor: Colors.blue),
    );
  }

  IconData _getConnectionStatusIcon() {
    if (_isPatientRoomJoined) return Icons.check_circle;
    if (_videoCallService.isConnected) return Icons.sync;
    return Icons.error;
  }

  Color _getConnectionStatusColor() {
    if (_isPatientRoomJoined) return Colors.green;
    if (_videoCallService.isConnected) return Colors.orange;
    return Colors.red;
  }

  String _getConnectionStatusText() {
    if (_isPatientRoomJoined) return '🟢 Ready for calls';
    if (_videoCallService.isConnected) return '🟡 Connected, joining room...';
    return '🔴 Disconnected';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled': return Colors.blue;
      case 'confirmed': return Colors.orange;
      case 'in-progress': return Colors.green;
      default: return Colors.blue;
    }
  }

  Color _getButtonColor(String status) {
    if (status.toLowerCase() != 'scheduled' && status.toLowerCase() != 'confirmed') {
      return Colors.grey;
    }
    return Color(0xFF18A3B6);
  }

  String _getButtonText(String status, String consultationType) {
    if (status.toLowerCase() != 'scheduled' && status.toLowerCase() != 'confirmed') {
      return 'Join ${consultationType == 'video' ? 'Video' : 'Audio'} Call';
    }
    return 'Join Consultation';
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
}