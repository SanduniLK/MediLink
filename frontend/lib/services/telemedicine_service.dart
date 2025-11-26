import 'package:flutter/material.dart';
import 'package:frontend/config/environment.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class TelemedicineService {
  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _currentRoomId;
  String? _userId;
  String? _userType;

  bool _isConnecting = false;
  int _connectionAttempts = 0;
  static const int MAX_CONNECTION_ATTEMPTS = 3;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(dynamic)? onIncomingCall;
  Function(dynamic)? onCallAnswered;
  Function(dynamic)? onCallRejected;
  Function(dynamic)? onCallEnded;
  Function(dynamic)? onUserJoined;
  Function(dynamic)? onUserLeft;
  Function(dynamic)? onWebRTCOffer;
  Function(dynamic)? onWebRTCAnswer;
  Function(dynamic)? onICECandidate;
  Function(String)? onConnectionError;
  Function(dynamic)? onMediaStateChanged;

  // Initialize socket connection
  void initializeSocket(String serverUrl, String userId, String userType) {
    String finalUrl = serverUrl;
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      finalUrl = 'http://$serverUrl';
      debugPrint('⚠️ Added http:// protocol to URL: $finalUrl');
    }
    debugPrint('🔌 Connecting to: $finalUrl');

    // Prevent multiple simultaneous connection attempts
    if (_isConnecting) {
      debugPrint('⚠️ Already attempting connection, skipping...');
      return;
    }
    
    _isConnecting = true;
    _connectionAttempts++;
    
    _userId = userId;
    _userType = userType;
    
    debugPrint('🔌 Attempting socket connection (attempt $_connectionAttempts/$MAX_CONNECTION_ATTEMPTS)');
    debugPrint('👤 User: $userId, Type: $userType');
    
    try {
      // Clean up previous socket
      _socket?.disconnect();
      _socket?.destroy();
      _socket = null;
      
      _socket = io.io(finalUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false,
        'forceNew': true,
        'timeout': 10000,
        'reconnection': false,
      });

      _setupEventHandlers();
      _socket!.connect();
      
      // Set connection timeout
      Future.delayed(const Duration(seconds: 10), () {
        if (_socket?.connected != true && _isConnecting) {
          debugPrint('⏰ Connection timeout after 10 seconds');
          _handleConnectionFailure('Connection timeout');
        }
      });

    } catch (e) {
      debugPrint('💥 Socket initialization error: $e');
      _handleConnectionFailure('Initialization error: $e');
    }
  }

  void _handleConnectionFailure(String error) {
    _isConnecting = false;
    
    if (_connectionAttempts < MAX_CONNECTION_ATTEMPTS) {
      debugPrint('🔄 Connection failed, will retry... (attempt $_connectionAttempts/$MAX_CONNECTION_ATTEMPTS)');
      Future.delayed(const Duration(seconds: 2), () {
        _retryConnection();
      });
    } else {
      debugPrint('❌ ❌ ❌ MAX CONNECTION ATTEMPTS REACHED');
      onConnectionError?.call('Failed to connect after $_connectionAttempts attempts: $error');
    }
  }

  void _retryConnection() {
    if (_userId != null && _userType != null) {
      _socket?.disconnect();
      _socket?.destroy();
      _socket = null;
      initializeSocket(Environment.socketUrl, _userId!, _userType!);
    }
  }

  bool get isReady => _socket?.connected == true && _peerConnection != null;

  void _setupEventHandlers() {
    if (_socket == null) return;
    
    _socket!.on('connect', (_) {
      debugPrint('✅ Connected to server with ID: ${_socket!.id}');
      _isConnecting = false;
      _connectionAttempts = 0;
      _socket!.emit('register-user', {
        'userId': _userId,
        'userType': _userType,
      });
    });

    _socket!.on('registration-confirmed', (data) {
      debugPrint('✅ User registration confirmed: ${data['userId']}');
    });

    _socket!.on('patient-room-joined', (data) {
      debugPrint('✅ Patient room joined: ${data['patientId']}');
    });

    _socket!.on('webrtc-offer', (data) {
      debugPrint('📨 WebRTC offer received from: ${data['from']}');
      onWebRTCOffer?.call(data);
    });

    _socket!.on('webrtc-answer', (data) {
      debugPrint('📨 WebRTC answer received from: ${data['from']}');
      onWebRTCAnswer?.call(data);
    });

    _socket!.on('ice-candidate', (data) {
      debugPrint('🧊 ICE candidate received from: ${data['from']}');
      onICECandidate?.call(data);
    });

    _socket!.on('call-ended', (data) {
      debugPrint('📞 Call ended by remote user: $data');
      onCallEnded?.call(data);
      _cleanupWebRTC(); // Clean up WebRTC but keep socket
    });

    _socket!.on('user-left', (data) {
      debugPrint('🚪 User left room: $data');
      onUserLeft?.call(data);
      _cleanupWebRTC(); // Clean up WebRTC but keep socket
    });

    _socket!.on('call-rejected', (data) {
      debugPrint('❌ Call rejected: $data');
      onCallRejected?.call(data);
    });

    _socket!.on('user-joined', (data) {
      debugPrint('👤 User joined room: $data');
      onUserJoined?.call(data);
    });

    _socket!.on('disconnect', (reason) {
      debugPrint('❌ Disconnected from server: $reason');
      _isConnecting = false;
    });

    _socket!.on('connect_error', (error) {
      debugPrint('❌ Connection error: $error');
      _handleConnectionFailure('Connect error: $error');
    });
    _socket!.on('ice-restart', (data) async {
  debugPrint('🔄 ICE restart received');
  try {
    if (_peerConnection != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['offer']['sdp'], data['offer']['type'])
      );
      
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      _socket?.emit('ice-restart-answer', {
        'roomId': _currentRoomId,
        'answer': answer.toMap(),
      });
      _socket!.on('patient-left-call', (data) {
  debugPrint('🚪 Patient left call: $data');
  // This will trigger on doctor side when patient ends call
  onUserLeft?.call(data);
  _cleanupWebRTC(); // Clean WebRTC but keep socket for restart
});
_socket!.on('doctor-end-meeting', (data) {
  debugPrint('📞📞 Meeting ended permanently by doctor: $data');
  onCallEnded?.call(data);
  _completeCallReset(); // Full reset - no restart
});
    }
  } catch (e) {
    debugPrint('❌ ICE restart handling failed: $e');
  }
});
  }

  // Patient: Join patient room
  void joinPatientRoom(String patientId, String patientName) {
    _socket?.emit('patient-join', {
      'patientId': patientId,
      'userName': patientName,
    });
  }

  // Doctor: Start consultation
  void startConsultation(String roomId, String callType, String callerName, String callerId, String targetUserId, dynamic offer) {
    _currentRoomId = roomId;
    
    _socket?.emit('doctor-start-call', {
      'roomId': roomId,
      'callType': callType,
      'callerName': callerName,
      'callerId': callerId,
      'targetUserId': targetUserId,
      'offer': offer,
    });
    _socket?.emit('call-started', {
  'roomId': roomId,
  'startedBy': callerId,
  'timestamp': DateTime.now().toIso8601String(),
});
  }
  
  // Patient: Answer call
  void answerCall(String roomId, dynamic answer) {
    _socket?.emit('patient-answer-call', {
      'roomId': roomId,
      'answer': answer,
    });
  }

  // Patient: Reject call
  void rejectCall(String roomId, String reason) {
    _socket?.emit('patient-reject-call', {
      'roomId': roomId,
      'reason': reason,
    });
    debugPrint('❌ Call rejected: $reason');
  }

  // Join call room
  void joinCallRoom(String roomId) {
    _currentRoomId = roomId;
    _socket?.emit('join-call-room', roomId);
  }

  // WebRTC: Send ICE candidate
  void sendICECandidate(String target, dynamic candidate) {
    _socket?.emit('ice-candidate', {
      'to': target,
      'candidate': candidate,
    });
  }

  // Send media state change
  void sendMediaStateChange(bool isVideoEnabled, bool isAudioEnabled) {
    if (_currentRoomId != null) {
      _socket?.emit('media-state-changed', {
        'roomId': _currentRoomId,
        'video': isVideoEnabled,
        'audio': isAudioEnabled,
      });
      debugPrint('🎛️ Media state changed - Video: $isVideoEnabled, Audio: $isAudioEnabled');
    }
  }

  // SINGLE END CALL METHOD - FIXED
void endCall(String endedBy) {
  debugPrint('📞📞📞 TELEMEDICINE SERVICE: Ending call for $endedBy');
  
  try {
    // 1. Send call ended event to other participant
    if (_currentRoomId != null && _socket?.connected == true) {
      _socket?.emit('end-call', {
        'roomId': _currentRoomId,
        'endedBy': endedBy,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('📤 Call ended event sent to server');
    }
    
    // 2. COMPLETE RESET (not just cleanup)
    resetForNewCall();
    
    debugPrint('✅✅✅ CALL ENDED IN SERVICE - Ready for new call');
    
  } catch (e) {
    debugPrint('❌❌❌ Error in TelemedicineService.endCall: $e');
    
    // Emergency reset even if there's an error
    resetForNewCall();
  }
}

  // Send call ended event separately
  void sendCallEnded(String roomId) {
    try {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('call-ended', {
          'roomId': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('📤 Call ended event sent for room: $roomId');
      }
    } catch (e) {
      debugPrint('❌ Error sending call ended: $e');
    }
  }

  // Initialize WebRTC
 Future<void> initializeWebRTC(bool isVideo) async {
  try {
    debugPrint('🔄🔄🔄 WEBRTC REINITIALIZATION STARTING...');
    
    // FORCE COMPLETE CLEANUP BEFORE INITIALIZATION
    _cleanupWebRTC();
    

    
    // Wait a bit to ensure resources are released
    await Future.delayed(const Duration(milliseconds: 500));
    
    debugPrint('   Creating new PeerConnection...');
    
    // Create FRESH peer connection
    _peerConnection = await createPeerConnection({
      'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
    {'urls': 'stun:stun4.l.google.com:19302'},
    {
      'urls': 'turn:openrelay.metered.ca:80',
      'username': 'openrelayproject',
      'credential': 'openrelayproject'
    },
    {
      'urls': 'turn:openrelay.metered.ca:443', 
      'username': 'openrelayproject',
      'credential': 'openrelayproject'
    },
    {
      'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
      'username': 'openrelayproject',
      'credential': 'openrelayproject'
    },
  ],
  'iceTransportPolicy': 'all',
  'bundlePolicy': 'max-bundle',
  'rtcpMuxPolicy': 'require',
  'sdpSemantics': 'unified-plan'
    });
    
    debugPrint('   ✅ NEW PeerConnection created');
    
    // Set up event handlers on FRESH connection
    _peerConnection!.onIceCandidate = (candidate) {
      debugPrint('🧊 NEW ICE candidate: ${candidate.candidate}');
      if (_currentRoomId != null) {
        sendICECandidate(_currentRoomId!, candidate.toMap());
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('📹📹📹 NEW REMOTE TRACK RECEIVED: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        final remoteStream = event.streams.first;
        debugPrint('   NEW Remote stream id: ${remoteStream.id}');
        onRemoteStream?.call(remoteStream);
      }
    };
    _peerConnection!.onIceConnectionState = (state) {
  debugPrint('🧊🧊🧊 ICE CONNECTION STATE: $state');
  
  if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
    debugPrint('❌❌❌ ICE CONNECTION FAILED - Attempting restart...');
    _handleIceRestart();
  } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
    debugPrint('✅✅✅ ICE CONNECTION CONNECTED');
  } else if (state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
    debugPrint('🎉🎉🎉 ICE CONNECTION COMPLETED');
  }
};
_peerConnection!.onConnectionState = (state) {
  debugPrint('🔗🔗🔗 PEER CONNECTION STATE: $state');
};
    // Get FRESH user media
    debugPrint('   Getting FRESH user media...');
    final mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'channelCount': 2,
      },
      'video': isVideo ? {
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      } : false
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    debugPrint('   ✅ FRESH Local media stream obtained');
    
    // Log NEW tracks
    final audioTracks = _localStream!.getAudioTracks();
    final videoTracks = _localStream!.getVideoTracks();
    debugPrint('   NEW Local audio tracks: ${audioTracks.length}');
    debugPrint('   NEW Local video tracks: ${videoTracks.length}');
    
    // Add NEW tracks to FRESH peer connection
    debugPrint('   Adding tracks to NEW PeerConnection...');
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
      debugPrint('     ➕ Added NEW ${track.kind} track: ${track.id}');
    }
    
    // Notify about NEW local stream
    onLocalStream?.call(_localStream!);
    debugPrint('✅✅✅ WEBRTC REINITIALIZED SUCCESSFULLY - Ready for call');
    
  } catch (e, stackTrace) {
    debugPrint('❌❌❌ WEBRTC REINITIALIZATION FAILED: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Emergency cleanup on failure
    _cleanupWebRTC();
    rethrow;
  }
}
Future<void> _handleIceRestart() async {
  debugPrint('🔄🔄🔄 ATTEMPTING ICE RESTART...');
  
  try {
    if (_peerConnection != null && _currentRoomId != null) {
      // Create new offer for ICE restart
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      // Send the new offer to remote peer
      _socket?.emit('ice-restart', {
        'roomId': _currentRoomId,
        'offer': offer.toMap(),
      });
      
      debugPrint('📤 ICE restart offer sent');
    }
  } catch (e) {
    debugPrint('❌ ICE restart failed: $e');
  }
}
  // Create WebRTC offer
  Future<dynamic> createOffer() async {
    try {
      debugPrint('📞 Creating WebRTC offer...');
      
      if (_peerConnection == null) {
        debugPrint('❌ PeerConnection is NULL - Reinitializing WebRTC...');
        await initializeWebRTC(true);
        
        if (_peerConnection == null) {
          throw Exception('WebRTC failed to initialize - PeerConnection is still null');
        }
      }
      
      final offer = await _peerConnection!.createOffer();
      debugPrint('   Offer type: ${offer.type}');
      debugPrint('   SDP length: ${offer.sdp?.length ?? 0}');
      
      await _peerConnection!.setLocalDescription(offer);
      debugPrint('   Local description set successfully');
      
      debugPrint('✅ WebRTC offer created successfully');
      return offer.toMap();
      
    } catch (e, stackTrace) {
      debugPrint('❌ FATAL ERROR creating WebRTC offer: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Create WebRTC answer
  Future<dynamic> createAnswer() async {
    try {
      debugPrint('🔄 Creating WebRTC answer...');
      
      if (_peerConnection == null) {
        throw Exception('PeerConnection is not initialized');
      }
      
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      debugPrint('✅ Answer created successfully');
      return answer.toMap();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating answer: $e');
      rethrow;
    }
  }

  // Handle WebRTC offer
  Future<void> handleOffer(dynamic offerData) async {
    try {
      debugPrint('🔄 Handling WebRTC offer...');
      
      if (_peerConnection == null) {
        throw Exception('PeerConnection not initialized');
      }
      
      final sdp = offerData['sdp']?.toString() ?? '';
      final type = offerData['type']?.toString() ?? 'offer';
      
      if (sdp.isEmpty) {
        throw Exception('Empty SDP in offer');
      }
      
      debugPrint('   Setting remote description...');
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
      debugPrint('   ✅ Remote description set');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling offer: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Handle WebRTC answer
  Future<void> handleAnswer(dynamic answerData) async {
    try {
      debugPrint('🔄 Handling WebRTC answer...');
      
      if (_peerConnection == null) {
        throw Exception('PeerConnection not initialized');
      }
      
      final sdp = answerData['sdp']?.toString() ?? '';
      final type = answerData['type']?.toString() ?? 'answer';
      
      if (sdp.isEmpty) {
        throw Exception('Empty SDP in answer');
      }
      
      debugPrint('   Setting remote description (answer)...');
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
      debugPrint('   ✅ Remote description set (answer)');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling answer: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Handle ICE candidate
  Future<void> handleICECandidate(dynamic candidate) async {
    try {
      if (_peerConnection == null) return;
      
      final String candidateStr = candidate['candidate']?.toString() ?? '';
      final String sdpMid = candidate['sdpMid']?.toString() ?? '';
      final int sdpMLineIndex = candidate['sdpMLineIndex'] ?? 0;
      
      if (candidateStr.isEmpty) {
        debugPrint('⚠️ Empty ICE candidate, skipping');
        return;
      }
      
      await _peerConnection!.addCandidate(
        RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex)
      );
      
      debugPrint('✅ ICE candidate added successfully');
      
    } catch (e) {
      debugPrint('❌ Error adding ICE candidate: $e');
    }
  }
  // PATIENT: End call but keep session active (doctor can restart)
void patientEndCall(String roomId, String patientId) {
  debugPrint('📞 PATIENT ending call - Room: $roomId, Patient: $patientId');
  
  try {
    // 1. Send patient-left event (not full call ended)
    if (_socket?.connected == true) {
      _socket?.emit('patient-left-call', {
        'roomId': roomId,
        'patientId': patientId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('📤 Patient left call event sent');
    }
    
    // 2. Reset WebRTC but keep socket connection
    _cleanupWebRTC();
    
    // 3. Update patient join status to false
    // This will trigger doctor side to show "Patient Waiting" again
    
    debugPrint('✅ Patient call ended - Doctor can restart');
    
  } catch (e) {
    debugPrint('❌ Error in patientEndCall: $e');
    _cleanupWebRTC();
  }
}

// DOCTOR: Permanently end meeting
void doctorEndMeeting(String roomId, String doctorId) {
  debugPrint('📞📞 DOCTOR PERMANENTLY ending meeting - Room: $roomId, Doctor: $doctorId');
  
  try {
    // 1. Send meeting-ended event (permanent)
    if (_socket?.connected == true) {
      _socket?.emit('doctor-end-meeting', {
        'roomId': roomId,
        'doctorId': doctorId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('📤 Doctor ended meeting permanently');
    }
    
    // 2. Complete cleanup - no restart possible
    _completeCallReset();
    
    debugPrint('✅✅ MEETING ENDED PERMANENTLY BY DOCTOR');
    
  } catch (e) {
    debugPrint('❌❌ Error in doctorEndMeeting: $e');
    _completeCallReset();
  }
}
Future<void> _emergencyMediaReset() async {
  debugPrint('🚨🚨🚨 EMERGENCY MEDIA RESET - Releasing camera/mic locks');
  
  try {
    // 1. Get all media devices to see what's available
    final devices = await navigator.mediaDevices.enumerateDevices();
    debugPrint('   Available devices:');
    for (final device in devices) {
      debugPrint('     ${device.kind}: ${device.label} (${device.deviceId})');
    }
    
    // 2. Try to get a temporary stream to force release any locks
    try {
      final tempStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': false
      });
      // Immediately stop the temporary stream
      tempStream.getTracks().forEach((track) => track.stop());
      debugPrint('   ✅ Temporary media access released locks');
    } catch (e) {
      debugPrint('   ⚠️ Temporary media access failed: $e');
    }
    
    // 3. Wait for system to fully release resources
    await Future.delayed(const Duration(milliseconds: 800));
    
    debugPrint('🚨🚨🚨 EMERGENCY MEDIA RESET COMPLETE');
  } catch (e) {
    debugPrint('❌❌❌ Emergency media reset failed: $e');
  }
}
  // Enhanced cleanup method for WebRTC only
 void _cleanupWebRTC() {
  debugPrint('🧹🧹🧹 COMPLETE WEBRTC CLEANUP STARTING...');
  
  try {
    // 1. Stop and dispose ALL local tracks completely
    if (_localStream != null) {
      debugPrint('   Stopping local stream tracks...');
      final tracks = _localStream!.getTracks();
      for (final track in tracks) {
        try {
          track.stop();
          debugPrint('     🛑 Stopped track: ${track.id} (${track.kind})');
        } catch (e) {
          debugPrint('     ⚠️ Error stopping track ${track.id}: $e');
        }
      }
      
      try {
        _localStream!.dispose();
        debugPrint('   ✅ Local stream disposed');
      } catch (e) {
        debugPrint('   ⚠️ Error disposing local stream: $e');
      }
      _localStream = null;
    }

    // 2. Close peer connection COMPLETELY
    if (_peerConnection != null) {
      debugPrint('   Closing peer connection...');
      try {
        _peerConnection!.close();
        debugPrint('   ✅ PeerConnection closed');
      } catch (e) {
        debugPrint('   ⚠️ Error closing peer connection: $e');
      }
      _peerConnection = null;
    }

    // 3. Force garbage collection delay
    debugPrint('   💤 Waiting for resource release...');
    
    debugPrint('✅✅✅ WEBRTC CLEANUP COMPLETED - Ready for new call');
    
  } catch (e) {
    debugPrint('❌❌❌ CRITICAL ERROR during WebRTC cleanup: $e');
  }
}

  // Reset for new call - SINGLE VERSION
// Add this to TelemedicineService for complete call reset
void resetForNewCall() {
  debugPrint('🔄🔄🔄 COMPLETE RESET FOR NEW CALL...');
  
  try {
    // 1. Clean up WebRTC resources
    _cleanupWebRTC();
    
    // 2. Leave current room but keep socket connection
    if (_currentRoomId != null && _socket?.connected == true) {
      _socket?.emit('leave-room', {'roomId': _currentRoomId});
      debugPrint('   Left room: $_currentRoomId');
    }
    
    // 3. Reset states but keep socket connection alive
    _currentRoomId = null;
    _isConnecting = false;
    _connectionAttempts = 0;
    
    // 4. Clear any pending event handlers
    // Note: Don't clear the main event handlers, just room-specific state
    
    debugPrint('✅✅✅ READY FOR NEW CALL - Complete reset done');
    
  } catch (e) {
    debugPrint('❌❌❌ Error in resetForNewCall: $e');
  }
}
void _completeCallReset() {
  debugPrint('🔄🔄🔄 COMPLETE CALL RESET - Full cleanup');
  
  try {
    // 1. Clean up WebRTC resources
    _cleanupWebRTC();
    
    // 2. Leave current room
    if (_currentRoomId != null && _socket?.connected == true) {
      _socket?.emit('leave-room', {'roomId': _currentRoomId});
      debugPrint('   Left room: $_currentRoomId');
    }
    
    // 3. Reset all states
    _currentRoomId = null;
    _isConnecting = false;
    _connectionAttempts = 0;
    
    debugPrint('✅✅✅ COMPLETE CALL RESET DONE');
    
  } catch (e) {
    debugPrint('❌❌❌ Error in _completeCallReset: $e');
  }
}

  // Complete cleanup
  void dispose() {
    debugPrint('🧹 FULL TelemedicineService disposal');
    _cleanupWebRTC();
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    _currentRoomId = null;
    _userId = null;
    _userType = null;
  }

  // Utility methods
  bool get isConnected => _socket?.connected == true;
  String? get socketId => _socket?.id;
  String? get currentRoomId => _currentRoomId;
  bool get isConnecting => _isConnecting;
}