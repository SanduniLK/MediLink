// services/video_call_service.dart - FIXED
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class VideoCallService {
  late io.Socket _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<RTCRtpSender> _senders = [];

  bool _isInitialized = false;

  // Update with your signaling server URL
  final String _socketUrl = 'http://192.168.1.100:5001'; // Change to your server IP

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(Map<String, dynamic>)? onIncomingCall;
  Function()? onCallAccepted;
  Function()? onCallEnded;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;

  String? _currentRoomId;
  String? _userId;
  String? _userName;
  bool? _isDoctor;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _initializePermissions();
      await _initializeSocket();
      _isInitialized = true;
      debugPrint('✅ VideoCallService initialized successfully');
    } catch (e) {
      debugPrint('❌ VideoCallService initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _initializePermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.bluetoothConnect.request();
  }
io.Socket get socket => _socket;
  Future<void> _initializeSocket() async {
    try {
      _socket = io.io(
        _socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .build(),
      );

      _setupSocketListeners();
      _socket.connect();
      debugPrint('🔄 Connecting to signaling server: $_socketUrl');
    } catch (e) {
      debugPrint('❌ Socket init error: $e');
      onError?.call(e.toString());
    }
  }

  void _setupSocketListeners() {
    _socket.onConnect((_) {
      debugPrint('✅ Connected to signaling server: ${_socket.id}');
      onConnected?.call();
    });

    _socket.onDisconnect((_) {
      debugPrint('❌ Disconnected from signaling server');
      onDisconnected?.call();
    });

    _socket.on('incoming-call', (data) {
      debugPrint('📞 Incoming call: ${data['fromUserName']}');
      onIncomingCall?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call-accepted', (_) {
      debugPrint('✅ Call accepted');
      onCallAccepted?.call();
    });

    _socket.on('webrtc-offer', (data) async {
      debugPrint('📨 Received WebRTC offer');
      await _handleOffer(Map<String, dynamic>.from(data));
    });

    _socket.on('webrtc-answer', (data) async {
      debugPrint('📨 Received WebRTC answer');
      await _handleAnswer(Map<String, dynamic>.from(data));
    });

    _socket.on('ice-candidate', (data) async {
      await _handleIceCandidate(Map<String, dynamic>.from(data));
    });

    _socket.on('call-ended', (_) {
      debugPrint('📞 Call ended');
      _cleanUp();
      onCallEnded?.call();
    });

    _socket.on('call-error', (data) {
      final message = data['message'] ?? 'Unknown error';
      debugPrint('❌ Call error: $message');
      onError?.call(message);
    });

    // Patient notification listener
    _socket.on('call-started', (data) {
      debugPrint('🎉 Received call notification from Dr. ${data['doctorName']}');
      if (onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
    });

    // Fallback patient notification
    _socket.on('call-started-patient-', (data) {
      debugPrint('🔄 Fallback call notification received');
      if (onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
    });
    _socket.on('call-notification', (data) {
      debugPrint('📞 PATIENT: Call notification received: $data');
      final callData = Map<String, dynamic>.from(data);
      _handleIncomingCallNotification(callData);
    });
     _socket.on('doctor-call-started', (data) {
      debugPrint('🎉 PATIENT: Doctor started call: $data');
      final callData = Map<String, dynamic>.from(data);
      onIncomingCall?.call(callData);
    });
  }
  
  void _handleIncomingCallNotification(Map<String, dynamic> callData) {
    debugPrint('🎉 PATIENT: INCOMING CALL NOTIFICATION!');
    debugPrint('   - Doctor: ${callData['doctorName']}');
    debugPrint('   - Room ID: ${callData['roomId']}');
    debugPrint('   - Doctor ID: ${callData['doctorId']}');
    
    // Store the room ID for joining later
    _currentRoomId = callData['roomId'];
    
    // Trigger the incoming call callback
    onIncomingCall?.call(callData);
  }

  // Join patient's personal room for notifications
   Future<void> joinPatientRoom(String patientId) async {
    try {
      if (!_isInitialized) await initialize();
      
      _userId = patientId;
      _isDoctor = false;
      
      _socket.emit('join-patient-room', {
        'patientId': patientId,
        'patientName': _userName ?? 'Patient'
      });
      
      debugPrint('👤 PATIENT: Joined personal notification room: $patientId');
    } catch (e) {
      debugPrint('❌ Error joining patient room: $e');
      rethrow;
    }
  }
Future<void> startCallAsDoctor(String patientId, String roomId, String doctorName) async {
    try {
      if (!_isInitialized) await initialize();

      _currentRoomId = roomId;
      _isDoctor = true;

      // Join the call room first
      _socket.emit('join-call-room', roomId);

      // Notify the patient
      _socket.emit('doctor-start-call', {
        'patientId': patientId,
        'roomId': roomId,
        'doctorName': doctorName,
        'doctorId': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('📞 DOCTOR: Started call for patient $patientId in room $roomId');
    } catch (e) {
      debugPrint('❌ Error starting call as doctor: $e');
      rethrow;
    }
  }

  
  // Join call room
  Future<void> joinRoom(String roomId, String userId, String userName, bool isDoctor) async {
    try {
      _currentRoomId = roomId;
      _userId = userId;
      _userName = userName;
      _isDoctor = isDoctor;

      _socket.emit('join-call-room', roomId);
      debugPrint('🚪 Joined room: $roomId as $userName (Doctor: $isDoctor)');
    } catch (e) {
      debugPrint('❌ Error joining room: $e');
      rethrow;
    }
  }

  // Make a call to another user
  Future<void> makeCall(String targetUserId) async {
    await _initiateCall(targetUserId, 'video');
  }

  // ✅ FIXED: Remove the duplicate _initiateCall method and keep only this one
  Future<void> _initiateCall(String targetUserId, String callType) async {
    try {
      await _createPeerConnection();
      await _initializeLocalStream(callType); // ✅ FIXED: Add parameter

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': callType == 'video',
      });

      await _peerConnection!.setLocalDescription(offer);

      _socket.emit('initiate-call', {
        'targetUserId': targetUserId,
        'roomId': _currentRoomId,
        'offer': offer.toMap(),
        'callerName': _userName,
        'callType': callType,
        'callerId': _userId,
      });

      debugPrint('📞 $callType call initiated to $targetUserId');
    } catch (e) {
      debugPrint('❌ Error initiating call: $e');
      onError?.call(e.toString());
    }
  }

  // Accept an incoming call
  Future<void> acceptCall(Map<String, dynamic> callData) async {
    try {
      await _createPeerConnection();
      await _initializeLocalStream(callData['callType'] ?? 'video'); // ✅ FIXED: Add parameter

      final offer = RTCSessionDescription(
        callData['offer']['sdp'],
        callData['offer']['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': callData['callType'] == 'video',
      });

      await _peerConnection!.setLocalDescription(answer);

      _socket.emit('accept-call', {
        'to': callData['from'],
        'answer': answer.toMap(),
      });

      debugPrint('✅ Call accepted and answer sent');
    } catch (e) {
      debugPrint('❌ Error accepting call: $e');
      onError?.call(e.toString());
    }
  }

  // Create WebRTC peer connection
  Future<void> _createPeerConnection() async {
    try {
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _socket.emit('ice-candidate', {
          'candidate': candidate.toMap(),
          'to': _currentRoomId,
        });
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        debugPrint('🎥 Remote stream received');
        onRemoteStream?.call(stream);
      };

      _peerConnection!.onRemoveStream = (MediaStream stream) {
        debugPrint('🎥 Remote stream removed');
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('🔗 Peer connection state: $state');
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('🧊 ICE connection state: $state');
      };

    } catch (e) {
      debugPrint('❌ Peer connection error: $e');
      rethrow;
    }
  }

  // In VideoCallService - ADD method for audio calls
  Future<void> makeAudioCall(String targetUserId) async {
  try {
    await _createPeerConnection();
    await _initializeLocalStream('audio'); // ✅ PASS 'audio' for audio calls

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false, // ✅ DISABLE video for audio calls
    });

    await _peerConnection!.setLocalDescription(offer);

    _socket.emit('initiate-call', {
      'targetUserId': targetUserId,
      'roomId': _currentRoomId,
      'offer': offer.toMap(),
      'callerName': _userName,
      'callType': 'audio', // ✅ SET call type to audio
      'callerId': _userId,
    });

    debugPrint('📞 Audio call initiated to $targetUserId');
  } catch (e) {
    debugPrint('❌ Error initiating audio call: $e');
    onError?.call(e.toString());
  }
}

  // UPDATE _initializeLocalStream to handle audio-only
  Future<void> _initializeLocalStream(String callType) async {
    try {
      final mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': callType == 'video' ? { // ✅ ONLY ENABLE VIDEO FOR VIDEO CALLS
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 30}
        } : false
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      onLocalStream?.call(_localStream!);

      // Add tracks to peer connection
      for (final track in _localStream!.getTracks()) {
        final sender = await _peerConnection!.addTrack(track, _localStream!);
        _senders.add(sender);
      }

      debugPrint('🎥 Local stream initialized with ${_localStream!.getTracks().length} tracks');
      debugPrint('📞 Call type: $callType');
    } catch (e) {
      debugPrint('❌ Local stream error: $e');
      rethrow;
    }
  }
// In your VideoCallService - ADD this method:

Future<void> notifyPatientCallStarted(
  String patientId, 
  String roomId, 
  String doctorName, {
  String consultationType = 'video'
}) async {
  try {
    if (!_isInitialized) await initialize();

    _socket.emit('notify-call-started', {
      'patientId': patientId,
      'roomId': roomId,
      'doctorName': doctorName,
      'doctorId': _userId,
      'consultationType': consultationType, // ✅ ADD THIS
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    debugPrint('📢 Notified patient $patientId about $consultationType call from Dr. $doctorName');
  } catch (e) {
    debugPrint('❌ Error notifying patient: $e');
    rethrow;
  }
}
  // Handle incoming WebRTC offer
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    try {
      final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      await _peerConnection!.setLocalDescription(answer);

      _socket.emit('webrtc-answer', {
        'to': data['from'],
        'answer': answer.toMap(),
      });

      debugPrint('✅ Sent answer to offer');
    } catch (e) {
      debugPrint('❌ Offer handling error: $e');
      onError?.call(e.toString());
    }
  }

  // Handle incoming WebRTC answer
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
      await _peerConnection!.setRemoteDescription(answer);
      debugPrint('✅ Remote description set from answer');
    } catch (e) {
      debugPrint('❌ Answer handling error: $e');
      onError?.call(e.toString());
    }
  }

  // Handle ICE candidates
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
      debugPrint('🧊 Added ICE candidate');
    } catch (e) {
      debugPrint('❌ ICE candidate error: $e');
    }
  }

  // Media controls
  Future<bool> toggleAudio([bool? enabled]) async {
    if (_localStream == null) return false;
    final tracks = _localStream!.getAudioTracks();
    if (tracks.isEmpty) return false;

    final newState = enabled ?? !tracks.first.enabled;
    tracks.first.enabled = newState;

    _socket.emit('toggle-media', {
      'roomId': _currentRoomId,
      'mediaType': 'audio',
      'isEnabled': newState,
    });

    debugPrint('🎙️ Audio ${newState ? 'unmuted' : 'muted'}');
    return newState;
  }

  Future<bool> toggleVideo([bool? enabled]) async {
    if (_localStream == null) return false;
    final tracks = _localStream!.getVideoTracks();
    if (tracks.isEmpty) return false;

    final newState = enabled ?? !tracks.first.enabled;
    tracks.first.enabled = newState;

    _socket.emit('toggle-media', {
      'roomId': _currentRoomId,
      'mediaType': 'video',
      'isEnabled': newState,
    });

    debugPrint('📹 Video ${newState ? 'enabled' : 'disabled'}');
    return newState;
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    try {
      await _reinitializeLocalStream();
      debugPrint('🔄 Camera switched');
    } catch (e) {
      debugPrint('❌ Switch camera error: $e');
    }
  }

  Future<void> _reinitializeLocalStream() async {
    try {
      // Stop old tracks
      _localStream?.getTracks().forEach((track) => track.stop());
      
      // Get new stream with opposite camera
      final mediaConstraints = {
        'audio': true,
        'video': {'facingMode': _getOppositeFacingMode()}
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      onLocalStream?.call(_localStream!);

      // Update peer connection tracks
      for (final sender in _senders) {
        await _peerConnection!.removeTrack(sender);
      }
      _senders.clear();

      for (final track in _localStream!.getTracks()) {
        final sender = await _peerConnection!.addTrack(track, _localStream!);
        _senders.add(sender);
      }
    } catch (e) {
      debugPrint('❌ Reinit stream error: $e');
      rethrow;
    }
  }

  String _getOppositeFacingMode() {
    // Simple toggle - you can make this smarter
    return 'user'; // Always use front camera for now
  }

  // End call
  Future<void> endCall() async {
    _socket.emit('end-call', {'roomId': _currentRoomId});
    await _cleanUp();
    debugPrint('📞 Call ended');
  }

  // Cleanup resources
  Future<void> _cleanUp() async {
    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
      await _peerConnection?.close();

      _localStream = null;
      _peerConnection = null;
      _senders.clear();
      _currentRoomId = null;
      
      debugPrint('🧹 Resources cleaned up');
    } catch (e) {
      debugPrint('❌ Cleanup error: $e');
    }
  }

  // Getters
  bool get isConnected => _socket.connected;
  bool get isInitialized => _isInitialized;
  String? get currentRoomId => _currentRoomId;
  String? get userId => _userId;
  String? get userName => _userName;
  bool? get isDoctor => _isDoctor;
  MediaStream? get localStream => _localStream;

  void dispose() {
    _cleanUp();
    _socket.disconnect();
    debugPrint('♻️ VideoCallService disposed');
  }
}