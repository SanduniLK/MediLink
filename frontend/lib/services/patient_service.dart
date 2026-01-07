import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PatientService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch patient data from Firestore for the provided patient ID.
  static Future<Map<String, dynamic>?> getPatientData(String patientId) async {
    try {
      if (kDebugMode) {
        debugPrint('📋 Loading patient data for ID: $patientId');
      }

      final docSnapshot = await _firestore
          .collection('patients')
          .doc(patientId)
          .get();

      if (docSnapshot.exists) {
        final patientData = docSnapshot.data();
        if (kDebugMode) {
          debugPrint('✅ Patient data loaded successfully');
        }
        return patientData;
      } else {
        if (kDebugMode) {
          debugPrint('❌ No patient found with ID: $patientId');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading patient data: $e');
      }
      return null;
    }
  }

  /// Fetch patient data by email
  static Future<Map<String, dynamic>?> getPatientDataByEmail(String email) async {
    try {
      if (kDebugMode) {
        debugPrint('📋 Loading patient data for email: $email');
      }

      final querySnapshot = await _firestore
          .collection('patients')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final patientData = doc.data();
        if (kDebugMode) {
          debugPrint('✅ Patient data loaded successfully');
        }
        return {'id': doc.id, ...patientData};
      } else {
        if (kDebugMode) {
          debugPrint('❌ No patient found with email: $email');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading patient data: $e');
      }
      return null;
    }
  }

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

  /// Update patient data in Firestore
  static Future<Map<String, dynamic>> updatePatientData(
    String patientId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Updating patient data for ID: $patientId');
        debugPrint('   Data to update: $updatedData');
      }

      await _firestore
          .collection('patients')
          .doc(patientId)
          .update(updatedData);

      if (kDebugMode) {
        debugPrint('✅ Patient data updated successfully');
      }

      return {'success': true};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating patient data: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Add new patient to Firestore
  static Future<Map<String, dynamic>> addNewPatient(
    Map<String, dynamic> patientData,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('➕ Adding new patient');
        debugPrint('   Patient data: $patientData');
      }

      final docRef = await _firestore
          .collection('patients')
          .add(patientData);

      if (kDebugMode) {
        debugPrint('✅ New patient added with ID: ${docRef.id}');
      }

      return {'success': true, 'id': docRef.id};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error adding new patient: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get patient vital signs/health metrics
  static Future<Map<String, dynamic>> getPatientVitals(
    String patientId, {
    int limit = 10,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📊 Loading vital signs for patient: $patientId');
      }

      final querySnapshot = await _firestore
          .collection('vital_signs')
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final vitals = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (kDebugMode) {
        debugPrint('✅ Found ${vitals.length} vital sign records');
      }

      return {'success': true, 'data': vitals};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading vital signs: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all patients (for admin/dashboard view)
  static Future<Map<String, dynamic>> getAllPatients({
    int limit = 50,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('👥 Loading all patients');
      }

      final querySnapshot = await _firestore
          .collection('patients')
          .limit(limit)
          .get();

      final patients = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (kDebugMode) {
        debugPrint('✅ Found ${patients.length} patients');
      }

      return {'success': true, 'data': patients};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading patients: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get patient medical history
  static Future<Map<String, dynamic>> getMedicalHistory(
    String patientId,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('📜 Loading medical history for patient: $patientId');
      }

      final querySnapshot = await _firestore
          .collection('medical_history')
          .where('patientId', isEqualTo: patientId)
          .orderBy('date', descending: true)
          .get();

      final history = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (kDebugMode) {
        debugPrint('✅ Found ${history.length} medical history records');
      }

      return {'success': true, 'data': history};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading medical history: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Search patients by name
  static Future<Map<String, dynamic>> searchPatientsByName(
    String nameQuery,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 Searching patients by name: $nameQuery');
      }

      final querySnapshot = await _firestore
          .collection('patients')
          .where('name', isGreaterThanOrEqualTo: nameQuery)
          .where('name', isLessThan: nameQuery + 'z')
          .limit(20)
          .get();

      final patients = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (kDebugMode) {
        debugPrint('✅ Found ${patients.length} patients matching search');
      }

      return {'success': true, 'data': patients};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error searching patients: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }
}