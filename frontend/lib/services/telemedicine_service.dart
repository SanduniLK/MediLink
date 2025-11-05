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

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan'
  };

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

  // Initialize socket connection
    void initializeSocket(String serverUrl, String userId, String userType) {
      String finalUrl = serverUrl;
  if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
    finalUrl = 'http://$serverUrl';
    debugPrint('⚠️ Added http:// protocol to URL: $finalUrl');
  }
  debugPrint('🔌 Connecting to: $finalUrl');

  _socket = io.io(finalUrl, <String, dynamic>{
    'transports': ['websocket', 'polling'],
    'autoConnect': false,
    'forceNew': true,
    'timeout': 10000,
    'reconnection': false,
  });
    // Prevent multiple simultaneous connection attempts
    if (_isConnecting) {
      debugPrint('⚠️ Already attempting connection, skipping...');
      return;
    }
    
    _isConnecting = true;
    _connectionAttempts++;
    
    _userId = userId;
    _userType = userType;
    
    debugPrint('🔌 Attempting socket connection (attempt $_connectionAttempts/$MAX_CONNECTION_ATTEMPTS) to: $serverUrl');
    debugPrint('👤 User: $userId, Type: $userType');
    
    try {
      // Clean up previous socket
      _socket?.disconnect();
      _socket?.destroy();
      _socket = null;
      
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false, // Manual connection for better control
        'forceNew': true,
        'timeout': 10000,
        'reconnection': false, // We handle reconnection manually
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
      // Auto-retry after delay
      Future.delayed(const Duration(seconds: 2), () {
        _retryConnection(); // REMOVED the mounted check here
      });
    } else {
      debugPrint('❌ ❌ ❌ MAX CONNECTION ATTEMPTS REACHED');
      onConnectionError?.call('Failed to connect after $_connectionAttempts attempts: $error');
    }
  }
   void _retryConnection() {
    if (_userId != null && _userType != null) {
      // Clear current socket and retry
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
      debugPrint('📞 Call ended: $data');
      onCallEnded?.call(data);
    });

    _socket!.on('call-rejected', (data) {
      debugPrint('❌ Call rejected: $data');
      onCallRejected?.call(data);
    });

    _socket!.on('user-joined', (data) {
      debugPrint('👤 User joined room: $data');
      onUserJoined?.call(data);
    });

    _socket!.on('user-left', (data) {
      debugPrint('🚪 User left room: $data');
      onUserLeft?.call(data);
    });

    _socket!.on('disconnect', (reason) {
      debugPrint('❌ Disconnected from server: $reason');
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
  }

  // Patient: Answer call
  void answerCall(String roomId, dynamic answer) {
    _socket?.emit('patient-answer-call', {
      'roomId': roomId,
      'answer': answer,
    });
  }

  // Patient: Reject call - ADDED METHOD
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

  // Send media state change - ADDED METHOD
  void sendMediaStateChange(bool isVideoEnabled, bool isAudioEnabled) {
    if (_currentRoomId != null) {
      // Send video state
      _socket?.emit('media-state-changed', {
        'roomId': _currentRoomId,
        'mediaType': 'video',
        'enabled': isVideoEnabled,
      });
      
      // Send audio state
      _socket?.emit('media-state-changed', {
        'roomId': _currentRoomId,
        'mediaType': 'audio',
        'enabled': isAudioEnabled,
      });
      
      debugPrint('🎛️ Media state changed - Video: $isVideoEnabled, Audio: $isAudioEnabled');
    }
  }

  // End call
  void endCall(String endedBy) {
    _socket?.emit('end-call', {
      'roomId': _currentRoomId,
      'endedBy': endedBy,
    });
    _cleanup();
  }

  // Initialize WebRTC
Future<void> initializeWebRTC(bool isVideo) async {
  try {
    debugPrint('🔄 INITIALIZING WEBRTC...');
    
    // Clean up existing connection
    _peerConnection?.close();
    _localStream?.getTracks().forEach((track) => track.stop());
    
    // Create peer connection with better configuration
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan'
    });
    
    debugPrint('   ✅ PeerConnection created');
    
    // Set up event handlers
    _peerConnection!.onIceCandidate = (candidate) {
      debugPrint('🧊 ICE candidate: ${candidate.candidate}');
      if (_currentRoomId != null) {
        sendICECandidate(_currentRoomId!, candidate.toMap());
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('📹 📹 📹 REMOTE TRACK RECEIVED: ${event.track.kind}');
      debugPrint('   Track id: ${event.track.id}');
      debugPrint('   Track enabled: ${event.track.enabled}');
      debugPrint('   Streams count: ${event.streams.length}');
      
      if (event.streams.isNotEmpty) {
        final remoteStream = event.streams.first;
        debugPrint('   Remote stream id: ${remoteStream.id}');
        debugPrint('   Remote audio tracks: ${remoteStream.getAudioTracks().length}');
        debugPrint('   Remote video tracks: ${remoteStream.getVideoTracks().length}');
        
        // Notify about remote stream
        onRemoteStream?.call(remoteStream);
      }
    };

    _peerConnection!.onAddStream = (stream) {
      debugPrint('📹 ADD STREAM: ${stream.id}');
      onRemoteStream?.call(stream);
    };

    // Get user media with proper audio configuration
    debugPrint('   Getting user media...');
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
    debugPrint('   ✅ Local media stream obtained');
    
    // Log local tracks
    final audioTracks = _localStream!.getAudioTracks();
    final videoTracks = _localStream!.getVideoTracks();
    debugPrint('   Local audio tracks: ${audioTracks.length}');
    debugPrint('   Local video tracks: ${videoTracks.length}');
    
    if (audioTracks.isNotEmpty) {
      debugPrint('   Audio track: ${audioTracks.first.id}');
      debugPrint('   Audio enabled: ${audioTracks.first.enabled}');
    }
    
    if (videoTracks.isNotEmpty) {
      debugPrint('   Video track: ${videoTracks.first.id}');
      debugPrint('   Video enabled: ${videoTracks.first.enabled}');
    }
    
    // Add tracks to peer connection
    debugPrint('   Adding tracks to PeerConnection...');
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
      debugPrint('     Added ${track.kind} track: ${track.id}');
    }
    
    // Notify about local stream
    onLocalStream?.call(_localStream!);
    debugPrint('✅ WEBRTC INITIALIZED SUCCESSFULLY');
    
  } catch (e, stackTrace) {
    debugPrint('❌ WEBRTC INITIALIZATION FAILED: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

  // Create WebRTC offer
Future<dynamic> createOffer() async {
  try {
    debugPrint('📞 Creating WebRTC offer...');
    
    // DEBUG: Check peerConnection state
    debugPrint('   PeerConnection state: ${_peerConnection != null ? "INITIALIZED" : "NULL"}');
    
    if (_peerConnection == null) {
      debugPrint('❌ CRITICAL: PeerConnection is NULL - WebRTC not initialized properly');
      debugPrint('   Reinitializing WebRTC...');
      await initializeWebRTC(true); // Reinitialize with video
      
      if (_peerConnection == null) {
        throw Exception('WebRTC failed to initialize - PeerConnection is still null');
      }
    }
    
    // Create offer
    debugPrint('   Creating offer...');
    final offer = await _peerConnection!.createOffer();
    debugPrint('   Offer type: ${offer.type}');
    debugPrint('   SDP length: ${offer.sdp?.length ?? 0}');
    
    // Set local description
    debugPrint('   Setting local description...');
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
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, type)
    );
    debugPrint('   ✅ Remote description set');
    
    // Create and set local answer
    debugPrint('   Creating answer...');
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    debugPrint('   ✅ Answer created and set');
    
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
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, type)
    );
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

  // Cleanup
  void _cleanup() {
    debugPrint('🧹 Cleaning up WebRTC resources...');
    
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;
    
    _peerConnection?.close();
    _peerConnection = null;
    
    debugPrint('✅ WebRTC resources cleaned up');
  }

  void dispose() {
    _cleanup();
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }

  // Utility methods
  bool get isConnected => _socket?.connected == true;
  String? get socketId => _socket?.id;
  String? get currentRoomId => _currentRoomId;
}