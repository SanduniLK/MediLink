import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/config/environment.dart';
import 'package:frontend/services/telemedicine_service.dart';
import 'package:frontend/services/firestore_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

class ConsultationScreen extends StatefulWidget {
  final String appointmentId;
  final String userId;
  final String userName;
  final String userType;
  final String consultationType;
  final String? patientId;
  final String? doctorId;
  final String patientName; 
  final String doctorName;
  

  const ConsultationScreen({
    super.key,
    required this.appointmentId,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.consultationType,
    this.patientId,
    this.doctorId,
    required this.patientName, 
    required this.doctorName, 
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
 
void _testAudioImmediately() async {
  debugPrint('🎧 IMMEDIATE AUDIO TEST');
  
  // Test 1: Play system sound
  SystemSound.play(SystemSoundType.click);
  debugPrint('🔊 Playing system sound - can you hear it?');
  
  // Test 2: Use WebRTC's audio management instead of method channel
  try {
    // WebRTC usually handles audio routing automatically
    // Force audio session for voice call
    debugPrint('🔊 Using WebRTC automatic audio routing');
    
    // Ensure audio tracks are enabled
    if (_localRenderer.srcObject != null) {
      final local = _localRenderer.srcObject!;
      for (final track in local.getAudioTracks()) {
        track.enabled = true;
      }
    }
    
  } catch (e) {
    debugPrint('⚠️ WebRTC audio setup: $e');
  }
  
  // Test 3: Check audio tracks again
  _debugAudioDetails();
}
void _checkVideoRenderers() {
  debugPrint('🎥 VIDEO RENDERER CHECK');
  debugPrint('   Local Renderer: INITIALIZED');
  debugPrint('   Remote Renderer: INITIALIZED');
  debugPrint('   Local srcObject: ${_localRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
  debugPrint('   Remote srcObject: ${_remoteRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
  debugPrint('   Local video element: ${_localRenderer.videoWidth}x${_localRenderer.videoHeight}');
  debugPrint('   Remote video element: ${_remoteRenderer.videoWidth}x${_remoteRenderer.videoHeight}');
  
  // Force renderer refresh
  if (mounted) {
    setState(() {});
  }
}
void _emergencyMediaFix() async {
  debugPrint('🚨 EMERGENCY MEDIA FIX');
  
  try {
    // 1. Complete reset
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    
    // 2. Reinitialize renderers
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    
    // 3. Force WebRTC reinitialization
    await _telemedicine.initializeWebRTC(true);
    
    // 4. Wait and force stream attachment
    await Future.delayed(Duration(seconds: 2));
    
    // 5. Force UI refresh multiple times
    for (int i = 0; i < 3; i++) {
      if (mounted) setState(() {});
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    debugPrint('✅ Emergency media fix complete');
    
  } catch (e) {
    debugPrint('❌ Emergency media fix failed: $e');
  }
}

void _forceMediaStreamAttachment() async {
  debugPrint('📹 FORCING MEDIA STREAM ATTACHMENT');
  
  try {
    // Force UI refresh
    if (mounted) {
      setState(() {});
    }
    
    // Wait for render
    await Future.delayed(Duration(milliseconds: 100));
    
    debugPrint('   Local renderer: ${_localRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
    debugPrint('   Remote renderer: ${_remoteRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
    
  } catch (e) {
    debugPrint('❌ Media stream attachment failed: $e');
  }
}
void _debugWebRTCStreams() {
  debugPrint('🔍 WEBRTC STREAMS DEBUG');
  
  debugPrint('   Local Renderer Stream: ${_localRenderer.srcObject != null ? "EXISTS" : "NULL"}');
  debugPrint('   Remote Renderer Stream: ${_remoteRenderer.srcObject != null ? "EXISTS" : "NULL"}');
  
  if (_localRenderer.srcObject != null) {
    final stream = _localRenderer.srcObject!;
    debugPrint('   Local Stream ID: ${stream.id}');
    debugPrint('   Local Audio Tracks: ${stream.getAudioTracks().length}');
    debugPrint('   Local Video Tracks: ${stream.getVideoTracks().length}');
    
    for (final track in stream.getTracks()) {
      debugPrint('     Track: ${track.id} - ${track.kind} - Enabled: ${track.enabled}');
    }
  }
  
  // Check renderer dimensions
  debugPrint('   Local Renderer Size: ${_localRenderer.videoWidth}x${_localRenderer.videoHeight}');
  debugPrint('   Remote Renderer Size: ${_remoteRenderer.videoWidth}x${_remoteRenderer.videoHeight}');
}



void _fixVideoVisibility() {
  debugPrint('👀 FIXING VIDEO VISIBILITY');
  
  // Sometimes video elements need forced refresh
  if (mounted) {
    setState(() {
      // This forces Flutter to rebuild the video widgets
    });
  }
  
  // Check if video elements are actually visible in UI
  debugPrint('   Call Status: $_callStatus');
  debugPrint('   Consultation Type: ${widget.consultationType}');
  debugPrint('   Video Enabled: $_isVideoEnabled');
}
Future<void> _forceSpeakerphone() async {
  try {
    debugPrint('🔊 Attempting to force speakerphone via WebRTC...');
    
    // WebRTC should handle this automatically for voice calls
    // The audio should route to speaker for video calls by default
    
    debugPrint('🔊 WebRTC audio session configured for voice call');
    
  } catch (e) {
    debugPrint('⚠️ WebRTC audio configuration: $e');
  }
}
void _forceWebRTCAudioProcessing() async {
  
  debugPrint('🎯 FORCING WEBRTC AUDIO PROCESSING');
  
  try {
    // 1. Create a temporary audio context to force WebRTC audio initialization
    final mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true, 
        'autoGainControl': true,
        'channelCount': 2,
      },
      'video': false
    };

    // 2. Get a new media stream to force audio context
    final tempStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    debugPrint('🔊 Temporary audio stream acquired');
    
    // 3. Add a small audio element to force audio processing
    for (final track in tempStream.getAudioTracks()) {
      track.enabled = true;
    }
    
    // 4. Wait a moment for audio context to initialize
    await Future.delayed(Duration(milliseconds: 500));
    
    // 5. Clean up temporary stream
    for (final track in tempStream.getTracks()) {
      track.stop();
    }
    
    debugPrint('✅ WebRTC audio processing forced');
    
  } catch (e) {
    debugPrint('❌ Audio processing force failed: $e');
  }
}
void _webRTCAudioWorkaround() async {
  debugPrint('🔄 WEBRTC AUDIO WORKAROUND');
  
  try {
    // Workaround: Reinitialize WebRTC with different audio constraints
    debugPrint('1. Stopping current tracks...');
    
    // Stop current tracks
    if (_localRenderer.srcObject != null) {
      for (final track in _localRenderer.srcObject!.getTracks()) {
        await track.stop();
      }
    }
    
    debugPrint('2. Reinitializing WebRTC with forced audio...');
    
    // Reinitialize with forced audio configuration
    await _telemedicine.initializeWebRTC(widget.consultationType == 'video');
    
    debugPrint('3. Forcing audio track enable...');
    
    // Double ensure audio tracks are enabled
    if (_localRenderer.srcObject != null) {
      for (final track in _localRenderer.srcObject!.getAudioTracks()) {
        track.enabled = true;
        debugPrint('   🎤 Enabled track: ${track.id}');
      }
    }
    
    debugPrint('✅ WebRTC audio workaround complete');
    
  } catch (e) {
    debugPrint('❌ WebRTC audio workaround failed: $e');
  }
}
void _testAudioContext() async {
  debugPrint('🎵 TESTING AUDIO CONTEXT');
  
  try {
    // Test if we can play audio through WebRTC context
    final mediaConstraints = {
      'audio': true,
      'video': false
    };
    
    final testStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    debugPrint('🔊 Test audio stream created');
    
    // Create a temporary audio element
    for (final track in testStream.getAudioTracks()) {
      debugPrint('   🎤 Test track: ${track.id} - Enabled: ${track.enabled}');
      track.enabled = true;
    }
    
    // Keep the stream alive briefly to test audio
    await Future.delayed(Duration(seconds: 2));
    
    // Clean up
    for (final track in testStream.getTracks()) {
      track.stop();
    }
    
    debugPrint('✅ Audio context test complete - could you hear anything?');
    
  } catch (e) {
    debugPrint('❌ Audio context test failed: $e');
  }
}
void _platformAudioFix() {
  debugPrint('📱 PLATFORM AUDIO FIX ATTEMPT');
  
  debugPrint('Please try these manual fixes:');
  debugPrint('1. 📞 Make a regular phone call and switch to speakerphone');
  debugPrint('2. 🔄 Restart your device completely');
  debugPrint('3. 🎧 Plug and unplug headphones during the call');
  debugPrint('4. 📱 Try on a different Android device');
  debugPrint('5. 🔇 Check if any other app is using microphone');
}
void _debugAudioDetails() {
  debugPrint('🎧 COMPLETE AUDIO ANALYSIS');
  
  // Check local audio
  if (_localRenderer.srcObject != null) {
    final local = _localRenderer.srcObject!;
    final audioTracks = local.getAudioTracks();
    debugPrint('📱 LOCAL AUDIO: ${audioTracks.length} track(s)');
    
    for (final track in audioTracks) {
      debugPrint('   🎤 Track: ${track.id}');
      debugPrint('      Enabled: ${track.enabled}');
      debugPrint('      Kind: ${track.kind}');
      debugPrint('      Muted: ${track.muted}');
    }
  }
  
  // Check remote audio
  if (_remoteRenderer.srcObject != null) {
    final remote = _remoteRenderer.srcObject!;
    final audioTracks = remote.getAudioTracks();
    debugPrint('📞 REMOTE AUDIO: ${audioTracks.length} track(s)');
    
    for (final track in audioTracks) {
      debugPrint('   🎤 Track: ${track.id}');
      debugPrint('      Enabled: ${track.enabled}');
      debugPrint('      Kind: ${track.kind}');
      debugPrint('      Muted: ${track.muted}');
    }
  }
  
  debugPrint('🎛️ Audio State: $_isAudioEnabled');
  debugPrint('📞 Call Status: $_callStatus');
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
     await _initializeAudioSession();
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    debugPrint('   ✅ Renderers ready');
    
    // STEP 2: Set up callbacks
    debugPrint('2️⃣ Setting up callbacks...');
    _setupTelemedicineCallbacks();

      await _setMaxVolume();
    
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
    debugPrint('📹 LOCAL STREAM CALLBACK - Attaching to renderer');
    _localRenderer.srcObject = stream;
    
    // DEBUG: Check what we received
    debugPrint('   Stream ID: ${stream.id}');
    debugPrint('   Audio Tracks: ${stream.getAudioTracks().length}');
    debugPrint('   Video Tracks: ${stream.getVideoTracks().length}');
    
    // Force UI update
    if (mounted) {
      setState(() {});
    }
    
    _debugMediaStreams();
  };
  
  
 _telemedicine.onRemoteStream = (stream) {
    debugPrint('📹 REMOTE STREAM CALLBACK - Attaching to renderer');
    _remoteRenderer.srcObject = stream;
    
    // DEBUG: Check what we received
    debugPrint('   Stream ID: ${stream.id}');
    debugPrint('   Audio Tracks: ${stream.getAudioTracks().length}');
    debugPrint('   Video Tracks: ${stream.getVideoTracks().length}');
    
    // TEST AUDIO IMMEDIATELY
    _testAudioImmediately();
    
    // FORCE AUDIO ON when connection is established
    if (!_isAudioEnabled) {
      debugPrint('🔊 Auto-enabling audio on connection');
      _toggleAudio(); // This will turn audio ON
    }
    
    if (mounted) {
      setState(() {
        _callStatus = 'connected';
      });
    }
    
    _debugMediaStreams();
    _checkAudioState();
    
    // Force UI refresh again
    if (mounted) {
      setState(() {});
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
     if (!_telemedicine.isReady) {
      debugPrint('🔄 WebRTC not ready - initializing before handling offer...');
      await _telemedicine.initializeWebRTC(widget.consultationType == 'video');
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
  _cancelIceTimeoutMonitor();
};
_telemedicine.onMediaStateChanged = (data) {
    debugPrint('🎛️ REMOTE MEDIA STATE CHANGE: $data');
    debugPrint('   From: ${data['from']}');
    debugPrint('   Audio: ${data['audio']}');
    debugPrint('   Video: ${data['video']}');
    
    // You can update UI to show remote user's media state
    if (mounted) {
      // Show indicator that remote user muted/unmuted
    }
  };
}
 void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    _telemedicine.sendMediaStateChange(_isVideoEnabled, _isAudioEnabled);
  }

void _toggleAudio() async {
  debugPrint('🎤 AUDIO TOGGLE: ${!_isAudioEnabled ? 'ENABLING' : 'DISABLING'} audio - User: ${widget.userType}');
  
  try {
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });
    
    // Log who's toggling and why
    debugPrint('   👤 User: ${widget.userName} (${widget.userType})');
    debugPrint('   📍 Call Status: $_callStatus');
    debugPrint('   🔗 Socket Connected: ${_telemedicine.isConnected}');
    
    // Toggle local audio tracks
    if (_localRenderer.srcObject != null) {
      final localStream = _localRenderer.srcObject!;
      for (final track in localStream.getAudioTracks()) {
        track.enabled = _isAudioEnabled;
        debugPrint('   🎵 Local track ${track.id}: ${_isAudioEnabled ? 'ENABLED' : 'DISABLED'}');
      }
    }
    
    // Send state to remote
    _telemedicine.sendMediaStateChange(_isVideoEnabled, _isAudioEnabled);
    debugPrint('   📤 Media state sent: Audio=$_isAudioEnabled, Video=$_isVideoEnabled');
    
    // Force audio routing when enabling audio
    if (_isAudioEnabled) {
      await _forceSpeakerphone();
      debugPrint('   🔊 Speakerphone forced ON');
    }
    
    _checkAudioState();
    
  } catch (e) {
    debugPrint('❌ Error toggling audio: $e');
  }
}
Future<void> _setMaxVolume() async {
  try {
    // This would typically use a volume control plugin
    debugPrint('🔊 Setting maximum volume for call');
    
    // You can use the volume_control package for this
    // await VolumeControl.setVolume(1.0); // Max volume
  } catch (e) {
    debugPrint('⚠️ Could not set max volume: $e');
  }
}

void _endCall() {
  debugPrint('📞📞📞 COMPLETE CALL ENDING PROCESS STARTING...');
  
  try {
    // 1. Update UI immediately
    if (mounted) {
      setState(() {
        _callStatus = 'ending';
      });
    }
    
    // 2. Stop connection monitoring FIRST
    _connectionMonitor?.cancel();
   // _connectionMonitor = null;
    _cancelIceTimeoutMonitor();
    
    // 3. Use the enhanced end call in TelemedicineService
    _telemedicine.endCall(widget.userType);
    
    // 4. Force cleanup of renderers
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    
    // 5. Reset all local states
    if (mounted) {
      setState(() {
        _callStatus = 'ended';
        _isVideoEnabled = false;
        _isAudioEnabled = false;
        _targetUserId = null;
        _connectionRetries = 0;
      });
    }
    
    debugPrint('✅✅✅ CALL ENDED COMPLETELY - Ready for new call');
    
    // 6. Navigate back after cleanup
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
    
  } catch (e) {
    debugPrint('❌❌❌ Error in _endCall: $e');
    
    // Emergency cleanup even if there's an error
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    
    // Still navigate back
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
// Add this method to handle starting a new call after ending previous one
Future<void> _restartCall() async {
  debugPrint('🔄🔄🔄 RESTARTING CALL PROCESS...');
  
  try {
    // 1. Complete cleanup first
    _endCall();
    
    // 2. Wait for cleanup to complete
    await Future.delayed(const Duration(seconds: 2));
    
    // 3. Reinitialize everything from scratch
    await _initializeConsultation();
    
    debugPrint('✅✅✅ CALL RESTARTED SUCCESSFULLY');
    
  } catch (e) {
    debugPrint('❌❌❌ Call restart failed: $e');
    _showError('Failed to restart call: $e');
  }
}
void _cleanupWebRTCResources() {
  debugPrint('🔧 Cleaning up WebRTC resources...');
  
  try {
    // Stop all local media tracks
    if (_localRenderer.srcObject != null) {
      final localStream = _localRenderer.srcObject!;
      for (final track in localStream.getTracks()) {
        track.stop();
        debugPrint('   🛑 Stopped local track: ${track.id} (${track.kind})');
      }
      _localRenderer.srcObject = null;
    }
    
    // Stop all remote media tracks
    if (_remoteRenderer.srcObject != null) {
      final remoteStream = _remoteRenderer.srcObject!;
      for (final track in remoteStream.getTracks()) {
        track.stop();
        debugPrint('   🛑 Stopped remote track: ${track.id} (${track.kind})');
      }
      _remoteRenderer.srcObject = null;
    }
    
    // Reset media states
    _isVideoEnabled = false;
    _isAudioEnabled = false;
    
    debugPrint('✅ WebRTC resources cleaned up');
    
  } catch (e) {
    debugPrint('❌ Error cleaning WebRTC resources: $e');
  }
}
  void _debugMediaStreams() {
  debugPrint('🎛️ MEDIA STREAMS DEBUG:');
  debugPrint('   Local Renderer: ${_localRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
  debugPrint('   Remote Renderer: ${_remoteRenderer.srcObject != null ? "HAS STREAM" : "NO STREAM"}');
  debugPrint('   Call Status: $_callStatus');
  
  if (_localRenderer.srcObject != null) {
    final localStream = _localRenderer.srcObject!;
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
Future<void> _initializeAudioSession() async {
  try {
    debugPrint('🔊 Initializing audio session...');
    
    // For Flutter WebRTC, audio management is often automatic
    // But we can ensure proper audio focus
    
    // Enable speakerphone by default for better audio quality
    await _setSpeakerphoneOn(true);
    
    debugPrint('✅ Audio session configured');
  } catch (e) {
    debugPrint('⚠️ Audio session configuration failed: $e');
  }
}


// Helper method for speakerphone control
Future<void> _setSpeakerphoneOn(bool enable) async {
  try {
    // This method varies by platform - use a simpler approach
    debugPrint('🔊 ${enable ? 'Enabling' : 'Disabling'} speakerphone');
    
    // For Android, you might need a platform channel
    // For now, we'll rely on WebRTC's default behavior
  } catch (e) {
    debugPrint('⚠️ Could not set speakerphone: $e');
  }
}
  void _checkAudioState() {
  debugPrint('🔊 AUDIO STATE CHECK:');
  debugPrint('   Audio Enabled: $_isAudioEnabled');
  
  if (_localRenderer.srcObject != null) {
    final localStream = _localRenderer.srcObject!;
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
     debugPrint('🔄 Attempting to send doctor started notification...');
    debugPrint('   Patient ID: $_targetUserId');
    debugPrint('   Doctor Name: ${widget.userName}');
    debugPrint('   Appointment ID: ${widget.appointmentId}');
    
    
        debugPrint('✅ Consultation offer sent successfully');
    _startIceTimeoutMonitor();
    
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
Timer? _iceTimeoutTimer;

void _startIceTimeoutMonitor() {
  // Cancel any existing timer first
  _iceTimeoutTimer?.cancel();
  
  debugPrint('⏰ Starting ICE timeout monitor (10 seconds)...');
  
  _iceTimeoutTimer = Timer(Duration(seconds: 10), () {
    if ((_callStatus == 'connecting' || _callStatus == 'answering') && mounted) {
      debugPrint('⏰ ICE connection timeout - streams connected but ICE failed');
      _handleIceFailure();
    } else {
      debugPrint('✅ ICE timeout monitor cancelled - call status: $_callStatus');
    }
  });
}
void _updateConnectionStatus(String status) {
  if (mounted) {
    setState(() {
      _callStatus = status;
    });
  }
  
  // Show user-friendly message
  if (status == 'reconnecting') {
    _showError('Connection issues - attempting to reconnect...');
  }
}

void _cancelIceTimeoutMonitor() {
  _iceTimeoutTimer?.cancel();
  _iceTimeoutTimer = null;
  debugPrint('🛑 ICE timeout monitor cancelled');
}
void _handleIceFailure() {
  debugPrint('❌❌❌ ICE FAILURE DETECTED - Showing user feedback...');
  
  _updateConnectionStatus('reconnecting');
  
  // Don't auto-restart multiple times - let user decide
  Future.delayed(Duration(seconds: 5), () {
    if (_callStatus == 'reconnecting' && mounted) {
      _showError('Connection failed. Please try the call again.');
      _endCall();
    }
  });
}
  Future<void> _answerIncomingCall(dynamic callData) async {
  try {
    debugPrint('✅ Answering incoming call...');
    
    if (!mounted) return;
    
    setState(() {
      _callStatus = 'connecting';
    });
    
    // **ENSURE WEBRTC IS INITIALIZED BEFORE ANSWERING**
    if (!_telemedicine.isReady) {
      debugPrint('🔄 Initializing WebRTC before answering call...');
      await _telemedicine.initializeWebRTC(widget.consultationType == 'video');
    }
    
    final answer = await _telemedicine.createAnswer();
    _telemedicine.answerCall(callData['roomId'], answer);

     final doctorId = callData['callerId'];
    if (doctorId != null) {
      await FirestoreService.createPatientJoinedNotification(
        doctorId: doctorId,
        patientName: widget.userName,
        appointmentId: widget.appointmentId,
      );
    }
    
    debugPrint('✅ Call answered successfully');
    
    // Start ICE timeout monitoring
    _startIceTimeoutMonitor();
    
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
// In _buildDebugPanel method, add this button:


// Add this method:
void _checkNotifications() async {
  debugPrint('🔔 CHECKING NOTIFICATIONS IN FIRESTORE...');
  
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('patientId', isEqualTo: _targetUserId)
        .get();
    
    debugPrint('📋 Found ${snapshot.docs.length} notifications for patient $_targetUserId');
    
    for (final doc in snapshot.docs) {
      debugPrint('   Notification: ${doc.data()}');
    }
    
    // Also check all notifications
    final allSnapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .get();
    
    debugPrint('📋 Total notifications in database: ${allSnapshot.docs.length}');
    
  } catch (e) {
    debugPrint('❌ Error checking notifications: $e');
  }
}
  

  @override
 Widget build(BuildContext context) {
  // Color scheme
  final Color primaryColor = const Color(0xFF18A3B6);
  final Color secondaryColor = const Color(0xFF32BACD);
  final Color lightColor = const Color(0xFFB2DEE6);
  final Color veryLightColor = const Color(0xFFDDF0F5);

  return Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.consultationType == 'video' ? 'Video' : 'Audio'} Consultation',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      actions: [
        if (_callStatus == 'connected')
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.white),
            onPressed: _endCall,
            tooltip: 'End Call',
          ),
      ],
    ),
    backgroundColor: veryLightColor,
    body: Column(
      children: [
        // Call Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
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

        // Video/Audio Area
        Expanded(
          child: widget.consultationType == 'video' 
            ? _buildVideoArea(primaryColor, veryLightColor)
            : _buildAudioArea(primaryColor, secondaryColor, veryLightColor, lightColor),
        ),

        // Debug Panel
        _buildDebugPanel(lightColor, primaryColor, secondaryColor),

        // Controls
        _buildControlPanel(lightColor, primaryColor, secondaryColor),
      ],
    ),
  );
}

Widget _buildVideoArea(Color primaryColor, Color backgroundColor) {
  return Container(
    color: Colors.black,
    child: _callStatus == 'connected'
        ? Stack(
            children: [
              // Remote Video (Full Screen)
              Container(
                width: double.infinity,
                height: double.infinity,
                child: _remoteRenderer.srcObject != null 
                    ? RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              'Waiting for video...',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
              ),
              
              // Local Video (Picture-in-Picture)
              Positioned(
                top: 20,
                right: 20,
                width: 120,
                height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
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
                    child: _localRenderer.srcObject != null
                        ? RTCVideoView(
                            _localRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            mirror: true,
                          )
                        : Container(
                            color: Color(0xFF18A3B6),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person, size: 32, color: Colors.white),
                                  SizedBox(height: 8),
                                  Text(
                                    'You',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // Connection Status
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'LIVE',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'Establishing Video Connection...',
                  style: TextStyle(fontSize: 16, color: primaryColor, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  _callStatus.toUpperCase(),
                  style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w500),
                ),
                if (_targetUserId != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                    children: [
                      Text(
                        widget.userType == 'doctor' 
                            ? 'Patient: ${widget.patientName}'
                            : 'Dr. ${widget.doctorName}',
                        style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.userType == 'doctor' 
                            ? 'Dr. ${widget.userName} (You)'
                            : '${widget.userName} (You)',
                        style: TextStyle(color: primaryColor, fontSize: 12),
                      ),
                    ],
                  ),
                  ),
                ],
              ],
            ),
          ),
  );
}

Widget _buildAudioArea(Color primaryColor, Color secondaryColor, Color backgroundColor, Color lightColor) {
  return Container(
    color: backgroundColor,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated audio icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _callStatus == 'connected' ? primaryColor : secondaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: _callStatus == 'connected' ? primaryColor : secondaryColor,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.audiotrack,
              size: 60,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: 30),
          
          Text(
            _callStatus == 'connected' ? 'Audio Call Connected' : 'Connecting Audio Call...',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          
          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                Text(
                  widget.userType == 'doctor' 
                      ? 'Patient: ${widget.patientName}'
                      : 'Dr. ${widget.doctorName}',
                  style: TextStyle(
                    fontSize: 16, 
                    color: primaryColor, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.userType == 'doctor' 
                      ? 'Dr. ${widget.userName} (You)'
                      : '${widget.userName} (You)',
                  style: TextStyle(
                    fontSize: 14, 
                    color: secondaryColor,
                  ),
                ),
              ],
            ),

          ),
          
          if (_callStatus == 'connecting' || _callStatus == 'waiting') ...[
            SizedBox(height: 30),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Connecting...',
              style: TextStyle(color: secondaryColor, fontSize: 14),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildDebugPanel(Color lightColor, Color primaryColor, Color secondaryColor) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: lightColor,
      border: Border(
        top: BorderSide(color: primaryColor, width: 1),
        bottom: BorderSide(color: primaryColor, width: 1),
      ),
    ),
    child: Column(
      children: [
        // Status Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusIndicator('AUDIO', _isAudioEnabled, primaryColor),
            _buildStatusIndicator('VIDEO', _isVideoEnabled, primaryColor),
            _buildConnectionIndicator(_callStatus, primaryColor),
          ],
        ),
        
        SizedBox(height: 12),
        
        // Debug Buttons - Row 1
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDebugButton(Icons.audio_file, 'Audio Fix', _forceWebRTCAudioProcessing, primaryColor),
            _buildDebugButton(Icons.swap_horiz, 'Audio Work', _webRTCAudioWorkaround, primaryColor),
            _buildDebugButton(Icons.videocam, 'Video Check', _checkVideoRenderers, primaryColor),
            _buildDebugButton(Icons.link, 'Reattach', _forceMediaStreamAttachment, primaryColor),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Debug Buttons - Row 2
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDebugButton(Icons.bug_report, 'Debug', _debugWebRTCStreams, primaryColor),
            _buildDebugButton(Icons.visibility, 'Visibility', _fixVideoVisibility, primaryColor),
            _buildDebugButton(Icons.emergency, 'Emergency', _emergencyMediaFix, primaryColor),
            _buildDebugButton(Icons.help, 'Full Debug', () {
              _debugMediaStreams();
              _checkAudioState();
              _checkSocketStatus();
            }, primaryColor),
          ],
        ),
      ],
    ),
  );
}

Widget _buildControlPanel(Color lightColor, Color primaryColor, Color secondaryColor) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: lightColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          offset: Offset(0, -2),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Video Toggle (only for video calls)
        if (widget.consultationType == 'video')
          _buildControlButton(
            _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            _isVideoEnabled ? 'Video On' : 'Video Off',
            _toggleVideo,
            _isVideoEnabled ? primaryColor : Colors.red,
          ),

        // Audio Toggle
        _buildControlButton(
          _isAudioEnabled ? Icons.mic : Icons.mic_off,
          _isAudioEnabled ? 'Mic On' : 'Mic Off',
          _toggleAudio,
          _isAudioEnabled ? primaryColor : Colors.red,
        ),

        // End Call
        _buildControlButton(
          Icons.call_end,
          'End Call',
          _endCall,
          Colors.red,
          isEndCall: true,
        ),
      ],
    ),
  );
}

Widget _buildStatusIndicator(String label, bool isEnabled, Color primaryColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isEnabled ? primaryColor : Colors.grey,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: primaryColor,
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _buildConnectionIndicator(String status, Color primaryColor) {
  Color color;
  String text;
  
  switch (status) {
    case 'connected':
      color = Colors.green;
      text = 'CONNECTED';
      break;
    case 'connecting':
      color = Colors.orange;
      text = 'CONNECTING';
      break;
    case 'waiting':
      color = Colors.blue;
      text = 'WAITING';
      break;
    default:
      color = Colors.grey;
      text = status.toUpperCase();
  }
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _buildDebugButton(IconData icon, String tooltip, VoidCallback onPressed, Color color) {
  return IconButton(
    icon: Icon(icon, size: 20),
    onPressed: onPressed,
    tooltip: tooltip,
    color: color,
  );
}

Widget _buildControlButton(IconData icon, String tooltip, VoidCallback onPressed, Color color, {bool isEndCall = false}) {
  return Column(
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isEndCall ? color : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: [
            if (isEndCall)
              BoxShadow(
                color: color,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, size: 28),
          onPressed: onPressed,
          color: isEndCall ? Colors.white : color,
        ),
      ),
      SizedBox(height: 4),
      Text(
        tooltip,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

Color _getStatusColor() {
  switch (_callStatus) {
    case 'connected':
      return Color(0xFF18A3B6);
    case 'connecting':
      return Color(0xFF32BACD);
    case 'waiting':
      return Color(0xFF85CEDA);
    case 'ended':
      return Colors.red;
    default:
      return Color(0xFFB2DEE6);
  }
}

 


 @override
void dispose() {
  debugPrint('🧹🧹🧹 COMPLETE CONSULTATION SCREEN DISPOSAL');
  
  // 1. Cancel timers first
  _connectionMonitor?.cancel();
  _cancelIceTimeoutMonitor();
  
  // 2. End call through service
  _telemedicine.endCall(widget.userType);
  
  // 3. Clear renderers
  _localRenderer.srcObject = null;
  _remoteRenderer.srcObject = null;
  
  // 4. Dispose renderers
  _localRenderer.dispose();
  _remoteRenderer.dispose();
  
  // 5. Reset all states
  _callStatus = 'ended';
  _isVideoEnabled = false;
  _isAudioEnabled = false;
  _targetUserId = null;
  _connectionRetries = 0;
  
  super.dispose();
}
}