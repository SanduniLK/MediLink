// telemedicine/video_call_screen.dart
import 'dart:async';

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
  final bool shouldInitiateCall;

  VideoCallScreen({
    super.key,
    required this.callId,
    required this.otherUserName,
    required this.otherUserId,
    required this.currentUserId, 
    required this.currentUserName, 
    required this.isDoctor, 
    required this.isVideoCall, 
    this.isIncomingCall = false,
    this.shouldInitiateCall = true,
  }) : assert(currentUserId.isNotEmpty, 'currentUserId cannot be empty'),
       assert(currentUserName.isNotEmpty, 'currentUserName cannot be empty');

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
  bool _isInitialized = false;
  String _callStatus = 'Initializing...';

  bool _isCameraInitialized = false;
  int _connectionRetryCount = 0;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _initializeCall();
  }

  Future<void> _initializeRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      debugPrint('✅ Renderers initialized successfully');
    } catch (e) {
      debugPrint('❌ Renderer initialization error: $e');
    }
  }

  Future<void> _initializeCall() async {
    try {
      _setupVideoCallService();
      
      if (!_videoCallService.isInitialized) {
        await _videoCallService.initialize();
      }

      await _waitForConnection();
      
      // Join room first
      await _videoCallService.joinRoom(
        widget.callId,
        widget.currentUserId, 
        widget.currentUserName,
        widget.isDoctor
      );

      // Wait for local stream to be ready before proceeding
      await _waitForLocalStream();

      // Role-based call initiation
      if (widget.shouldInitiateCall && !widget.isIncomingCall) {
        debugPrint('🎯 INITIATOR: Creating and sending offer...');
        setState(() => _callStatus = 'Calling ${widget.otherUserName}...');
        await _createAndSendOffer();
      } else {
        debugPrint('🎯 ANSWERER: Waiting for offer...');
        setState(() => _callStatus = 'Waiting for call...');
        _setupOfferListener();
      }

      setState(() => _isInitialized = true);

      // Start connection monitoring
      _startConnectionMonitor();

    } catch (e) {
      debugPrint('❌ Call init error: $e');
      setState(() => _callStatus = 'Failed: $e');
      _showErrorDialog('Call initialization failed: $e');
    }
  }
Future<void> _waitForLocalStream() async {
    for (int i = 0; i < 20; i++) {
      if (_localRenderer.srcObject != null) {
        debugPrint('✅ Local stream is ready');
        setState(() => _isCameraInitialized = true);
        return;
      }
      await Future.delayed(Duration(milliseconds: 250));
    }
    throw Exception('Local stream not ready after 5 seconds');
  }
void _startConnectionMonitor() {
  _connectionTimer = Timer.periodic(Duration(seconds: 10), (timer) { // Increased to 10 seconds
    if (!_isCallConnected && mounted) {
      _connectionRetryCount++;
      
      if (_connectionRetryCount > 2) { // Reduced from 3 to 2
        debugPrint('🔄 Auto-reconnecting due to connection issues...');
        _forceReconnect();
        _connectionRetryCount = 0;
      }
    } else {
      _connectionRetryCount = 0;
    }
  });
}
  Future<void> _createAndSendOffer() async {
    try {
      // Wait for local stream to be ready
      if (_localRenderer.srcObject == null) {
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Create offer
      final offer = await _videoCallService.createOffer();
      
      // Send offer to the other participant
      _videoCallService.socket.emit('webrtc-offer', {
        'to': widget.callId,
        'offer': offer.toMap(),
        'targetUserId': widget.otherUserId,
      });
      
      debugPrint('✅ Offer created and sent successfully');
      setState(() => _callStatus = 'Calling ${widget.otherUserName}...');
    } catch (e) {
      debugPrint('❌ Error creating offer: $e');
      rethrow;
    }
  }

  void _setupOfferListener() {
    // Listen for incoming offers specifically
    _videoCallService.onOfferReceived = (offer, fromUserId) async {
      debugPrint('🎯 OFFER RECEIVED from: $fromUserId');
      if (mounted) {
        setState(() {
          _callStatus = 'Incoming call - connecting...';
        });
      }
      
      try {
        // Handle the incoming offer
        await _videoCallService.handleIncomingOffer({
          'from': fromUserId,
          'offer': offer
        });
      } catch (e) {
        debugPrint('❌ Error handling incoming offer: $e');
      }
    };
  }

  Future<void> _waitForConnection() async {
    // Wait for socket connection with timeout
    for (int i = 0; i < 20; i++) {
      if (_videoCallService.isConnected) {
        debugPrint('✅ Connected to signaling server');
        return;
      }
      debugPrint('⏳ Waiting for connection... ($i/20)');
      await Future.delayed(Duration(milliseconds: 500));
    }
    throw Exception('Failed to connect to signaling server after 10 seconds');
  }

  void _setupVideoCallService() {
    _videoCallService.onLocalStream = (stream) {
      debugPrint('📹 Local stream ready with ${stream.getVideoTracks().length} video tracks');
      
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = stream;
          _isCameraInitialized = true;
        });
      }
    };

    _videoCallService.onRemoteStream = (stream) {
      debugPrint('🎉 🎉 REMOTE STREAM RECEIVED! 🎉 🎉');
      debugPrint('   Stream ID: ${stream.id}');
      debugPrint('   Audio tracks: ${stream.getAudioTracks().length}');
      debugPrint('   Video tracks: ${stream.getVideoTracks().length}');
      
      // Verify tracks are working
      for (var track in stream.getAudioTracks()) {
        debugPrint('   🔊 Audio track: ${track.id} - enabled: ${track.enabled}');
      }
      for (var track in stream.getVideoTracks()) {
        debugPrint('   📹 Video track: ${track.id} - enabled: ${track.enabled}');
      }
      
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isCallConnected = true;
          _callStatus = 'Connected!';
        });
      }
    };

    // Enhanced error handling
    _videoCallService.onError = (error) {
      debugPrint('❌ VideoCallService error: $error');
      if (mounted) {
        setState(() {
          _callStatus = 'Error: $error';
        });
      }
    };

    // Track-specific events
    _videoCallService.onIceConnectionState = (state) {
      debugPrint('🧊 ICE State: $state');
      
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        debugPrint('🎉 ICE CONNECTED! Audio/Video should work now!');
        if (mounted) {
          setState(() {
            _isCallConnected = true;
            _callStatus = 'Connected';
          });
        }
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('❌ ICE Connection failed');
        if (mounted) {
          setState(() {
            _isCallConnected = false;
            _callStatus = 'Connection Lost - Retrying...';
          });
        }
        _forceReconnect();
      }
    };
  }

  void _acceptCall() async {
    try {
      setState(() {
        _callStatus = 'Connecting...';
      });
      
      // For incoming calls, create an answer
      if (widget.isVideoCall) {
        await _videoCallService.makeCall(widget.otherUserId);
      } else {
        await _videoCallService.makeAudioCall(widget.otherUserId);
      }
      
    } catch (e) {
      _showErrorDialog('Failed to accept call: $e');
    }
  }

  void _endCall() {
    _videoCallService.endCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleAudio() async {
    try {
      final newState = await _videoCallService.toggleAudio();
      if (mounted) {
        setState(() => _isAudioMuted = !newState);
      }
    } catch (e) {
      debugPrint('❌ Toggle audio error: $e');
    }
  }

 Future<void> _toggleVideo() async {
    try {
      if (!_isCameraInitialized) {
        debugPrint('🔄 Camera not ready, initializing...');
        await _waitForLocalStream();
      }
      
      final newState = await _videoCallService.toggleVideo();
      if (mounted) {
        setState(() => _isVideoMuted = !newState);
      }
    } catch (e) {
      debugPrint('❌ Toggle video error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }


  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endCall();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _forceReconnect() async {
    setState(() => _callStatus = 'Reconnecting...');
    await _videoCallService.forceReconnect();
  }

  void _testConnection() async {
    try {
      setState(() => _callStatus = 'Testing connection...');
      
      // Test if we can create an offer
      final offer = await _videoCallService.createOffer();
      debugPrint('✅ Test offer created: ${offer.type}');
      
      // Test if local stream is working
      if (_localRenderer.srcObject != null) {
        debugPrint('✅ Local stream is active');
      }
      
      setState(() => _callStatus = 'Connection test passed');
      
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      setState(() => _callStatus = 'Test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video (Full Screen)
            if (_isCallConnected && !_isVideoMuted && _remoteRenderer.srcObject != null)
              RTCVideoView(_remoteRenderer)
            else
              _buildNoVideoDisplay(),

            // Local Video (Picture-in-Picture)
            if (_localRenderer.srcObject != null && !_isVideoMuted)
              Positioned(
                top: 50,
                right: 20,
                width: 120,
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
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
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _callStatus,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Room: ${widget.callId}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (!_isAudioMuted) SizedBox(height: 4),
                    if (!_isAudioMuted)
                      Row(
                        children: [
                          Icon(Icons.mic, color: Colors.green, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Audio on',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // ✅ CONNECTION STATUS INDICATOR
            if (!_isCallConnected)
              Positioned(
                top: 150,
                left: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Connecting...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _callStatus,
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      if (_callStatus.contains('Connecting') || 
                          _callStatus.contains('Waiting'))
                        CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _forceReconnect,
                            child: Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _testConnection,
                            child: Text('Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Call Controls
            if (_isInitialized)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: _buildCallControls(),
              ),

            // Incoming Call Dialog
            if (widget.isIncomingCall && !_isCallConnected && _isInitialized)
              _buildIncomingCallDialog(),

            // Loading Indicator
            if (!_isInitialized)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'Initializing call...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
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
                color: _getStatusColor(),
                fontSize: 16,
              ),
            ),
            if (_callStatus == 'Connected' && _isVideoMuted)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Video is turned off',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_callStatus) {
      case 'Connected':
      case 'Connected!':
        return Colors.green;
      case 'Call Ended':
      case 'Failed to connect':
        return Colors.red;
      case 'Incoming Call':
        return Colors.orange;
      default:
        return Colors.white70;
    }
  }

  Widget _buildCallControls() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Audio
          _buildControlButton(
            icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
            label: _isAudioMuted ? 'Unmute' : 'Mute',
            backgroundColor: _isAudioMuted ? Colors.red : Colors.white24,
            onPressed: _toggleAudio,
          ),

          // End Call
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End',
            backgroundColor: Colors.red,
            iconColor: Colors.white,
            onPressed: _endCall,
            isLarge: true,
          ),

          // Toggle Video
          _buildControlButton(
            icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
            label: _isVideoMuted ? 'Video On' : 'Video Off',
            backgroundColor: _isVideoMuted ? Colors.red : Colors.white24,
            onPressed: _toggleVideo,
          ),

          // Switch Camera
          if (widget.isVideoCall)
            _buildControlButton(
              icon: Icons.cameraswitch,
              label: 'Switch',
              backgroundColor: Colors.white24,
              onPressed: _videoCallService.switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return Column(
      children: [
        Container(
          width: isLarge ? 64 : 50,
          height: isLarge ? 64 : 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: iconColor, size: isLarge ? 30 : 24),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingCallDialog() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile Avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isVideoCall ? Icons.videocam : Icons.call,
                size: 80,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 30),
            
            // Call Type
            Text(
              widget.isVideoCall ? 'Video Call' : 'Audio Call',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 10),
            
            // Caller Name
            Text(
              widget.otherUserName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),
            
            // Call Status
            Text(
              'is calling...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 40),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject
                _buildIncomingCallButton(
                  icon: Icons.call_end,
                  label: 'Decline',
                  backgroundColor: Colors.red,
                  onPressed: _endCall,
                ),

                // Accept
                _buildIncomingCallButton(
                  icon: widget.isVideoCall ? Icons.videocam : Icons.call,
                  label: widget.isVideoCall ? 'Video' : 'Audio',
                  backgroundColor: Colors.green,
                  onPressed: _acceptCall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
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
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
     _connectionTimer?.cancel();
    _videoCallService.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
}