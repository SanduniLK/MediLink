import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'signaling_service.dart';

class WebRTCService {
  final SignalingService _signaling;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  List<RTCRtpSender> _senders = [];
  
  // Callbacks for UI updates
  Function(MediaStream)? onRemoteStream;
  Function(RTCPeerConnectionState)? onConnectionStateChange;
  Function(String)? onError;

  WebRTCService(this._signaling);

  // Initialize WebRTC connection with better configuration
  Future<void> initialize() async {
    try {
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
        'iceTransportPolicy': 'all',
      });

      // Set up event listeners
      _setupPeerConnectionListeners();

      if (kDebugMode) {
        debugPrint('✅ WebRTC peer connection initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing WebRTC: $e');
      }
      rethrow;
    }
  }

  void _setupPeerConnectionListeners() {
    if (_peerConnection == null) return;

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _signaling.sendIceCandidate(candidate);
        if (kDebugMode) {
          debugPrint('🧊 Local ICE candidate: ${candidate.candidate}');
        }
      }
    };

    _peerConnection!.onAddStream = (stream) {
      if (kDebugMode) {
        debugPrint('📹 Remote stream received with ${stream.getTracks().length} tracks');
      }
      onRemoteStream?.call(stream);
    };

    _peerConnection!.onConnectionState = (state) {
      if (kDebugMode) {
        debugPrint('🔗 Connection state: $state');
      }
      onConnectionStateChange?.call(state);
    };

    _peerConnection!.onIceConnectionState = (state) {
      if (kDebugMode) {
        debugPrint('🧊 ICE connection state: $state');
      }
    };

    _peerConnection!.onIceGatheringState = (state) {
      if (kDebugMode) {
        debugPrint('📡 ICE gathering state: $state');
      }
    };

    _peerConnection!.onRemoveStream = (stream) {
      if (kDebugMode) {
        debugPrint('📹 Remote stream removed');
      }
    };

    _peerConnection!.onSignalingState = (state) {
      if (kDebugMode) {
        debugPrint('📶 Signaling state: $state');
      }
    };
  }

  // Start local camera and microphone with error handling
  Future<MediaStream> startLocalStream({bool audio = true, bool video = true}) async {
    try {
      final constraints = <String, dynamic>{
        'audio': audio,
        'video': video ? {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30}
        } : false
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      if (kDebugMode) {
        debugPrint('✅ Local stream started with ${_localStream!.getTracks().length} tracks');
        for (var track in _localStream!.getTracks()) {
          debugPrint('   - ${track.kind} track: ${track.id}');
        }
      }
      
      return _localStream!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error starting local stream: $e');
      }
      onError?.call('Failed to access camera/microphone: $e');
      rethrow;
    }
  }

  // Add local stream to peer connection
  Future<void> addLocalStream(MediaStream localStream) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      for (final track in localStream.getTracks()) {
        final sender = await _peerConnection!.addTrack(track, localStream);
        _senders.add(sender);
      }
      
      if (kDebugMode) {
        debugPrint('✅ Added ${localStream.getTracks().length} local tracks to peer connection');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error adding local stream: $e');
      }
      rethrow;
    }
  }

  // Create offer for call initiator with better error handling
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
      
      if (kDebugMode) {
        debugPrint('✅ Created offer: ${offer.type}');
      }
      
      return offer;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating offer: $e');
      }
      onError?.call('Failed to create offer: $e');
      rethrow;
    }
  }

  // Create answer for call receiver
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
      
      if (kDebugMode) {
        debugPrint('✅ Created answer: ${answer.type}');
      }
      
      return answer;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating answer: $e');
      }
      onError?.call('Failed to create answer: $e');
      rethrow;
    }
  }

  // Set remote description with validation
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      await _peerConnection!.setRemoteDescription(description);
      
      if (kDebugMode) {
        debugPrint('✅ Set remote description: ${description.type}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error setting remote description: $e');
      }
      onError?.call('Failed to set remote description: $e');
      rethrow;
    }
  }

  // Add ICE candidate with validation
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      await _peerConnection!.addCandidate(candidate);
      
      if (kDebugMode) {
        debugPrint('✅ Added ICE candidate: ${candidate.candidate}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error adding ICE candidate: $e');
      }
      // Don't throw for ICE candidate errors as they're common during negotiation
    }
  }

  // Toggle camera with proper state management
  Future<bool> toggleCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        videoTrack.enabled = !videoTrack.enabled;
        
        final newState = videoTrack.enabled;
        if (kDebugMode) {
          debugPrint('✅ Camera ${newState ? 'enabled' : 'disabled'}');
        }
        return newState;
      }
    }
    return false;
  }

  // Toggle microphone with proper state management
  Future<bool> toggleMicrophone() async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final audioTrack = audioTracks.first;
        audioTrack.enabled = !audioTrack.enabled;
        
        final newState = audioTrack.enabled;
        if (kDebugMode) {
          debugPrint('✅ Microphone ${newState ? 'enabled' : 'disabled'}');
        }
        return newState;
      }
    }
    return false;
  }

  // Switch camera (front/back) with better error handling
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        try {
          await Helper.switchCamera(videoTrack);
          if (kDebugMode) {
            debugPrint('✅ Camera switched');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Camera switching not supported: $e');
          }
          onError?.call('Camera switching not supported on this device');
        }
      }
    }
  }

  // Get current camera state
  bool get isCameraEnabled {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        return videoTracks.first.enabled;
      }
    }
    return false;
  }

  // Get current microphone state
  bool get isMicrophoneEnabled {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        return audioTracks.first.enabled;
      }
    }
    return false;
  }

  // End call and cleanup resources properly
  Future<void> endCall() async {
    try {
      // Stop all tracks
      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream?.dispose();
      }

      // Close peer connection
      await _peerConnection?.close();

      // Clear senders
      _senders.clear();

      // Reset state
      _peerConnection = null;
      _localStream = null;

      if (kDebugMode) {
        debugPrint('✅ Call ended and resources cleaned up');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error ending call: $e');
      }
      // Don't rethrow during cleanup
    }
  }

  // Get local stream for UI
  MediaStream? get localStream => _localStream;

  // Get peer connection state
  RTCPeerConnectionState? get connectionState => _peerConnection?.connectionState;

  // Check if peer connection is active
  bool get isConnected => _peerConnection != null;

  // Dispose method for complete cleanup
  Future<void> dispose() async {
    await endCall();
    onRemoteStream = null;
    onConnectionStateChange = null;
    onError = null;
  }
}