// screens/patient_telemedicine_screen.dart - FIXED VERSION
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
      await _videoCallService.initialize();
      
      // Setup incoming call listener
      _videoCallService.onIncomingCall = (callData) {
        debugPrint('📞 PATIENT: Incoming call received');
        
        final roomId = callData['roomId'] ?? '';
        final doctorName = callData['doctorName'] ?? 'Doctor';
        final doctorId = callData['doctorId'] ?? '';
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
                callType: callType,
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

    } catch (e) {
      debugPrint('❌ Error setting up call listener: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Telemedicine'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_patientId == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Connection Status
        Container(
          padding: EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Row(
            children: [
              Icon(
                _isWebRTCConnected ? Icons.check_circle : Icons.sync,
                color: _isWebRTCConnected ? Colors.green : Colors.orange,
              ),
              SizedBox(width: 8),
              Text(
                _isWebRTCConnected ? '🟢 Ready for calls' : '🟡 Connecting...',
                style: TextStyle(
                  color: _isWebRTCConnected ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildAppointmentsList(),
        ),
      ],
    );
  }

  Widget _buildAppointmentsList() {
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
    final consultationType = sessionData['consultationType'] ?? 'video';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dr. $doctorName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Date: $date'),
            Text('Time: $timeSlot'),
            Text('Type: ${consultationType == 'video' ? 'Video Call' : 'Audio Call'}'),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _joinConsultation(sessionId, sessionData),
              child: Text('Join Consultation'),
            ),
          ],
        ),
      ),
    );
  }

  void _joinConsultation(String sessionId, Map<String, dynamic> sessionData) async {
    try {
      final doctorName = sessionData['doctorName'] ?? 'Doctor';
      final doctorId = sessionData['doctorId'] ?? '';
      final consultationType = sessionData['consultationType'] ?? 'video';

      await _videoCallService.joinRoom(
        sessionId, 
        _patientId!,
        _patientName!,
        false // isDoctor = false
      );

      if (mounted) {
        if (consultationType == 'video') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                callId: sessionId,
                otherUserName: doctorName,
                otherUserId: doctorId,
                currentUserId: _patientId!,
                currentUserName: _patientName!,
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
                currentUserId: _patientId!,
                currentUserName: _patientName!,
                isDoctor: false,
                isIncomingCall: false,
                shouldInitiateCall: false,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error joining consultation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining call: $e')),
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
          Text('No Telemedicine Appointments'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
}