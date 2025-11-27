// lib/services/feedback_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit feedback - WORKS WITHOUT INDEX
  static Future<Map<String, dynamic>> submitFeedback({
    required String patientId,
    required String patientName,
    required String patientEmail,
    required String medicalCenterId,
    required String medicalCenterName,
    required String doctorId,
    required String doctorName,
    String? appointmentId,
    required int rating,
    required String comment,
    required bool wouldRecommend,
    List<String> categories = const [],
    bool anonymous = false,
    required String feedbackType,
  }) async {
    try {
      print('📝 Submitting feedback to Firestore...');
      
      final feedbackRef = _firestore.collection('feedback').doc();
      final feedbackData = {
        'feedbackId': feedbackRef.id,
        'patientId': patientId,
        'patientName': anonymous ? 'Anonymous' : patientName,
        'patientEmail': anonymous ? '' : patientEmail,
        'medicalCenterId': medicalCenterId,
        'medicalCenterName': medicalCenterName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'appointmentId': appointmentId,
        'rating': rating,
        'comment': comment,
        'wouldRecommend': wouldRecommend,
        'categories': categories,
        'anonymous': anonymous,
        'feedbackType': feedbackType,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await feedbackRef.set(feedbackData);
      print('✅ Feedback submitted successfully: ${feedbackRef.id}');

      return {
        'success': true,
        'message': 'Thank you for your feedback!',
        'feedbackId': feedbackRef.id
      };

    } catch (error) {
      print('❌ Error submitting feedback: $error');
      return {
        'success': false,
        'error': 'Failed to submit feedback: $error'
      };
    }
  }

  // Get ALL feedback - SIMPLE QUERY, NO INDEX NEEDED
  static Stream<QuerySnapshot> getAllFeedbackStream() {
    return _firestore
        .collection('feedback')
        .snapshots();
  }

  // Get ALL feedback once - SIMPLE QUERY, NO INDEX NEEDED
  static Future<List<Map<String, dynamic>>> getAllFeedbackOnce() async {
    try {
      final snapshot = await _firestore
          .collection('feedback')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error getting feedback: $e');
      return [];
    }
  }
}