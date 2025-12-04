import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PatientService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch appointments stored in Firestore for the provided patient ID.
  static Future<Map<String, dynamic>> getPatientAppointments(
    String patientId,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('📋 Loading appointments for patient: $patientId');
      }

      final querySnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .get();

      final appointments = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (kDebugMode) {
        debugPrint('✅ Found ${appointments.length} appointments');
      }

      return {'success': true, 'data': appointments};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading appointments: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }
}
