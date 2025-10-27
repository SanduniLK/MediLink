// services/patient_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PatientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get patient data from your existing collections
  Future<Map<String, dynamic>> getPatientData(String patientId) async {
    try {
      debugPrint('👤 Fetching patient data for: $patientId');
      
      // Try users collection first (common for Firebase Auth)
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(patientId)
          .get();

      if (userDoc.exists) {
        debugPrint('✅ Found patient in users collection');
        return userDoc.data() as Map<String, dynamic>;
      }

      // Try patients collection
      DocumentSnapshot patientDoc = await _firestore
          .collection('patients')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        debugPrint('✅ Found patient in patients collection');
        return patientDoc.data() as Map<String, dynamic>;
      }

      // Try telemedicine_sessions to find patient info
      QuerySnapshot sessionsSnapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();

      if (sessionsSnapshot.docs.isNotEmpty) {
        final sessionData = sessionsSnapshot.docs.first.data() as Map<String, dynamic>;
        debugPrint('✅ Found patient in telemedicine_sessions');
        return {
          'name': sessionData['patientName'],
          'patientId': patientId,
          // Add other fields you have in sessions
        };
      }

      throw Exception('Patient not found in any collection');
    } catch (e) {
      debugPrint('❌ Error fetching patient data: $e');
      rethrow;
    }
  }

  // Get patient medical stats from medical_records
  Future<Map<String, dynamic>> getPatientMedicalStats(String patientId) async {
    try {
      // Get record counts from medical_records collection
      QuerySnapshot recordsSnapshot = await _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: patientId)
          .get();

      int labResultsCount = 0;
      int prescriptionsCount = 0;
      int otherCount = 0;
      DateTime? lastUploadDate;

      for (var doc in recordsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] ?? '';
        
        if (category == 'lab_results') labResultsCount++;
        else if (category == 'past_prescriptions') prescriptionsCount++;
        else if (category == 'other') otherCount++;

        final uploadDate = data['uploadDate'];
        if (uploadDate != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(uploadDate);
          if (lastUploadDate == null || date.isAfter(lastUploadDate)) {
            lastUploadDate = date;
          }
        }
      }

      return {
        'labResultsCount': labResultsCount,
        'prescriptionsCount': prescriptionsCount,
        'otherCount': otherCount,
        'totalRecords': labResultsCount + prescriptionsCount + otherCount,
        'lastUploadDate': lastUploadDate,
      };
    } catch (e) {
      debugPrint('❌ Error fetching medical stats: $e');
      return {
        'labResultsCount': 0,
        'prescriptionsCount': 0,
        'otherCount': 0,
        'totalRecords': 0,
        'lastUploadDate': null,
      };
    }
  }
}