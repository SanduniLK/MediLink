// telemedicine/incoming_call_screen.dart - FIXED
import 'package:flutter/material.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String doctorName;
  final String doctorId;
  final String patientId; // ✅ ADD THIS
  final String patientName; // ✅ ADD THIS
  final String consultationType;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.doctorName,
    required this.doctorId,
    required this.patientId, // ✅ ADD THIS
    required this.patientName, // ✅ ADD THIS
    this.consultationType = 'video',
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final VideoCallService _videoCallService = VideoCallService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎯 INCOMING CALL SCREEN: Doctor ${widget.doctorName} is calling');
    debugPrint('🎯 INCOMING CALL SCREEN: Room ID: ${widget.callId}');
    debugPrint('🎯 INCOMING CALL SCREEN: Patient: ${widget.patientName} (${widget.patientId})');
      debugPrint('🎯 INCOMING CALL SCREEN: Type: ${widget.consultationType}');
    _initializeService();
  }

  void _initializeService() async {
    try {
      await _videoCallService.initialize();
      await _videoCallService.joinRoom(
        widget.callId, 
        widget.patientId, // ✅ Use actual patient ID
        widget.patientName, // ✅ Use actual patient name
        false
      );
      setState(() {
        _isInitialized = true;
      });
      debugPrint('🟢 INCOMING CALL: Joined room ${widget.callId} as ${widget.patientName}');
    } catch (e) {
      debugPrint('🔴 INCOMING CALL: Error initializing: $e');
    }
  }

  void _acceptCall() {
    if (!_isInitialized) {
      debugPrint('🟡 INCOMING CALL: Service not ready yet');
      return;
    }

    debugPrint('✅ PATIENT: Accepting call from Dr. ${widget.doctorName}');
    final isVideoCall = widget.consultationType == 'video';
  if (isVideoCall) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            callId: widget.callId,
            otherUserName: widget.doctorName,
            otherUserId: widget.doctorId,
            currentUserId: widget.patientId,
            currentUserName: widget.patientName,
            isDoctor: false,
            isIncomingCall: true,
            isVideoCall: true, // ✅ FIXED: Add missing parameter
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AudioCallScreen(
            callId: widget.callId,
            otherUserName: widget.doctorName,
            otherUserId: widget.doctorId,
            currentUserId: widget.patientId,
            currentUserName: widget.patientName,
            isDoctor: false,
            isIncomingCall: true,
          ),
        ),
      );
    }
  }

  

  void _rejectCall() {
    debugPrint('❌ PATIENT: Rejecting call from Dr. ${widget.doctorName}');
    _videoCallService.endCall();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.consultationType == 'video';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Doctor Avatar
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideoCall ? Icons.videocam : Icons.call,
                size: 80,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 30),
            Text(
               'Incoming ${isVideoCall ? 'Video' : 'Audio'} Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Dr. ${widget.doctorName}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Room: ${widget.callId}',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            if (!_isInitialized) ...[
              SizedBox(height: 10),
              Text(
                'Connecting...',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
            ],
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject Button
                _buildCallButton(
                  icon: Icons.call_end,
                  backgroundColor: Colors.red,
                  onPressed: _rejectCall,
                  text: 'Reject',
                ),
                // Accept Button
                _buildCallButton(
                   icon: isVideoCall ? Icons.videocam : Icons.call,
                  backgroundColor: _isInitialized ? Colors.green : Colors.grey,
                  onPressed: _isInitialized ? _acceptCall : null,
                  text: 'Accept',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback? onPressed,
    required String text,
  }) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
}