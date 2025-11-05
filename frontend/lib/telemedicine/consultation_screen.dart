import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/config/environment.dart';
import 'package:frontend/services/telemedicine_service.dart';
import 'package:frontend/services/firestore_service.dart';

class ConsultationScreen extends StatefulWidget {
  final String appointmentId;
  final String userId;
  final String userName;
  final String userType;
  final String consultationType;
  final String? patientId;
  final String? doctorId;

  

  const ConsultationScreen({
    super.key,
    required this.appointmentId,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.consultationType,
    this.patientId,
    this.doctorId,
  });

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final TelemedicineService _telemedicine = TelemedicineService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  String _callStatus = 'connecting';
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  String? _targetUserId;
  Timer? _connectionMonitor;
  int _connectionRetries = 0;

  @override
  void initState() {
    super.initState();
    _initializeConsultation();
    _startConnectionMonitoring();
  }
void _startConnectionMonitoring() {
  _connectionMonitor = Timer.periodic(const Duration(seconds: 3), (timer) {
    if (!_telemedicine.isConnected && _callStatus != 'ended' && mounted) {
      _connectionRetries++;
      debugPrint('⚠️ Connection lost, retrying... (attempt $_connectionRetries)');
      
      if (_connectionRetries <= 3) {
        _reconnect();
      } else {
        _showError('Connection lost. Please check your internet and try again.');
        timer.cancel();
      }
    } else {
      _connectionRetries = 0; // Reset counter on successful connection
    }
  });
}
Future<void> _reconnect() async {
    try {
      debugPrint('🔄 Attempting reconnection...');
      
      // Reinitialize socket with current environment
      _telemedicine.initializeSocket(
        Environment.socketUrl, 
        widget.userId, 
        widget.userType
      );
      
      // Rejoin rooms
      if (widget.userType == 'doctor') {
        _telemedicine.joinCallRoom(widget.appointmentId);
        // Restart call if doctor
        await _startCallAsDoctor();
      } else {
        _telemedicine.joinPatientRoom(widget.userId, widget.userName);
        _telemedicine.joinCallRoom(widget.appointmentId);
      }
      
    } catch (e) {
      debugPrint('❌ Reconnection failed: $e');
    }
  }
Future<void> _initializeConsultation() async {
  debugPrint('🎯 INITIALIZING CONSULTATION: ${widget.appointmentId}');
  
  try {
    // STEP 1: Initialize video renderers (independent of backend)
    debugPrint('1️⃣ Initializing video renderers...');
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    debugPrint('   ✅ Renderers ready');
    
    // STEP 2: Set up callbacks
    debugPrint('2️⃣ Setting up callbacks...');
    _setupTelemedicineCallbacks();
    
    // STEP 3: Get target user ID from Firestore
    debugPrint('3️⃣ Getting target user ID...');
    await _getTargetUserId();
    debugPrint('   ✅ Target: $_targetUserId');
    
    // STEP 4: Initialize backend connection
    debugPrint('4️⃣ Initializing backend connection...');
    await _initializeBackendWithRetry();
    
    // STEP 5: Initialize WebRTC (camera/microphone)
    debugPrint('5️⃣ Initializing WebRTC...');
    await _initializeWebRTCWithRetry();
    
    // STEP 6: Join rooms and start call
    debugPrint('6️⃣ Joining rooms...');
    await _joinRoomsAndStartCall();
    
    debugPrint('🎉 CONSULTATION INITIALIZED SUCCESSFULLY');
    
  } catch (e) {
    debugPrint('💥 CONSULTATION INITIALIZATION FAILED: $e');
    _showError('Failed to start consultation: ${e.toString()}');
  }
}
Future<void> _joinRoomsAndStartCall() async {
  try {
    debugPrint('🚪 Joining rooms...');
    
    // Join patient room if patient
    if (widget.userType == 'patient') {
      debugPrint('👤 Joining patient room...');
      _telemedicine.joinPatientRoom(widget.userId, widget.userName);
      debugPrint('✅ Patient room joined');
    }
    
    // Join call room
    debugPrint('🚪 Joining call room: ${widget.appointmentId}');
    _telemedicine.joinCallRoom(widget.appointmentId);
    debugPrint('✅ Call room joined');
    
    // Start call if doctor
    if (widget.userType == 'doctor') {
      debugPrint('👨‍⚕️ Doctor starting call...');
      await _startCallAsDoctor();
    } else {
      debugPrint('👤 Patient waiting for call...');
      if (mounted) {
        setState(() {
          _callStatus = 'waiting';
        });
      }
    }
    
    // Start connection monitoring
    _startConnectionMonitoring();
    
  } catch (e) {
    debugPrint('❌ Error joining rooms: $e');
    rethrow;
  }
}
Future<void> _initializeBackendWithRetry() async {
  const maxRetries = 5;
  
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      debugPrint('   🔄 Backend connection attempt $attempt/$maxRetries...');
      await Environment.initialize();
      debugPrint('   ✅ Connected to: ${Environment.socketUrl}');
      return;
    } catch (e) {
      debugPrint('   ❌ Attempt $attempt failed: $e');
      
      if (attempt < maxRetries) {
        debugPrint('   ⏳ Waiting 3 seconds...');
        await Future.delayed(const Duration(seconds: 3));
      } else {
        throw Exception('Backend connection failed after $maxRetries attempts. Please start the server.');
      }
    }
  }
}

Future<void> _initializeWebRTCWithRetry() async {
  const maxRetries = 3;
  
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      debugPrint('   🔄 WebRTC initialization attempt $attempt/$maxRetries...');
      await _telemedicine.initializeWebRTC(widget.consultationType == 'video');
      debugPrint('   ✅ WebRTC initialized');
      return;
    } catch (e) {
      debugPrint('   ❌ WebRTC attempt $attempt failed: $e');
      
      if (attempt < maxRetries) {
        debugPrint('   ⏳ Waiting 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      } else {
        throw Exception('WebRTC initialization failed: $e');
      }
    }
  }
}
void _setupTelemedicineCallbacks() {
  _telemedicine.onLocalStream = (stream) {
    debugPrint('📹 Local stream received');
    _localRenderer.srcObject = stream;
  };
  
  _telemedicine.onRemoteStream = (stream) {
    debugPrint('📹 Remote stream received');
    _remoteRenderer.srcObject = stream;
    if (mounted) {
      setState(() {
        _callStatus = 'connected';
      });
    }
  };
  
  _telemedicine.onConnectionError = (error) {
    debugPrint('❌ Connection error: $error');
    if (mounted) {
      _showError('Connection error: $error');
    }
  };
  
  _telemedicine.onIncomingCall = (data) {
    debugPrint('📞 Incoming call received in ConsultationScreen: $data');
    if (widget.userType == 'patient') {
      _handleIncomingCallAsPatient(data);
    }
  };

  _telemedicine.onCallAnswered = (data) {
    debugPrint('✅ Remote user answered the call: $data');
    if (mounted) {
      setState(() {
        _callStatus = 'connected';
      });
    }
  };

  _telemedicine.onCallRejected = (data) {
    debugPrint('❌ Remote user rejected the call: $data');
    if (mounted) {
      _showError('Call was rejected by the remote user');
      Navigator.pop(context);
    }
  };

  _telemedicine.onWebRTCOffer = (data) async {
     debugPrint('📨 📨 📨 WebRTC OFFER RECEIVED FROM DOCTOR!');
  debugPrint('   Full data: $data');
    try {
    final offer = data['offer'];
    final roomId = data['roomId']?.toString() ?? widget.appointmentId;
    
    if (offer == null) {
      debugPrint('❌ Offer is null');
      return;
    }
    
    debugPrint('   Offer type: ${offer['type']}');
    debugPrint('   Room ID: $roomId');
    debugPrint('   Caller ID: ${data['callerId']}');
    
    // Update UI
    if (mounted) {
      setState(() {
        _callStatus = 'answering';
      });
    }
    
    // Handle the offer (this sets remote description)
    debugPrint('🔄 Handling WebRTC offer...');
    await _telemedicine.handleOffer(offer);
    
    // Create answer
    debugPrint('🔄 Creating answer...');
    final answer = await _telemedicine.createAnswer();
    
    // Send answer back to doctor
    debugPrint('🔄 Sending answer to doctor...');
    _telemedicine.answerCall(roomId, answer);
    
    debugPrint('✅ WebRTC negotiation completed - call should be connected');
    
    // Update UI
    if (mounted) {
      setState(() {
        _callStatus = 'connected';
      });
      _debugMediaStreams(); // ADD THIS
     _checkAudioState(); // ADD THIS
    }
    
  } catch (e, stackTrace) {
    debugPrint('❌ Error handling WebRTC offer: $e');
    debugPrint('Stack trace: $stackTrace');
    _showError('Failed to handle call: $e');
  }
  };

  _telemedicine.onWebRTCAnswer = (data) async {
    debugPrint('📨 Handling WebRTC answer from remote: $data');
    await _telemedicine.handleAnswer(data['answer']);
    if (mounted) {
      setState(() {
        _callStatus = 'connected';
      });
    }
  };

  _telemedicine.onICECandidate = (data) async {
    debugPrint('🧊 Handling ICE candidate from remote: $data');
    await _telemedicine.handleICECandidate(data['candidate']);
  };

  _telemedicine.onLocalStream = (stream) {
  debugPrint('📹 Local stream received');
  _localRenderer.srcObject = stream;
  _debugMediaStreams(); // ADD THIS
};

_telemedicine.onRemoteStream = (stream) {
  debugPrint('📹 Remote stream received');
  _remoteRenderer.srcObject = stream;
  _debugMediaStreams(); // ADD THIS
  _checkAudioState(); // ADD THIS
  if (mounted) {
    setState(() {
      _callStatus = 'connected';
    });
  }
};
}
 void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    _telemedicine.sendMediaStateChange(_isVideoEnabled, _isAudioEnabled);
  }

  void _toggleAudio() {
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });
    _telemedicine.sendMediaStateChange(_isVideoEnabled, _isAudioEnabled);
    _checkAudioState(); // Call debug after toggle
  }

  void _endCall() {
    debugPrint('📞 Ending call...');
    _telemedicine.endCall(widget.userType);
    if (mounted) {
      Navigator.pop(context);
    }
  }
  void _debugMediaStreams() {
  debugPrint('🎛️ MEDIA STREAMS DEBUG:');
  debugPrint('   Local Renderer: ${_localRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
  debugPrint('   Remote Renderer: ${_remoteRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
  debugPrint('   Call Status: $_callStatus');
  
  if (_localRenderer.srcObject != null) {
    final localStream = _localRenderer.srcObject! as MediaStream;
    debugPrint('   Local Audio Tracks: ${localStream.getAudioTracks().length}');
    debugPrint('   Local Video Tracks: ${localStream.getVideoTracks().length}');
    
    // Log each track details
    for (final track in localStream.getTracks()) {
      debugPrint('     ${track.kind?.toUpperCase()} Track: ${track.id} - Enabled: ${track.enabled}');
    }
  }
  
  if (_remoteRenderer.srcObject != null) {
    final remoteStream = _remoteRenderer.srcObject! as MediaStream;
    debugPrint('   Remote Audio Tracks: ${remoteStream.getAudioTracks().length}');
    debugPrint('   Remote Video Tracks: ${remoteStream.getVideoTracks().length}');
    
    // Log each track details
    for (final track in remoteStream.getTracks()) {
      debugPrint('     ${track.kind?.toUpperCase()} Track: ${track.id} - Enabled: ${track.enabled}');
    }
  }
}
  void _checkAudioState() {
  debugPrint('🔊 AUDIO STATE CHECK:');
  debugPrint('   Audio Enabled: $_isAudioEnabled');
  
  if (_localRenderer.srcObject != null) {
    final localStream = _localRenderer.srcObject! as MediaStream;
    final audioTracks = localStream.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      for (final track in audioTracks) {
        debugPrint('   Local Audio Track: ${track.id} - Enabled: ${track.enabled}');
      }
    } else {
      debugPrint('   No local audio tracks found');
    }
  } else {
    debugPrint('   No local stream available');
  }
  
  if (_remoteRenderer.srcObject != null) {
    final remoteStream = _remoteRenderer.srcObject! as MediaStream;
    final audioTracks = remoteStream.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      for (final track in audioTracks) {
        debugPrint('   Remote Audio Track: ${track.id} - Enabled: ${track.enabled}');
      }
    } else {
      debugPrint('   No remote audio tracks found');
    }
  } else {
    debugPrint('   No remote stream available');
  }
}
void _checkSocketStatus() {
  debugPrint('🔌 Socket Status Check:');
  debugPrint('   Connected: ${_telemedicine.isConnected}');
  debugPrint('   Socket ID: ${_telemedicine.socketId}');
  debugPrint('   Current Room: ${_telemedicine.currentRoomId}');
  debugPrint('   User ID: ${widget.userId}');
  debugPrint('   User Type: ${widget.userType}');
  debugPrint('   Appointment ID: ${widget.appointmentId}');
}

  Future<void> _getTargetUserId() async {
  try {
    debugPrint('🔍 Getting target user ID for appointment: ${widget.appointmentId}');
    
    final session = await FirestoreService.getSessionByAppointmentId(widget.appointmentId);
    
    if (session != null) {
      debugPrint('📋 Raw Firestore data for ${session['telemedicineId']}:');
      session.forEach((key, value) {
        debugPrint('   $key: $value (${value.runtimeType})');
      });
      
      if (widget.userType == 'doctor') {
        _targetUserId = session['patientId'];
        debugPrint('✅ Target patient ID: $_targetUserId');
      } else {
        _targetUserId = session['doctorId'];
        debugPrint('✅ Target doctor ID: $_targetUserId');
      }
    } else {
      debugPrint('❌ No session found for appointment: ${widget.appointmentId}');
      _showError('Session not found');
    }
  } catch (e) {
    debugPrint('❌ Error getting target user ID: $e');
    _showError('Failed to get session details');
  }
}

  Future<void> _startCallAsDoctor() async {
  try {
    if (_targetUserId == null) {
      debugPrint('❌ No target user ID available');
      // Try to get it again
      await _getTargetUserId();
      
      if (_targetUserId == null) {
        _showError('Cannot start call: Patient ID not found');
        return;
      }
    }

    debugPrint('📞 Creating WebRTC offer...');
    final offer = await _telemedicine.createOffer();
    
    debugPrint('🎯 Starting consultation with patient: $_targetUserId');
    debugPrint('   Room ID: ${widget.appointmentId}');
    debugPrint('   Doctor ID: ${widget.userId}');
    debugPrint('   Patient ID: $_targetUserId');
    
    // Send the offer via socket
    _telemedicine.startConsultation(
      widget.appointmentId,
      widget.consultationType,
      widget.userName,
      widget.userId,
      _targetUserId!,
      offer,
    );
    
    debugPrint('✅ Consultation offer sent successfully');
    
  } catch (e) {
    debugPrint('❌ Error starting call: $e');
    _showError('Failed to start call: $e');
  }
}

  Future<void> _handleIncomingCallAsPatient(dynamic callData) async {
    try {
      debugPrint('📞 Handling incoming call: $callData');
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Incoming Video Call'),
          content: Text('Dr. ${callData['doctorName']} is calling you'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectIncomingCall(callData);
              },
              child: const Text('Reject'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _answerIncomingCall(callData);
              },
              child: const Text('Answer'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Error handling incoming call: $e');
    }
  }

  Future<void> _answerIncomingCall(dynamic callData) async {
    try {
      debugPrint('✅ Answering incoming call...');
      
      if (!mounted) return;
      
      setState(() {
        _callStatus = 'connecting';
      });
      
      final answer = await _telemedicine.createAnswer();
      _telemedicine.answerCall(callData['roomId'], answer);
      
      debugPrint('✅ Call answered successfully');
      
    } catch (e) {
      debugPrint('❌ Error answering call: $e');
      _showError('Failed to answer call: $e');
    }
  }

  void _rejectIncomingCall(dynamic callData) {
    debugPrint('❌ Rejecting incoming call');
    _telemedicine.rejectCall(callData['roomId'], 'User rejected call');
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.consultationType == 'video' ? 'Video' : 'Audio'} Consultation'),
        backgroundColor: Colors.blue[700],
        actions: [
          if (_callStatus == 'connected')
            IconButton(
              icon: const Icon(Icons.call_end),
              onPressed: _endCall,
              color: Colors.red,
            ),
        ],
      ),
      body: Column(
        children: [
          // Call Status
          Container(
            padding: const EdgeInsets.all(16),
            color: _getStatusColor(),
            child: Center(
              child: Text(
                'Status: ${_callStatus.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // Video Area
          if (widget.consultationType == 'video') 
            Expanded(
              child: _callStatus == 'connected'
                  ? Stack(
                      children: [
                        // Remote Video (Full Screen)
                        RTCVideoView(_remoteRenderer),
                        
                        // Local Video (Picture-in-Picture)
                        Positioned(
                          top: 20,
                          right: 20,
                          width: 120,
                          height: 160,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: RTCVideoView(_localRenderer),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          const Text('Connecting...'),
                          if (_targetUserId != null)
                            Text('With: ${widget.userType == 'doctor' ? 'Patient' : 'Dr. ${widget.userName}'}'),
                        ],
                      ),
                    ),
            ) 
          else 
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.audiotrack, 
                      size: 100, 
                      color: _callStatus == 'connected' ? Colors.green : Colors.blue
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _callStatus == 'connected' ? 'Audio Call Connected' : 'Connecting Audio Call...',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'With ${widget.userType == 'doctor' ? 'Patient' : 'Dr. ${widget.userName}'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (_callStatus == 'connecting' || _callStatus == 'waiting') ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Video Toggle (only for video calls)
                if (widget.consultationType == 'video')
                  IconButton(
                    icon: Icon(
                      _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      color: _isVideoEnabled ? Colors.blue : Colors.red,
                    ),
                    onPressed: _toggleVideo,
                    iconSize: 32,
                  ),

                // Audio Toggle
                IconButton(
                  icon: Icon(
                    _isAudioEnabled ? Icons.mic : Icons.mic_off,
                    color: _isAudioEnabled ? Colors.blue : Colors.red,
                  ),
                  onPressed: _toggleAudio,
                  iconSize: 32,
                ),

                // End Call
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.red),
                  onPressed: _endCall,
                  iconSize: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_callStatus) {
      case 'connected':
        return Colors.green;
      case 'connecting':
      case 'waiting':
        return Colors.orange;
      case 'ended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
     _connectionMonitor?.cancel();
    debugPrint('🧹 Disposing ConsultationScreen...');
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _telemedicine.endCall(widget.userType);
    super.dispose();
  }
}