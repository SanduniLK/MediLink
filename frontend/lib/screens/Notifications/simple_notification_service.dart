import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SimpleNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Existing method for doctor started consultation
  static Future<void> sendConsultationStartedNotification({
    required String patientId,
    required String doctorName,
    required String appointmentId,
    required String consultationType,
  }) async {
    // ... your existing implementation ...
  }

  // ADD THIS METHOD for patient joined notifications
  static Future<void> sendPatientJoinedNotification({
    required String doctorId,
    required String patientName,
    required String appointmentId,
    required String consultationType,
  }) async {
    try {
      debugPrint('🔔 Sending patient joined notification to doctor: $doctorId');
      
      await _storePatientJoinedNotification(
        doctorId: doctorId,
        patientName: patientName,
        appointmentId: appointmentId,
        consultationType: consultationType,
      );

      debugPrint('✅ Patient joined notification sent successfully');

    } catch (e) {
      debugPrint('❌ Error sending patient joined notification: $e');
    }
  }

  static Future<void> _storePatientJoinedNotification({
    required String doctorId,
    required String patientName,
    required String appointmentId,
    required String consultationType,
  }) async {
    try {
      final notificationData = {
        'doctorId': doctorId,
        'patientName': patientName,
        'appointmentId': appointmentId,
        'consultationType': consultationType,
        'type': 'patient_joined',
        'title': 'Patient Joined ✅',
        'message': '$patientName has joined your $consultationType consultation',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'action': 'join_consultation',
        'priority': 'high',
      };

      await _firestore.collection('notifications').add(notificationData);
      debugPrint('✅ Patient joined notification stored in Firestore');
      
    } catch (e) {
      debugPrint('❌ Error storing patient joined notification: $e');
    }
  }

  // ... rest of your existing methods ...
}