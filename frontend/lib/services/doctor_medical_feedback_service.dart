// services/doctor_medical_feedback_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorMedicalFeedbackService {
  static Future<Map<String, dynamic>> submitMedicalCenterFeedback({
    required String doctorId,
    required String doctorName,
    required String medicalCenterId,
    required String medicalCenterName,
    required int rating,
    required String comment,
    required bool wouldRecommend,
    required List<String> categories,
    required bool anonymous,
  }) async {
    try {
      final feedbackData = {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'medicalCenterId': medicalCenterId,
        'medicalCenterName': medicalCenterName,
        'rating': rating, // This should be int
        'comment': comment,
        'wouldRecommend': wouldRecommend,
        'categories': categories,
        'anonymous': anonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'approved',
      };

      // Add to doctorMedicalCenterFeedback collection
      final feedbackDoc = await FirebaseFirestore.instance
          .collection('doctorMedicalCenterFeedback')
          .add(feedbackData);

      // Update medical center statistics - FIXED VERSION
      await _updateMedicalCenterRatings(medicalCenterId, rating);

      return {
        'success': true,
        'feedbackId': feedbackDoc.id,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<void> _updateMedicalCenterRatings(String medicalCenterId, int newRating) async {
    try {
      final medicalCenterRef = FirebaseFirestore.instance
          .collection('medicalCenters')
          .doc(medicalCenterId);

      // Get current medical center data
      final medicalCenterDoc = await medicalCenterRef.get();
      
      if (!medicalCenterDoc.exists) {
        print('Medical center $medicalCenterId not found');
        return;
      }

      final medicalCenterData = medicalCenterDoc.data() as Map<String, dynamic>? ?? {};
      
      // Get current doctor ratings data
      final currentDoctorRatings = medicalCenterData['doctorRatings'] as Map<String, dynamic>? ?? {};
      
      // Calculate new average
      final currentRatingsList = currentDoctorRatings['ratings'] as List<dynamic>? ?? [];
      final totalRatings = currentDoctorRatings['totalRatings'] as int? ?? 0;
      final averageRating = currentDoctorRatings['averageRating'] as double? ?? 0.0;

      // Add new rating
      final updatedRatingsList = List<dynamic>.from(currentRatingsList)..add(newRating);
      final newTotalRatings = totalRatings + 1;
      final newAverageRating = ((averageRating * totalRatings) + newRating) / newTotalRatings;

      // Update doctor ratings
      final updatedDoctorRatings = {
        'ratings': updatedRatingsList,
        'totalRatings': newTotalRatings,
        'averageRating': double.parse(newAverageRating.toStringAsFixed(2)),
      };

      // Update medical center document
      await medicalCenterRef.update({
        'doctorRatings': updatedDoctorRatings,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Successfully updated medical center doctor ratings');
    } catch (e) {
      print('❌ Error updating medical center doctor ratings: $e');
      rethrow;
    }
  }

  // Alternative simpler approach if you don't need detailed rating tracking
  static Future<void> _updateMedicalCenterRatingsSimple(String medicalCenterId, int newRating) async {
    try {
      final medicalCenterRef = FirebaseFirestore.instance
          .collection('medicalCenters')
          .doc(medicalCenterId);

      // Use Firestore transactions or batched writes for atomic updates
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final medicalCenterDoc = await transaction.get(medicalCenterRef);
        
        if (!medicalCenterDoc.exists) {
          throw Exception('Medical center not found');
        }

        final medicalCenterData = medicalCenterDoc.data() as Map<String, dynamic>? ?? {};
        final currentDoctorRatings = medicalCenterData['doctorRatings'] as Map<String, dynamic>? ?? {};

        // Initialize if doesn't exist
        final totalRatings = (currentDoctorRatings['totalRatings'] as int? ?? 0) + 1;
        final currentAverage = (currentDoctorRatings['averageRating'] as double? ?? 0.0);
        
        // Calculate new average
        final newAverage = ((currentAverage * (totalRatings - 1)) + newRating) / totalRatings;

        // Update with proper types
        transaction.update(medicalCenterRef, {
          'doctorRatings': {
            'totalRatings': totalRatings, // int
            'averageRating': double.parse(newAverage.toStringAsFixed(2)), // double
            'lastRating': newRating, // int
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        });
      });

      print('✅ Successfully updated medical center doctor ratings (simple method)');
    } catch (e) {
      print('❌ Error in simple rating update: $e');
      rethrow;
    }
  }
}