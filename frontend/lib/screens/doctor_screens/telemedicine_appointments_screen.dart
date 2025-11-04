import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';

class TelemedicineAppointmentsScreen extends StatefulWidget {
  const TelemedicineAppointmentsScreen({super.key});

  @override
  State<TelemedicineAppointmentsScreen> createState() => _TelemedicineAppointmentsScreenState();
}

class _TelemedicineAppointmentsScreenState extends State<TelemedicineAppointmentsScreen> {
  final VideoCallService _videoCallService = VideoCallService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _doctorId;
  String? _doctorName;
  bool _isCallServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _getDoctorInfo();
    _initializeCallService();
  }

  // ✅ FIXED: Added missing _getDoctorInfo method
  Future<void> _getDoctorInfo() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _doctorId = user.uid;
          _doctorName = user.displayName ?? user.email?.split('@').first ?? 'Doctor';
        });
        debugPrint('✅ Doctor info loaded: $_doctorName ($_doctorId)');
      }
    } catch (e) {
      debugPrint('❌ Error getting doctor info: $e');
    }
  }

  Future<void> _initializeCallService() async {
    try {
      await _videoCallService.initialize();
      setState(() {
        _isCallServiceInitialized = true;
      });
      debugPrint('✅ Call service initialized');
    } catch (e) {
      debugPrint('❌ Call service error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize call service: $e')),
        );
      }
    }
  }

  // ✅ DOCTOR: START VIDEO CALL - FIXED with proper error handling
  void _startVideoCall(String sessionId, Map<String, dynamic> data) async {
    if (!_isCallServiceInitialized || _doctorId == null || _doctorName == null) {
      _showError('Call service not ready. Please wait...');
      return;
    }

    try {
      final patientId = data['patientId'] ?? '';
      final patientName = data['patientName'] ?? 'Patient';

      debugPrint('🎯 DOCTOR: Starting VIDEO call with $patientName');

      // 1. Join room first
      await _videoCallService.joinRoom(
        sessionId, 
        _doctorId!,
        _doctorName!,
        true // isDoctor = true
      );

      // 2. Notify patient using socket event
      _videoCallService.socket.emit('notify-call-started', {
        'patientId': patientId,
        'roomId': sessionId,
        'doctorName': _doctorName!,
        'doctorId': _doctorId!,
        'consultationType': 'video',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 3. Make the call
      await _videoCallService.makeCall(patientId);

      // 4. Navigate to video call screen
      if (mounted) {
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
              shouldInitiateCall: true,
            ),
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ Error starting video call: $e');
      if (mounted) {
        _showError('Failed to start video call: $e');
      }
    }
  }

  // ✅ DOCTOR: START AUDIO CALL - FIXED with proper error handling
  void _startAudioCall(String sessionId, Map<String, dynamic> data) async {
    if (!_isCallServiceInitialized || _doctorId == null || _doctorName == null) {
      _showError('Call service not ready. Please wait...');
      return;
    }

    try {
      final patientId = data['patientId'] ?? '';
      final patientName = data['patientName'] ?? 'Patient';

      debugPrint('🎯 DOCTOR: Starting AUDIO call with $patientName');

      // 1. Join room first
      await _videoCallService.joinRoom(
        sessionId, 
        _doctorId!,
        _doctorName!,
        true
      );

      // 2. Notify patient using socket event
      _videoCallService.socket.emit('notify-call-started', {
        'patientId': patientId,
        'roomId': sessionId,
        'doctorName': _doctorName!,
        'doctorId': _doctorId!,
        'consultationType': 'audio',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 3. Make the audio call
      await _videoCallService.makeAudioCall(patientId);

      // 4. Navigate to audio call screen
      if (mounted) {
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
              shouldInitiateCall: true,
            ),
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ Error starting audio call: $e');
      if (mounted) {
        _showError('Failed to start audio call: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${_doctorName ?? "Doctor"} - Telemedicine'),
      ),
      body: _buildSessionsList(),
    );
  }

  Widget _buildSessionsList() {
    if (_doctorId == null) {
      return Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('telemedicine_sessions')
          .where('doctorId', isEqualTo: _doctorId)
          .where('status', whereIn: ['Scheduled', 'confirmed'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No telemedicine appointments found'));
        }

        final sessions = snapshot.data!.docs;
        
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final data = session.data() as Map<String, dynamic>;
            
            return Card(
              margin: EdgeInsets.all(8),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${data['patientName'] ?? 'Unknown'}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Token: #${data['tokenNumber'] ?? 'N/A'}'),
                    Text('Date: ${data['date'] ?? 'N/A'}'),
                    Text('Time: ${data['timeSlot'] ?? 'N/A'}'),
                    SizedBox(height: 12),
                    // ✅ DOCTOR CAN START BOTH CALL TYPES
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.videocam),
                            label: Text('Video Call'),
                            onPressed: _isCallServiceInitialized
                                ? () => _startVideoCall(session.id, data)
                                : null,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.call),
                            label: Text('Audio Call'),
                            onPressed: _isCallServiceInitialized
                                ? () => _startAudioCall(session.id, data)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (!_isCallServiceInitialized) ...[
                      SizedBox(height: 8),
                      Text(
                        'Initializing call service...',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
}