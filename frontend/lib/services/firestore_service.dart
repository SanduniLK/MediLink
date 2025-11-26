// frontend/lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/screens/Notifications/notification_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Complete Flow Methods
  static Future<void> completeDoctorStartFlow({
    required String appointmentId,
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String consultationType,
  }) async {
    try {
      debugPrint('🚀 STARTING COMPLETE FLOW: Doctor Starts Consultation');
      
      // Step 1: Update session status to In-Progress
      await updateSessionStatus(
        appointmentId: appointmentId,
        status: 'In-Progress',
        startedAt: DateTime.now(),
      );
      
      // Step 2: Send notification to patient
      await createDoctorStartedNotification(
        patientId: patientId,
        doctorName: doctorName,
        appointmentId: appointmentId,
        consultationType: consultationType,
      );
      
      debugPrint('✅ STEP 1 COMPLETE: Doctor started consultation → Patient notified');
      
    } catch (e) {
      debugPrint('❌ Error in doctor start flow: $e');
      rethrow;
    }
  }

  static Future<void> completePatientJoinFlow({
    required String appointmentId,
    required String patientId,
    required String patientName,
    required String doctorId,
    required String consultationType,
  }) async {
    try {
      debugPrint('🚀 STEP 2: Patient Joins Consultation');
      
      // Update patient join status
      await updateSessionJoinStatus(
        appointmentId: appointmentId,
        userType: 'patient',
        hasJoined: true,
      );
      
      // Send notification to doctor
      await createPatientJoinedNotification(
        doctorId: doctorId,
        patientName: patientName,
        appointmentId: appointmentId,
        consultationType: consultationType,
      );
      
      debugPrint('✅ STEP 2 COMPLETE: Patient joined → Doctor notified');
      
    } catch (e) {
      debugPrint('❌ Error in patient join flow: $e');
      rethrow;
    }
  }

  static Future<void> completeDoctorJoinFlow({
    required String appointmentId,
    required String doctorId,
  }) async {
    try {
      debugPrint('🚀 STEP 3: Doctor Joins Consultation');
      
      // Update doctor join status
      await updateSessionJoinStatus(
        appointmentId: appointmentId,
        userType: 'doctor',
        hasJoined: true,
      );
      
      debugPrint('✅ STEP 3 COMPLETE: Doctor joined → Both in consultation room');
      
    } catch (e) {
      debugPrint('❌ Error in doctor join flow: $e');
      rethrow;
    }
  }

  // Test the complete flow
  static Future<void> testCompleteFlow({
    required String appointmentId,
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String patientName,
    required String consultationType,
  }) async {
    try {
      debugPrint('🧪 TESTING COMPLETE FLOW');
      debugPrint('Appointment: $appointmentId');
      debugPrint('Doctor: $doctorName ($doctorId)');
      debugPrint('Patient: $patientName ($patientId)');
      
      // Step 1: Doctor starts
      await completeDoctorStartFlow(
        appointmentId: appointmentId,
        doctorId: doctorId,
        doctorName: doctorName,
        patientId: patientId,
        consultationType: consultationType,
      );
      
      // Wait a bit for notification delivery
      await Future.delayed(Duration(seconds: 2));
      
      // Step 2: Patient joins
      await completePatientJoinFlow(
        appointmentId: appointmentId,
        patientId: patientId,
        patientName: patientName,
        doctorId: doctorId,
        consultationType: consultationType,
      );
      
      // Wait a bit for notification delivery
      await Future.delayed(Duration(seconds: 2));
      
      // Step 3: Doctor joins
      await completeDoctorJoinFlow(
        appointmentId: appointmentId,
        doctorId: doctorId,
      );
      
      debugPrint('🎉 COMPLETE FLOW TEST FINISHED SUCCESSFULLY!');
      
    } catch (e) {
      debugPrint('❌ Complete flow test failed: $e');
      rethrow;
    }
  }

  // Get telemedicine sessions for patient
  static Stream<List<Map<String, dynamic>>> getPatientSessionsStream(String patientId) {
    return _firestore
        .collection('telemedicine_sessions')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs.map((doc) {
            final data = doc.data();
            return _parseSessionData(doc.id, data);
          }).toList();
          
          sessions.sort((a, b) {
            final dateA = a['createdAt'] as DateTime;
            final dateB = b['createdAt'] as DateTime;
            return dateB.compareTo(dateA);
          });
          
          return sessions;
        });
  }

  // Get telemedicine sessions for doctor
  static Stream<List<Map<String, dynamic>>> getDoctorSessionsStream(String doctorId) {
    return _firestore
        .collection('telemedicine_sessions')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs.map((doc) {
            final data = doc.data();
            return _parseSessionData(doc.id, data);
          }).toList();
          
          sessions.sort((a, b) {
            final dateA = a['createdAt'] as DateTime;
            final dateB = b['createdAt'] as DateTime;
            return dateB.compareTo(dateA);
          });
          
          return sessions;
        });
  }

  // Parse session data with proper date handling
  static Map<String, dynamic> _parseSessionData(String docId, Map<String, dynamic> data) {
    debugPrint('📋 Raw Firestore data for $docId:');
    data.forEach((key, value) {
      debugPrint('   $key: $value (${value.runtimeType})');
    });
    
    return {
      'id': docId,
      ...data,
      'createdAt': _safeParseDate(data['createdAt']),
      'startedAt': _safeParseDate(data['startedAt']),
      'endedAt': _safeParseDate(data['endedAt']),
      'updatedAt': _safeParseDate(data['updatedAt']),
    };
  }

  // Safe date parser
  static DateTime _safeParseDate(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }
    
    if (dateValue is DateTime) {
      return dateValue;
    }
    
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    }
    
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        final alternative = _tryAlternativeDateFormats(dateValue);
        if (alternative != null) {
          return alternative;
        }
        return DateTime.now();
      }
    }
    
    return DateTime.now();
  }

  // Try alternative date formats
  static DateTime? _tryAlternativeDateFormats(String dateString) {
    try {
      if (dateString.toLowerCase().contains('today') || dateString.toLowerCase().contains('tomorrow')) {
        final match = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(dateString);
        if (match != null) {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final year = int.parse(match.group(3)!);
          return DateTime(year, month, day);
        }
      }
      
      if (RegExp(r'^\d+$').hasMatch(dateString)) {
        final timestamp = int.tryParse(dateString);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
    } catch (e) {
      debugPrint('❌ Alternative date parsing failed: $e');
    }
    
    return null;
  }

  // Enhanced notification methods
  static Future<void> createDoctorStartedNotification({
    required String patientId,
    required String doctorName,
    required String appointmentId,
    required String consultationType,
  }) async {
    try {
      debugPrint('🔔 Creating doctor started notification for patient: $patientId');
      
      await NotificationService.sendConsultationStartedNotification(
        patientId: patientId,
        doctorName: doctorName,
        appointmentId: appointmentId,
        consultationType: consultationType,
      );
      
      // Also store in Firestore for persistence
      await _firestore.collection('notifications').add({
        'patientId': patientId,
        'title': 'Consultation Started',
        'message': 'Dr. $doctorName has started your $consultationType consultation',
        'type': 'consultation_started',
        'appointmentId': appointmentId,
        'consultationType': consultationType,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'priority': 'high',
      });
      
    } catch (e) {
      debugPrint('❌ Error creating doctor started notification: $e');
    }
  }

  // In FirestoreService - enhance the notification
static Future<void> createPatientJoinedNotification({
  required String doctorId,
  required String patientName,
  required String appointmentId,
  required String consultationType,
}) async {
  try {
    debugPrint('🔔 Creating patient joined notification with JOIN button');
    
    await _firestore.collection('notifications').add({
      'doctorId': doctorId,
      'title': 'Patient Joined 👤', // Updated emoji
      'message': '$patientName has joined the consultation',
      'type': 'patient_joined',
      'appointmentId': appointmentId,
      'consultationType': consultationType,
      'patientName': patientName, // Include for display
      'hasAction': true, // ✅ NEW: Indicates this has action button
      'actionText': 'JOIN MEETING', // ✅ NEW: Button text
      'actionType': 'join_consultation', // ✅ NEW: Action type
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'priority': 'high',
    });
    
    debugPrint('✅ Patient joined notification with JOIN button created');
    
  } catch (e) {
    debugPrint('❌ Error creating patient joined notification: $e');
  }
}

  // Get single session by appointment ID
  static Future<Map<String, dynamic>?> getSessionByAppointmentId(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        return _parseSessionData(doc.id, data);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting session: $e');
      return null;
    }
  }

  // Update session status
  static Future<void> updateSessionStatus({
    required String appointmentId,
    required String status,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (startedAt != null) {
        updateData['startedAt'] = Timestamp.fromDate(startedAt);
      }

      if (endedAt != null) {
        updateData['endedAt'] = Timestamp.fromDate(endedAt);
      }

      final snapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update(updateData);
        debugPrint('✅ Session status updated to: $status');
      } else {
        debugPrint('❌ Session not found with appointmentId: $appointmentId');
      }
    } catch (e) {
      debugPrint('❌ Error updating session status: $e');
      rethrow;
    }
  }

  // Notification methods
  static Stream<List<Map<String, dynamic>>> getDoctorNotificationsStream(String doctorId) {
    return _firestore
        .collection('notifications')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  static Stream<List<Map<String, dynamic>>> getPatientNotificationsStream(String patientId) {
    return _firestore
        .collection('notifications')
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  static Future<void> clearDoctorNotifications(String doctorId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('doctorId', isEqualTo: doctorId)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> clearPatientNotifications(String patientId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('patientId', isEqualTo: patientId)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
static Future<void> addJoinStatusFields(String appointmentId) async {
  try {
    final docRef = _firestore.collection('telemedicine_sessions').doc(appointmentId);
    
    await docRef.update({
      'patientJoined': false,
      'doctorJoined': false,
      'patientJoinedAt': null,
      'doctorJoinedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    debugPrint('✅ Added join status fields to session: $appointmentId');
  } catch (e) {
    debugPrint('❌ Error adding join status fields: $e');
  }
}
  // Join status methods
  static Future<void> updateSessionJoinStatus({
  required String appointmentId,
  required String userType,
  required bool hasJoined,
}) async {
  try {
    final updateData = userType == 'doctor' 
        ? {
            'doctorJoined': hasJoined, 
            'doctorJoinedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }
        : {
            'patientJoined': hasJoined, 
            'patientJoinedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

    final docRef = _firestore.collection('telemedicine_sessions').doc(appointmentId);
    
    // Use set with merge: true to create fields if they don't exist
    await docRef.set(updateData, SetOptions(merge: true));
    
    debugPrint('✅ $userType join status updated: $hasJoined for $appointmentId');

  } catch (e) {
    debugPrint('❌ Error updating $userType join status: $e');
    rethrow;
  }
}
  // In FirestoreService - fix getSessionJoinStatus to handle missing fields
static Future<Map<String, dynamic>?> getSessionJoinStatus(String appointmentId) async {
  try {
    final doc = await _firestore
        .collection('telemedicine_sessions')
        .doc(appointmentId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      debugPrint('🔍 getSessionJoinStatus - Raw data: ${data['patientJoined']}, ${data['doctorJoined']}');
      
      return {
        'patientJoined': data['patientJoined'] ?? false,
        'doctorJoined': data['doctorJoined'] ?? false,
        'patientJoinedAt': data['patientJoinedAt'],
        'doctorJoinedAt': data['doctorJoinedAt'],
      };
    } else {
      debugPrint('⚠️ Document not found for: $appointmentId');
      return {
        'patientJoined': false,
        'doctorJoined': false,
        'patientJoinedAt': null,
        'doctorJoinedAt': null,
      };
    }
  } catch (e) {
    debugPrint('❌ Error in getSessionJoinStatus: $e');
    return {
      'patientJoined': false,
      'doctorJoined': false,
      'patientJoinedAt': null,
      'doctorJoinedAt': null,
    };
  }
}

  static Stream<Map<String, dynamic>> getSessionJoinStatusStream(String appointmentId) {
    return _firestore
        .collection('telemedicine_sessions')
        .doc(appointmentId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final data = doc.data()!;
            return {
              'patientJoined': data['patientJoined'] ?? false,
              'doctorJoined': data['doctorJoined'] ?? false,
              'patientJoinedAt': data['patientJoinedAt'],
              'doctorJoinedAt': data['doctorJoinedAt'],
            };
          }
          return {'patientJoined': false, 'doctorJoined': false};
        });
  }
  static Future<void> completeConsultation({
  required String appointmentId,
  required String doctorId,
  required String patientId,
}) async {
  try {
    debugPrint('🔄 COMPLETING CONSULTATION: $appointmentId');

    final sessionDoc = FirebaseFirestore.instance
        .collection('telemedicine_sessions')
        .doc(appointmentId);

    // Update session status to completed
    await sessionDoc.update({
      'status': 'Completed',
      'endedAt': FieldValue.serverTimestamp(),
      'doctorJoined': false,
      'patientJoined': false,
    });

    debugPrint('✅ CONSULTATION COMPLETED: $appointmentId');

    // Send completion notification to patient
    await createConsultationCompletedNotification(
      patientId: patientId,
      doctorName: await _getDoctorName(doctorId),
      appointmentId: appointmentId,
    );

  } catch (e) {
    debugPrint('❌ ERROR COMPLETING CONSULTATION: $e');
    rethrow;
  }
}
static Future<String> _getDoctorName(String doctorId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(doctorId)
        .get();
    return doc.data()?['name'] ?? 'Doctor';
  } catch (e) {
    return 'Doctor';
  }
}
static Future<void> createConsultationCompletedNotification({
  required String patientId,
  required String doctorName,
  required String appointmentId,
}) async {
  try {
    await FirebaseFirestore.instance.collection('notifications').add({
      'patientId': patientId,
      'doctorName': doctorName,
      'appointmentId': appointmentId,
      'type': 'consultation_completed',
      'message': 'Your consultation with Dr. $doctorName has been completed',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  } catch (e) {
    debugPrint('❌ ERROR CREATING COMPLETION NOTIFICATION: $e');
  }
}
static Future<void> updatePatientLeftCall(String appointmentId) async {
  try {
    await FirebaseFirestore.instance
        .collection('telemedicine_sessions')
        .doc(appointmentId)
        .update({
      'patientJoined': false,
      'lastPatientLeft': DateTime.now(),
    });
    debugPrint('✅ Patient left call status updated');
  } catch (e) {
    debugPrint('❌ Error updating patient left call: $e');
    rethrow;
  }
}
}