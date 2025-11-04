// screens/patient_telemedicine_screen.dart - COMPLETELY FIXED
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/incoming_call_screen.dart';

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
  bool _isWebRTCConnected = false;
  final bool _isPhysicalDevice = true; // ✅ MADE FINAL

  @override
  void initState() {
    super.initState();
    _getPatientInfo().then((_) {
      if (_patientId != null) {
        _setupCallListener();
      }
    });
  }

  Future<void> _getPatientInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _patientId = user.uid;
        _patientName = user.displayName ?? user.email?.split('@').first ?? 'Patient';
      });
    }
  }

  void _setupCallListener() async {
    try {
      await _videoCallService.initialize(isPhysicalDevice: _isPhysicalDevice);
      
      // Setup incoming call listener
      _videoCallService.onIncomingCall = (callData) {
        debugPrint('📞 PATIENT: Incoming call received');
        
        final roomId = callData['roomId'] ?? '';
        final doctorName = callData['doctorName'] ?? 'Doctor';
        final doctorId = callData['doctorId'] ?? '';
        
        // ✅ FIXED: Handle both 'callType' and 'consultationType'
        final callType = callData['callType'] ?? callData['consultationType'] ?? 'video';

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                callId: roomId,
                doctorName: doctorName,
                doctorId: doctorId,
                patientId: _patientId!,
                patientName: _patientName!,
                callType: callType, // ✅ ADDED REQUIRED PARAMETER
              ),
            ),
          );
        }
      };

      _videoCallService.onConnected = () {
        if (mounted) {
          setState(() {
            _isWebRTCConnected = true;
          });
        }
      };

      // Join patient room to listen for calls
      if (_patientId != null) {
        await _videoCallService.joinPatientRoom(_patientId!);
      }

    } catch (e) {
      debugPrint('❌ Error setting up call listener: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup call service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleIncomingCall(Map<String, dynamic> callData) {
    final roomId = callData['roomId'] ?? '';
    final doctorName = callData['doctorName'] ?? 'Doctor';
    final doctorId = callData['doctorId'] ?? '';
    final callType = callData['callType'] ?? callData['consultationType'] ?? 'video';

    debugPrint('🎉 PATIENT: Handling incoming call navigation');

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            callId: roomId,
            doctorName: doctorName,
            doctorId: doctorId,
            patientId: _patientId!,
            patientName: _patientName!,
            callType: callType, // ✅ ADDED REQUIRED PARAMETER
          ),
        ),
      );
    }
  }

  void _testWebRTCConnection() async {
    await _videoCallService.testWebRTCConnection();
  }

  void _forceJoinRoom() async {
    if (_patientId == null || _patientName == null) {
      debugPrint('🔴 PATIENT: Cannot join room - missing patient info');
      return;
    }

    try {
      debugPrint('🔄 PATIENT: Manually joining patient room...');
      await _videoCallService.joinPatientRoom(_patientId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined patient room - Ready for calls!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ PATIENT: Error manually joining patient room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining room: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          Text('WebRTC Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _isWebRTCConnected ? Icons.check_circle : Icons.sync,
                color: _isWebRTCConnected ? Colors.green : Colors.orange,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                _isWebRTCConnected ? '🟢 Ready for video calls' : '🟡 Connecting to WebRTC...',
                style: TextStyle(
                  color: _isWebRTCConnected ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text('Server: 192.168.1.126:5001', style: TextStyle(fontSize: 12)),
          Text('Device: Physical', style: TextStyle(fontSize: 12)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testWebRTCConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('Test Connection'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _forceJoinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('Join Room'),
                ),
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
    final doctorId = sessionData['doctorId'] ?? '';
    final consultationType = sessionData['consultationType'] ?? 'video';

    final patientName = _patientName ?? user.displayName ?? 'Patient';
    final patientId = _patientId ?? user.uid;

    debugPrint('🎬 PATIENT: Joining consultation as ANSWERER');

    // ✅ FIXED: Validate required fields with mounted checks
    if (patientId.isEmpty) {
      debugPrint('❌ PATIENT: Cannot join - patient ID is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot join call: Patient ID missing'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      if (!_videoCallService.isConnected) {
        debugPrint('🟡 PATIENT: Call service not connected, initializing...');
        await _videoCallService.initialize();
      }

      await _videoCallService.joinRoom(
        sessionId, 
        patientId,
        patientName,
        false // isDoctor = false
      );

      debugPrint('✅ PATIENT: Joined room $sessionId as answerer');

      if (mounted) {
        if (consultationType == 'video') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                callId: sessionId,
                otherUserName: doctorName,
                otherUserId: doctorId,
                currentUserId: patientId,
                currentUserName: patientName,
                isDoctor: false,
                isIncomingCall: false,
                isVideoCall: true,
                shouldInitiateCall: false,
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
                otherUserId: doctorId,
                currentUserId: patientId,
                currentUserName: patientName,
                isDoctor: false,
                isIncomingCall: false,
                shouldInitiateCall: false,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ PATIENT: Error joining consultation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isWebRTCConnected 
              ? '✅ Ready for incoming calls' 
              : '🟡 Connecting to server...'),
          backgroundColor: _isWebRTCConnected ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Color _getConnectionStatusColor() {
    if (_isWebRTCConnected) return Colors.green;
    return Colors.orange;
  }

  String _getConnectionStatusText() {
    if (_isWebRTCConnected) return '🟢 Ready for calls';
    return '🟡 Connecting...';
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