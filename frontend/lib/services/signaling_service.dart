// services/signaling_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String callSessionId;

  SignalingService(this.callSessionId);

  // Send offer to Firestore
  Future<void> sendOffer(RTCSessionDescription offer) async {
    try {
      await _firestore
          .collection('call_sessions')
          .doc(callSessionId)
          .collection('signaling')
          .add({
        'type': 'offer',
        'sdp': offer.sdp,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ Offer sent to signaling channel');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error sending offer: $e');
      }
      rethrow;
    }
  }

  // Send answer to Firestore
  Future<void> sendAnswer(RTCSessionDescription answer) async {
    try {
      await _firestore
          .collection('call_sessions')
          .doc(callSessionId)
          .collection('signaling')
          .add({
        'type': 'answer',
        'sdp': answer.sdp,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ Answer sent to signaling channel');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error sending answer: $e');
      }
      rethrow;
    }
  }

  // Send ICE candidate
  Future<void> sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      // Debug: Print candidate properties to see what's available
      if (kDebugMode) {
        debugPrint('🔍 ICE Candidate properties:');
        debugPrint('  - candidate: ${candidate.candidate}');
        debugPrint('  - sdpMid: ${candidate.sdpMid}');
        debugPrint('  - sdpMLineIndex: ${candidate.sdpMLineIndex}');
      }

      await _firestore
          .collection('call_sessions')
          .doc(callSessionId)
          .collection('signaling')
          .add({
        'type': 'ice-candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ ICE candidate sent to signaling channel');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error sending ICE candidate: $e');
      }
      rethrow;
    }
  }

  // Listen for signaling messages
  Stream<Map<String, dynamic>> get signalingStream {
    return _firestore
        .collection('call_sessions')
        .doc(callSessionId)
        .collection('signaling')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .handleError((error) {
      if (kDebugMode) {
        debugPrint('❌ Signaling stream error: $error');
      }
    }).map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.last;
        final data = doc.data() as Map<String, dynamic>;
        
        if (kDebugMode) {
          debugPrint('📨 Received signaling message: ${data['type']}');
        }
        
        return data..['id'] = doc.id;
      }
      return {};
    });
  }

  // Clean up old signaling messages
  Future<void> cleanupSignalingMessages() async {
    try {
      final messagesSnapshot = await _firestore
          .collection('call_sessions')
          .doc(callSessionId)
          .collection('signaling')
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      if (messagesSnapshot.docs.isNotEmpty) {
        await batch.commit();
        if (kDebugMode) {
          debugPrint('✅ Cleaned up ${messagesSnapshot.docs.length} signaling messages');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error cleaning up signaling messages: $e');
      }
    }
  }

  // Create RTCIceCandidate from Firestore data
  RTCIceCandidate createIceCandidateFromData(Map<String, dynamic> data) {
    return RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
  }

  // Create RTCSessionDescription from Firestore data
  RTCSessionDescription createSessionDescriptionFromData(Map<String, dynamic> data) {
    return RTCSessionDescription(
      data['sdp'],
      data['type'],
    );
  }
}