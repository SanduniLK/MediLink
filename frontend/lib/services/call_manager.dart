import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/signaling_service.dart';

class CallManager {
  final WebRTCService webRTCService;
  final SignalingService signalingService;

  CallManager({required this.signalingService})
      : webRTCService = WebRTCService(signalingService);

  Future<void> initializeCall() async {
    try {
      // Set up callbacks
      webRTCService.onRemoteStream = (stream) {
        // Update UI with remote video
        if (kDebugMode) {
          debugPrint('📹 Remote stream received in CallManager');
        }
      };
      
      webRTCService.onConnectionStateChange = (state) {
        // Update connection status in UI
        if (kDebugMode) {
          debugPrint('🔗 Connection state changed: $state');
        }
      };
      
      webRTCService.onError = (error) {
        // Show error to user
        if (kDebugMode) {
          debugPrint('❌ WebRTC Error: $error');
        }
      };

      // Initialize WebRTC
      await webRTCService.initialize();
      
      // Start local stream
      final localStream = await webRTCService.startLocalStream();
      
      // Add local stream to peer connection
      await webRTCService.addLocalStream(localStream);

      if (kDebugMode) {
        debugPrint('✅ Call initialized successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Call initialization failed: $e');
      }
      rethrow;
    }
  }

  Future<void> startCall() async {
    try {
      // Create and send offer
      final offer = await webRTCService.createOffer();
      await signalingService.sendOffer(offer);
      
      if (kDebugMode) {
        debugPrint('✅ Call started successfully');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error starting call: $e');
      }
      rethrow;
    }
  }

  Future<void> endCall() async {
    try {
      await webRTCService.endCall();
      await signalingService.cleanupSignalingMessages();
      
      if (kDebugMode) {
        debugPrint('✅ Call ended successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error ending call: $e');
      }
      // Don't rethrow during cleanup
    }
  }

  // Additional utility methods
  Future<bool> toggleAudio() async {
    return await webRTCService.toggleMicrophone();
  }

  Future<bool> toggleVideo() async {
    return await webRTCService.toggleCamera();
  }

  Future<void> switchCamera() async {
    await webRTCService.switchCamera();
  }

  // Get current states
  bool get isAudioEnabled => webRTCService.isMicrophoneEnabled;
  bool get isVideoEnabled => webRTCService.isCameraEnabled;
  RTCPeerConnectionState? get connectionState => webRTCService.connectionState;
}