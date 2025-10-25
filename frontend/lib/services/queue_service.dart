// services/queue_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class QueueService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize queue for doctor for today
  static Future<void> initializeDoctorQueue(String doctorId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final queueDocRef = _firestore.collection('live_queue').doc('doctor_${doctorId}_$today');

      await queueDocRef.set({
        'doctorId': doctorId,
        'date': today,
        'currentToken': 0,
        'nextToken': 1,
        'queueStatus': 'active',
        'waitingPatients': 0,
        'averageConsultationTime': 15,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error initializing queue: $e');
    }
  }

  // Add patient to queue when booking appointment
  static Future<int> addToQueue(String appointmentId, String doctorId, String date) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final queueDocRef = _firestore.collection('live_queue').doc('doctor_${doctorId}_$today');

      return await _firestore.runTransaction((transaction) async {
        final queueDoc = await transaction.get(queueDocRef);
        
        if (!queueDoc.exists) {
          // Initialize queue if not exists
          transaction.set(queueDocRef, {
            'doctorId': doctorId,
            'date': today,
            'currentToken': 0,
            'nextToken': 1,
            'queueStatus': 'active',
            'waitingPatients': 1,
            'averageConsultationTime': 15,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          return 1;
        }

        final data = queueDoc.data()!;
        final nextToken = data['nextToken'];
        
        // Update queue
        transaction.update(queueDocRef, {
          'nextToken': nextToken + 1,
          'waitingPatients': data['waitingPatients'] + 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Update appointment with token number
        final appointmentRef = _firestore.collection('appointments').doc(appointmentId);
        transaction.update(appointmentRef, {
          'tokenNumber': nextToken,
          'currentPosition': data['waitingPatients'] + 1,
          'queueStatus': 'waiting',
        });

        return nextToken;
      });
    } catch (e) {
      print('Error adding to queue: $e');
      return 0;
    }
  }

  // Doctor calls next patient
  static Future<void> callNextPatient(String doctorId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final queueDocRef = _firestore.collection('live_queue').doc('doctor_${doctorId}_$today');

      await _firestore.runTransaction((transaction) async {
        final queueDoc = await transaction.get(queueDocRef);
        if (!queueDoc.exists) return;

        final data = queueDoc.data()!;
        final currentToken = data['currentToken'];
        final nextToken = data['nextToken'];

        if (currentToken >= nextToken - 1) {
          throw Exception('No more patients in queue');
        }

        final newCurrentToken = currentToken + 1;

        // Update queue
        transaction.update(queueDocRef, {
          'currentToken': newCurrentToken,
          'waitingPatients': data['waitingPatients'] - 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Update current patient to in-consultation
        final currentAppointment = await _findAppointmentByToken(doctorId, newCurrentToken);
        if (currentAppointment != null) {
          transaction.update(currentAppointment.reference, {
            'queueStatus': 'in-consultation',
            'consultationStartTime': FieldValue.serverTimestamp(),
          });
        }

        // Update previous patient to completed
        if (currentToken > 0) {
          final previousAppointment = await _findAppointmentByToken(doctorId, currentToken);
          if (previousAppointment != null) {
            transaction.update(previousAppointment.reference, {
              'queueStatus': 'completed',
              'consultationEndTime': FieldValue.serverTimestamp(),
            });
          }
        }

        // Update positions for all waiting patients
        await _updateWaitingPositions(transaction, doctorId, today);
      });
    } catch (e) {
      print('Error calling next patient: $e');
      rethrow;
    }
  }

  // Patient checks in via QR code
  static Future<void> patientCheckIn(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'checkedIn': true,
        'checkInTime': FieldValue.serverTimestamp(),
        'queueStatus': 'waiting',
      });
    } catch (e) {
      print('Error during patient check-in: $e');
      rethrow;
    }
  }

  // Get live queue stream for doctor
  static Stream<DocumentSnapshot> getLiveQueueStream(String doctorId) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _firestore
        .collection('live_queue')
        .doc('doctor_${doctorId}_$today')
        .snapshots();
  }

  // Get patient's current position
  static Stream<int> getPatientPositionStream(String appointmentId) {
    return _firestore
        .collection('appointments')
        .doc(appointmentId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['currentPosition'] ?? 0);
  }

  // Helper methods
  static Future<DocumentSnapshot?> _findAppointmentByToken(String doctorId, int tokenNumber) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final snapshot = await _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isEqualTo: today)
        .where('tokenNumber', isEqualTo: tokenNumber)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  }

  static Future<void> _updateWaitingPositions(Transaction transaction, String doctorId, String date) async {
    final waitingAppointments = await _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isEqualTo: date)
        .where('queueStatus', isEqualTo: 'waiting')
        .orderBy('tokenNumber')
        .get();

    int position = 1;
    for (var doc in waitingAppointments.docs) {
      transaction.update(doc.reference, {
        'currentPosition': position,
      });
      position++;
    }
  }
}