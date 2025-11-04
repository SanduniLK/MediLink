// services/video_call_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class VideoCallService {
  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<RTCRtpSender> _senders = [];
  
  // Connection info
  String? _currentRoomId;
  String? _userId;
  String? _userName;
  bool _isDoctor = false;

  Function(dynamic, String)? onOfferReceived;
  Function(dynamic, String)? onAnswerReceived;
  Function(List<dynamic>)? onIceCandidateReceived;

  // Add connection state tracking
  bool get isInitialized => _isInitialized;
  bool _isInitialized = false;
  
  // Signaling state management
  bool _isMakingOffer = false;
  bool _isIgnoringOffer = false;
  bool _isSettingRemoteAnswer = false;
  
  // Event callbacks
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  Function(String)? onError;
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  VoidCallback? onCallEnded;
  Function(Map<String, dynamic>)? onIncomingCall;
  VoidCallback? onCallAccepted;
  Function(String)? onConnectionState;
  Function(RTCIceConnectionState)? onIceConnectionState;

  // Public getters
  io.Socket get socket => _socket!;
  bool get isConnected => _socket?.connected ?? false;
  String? get currentRoomId => _currentRoomId;
  String? get userId => _userId;
  String? get userName => _userName;
  bool get isDoctor => _isDoctor;
  
  // Polite peer logic
  bool get _isPolite => !_isDoctor;

  // Server URL method
  static String getServerUrl() {
    return 'http://192.168.1.126:5001';
  }

  // In your VideoCallService - FIXED connection handling
Future<void> initialize({bool isPhysicalDevice = false}) async {
  try {
    debugPrint('🎯 Initializing VideoCallService...');
    
    final serverUrl = getServerUrl();
    debugPrint('🔗 Connecting to: $serverUrl');

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .disableAutoConnect()
        .setTimeout(30000)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setRandomizationFactor(0.5)
        .build(),
    );

    _setupSocketListeners();
    _socket!.connect();
    
    // Wait for connection with timeout
    await _waitForConnection();
    
    _isInitialized = true;
    debugPrint('✅ VideoCallService initialization completed');
    
  } catch (e) {
    debugPrint('❌ Error initializing VideoCallService: $e');
    rethrow;
  }
}

Future<void> _waitForConnection({int timeoutSeconds = 15}) async {
  for (int i = 0; i < timeoutSeconds * 2; i++) {
    if (_socket?.connected == true) {
      debugPrint('✅ Connected to signaling server');
      return;
    }
    await Future.delayed(Duration(milliseconds: 500));
  }
  throw Exception('Failed to connect to signaling server after $timeoutSeconds seconds');
}

Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      
      await _peerConnection!.setLocalDescription(offer);
      debugPrint('✅ Offer created successfully');
      return offer;
    } catch (e) {
      debugPrint('❌ Error creating offer: $e');
      rethrow;
    }
  }
   Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('✅ Answer created successfully');
      return answer;
    } catch (e) {
      debugPrint('❌ Error creating answer: $e');
      rethrow;
    }
  }
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      await _peerConnection!.setRemoteDescription(description);
      debugPrint('✅ Remote description set successfully');
    } catch (e) {
      debugPrint('❌ Error setting remote description: $e');
      rethrow;
    }
  }

  // Server status check method
  Future<bool> _checkServerStatus() async {
    try {
      debugPrint('🔍 Checking server connectivity...');
      
      final client = http.Client();
      final serverUrl = 'http://192.168.1.126:5001';
      
      final response = await client.get(
        Uri.parse('$serverUrl/api/webrtc/health')
      ).timeout(const Duration(seconds: 5));
      
      client.close();

      if (response.statusCode == 200) {
        debugPrint('✅ Server is running and accessible!');
        return true;
      } else {
        debugPrint('❌ Server returned status: ${response.statusCode}');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Server check failed: $e');
      return false;
    }
  }

  void _setupSocketListeners() {
    if (_socket == null) return;

    Timer? connectionTimer;
    
    _socket!.onConnect((_) {
      debugPrint('🎉 SOCKET.IO CONNECTED SUCCESSFULLY!');
      debugPrint('   Socket ID: ${_socket!.id}');
      connectionTimer?.cancel();
      onConnected?.call();
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔴 SOCKET.IO DISCONNECTED');
      onDisconnected?.call();
    });

    _socket!.onConnectError((error) {
      debugPrint('🔴 SOCKET CONNECTION ERROR: $error');
      onError?.call('Connection failed: $error');
    });

    _socket!.onError((error) {
      debugPrint('🔴 SOCKET ERROR: $error');
      onError?.call('Socket error: $error');
    });

    // Monitor connection progress
    connectionTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (_socket == null) {
        timer.cancel();
        return;
      }
      if (_socket!.connected) {
        debugPrint("✅ Socket is connected to the server");
      } else {
        debugPrint("⏳ Waiting for socket connection... (${timer.tick * 2}s)");
      }
    });

    // Debug all events
    _socket!.onAny((event, data) {
      if (event != 'ice-candidate' && event != 'ping' && event != 'pong') {
        debugPrint('📡 SOCKET EVENT: "$event" → ${data != null ? data.toString() : "null"}');
      }
    });

    // WebRTC specific handlers
    _socket!.on('call-started', (data) {
      debugPrint('📞 INCOMING CALL RECEIVED!');
      if (data is Map<String, dynamic>) {
        onIncomingCall?.call(data);
      } else {
        onIncomingCall?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('incoming-call', (data) {
      debugPrint('📞 INCOMING CALL (alternate event)');
      if (data is Map<String, dynamic>) {
        onIncomingCall?.call(data);
      } else {
        onIncomingCall?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('webrtc-offer', (data) async {
      debugPrint('🎉 🎉 🎉 WEBRTC OFFER FINALLY RECEIVED! 🎉 🎉 🎉');
      debugPrint('   From: ${data['from']}');
      debugPrint('   Room: $_currentRoomId');
      debugPrint('   Offer data: ${data.containsKey('offer')}');
      
      await _handleOffer(data);
    });

    _socket!.on('webrtc-answer', (data) async {
      debugPrint('📨 WebRTC ANSWER received');
      await _handleAnswer(data);
    });

    _socket!.on('ice-candidate', (data) async {
      debugPrint('🧊 ICE CANDIDATE received');
      await _handleIceCandidate(data);
    });

    _socket!.on('test-response', (data) {
      debugPrint('🧪 TEST RESPONSE: $data');
    });
  }

  Future<void> testWebRTCConnection() async {
    try {
      debugPrint('🧪 TESTING WEBRTC CONNECTION...');
      
      if (_socket == null) {
        debugPrint('❌ Socket not initialized');
        return;
      }
      
      debugPrint('   Socket connected: ${_socket!.connected}');
      debugPrint('   Socket ID: ${_socket!.id}');
      debugPrint('   Current room: $_currentRoomId');
      
      if (_socket!.connected) {
        _socket!.emit('test-connection', {
          'client': 'flutter_app',
          'userId': _userId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'message': 'WebRTC connection test'
        });
        
        debugPrint('   ✅ Test event sent to server');
      } else {
        debugPrint('   ⚠️ Socket not connected yet');
      }
      
    } catch (e) {
      debugPrint('❌ WebRTC test failed: $e');
    }
  }

  Future<void> joinRoom(String roomId, String userId, String userName, bool isDoctor) async {
    try {
      _currentRoomId = roomId;
      _userId = userId;
      _userName = userName;
      _isDoctor = isDoctor;

      debugPrint('🚀 Joining room: $roomId as $userName (Doctor: $isDoctor)');
      
      _socket!.emit('join-call-room', {
        'roomId': roomId,
        'userId': userId,
        'userName': userName,
        'isDoctor': isDoctor,
      });
      
      await _initializeWebRTC();
      
      debugPrint('✅ Successfully joined room: $roomId');
    } catch (e) {
      debugPrint('❌ Error joining room: $e');
      rethrow;
    }
  }

  Future<void> joinPatientRoom(String patientId) async {
    try {
      debugPrint('👤 Joining patient room: $patientId');
      _socket!.emit('patient-join', {
        'patientId': patientId,
        'userName': _userName,
      });
    } catch (e) {
      debugPrint('❌ Error joining patient room: $e');
      rethrow;
    }
  }

  Future<void> _initializeWebRTC() async {
    try {
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      });

      // Set up event handlers
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          debugPrint('🧊 Sending ICE candidate: ${candidate.candidate}');
          _socket!.emit('ice-candidate', {
            'to': _currentRoomId,
            'candidate': candidate.toMap(),
          });
        }
      };

      _peerConnection!.onAddStream = (stream) {
        debugPrint('📹 Remote stream received');
        onRemoteStream?.call(stream);
      };

      _peerConnection!.onConnectionState = (state) {
        debugPrint('🔗 Connection state: $state');
        onConnectionState?.call(state.toString());
      };

      _peerConnection!.onIceConnectionState = (state) {
        debugPrint('🧊 ICE connection state: $state');
        onIceConnectionState?.call(state);
      };

      // Signaling state listener
      _peerConnection!.onSignalingState = (state) {
        debugPrint('📶 Signaling state: $state');
        _handleSignalingStateChange(state);
      };

      // Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': _isDoctor ? {
          'facingMode': 'user',
          'width': 1280,
          'height': 720,
        } : true,
      });

      debugPrint('🎥 Local stream obtained with ${_localStream!.getVideoTracks().length} video tracks');

      // Add tracks to peer connection
      for (var track in _localStream!.getTracks()) {
        _senders.add(await _peerConnection!.addTrack(track, _localStream!));
      }

      onLocalStream?.call(_localStream!);
      debugPrint('✅ WebRTC initialized successfully');

    } catch (e) {
      debugPrint('❌ Error initializing WebRTC: $e');
      rethrow;
    }
  }

  // Signaling state handler
  void _handleSignalingStateChange(RTCSignalingState state) {
    switch (state) {
      case RTCSignalingState.RTCSignalingStateStable:
        _isMakingOffer = false;
        _isSettingRemoteAnswer = false;
        break;
      case RTCSignalingState.RTCSignalingStateHaveLocalOffer:
        _isMakingOffer = true;
        break;
      case RTCSignalingState.RTCSignalingStateHaveRemoteOffer:
        _isMakingOffer = false;
        break;
      default:
        break;
    }
  }

  Future<void> forceReconnect() async {
    try {
      debugPrint('🔄 FORCE RECONNECTING...');
      
      // Close existing connection
      await _peerConnection?.close();
      _peerConnection = null;
      
      // Reinitialize
      await _initializeWebRTC();
      
      // Rejoin room
      if (_currentRoomId != null && _userId != null && _userName != null) {
        await joinRoom(_currentRoomId!, _userId!, _userName!, _isDoctor);
      }
      
      debugPrint('✅ Force reconnect completed');
    } catch (e) {
      debugPrint('❌ Force reconnect failed: $e');
    }
  }

  // Make call with collision prevention
  Future<void> makeCall(String targetUserId) async {
    try {
      // Prevent multiple simultaneous offers
      if (_isMakingOffer) {
        debugPrint('⚠️ Already making an offer, skipping...');
        return;
      }
      
      _isMakingOffer = true;
      
      debugPrint('📞 Making video call to: $targetUserId');
      
      final offer = await _peerConnection!.createOffer();
      await _setLocalDescription(offer);
      
      _socket!.emit('webrtc-offer', {
        'to': _currentRoomId,
        'offer': offer.toMap(),
      });
      
      debugPrint('✅ Video call offer sent');
    } catch (e) {
      debugPrint('❌ Error making video call: $e');
      _isMakingOffer = false;
      rethrow;
    }
  }

  // Make audio call with collision prevention
  Future<void> makeAudioCall(String targetUserId) async {
    try {
      if (_isMakingOffer) {
        debugPrint('⚠️ Already making an offer, skipping...');
        return;
      }
      
      _isMakingOffer = true;
      
      debugPrint('🎙️ Making audio call to: $targetUserId');
      
      // For audio-only calls, disable video track
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        for (var track in videoTracks) {
          track.enabled = false;
        }
      }
      
      final offer = await _peerConnection!.createOffer();
      await _setLocalDescription(offer);
      
      _socket!.emit('webrtc-offer', {
        'to': _currentRoomId,
        'offer': offer.toMap(),
      });
      
      debugPrint('✅ Audio call offer sent');
    } catch (e) {
      debugPrint('❌ Error making audio call: $e');
      _isMakingOffer = false;
      rethrow;
    }
  }

  // Safe local description setter
  Future<void> _setLocalDescription(RTCSessionDescription description) async {
    try {
      await _peerConnection!.setLocalDescription(description);
    } catch (e) {
      debugPrint('❌ Error setting local description: $e');
      rethrow;
    }
  }

  Future<void> notifyPatientCallStarted(String patientId, String roomId, String doctorName, {String consultationType = 'video'}) async {
    try {
      debugPrint('🔔 Notifying patient $patientId about $consultationType call');
      
      _socket!.emit('notify-call-started', {
        'patientId': patientId,
        'roomId': roomId,
        'doctorName': doctorName,
        'doctorId': _userId,
        'consultationType': consultationType,
      });
      
      debugPrint('✅ Patient notification sent');
    } catch (e) {
      debugPrint('❌ Error notifying patient: $e');
      rethrow;
    }
  }

  // Offer handling with collision detection
  Future<void> _handleOffer(dynamic data) async {
    try {
      final from = data['from'];
      final Map<String, dynamic> offerData = Map<String, dynamic>.from(data['offer']);
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      
      debugPrint('📨 WebRTC OFFER received from $from');
      debugPrint('   Current signaling state: ${_peerConnection?.signalingState}');
      debugPrint('   Is making offer: $_isMakingOffer');

      // COLLISION DETECTION & RESOLUTION
      bool collision = _isMakingOffer || _peerConnection?.signalingState != RTCSignalingState.RTCSignalingStateStable;
      
      if (collision) {
        debugPrint('🔄 Offer collision detected!');
        
        if (!_isPolite) {
          // Impolite peer (doctor) ignores collision
          debugPrint('   👨‍⚕️ Doctor ignoring collision');
          return;
        } else {
          // Polite peer (patient) rolls back by creating a new connection
          debugPrint('   👤 Patient handling collision - creating new answer');
          // Instead of rollback, we'll handle it by creating a new answer
        }
      }

      // Set remote description
      await _setRemoteDescription(offer);
      
      // Create and send answer
      final answer = await _peerConnection!.createAnswer();
      await _setLocalDescription(answer);
      
      _socket!.emit('webrtc-answer', {
        'to': from,
        'answer': answer.toMap(),
      });
      
      debugPrint('✅ Handled offer and sent answer to $from');
    } catch (e) {
      debugPrint('❌ Error handling offer: $e');
      onError?.call('Failed to handle offer: $e');
    }
  }

  // Answer handling
  Future<void> _handleAnswer(dynamic data) async {
    try {
      final from = data['from'];
      final Map<String, dynamic> answerData = Map<String, dynamic>.from(data['answer']);
      final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
      
      debugPrint('📨 WebRTC ANSWER received from $from');
      
      await _setRemoteDescription(answer);
      
      debugPrint('✅ Handled answer from $from');
    } catch (e) {
      debugPrint('❌ Error handling answer: $e');
    }
  }

  // Safe remote description setter
  Future<void> _setRemoteDescription(RTCSessionDescription description) async {
    try {
      await _peerConnection!.setRemoteDescription(description);
    } catch (e) {
      debugPrint('❌ Error setting remote description: $e');
      debugPrint('   Current state: ${_peerConnection?.signalingState}');
      
      // Handle offer collision in setRemoteDescription
      if (e.toString().contains('have-local-offer') && description.type == 'offer') {
        debugPrint('🔄 Offer collision detected in setRemoteDescription');
        await _handleOfferCollision(description);
      } else {
        rethrow;
      }
    }
  }

  // SIMPLIFIED: Offer collision handler without RTCSdpType
  Future<void> _handleOfferCollision(RTCSessionDescription offer) async {
    try {
      debugPrint('🔄 Handling offer collision by creating new answer...');
      
      // For flutter_webrtc, we can't use rollback, so we handle it differently
      // by creating a new answer after setting the remote description
      await _peerConnection!.setRemoteDescription(offer);
      
      final answer = await _peerConnection!.createAnswer();
      await _setLocalDescription(answer);
      
      _socket!.emit('webrtc-answer', {
        'to': _currentRoomId,
        'answer': answer.toMap(),
      });
      
      debugPrint('✅ Recovered from offer collision');
    } catch (e) {
      debugPrint('❌ Error handling offer collision: $e');
      
      // If collision handling fails, try to reinitialize the connection
      debugPrint('🔄 Attempting to reinitialize WebRTC connection...');
      try {
        await _peerConnection?.close();
        await _initializeWebRTC();
        debugPrint('✅ WebRTC reinitialized after collision');
      } catch (reinitError) {
        debugPrint('❌ Failed to reinitialize WebRTC: $reinitError');
      }
    }
  }

  Future<void> _handleIceCandidate(dynamic data) async {
    try {
      final Map<String, dynamic> candidateData = Map<String, dynamic>.from(data['candidate']);
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'] ?? '',
        candidateData['sdpMLineIndex'] ?? 0,
      );
      await _peerConnection!.addCandidate(candidate);
      debugPrint('✅ Handled ICE candidate');
    } catch (e) {
      debugPrint('❌ Error handling ICE candidate: $e');
    }
  }

  Future<bool> toggleAudio() async {
    try {
      if (_localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          final newState = !audioTracks.first.enabled;
          audioTracks.first.enabled = newState;
          debugPrint('🎙️ Audio ${newState ? 'unmuted' : 'muted'}');
          return newState;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error toggling audio: $e');
      return false;
    }
  }

  Future<bool> toggleVideo() async {
    try {
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final newState = !videoTracks.first.enabled;
          videoTracks.first.enabled = newState;
          debugPrint('📹 Video ${newState ? 'enabled' : 'disabled'}');
          return newState;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error toggling video: $e');
      return false;
    }
  }

  Future<void> switchCamera() async {
    try {
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          await Helper.switchCamera(videoTracks.first);
          debugPrint('🔄 Camera switched');
        }
      }
    } catch (e) {
      debugPrint('❌ Error switching camera: $e');
    }
  }

  void endCall() {
    debugPrint('📞 Ending call and cleaning up...');
    
    _socket!.emit('end-call', {'roomId': _currentRoomId});
    _socket!.emit('leave-call-room', _currentRoomId);
    
    _localStream?.dispose();
    _peerConnection?.close();
    
    _localStream = null;
    _peerConnection = null;
    _senders.clear();
    
    // Reset state
    _isMakingOffer = false;
    _isIgnoringOffer = false;
    _isSettingRemoteAnswer = false;
    
    debugPrint('✅ Call ended and resources cleaned up');
  }

  void dispose() {
    debugPrint('♻️ Disposing VideoCallService...');
    endCall();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}