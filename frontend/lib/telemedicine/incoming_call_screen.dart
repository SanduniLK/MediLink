// telemedicine/incoming_call_screen.dart - FIXED
import 'package:flutter/material.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String doctorName;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String callType;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.doctorName,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.callType,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final VideoCallService _videoCallService = VideoCallService();

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() async {
    try {
      await _videoCallService.initialize();
    } catch (e) {
      debugPrint('❌ Error initializing incoming call: $e');
    }
  }

  void _answerCall() async {
    try {
      // Join room first
      await _videoCallService.joinRoom(
        widget.callId, 
        widget.patientId,
        widget.patientName,
        false
      );

      // Navigate to call screen
      if (widget.callType == 'video') {
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
              isVideoCall: true,
              shouldInitiateCall: false,
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
              shouldInitiateCall: false,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error answering call: $e');
    }
  }

  void _rejectCall() {
    _videoCallService.endCall();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.callType == 'video';
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blue[800],
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
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Dr. ${widget.doctorName}', style: TextStyle(color: Colors.white70, fontSize: 18)),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: Icons.call_end,
                  backgroundColor: Colors.red,
                  onPressed: _rejectCall,
                  text: 'Reject',
                ),
                _buildCallButton(
                  icon: isVideoCall ? Icons.videocam : Icons.call,
                  backgroundColor: Colors.green,
                  onPressed: _answerCall,
                  text: 'Answer',
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
    required VoidCallback onPressed,
    required String text,
  }) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
          child: IconButton(icon: Icon(icon, color: Colors.white, size: 30), onPressed: onPressed),
        ),
        SizedBox(height: 8),
        Text(text, style: TextStyle(color: Colors.white)),
      ],
    );
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
}