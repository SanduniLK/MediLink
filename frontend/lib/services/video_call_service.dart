// services/video_call_service.dart - COMPLETE FIXED VERSION
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_webrtc/flutter_webrtc.dart';

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

  // Event callbacks - ADD THE MISSING ONES
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  Function(String)? onError;
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  VoidCallback? onCallEnded;
  Function(Map<String, dynamic>)? onIncomingCall;
  VoidCallback? onCallAccepted;
  Function(String)? onCallRejected;
  VoidCallback? onCallConnected;
  Function(String)? onConnectionState;
  Function(RTCIceConnectionState)? onIceConnectionState;
  Function(dynamic, String)? onOfferReceived; // ADD THIS
  Function(dynamic, String)? onAnswerReceived; // ADD THIS

  // State management
  bool _isInitialized = false;
  bool _hasRemoteDescription = false;
  bool _isSettingRemoteDescription = false;
  bool _isCreatingOffer = false;
  bool _isCreatingAnswer = false;

  // Server URL
  static String getServerUrl() {
    return 'http://192.168.1.126:5001';
  }

  // Public getters
  io.Socket get socket => _socket!;
  bool get isConnected => _socket?.connected ?? false;
  String? get currentRoomId => _currentRoomId;
  String? get userId => _userId;
  String? get userName => _userName;
  bool get isDoctor => _isDoctor;
  bool get isInitialized => _isInitialized;

  // ✅ INITIALIZE SERVICE
  Future<void> initialize({bool isPhysicalDevice = false}) async {
    try {
      debugPrint('🎯 Initializing VideoCallService...');
      
      if (_isInitialized && _socket?.connected == true) {
        debugPrint('✅ Already initialized and connected');
        return;
      }

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
          .build(),
      );

      _setupSocketListeners();
      _socket!.connect();
      
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
    throw Exception('Failed to connect to signaling server');
  }

  // ✅ JOIN ROOM
  Future<void> joinRoom(String roomId, String userId, String userName, bool isDoctor) async {
    try {
      _currentRoomId = roomId;
      _userId = userId;
      _userName = userName;
      _isDoctor = isDoctor;

      debugPrint('🚀 Joining room: $roomId as $userName (Doctor: $isDoctor)');
      
      if (!isConnected) await initialize();

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

  // ✅ ADD MISSING METHOD: Join Patient Room
  Future<void> joinPatientRoom(String patientId) async {
    try {
      debugPrint('👤 Joining patient room: $patientId');
      
      _socket!.emit('patient-join', {
        'patientId': patientId,
        'userName': _userName ?? 'Patient',
        'userId': _userId,
        'socketId': _socket!.id,
      });
      
      debugPrint('✅ Joined patient room: $patientId');
    } catch (e) {
      debugPrint('❌ Error joining patient room: $e');
      rethrow;
    }
  }

  // ✅ ADD MISSING METHOD: Make Video Call
  Future<void> makeCall(String targetUserId) async {
    try {
      debugPrint('📞 Making video call to: $targetUserId');
      
      await _ensurePeerConnectionInitialized();
      final offer = await createOffer();
      
      _socket!.emit('webrtc-offer', {
        'to': _currentRoomId,
        'offer': offer.toMap(),
        'targetUserId': targetUserId,
      });
      
      debugPrint('✅ Video call offer sent');
    } catch (e) {
      debugPrint('❌ Error making video call: $e');
      rethrow;
    }
  }

  // ✅ ADD MISSING METHOD: Make Audio Call
  Future<void> makeAudioCall(String targetUserId) async {
    try {
      debugPrint('🎙️ Making audio call to: $targetUserId');
      
      await _ensurePeerConnectionInitialized();
      
      // Disable video for audio call
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        for (var track in videoTracks) {
          track.enabled = false;
        }
      }
      
      final offer = await createOffer();
      
      _socket!.emit('webrtc-offer', {
        'to': _currentRoomId,
        'offer': offer.toMap(),
      });
      
      debugPrint('✅ Audio call offer sent');
    } catch (e) {
      debugPrint('❌ Error making audio call: $e');
      rethrow;
    }
  }

  // ✅ ADD MISSING METHOD: Handle Incoming Offer
  Future<void> handleIncomingOffer(dynamic data) async {
    try {
      if (_hasRemoteDescription) {
        debugPrint('⚠️ Already have remote description, ignoring duplicate offer');
        return;
      }
      
      final from = data['from'];
      final Map<String, dynamic> offerData = Map<String, dynamic>.from(data['offer']);
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      
      debugPrint('📨 HANDLING INCOMING OFFER from $from');
      
      // Set remote description
      await _setRemoteDescription(offer);
      _hasRemoteDescription = true;
      
      // Create and send answer
      final answer = await createAnswer();
      
      _socket!.emit('webrtc-answer', {
        'to': from,
        'answer': answer.toMap(),
      });
      
      debugPrint('✅ Sent answer to $from');
      
    } catch (e) {
      debugPrint('❌ Error handling incoming offer: $e');
      rethrow;
    }
  }

  // ✅ ADD MISSING METHOD: Force Reconnect
  Future<void> forceReconnect() async {
    try {
      debugPrint('🔄 FORCE RECONNECTING...');
      
      // Reset state
      _hasRemoteDescription = false;
      _isSettingRemoteDescription = false;
      
      // Safe cleanup
      await _peerConnection?.close();
      _peerConnection = null;
      _senders.clear();
      
      // Reinitialize WebRTC
      await _initializeWebRTC();
      
      debugPrint('✅ Force reconnect completed');
    } catch (e) {
      debugPrint('❌ Force reconnect failed: $e');
      rethrow;
    }
  }

  // ✅ ADD MISSING METHOD: Test WebRTC Connection
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
        });
        
        debugPrint('   ✅ Test event sent to server');
      }
      
    } catch (e) {
      debugPrint('❌ WebRTC test failed: $e');
    }
  }

  // ✅ ADD MISSING METHOD: Switch Camera
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

  // ✅ WEBRTC CORE FUNCTIONS
  Future<void> _initializeWebRTC() async {
    try {
      await _createPeerConnection();
      
      final mediaConstraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (_localStream == null) {
        throw Exception('Failed to get local media stream');
      }
      
      debugPrint('🎥 Local stream obtained with audio & video tracks');

      // Add tracks to peer connection
      for (var track in _localStream!.getTracks()) {
        final sender = await _peerConnection!.addTrack(track, _localStream!);
        _senders.add(sender);
      }

      if (onLocalStream != null) {
        onLocalStream!(_localStream!);
      }
      
      debugPrint('✅ WebRTC initialized successfully');

    } catch (e) {
      debugPrint('❌ Error initializing WebRTC: $e');
      await _cleanupWebRTC();
      rethrow;
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      if (_peerConnection != null) {
        await _peerConnection!.close();
      }

      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration, {});
      
      if (_peerConnection == null) {
        throw Exception('Failed to create peer connection');
      }
      
      _setupPeerConnectionListeners();
      debugPrint('✅ Peer connection created successfully');
    } catch (e) {
      debugPrint('❌ Error creating peer connection: $e');
      rethrow;
    }
  }

  void _setupPeerConnectionListeners() {
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _socket!.emit('ice-candidate', {
          'to': _currentRoomId,
          'candidate': candidate.toMap(),
        });
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('🎯 REMOTE TRACK RECEIVED: ${event.track.kind}');
      
      if (event.streams.isNotEmpty) {
        final remoteStream = event.streams.first;
        debugPrint('📹 Remote stream received with ${remoteStream.getTracks().length} tracks');
        
        if (onRemoteStream != null) {
          onRemoteStream!(remoteStream);
        }
        
        onCallConnected?.call();
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('🧊 ICE Connection State: $state');
      onIceConnectionState?.call(state);
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    await _ensurePeerConnectionInitialized();
    
    _isCreatingOffer = true;
    
    try {
      debugPrint('🎯 Creating WebRTC offer...');
      
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      
      await _peerConnection!.setLocalDescription(offer);
      debugPrint('✅ Offer created and local description set');
      
      return offer;
    } catch (e) {
      debugPrint('❌ Error creating offer: $e');
      rethrow;
    } finally {
      _isCreatingOffer = false;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    await _ensurePeerConnectionInitialized();
    
    _isCreatingAnswer = true;
    
    try {
      debugPrint('🎯 Creating WebRTC answer...');
      
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('✅ Answer created and local description set');
      
      return answer;
    } catch (e) {
      debugPrint('❌ Error creating answer: $e');
      rethrow;
    } finally {
      _isCreatingAnswer = false;
    }
  }

  // ✅ SOCKET EVENT HANDLERS
  void _setupSocketListeners() {
    _socket!.onConnect((_) {
      debugPrint('🎉 SOCKET.IO CONNECTED!');
      onConnected?.call();
    });

    // Handle WebRTC offers
    _socket!.on('webrtc-offer', (data) async {
      debugPrint('📨 WebRTC OFFER RECEIVED');
      
      if (onOfferReceived != null) {
        onOfferReceived!(data['offer'], data['from']);
      } else {
        await handleIncomingOffer(data);
      }
    });

    // Handle WebRTC answers
    _socket!.on('webrtc-answer', (data) async {
      debugPrint('✅ WebRTC ANSWER received');
      
      try {
        final Map<String, dynamic> answerData = Map<String, dynamic>.from(data['answer']);
        final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
        
        await _setRemoteDescription(answer);
        _hasRemoteDescription = true;
        
        onCallAccepted?.call();
        
      } catch (e) {
        debugPrint('❌ Error handling answer: $e');
      }
    });

    // Handle incoming calls
    _socket!.on('incoming-call', (data) {
      debugPrint('📞 INCOMING CALL RECEIVED');
      if (onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('call-started', (data) {
      debugPrint('📞 CALL STARTED RECEIVED');
      if (onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
    });

    // ICE candidates
    _socket!.on('ice-candidate', (data) async {
      await _handleIceCandidate(data);
    });

    // Call ended
    _socket!.on('call-ended', (data) {
      debugPrint('📞 CALL ENDED REMOTELY');
      onCallEnded?.call();
    });
  }

  Future<void> _setRemoteDescription(RTCSessionDescription description) async {
    await _ensurePeerConnectionInitialized();
    await _peerConnection!.setRemoteDescription(description);
    debugPrint('✅ Remote description set: ${description.type}');
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
    } catch (e) {
      debugPrint('❌ Error handling ICE candidate: $e');
    }
  }

  // ✅ MEDIA CONTROLS
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

  // ✅ UTILITY FUNCTIONS
  bool get isPeerConnectionReady => _peerConnection != null;

  Future<void> _ensurePeerConnectionInitialized() async {
    if (!isPeerConnectionReady) {
      await _createPeerConnection();
    }
  }

  Future<void> _cleanupWebRTC() async {
    try {
      _localStream?.dispose();
      await _peerConnection?.close();
      _localStream = null;
      _peerConnection = null;
      _senders.clear();
    } catch (e) {
      debugPrint('❌ Error during WebRTC cleanup: $e');
    }
  }

  // ✅ END CALL
  void endCall() {
    debugPrint('📞 Ending call...');
    
    _socket!.emit('end-call', {'roomId': _currentRoomId});
    _socket!.emit('leave-call-room', _currentRoomId);
    
    _cleanupWebRTC();
    debugPrint('✅ Call ended');
  }

  void dispose() {
    endCall();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}