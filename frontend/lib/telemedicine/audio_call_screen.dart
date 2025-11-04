// telemedicine/audio_call_screen.dart - FIXED
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/services/video_call_service.dart';

class AudioCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserName;
  final String otherUserId;
  final String currentUserId;
  final String currentUserName;
  final bool isDoctor;
  final bool isIncomingCall;
  final bool shouldInitiateCall;

  const AudioCallScreen({
    super.key,
    required this.callId,
    required this.otherUserName,
    required this.otherUserId,
    required this.currentUserId,
    required this.currentUserName,
    required this.isDoctor,
    required this.isIncomingCall,
    this.shouldInitiateCall = true,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  final VideoCallService _videoCallService = VideoCallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isAudioMuted = false;
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
      debugPrint('🎙️ Local audio stream received');
      _localRenderer.srcObject = stream;
      setState(() {});
    };

    _videoCallService.onRemoteStream = (stream) {
      debugPrint('🔊 Remote audio stream received');
      _remoteRenderer.srcObject = stream;
      setState(() {
        _isCallConnected = true;
        _callStatus = 'Connected';
      });
    };

    _videoCallService.onCallEnded = () {
      debugPrint('📞 Call ended remotely');
      setState(() {
        _callStatus = 'Call Ended';
      });
      _endCall();
    };

    _videoCallService.onError = (error) {
      debugPrint('❌ Call error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call Error: $error')),
        );
      }
    };

    _videoCallService.onCallAccepted = () {
      debugPrint('✅ Call accepted by remote user');
      setState(() {
        _callStatus = 'Call Accepted';
      });
    };

    try {
      await _videoCallService.initialize();
      await _videoCallService.joinRoom(
        widget.callId, 
        widget.currentUserId,
        widget.currentUserName,
        widget.isDoctor
      );

      if (!widget.isIncomingCall) {
        await _videoCallService.makeAudioCall(widget.otherUserId);
        debugPrint('📞 Audio call initiated to ${widget.otherUserName}');
      } else {
        debugPrint('📞 Waiting for incoming audio call from ${widget.otherUserName}');
      }
    } catch (e) {
      debugPrint('❌ Error initializing audio call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize call: $e')),
        );
      }
    }
  }

  void _endCall() {
    debugPrint('📞 Ending audio call');
    _videoCallService.endCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleAudio() async {
    try {
      final newState = await _videoCallService.toggleAudio();
      setState(() {
        _isAudioMuted = !newState;
      });
      debugPrint(_isAudioMuted ? '🎙️ Audio muted' : '🎙️ Audio unmuted');
    } catch (e) {
      debugPrint('❌ Error toggling audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Audio Call Display
            _buildAudioDisplay(),

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
                  Text(
                    'Audio Call',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                  if (_isAudioMuted) ...[
                    SizedBox(height: 4),
                    Text(
                      'Microphone Muted',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildAudioDisplay() {
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
            SizedBox(height: 4),
            Text(
              'Audio Call',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),
            if (!_isCallConnected) ...[
              SizedBox(height: 20),
              CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
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
          tooltip: _isAudioMuted ? 'Unmute' : 'Mute',
        ),

        // End Call
        _buildControlButton(
          icon: Icons.call_end,
          backgroundColor: Colors.red,
          iconColor: Colors.white,
          onPressed: _endCall,
          isLarge: true,
          tooltip: 'End Call',
        ),

        // Speaker (placeholder)
        _buildControlButton(
          icon: Icons.volume_up,
          backgroundColor: Colors.white24,
          onPressed: () {
            debugPrint('🔊 Speaker button pressed');
            // TODO: Implement speaker toggle
          },
          tooltip: 'Speaker',
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
    String tooltip = '',
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
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
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('♻️ Disposing AudioCallScreen resources');
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _videoCallService.dispose();
    super.dispose();
  }
}