// telemedicine/video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/services/video_call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserName;
  final String otherUserId;
  final String currentUserId; 
  final String currentUserName; 
  final bool isDoctor; 
  final bool isIncomingCall;
  final bool isVideoCall;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.otherUserName,
    required this.otherUserId,
    required this.currentUserId, 
    required this.currentUserName, 
    required this.isDoctor, 
    required this.isVideoCall, 
    this.isIncomingCall = false,
    
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final VideoCallService _videoCallService = VideoCallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isCallConnected = false;
  String _callStatus = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _initializeCall();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initializeCall() async {
    _videoCallService.onLocalStream = (stream) {
      _localRenderer.srcObject = stream;
      setState(() {});
    };

    _videoCallService.onRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {
        _isCallConnected = true;
        _callStatus = 'Connected';
      });
    };

    _videoCallService.onCallEnded = () {
      setState(() {
        _callStatus = 'Call Ended';
      });
      _endCall();
    };

    _videoCallService.onError = (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call Error: $error')),
      );
    };

    await _videoCallService.initialize();
     await _videoCallService.joinRoom(
    widget.callId, 
    widget.currentUserId,
    widget.currentUserName,
    widget.isDoctor
  );

    // Join the room with actual user data
    await _videoCallService.joinRoom(
      widget.callId, 
      widget.currentUserId, // ✅ USE ACTUAL USER ID
      widget.currentUserName, // ✅ USE ACTUAL USER NAME
      widget.isDoctor // ✅ USE ACTUAL ROLE
    );

    if (!widget.isIncomingCall) {
        if (widget.isVideoCall) {
      await _videoCallService.makeCall(widget.otherUserId);
    } else {
      await _videoCallService.makeAudioCall(widget.otherUserId);
    }
  }
  }

  void _endCall() {
    _videoCallService.endCall();
    Navigator.pop(context);
  }

  void _toggleAudio() async {
    final newState = await _videoCallService.toggleAudio();
    setState(() {
      _isAudioMuted = !newState;
    });
  }

  void _toggleVideo() async {
    final newState = await _videoCallService.toggleVideo();
    setState(() {
      _isVideoMuted = !newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video (Full Screen)
            if (_isCallConnected && !_isVideoMuted)
              RTCVideoView(_remoteRenderer)
            else
              _buildNoVideoDisplay(),

            // Local Video (Picture-in-Picture)
            if (!_isVideoMuted)
              Positioned(
                top: 50,
                right: 20,
                width: 120,
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RTCVideoView(_localRenderer),
                  ),
                ),
              ),

            // Call Info
            Positioned(
              top: 50,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _callStatus,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Call Controls
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: _buildCallControls(),
            ),

            // Incoming Call Dialog
            if (widget.isIncomingCall && !_isCallConnected)
              _buildIncomingCallDialog(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVideoDisplay() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 20),
            Text(
              widget.otherUserName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _callStatus,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute Audio
        _buildControlButton(
          icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
          backgroundColor: _isAudioMuted ? Colors.red : Colors.white24,
          onPressed: _toggleAudio,
        ),

        // End Call
        _buildControlButton(
          icon: Icons.call_end,
          backgroundColor: Colors.red,
          iconColor: Colors.white,
          onPressed: _endCall,
          isLarge: true,
        ),

        // Toggle Video
        _buildControlButton(
          icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
          backgroundColor: _isVideoMuted ? Colors.red : Colors.white24,
          onPressed: _toggleVideo,
        ),

        // Switch Camera
        _buildControlButton(
          icon: Icons.cameraswitch,
          backgroundColor: Colors.white24,
          onPressed: _videoCallService.switchCamera,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return Container(
      width: isLarge ? 70 : 56,
      height: isLarge ? 70 : 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: isLarge ? 30 : 24),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildIncomingCallDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 30),
            Text(
              'Incoming Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              widget.otherUserName,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject
                _buildControlButton(
                  icon: Icons.call_end,
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                  onPressed: _endCall,
                  isLarge: true,
                ),

                // Accept
                _buildControlButton(
                  icon: Icons.call,
                  backgroundColor: Colors.green,
                  iconColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _callStatus = 'Connecting...';
                    });
                    // Handle call acceptance - you'll need to implement this
                  },
                  isLarge: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _videoCallService.dispose();
    super.dispose();
  }
}