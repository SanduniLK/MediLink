// frontend/lib/services/telemedicine_socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TelemedicineSocketService {
  IO.Socket? _socket;
  String? _currentRoomId;
  String? _userId;
  String? _userType;

  // Callbacks
  Function(dynamic)? onIncomingCall;
  Function(dynamic)? onCallAnswered;
  Function(dynamic)? onCallRejected;
  Function(dynamic)? onWebRTCOffer;
  Function(dynamic)? onWebRTCAnswer;
  Function(dynamic)? onICECandidate;
  Function(dynamic)? onCallEnded;
  Function(dynamic)? onUserJoined;
  Function(dynamic)? onUserLeft;
  Function(dynamic)? onConnectionStatus;
  Function(dynamic)? onError;

  // Initialize socket connection
  void initializeSocket(String serverUrl, String userId, String userType) {
    _userId = userId;
    _userType = userType;
    
    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'forceNew': true,
    });

    _setupEventHandlers();
    _socket!.connect();
  }

  // Set up all socket event handlers
  void _setupEventHandlers() {
    _socket!.on('connect', (_) {
      print('✅ Connected to telemedicine server');
      onConnectionStatus?.call({'status': 'connected'});
    });

    _socket!.on('disconnect', (_) {
      print('❌ Disconnected from telemedicine server');
      onConnectionStatus?.call({'status': 'disconnected'});
    });

    _socket!.on('error', (error) {
      print('❌ Socket error: $error');
      onError?.call(error);
    });

    // Telemedicine specific events
    _socket!.on('incoming-call-from-doctor', (data) {
      print('📞 Incoming call received: $data');
      onIncomingCall?.call(data);
    });

    _socket!.on('call-answered-by-patient', (data) {
      print('✅ Call answered by patient: $data');
      onCallAnswered?.call(data);
    });

    _socket!.on('call-rejected-by-patient', (data) {
      print('❌ Call rejected by patient: $data');
      onCallRejected?.call(data);
    });

    _socket!.on('webrtc-offer', (data) {
      print('📨 WebRTC offer received');
      onWebRTCOffer?.call(data);
    });

    _socket!.on('webrtc-answer', (data) {
      print('📨 WebRTC answer received');
      onWebRTCAnswer?.call(data);
    });

    _socket!.on('ice-candidate', (data) {
      print('🧊 ICE candidate received');
      onICECandidate?.call(data);
    });

    _socket!.on('call-ended', (data) {
      print('📞 Call ended: $data');
      onCallEnded?.call(data);
    });

    _socket!.on('user-joined', (data) {
      print('👤 User joined: $data');
      onUserJoined?.call(data);
    });

    _socket!.on('user-left', (data) {
      print('🚪 User left: $data');
      onUserLeft?.call(data);
    });

    _socket!.on('patient-room-joined', (data) {
      print('🎯 Patient room joined: $data');
    });
  }

  // ==================== PATIENT METHODS ====================

  // Patient: Join patient room
  void joinPatientRoom(String patientId, String patientName) {
    _socket?.emit('patient-join', {
      'patientId': patientId,
      'userName': patientName,
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
  }

  // ==================== DOCTOR METHODS ====================

  // Doctor: Start consultation
  void startConsultation({
    required String roomId,
    required String callType,
    required String callerName,
    required String callerId,
    required String targetUserId,
    required dynamic offer,
  }) {
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

  // ==================== COMMON METHODS ====================

  // Join call room
  void joinCallRoom(String roomId) {
    _currentRoomId = roomId;
    _socket?.emit('join-call-room', roomId);
  }

  // Leave call room
  void leaveCallRoom(String roomId) {
    _socket?.emit('leave-call-room', roomId);
    _currentRoomId = null;
  }

  // WebRTC: Send offer
  void sendOffer(String target, dynamic offer, String targetUserId) {
    _socket?.emit('webrtc-offer', {
      'to': target,
      'offer': offer,
      'targetUserId': targetUserId,
    });
  }

  // WebRTC: Send answer
  void sendAnswer(String target, dynamic answer) {
    _socket?.emit('webrtc-answer', {
      'to': target,
      'answer': answer,
    });
  }

  // WebRTC: Send ICE candidate
  void sendICECandidate(String target, dynamic candidate) {
    _socket?.emit('ice-candidate', {
      'to': target,
      'candidate': candidate,
    });
  }

  // Send media state change
  void sendMediaStateChange(String roomId, String mediaType, bool enabled) {
    _socket?.emit('media-state-changed', {
      'roomId': roomId,
      'mediaType': mediaType,
      'enabled': enabled,
    });
  }

  // End call
  void endCall(String endedBy) {
    if (_currentRoomId != null) {
      _socket?.emit('end-call', {
        'roomId': _currentRoomId,
        'endedBy': endedBy,
      });
    }
    _cleanup();
  }

  // Test notification
  void testPatientNotification(String patientId) {
    _socket?.emit('test-patient-notification', {
      'patientId': patientId,
    });
  }

  // ==================== UTILITY METHODS ====================

  // Check if connected
  bool get isConnected => _socket?.connected == true;

  // Get current room ID
  String? get currentRoomId => _currentRoomId;

  // Get socket ID
  String? get socketId => _socket?.id;

  // Disconnect socket
  void disconnect() {
    _socket?.disconnect();
    _cleanup();
  }

  // Cleanup
  void _cleanup() {
    _currentRoomId = null;
  }

  // Dispose
  void dispose() {
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }
}