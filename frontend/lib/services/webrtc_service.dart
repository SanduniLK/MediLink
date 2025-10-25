import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'signaling_service.dart';

class WebRTCService {
  final SignalingService _signaling;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  // Removed unused _senders field

  WebRTCService(this._signaling);

  // Initialize WebRTC connection
  Future<void> initialize() async {
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // Add your TURN servers here for production
      ]
    });

    // Add event listeners
    _peerConnection!.onIceCandidate = (candidate) {
      _signaling.sendIceCandidate(candidate);
    };

    _peerConnection!.onAddStream = (stream) {
      // Handle remote stream
      _onRemoteStream(stream);
    };

    _peerConnection!.onConnectionState = (state) {
      // Handle connection state changes
      _onConnectionStateChange(state);
    };

    if (kDebugMode) {
      debugPrint('✅ WebRTC peer connection initialized');
    }
  }

  // Start local camera and microphone
  Future<MediaStream> startLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': 1280,
        'height': 720,
      }
    });
    
    if (kDebugMode) {
      debugPrint('✅ Local stream started');
    }
    
    return _localStream!;
  }

  // Add local stream to peer connection
  Future<void> addLocalStream(MediaStream localStream) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    for (final track in localStream.getTracks()) {
      await _peerConnection!.addTrack(track, localStream);
    }
    
    if (kDebugMode) {
      debugPrint('✅ Added local stream tracks to peer connection');
    }
  }

  // Create offer for call initiator
  Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    if (kDebugMode) {
      debugPrint('✅ Created offer');
    }
    
    return offer;
  }

  // Create answer for call receiver
  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    
    if (kDebugMode) {
      debugPrint('✅ Created answer');
    }
    
    return answer;
  }

  // Add remote description
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    await _peerConnection!.setRemoteDescription(description);
    
    if (kDebugMode) {
      debugPrint('✅ Set remote description: ${description.type}');
    }
  }

  // Add ICE candidate
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    await _peerConnection!.addCandidate(candidate);
    
    if (kDebugMode) {
      debugPrint('✅ Added ICE candidate');
    }
  }

  // Toggle camera - FIXED: Use the correct property assignment
  Future<void> toggleCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        // Fixed: Directly assign to the enabled property
        videoTrack.enabled = !videoTrack.enabled;
        
        if (kDebugMode) {
          debugPrint('✅ Camera ${videoTrack.enabled ? 'enabled' : 'disabled'}');
        }
      }
    }
  }

  // Toggle microphone - FIXED: Use the correct property assignment
  Future<void> toggleMicrophone() async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final audioTrack = audioTracks.first;
        // Fixed: Directly assign to the enabled property
        audioTrack.enabled = !audioTrack.enabled;
        
        if (kDebugMode) {
          debugPrint('✅ Microphone ${audioTrack.enabled ? 'enabled' : 'disabled'}');
        }
      }
    }
  }

  // Switch camera (front/back) - FIXED: Use Helper.switchCamera()
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        try {
          // Fixed: Use Helper.switchCamera() instead of deprecated switchCamera()
          await Helper.switchCamera(videoTrack);
          if (kDebugMode) {
            debugPrint('✅ Camera switched using Helper.switchCamera()');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Camera switching not supported: $e');
          }
        }
      }
    }
  }

  // End call and cleanup
  Future<void> endCall() async {
    try {
      await _peerConnection?.close();
      await _localStream?.dispose();
      _peerConnection = null;
      _localStream = null;
      
      if (kDebugMode) {
        debugPrint('✅ Call ended and resources cleaned up');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error ending call: $e');
      }
      rethrow;
    }
  }

  // Get local stream for UI
  MediaStream? get localStream => _localStream;

  // Get peer connection state
  RTCPeerConnectionState? get connectionState => _peerConnection?.connectionState;

  // Handle remote stream
  void _onRemoteStream(MediaStream stream) {
    if (kDebugMode) {
      debugPrint('✅ Remote stream received');
    }
    // You can notify the UI about the remote stream here
    // This would typically be handled via a callback or stream
  }

  // Handle connection state changes
  void _onConnectionStateChange(RTCPeerConnectionState state) {
    if (kDebugMode) {
      debugPrint('🔗 Connection state changed: $state');
    }
    // You can notify the UI about connection state changes here
    // This would typically be handled via a callback or stream
  }
}