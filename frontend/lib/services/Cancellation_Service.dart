import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Complete Cancellation Service with Dynamic Token Management
class CancellationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Main cancellation method with dynamic token updates
  Future<Map<String, dynamic>> cancelAppointment({
    required String appointmentId,
    required String scheduleId,
    required String doctorId,
    required String date,
  }) async {
    try {
      print('🔄 Starting cancellation process...');
      print('   Appointment: $appointmentId');
      print('   Schedule: $scheduleId');
      print('   Doctor: $doctorId, Date: $date');

      Map<String, dynamic> result = {
        'success': false,
        'cancelledToken': null,
        'updatedAppointments': 0,
        'message': '',
      };

      await _firestore.runTransaction((transaction) async {
        // 1. Get appointment details
        final appointmentDoc = await transaction.get(
          _firestore.collection('appointments').doc(appointmentId)
        );

        if (!appointmentDoc.exists) {
          throw Exception('Appointment not found');
        }

        final appointmentData = appointmentDoc.data()!;
        final currentStatus = appointmentData['status'] as String? ?? '';
        final cancelledTokenNumber = appointmentData['tokenNumber'] as int?;
        final paymentStatus = appointmentData['paymentStatus'] as String? ?? '';

        // Check if already cancelled
        if (currentStatus == 'cancelled') {
          result['message'] = 'Appointment already cancelled';
          return;
        }

        // 2. Update appointment status to cancelled
        transaction.update(appointmentDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        result['cancelledToken'] = cancelledTokenNumber;
        print('✅ Appointment status updated to cancelled');

        // 3. Update schedule slot count
        final scheduleDoc = await transaction.get(
          _firestore.collection('doctorSchedules').doc(scheduleId)
        );

        if (scheduleDoc.exists) {
          final currentBooked = (scheduleDoc.data()!['bookedAppointments'] as int? ?? 0);
          final newBookedCount = currentBooked > 0 ? currentBooked - 1 : 0;
          
          transaction.update(scheduleDoc.reference, {
            'bookedAppointments': newBookedCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('📊 Slot count updated: $currentBooked → $newBookedCount');
        }

        // 4. Handle token number updates if token exists
        if (cancelledTokenNumber != null) {
          final updateCount = await _updateTokenNumbers(
            transaction,
            doctorId,
            date,
            cancelledTokenNumber,
          );
          result['updatedAppointments'] = updateCount;
        }

        // 5. Update queue total count
        await _updateQueueCount(transaction, doctorId, date);

        // 6. Handle refund if payment was made
        if (paymentStatus == 'paid') {
          await _handleRefund(appointmentId, appointmentData);
        }

        result['success'] = true;
        result['message'] = 'Appointment cancelled successfully';
      });

      // 7. Clear local storage
      await _clearLocalStorage(appointmentId);

      print('🎉 Cancellation completed: ${result['message']}');
      return result;

    } catch (e) {
      print('❌ Error in cancellation process: $e');
      return {
        'success': false,
        'message': 'Failed to cancel appointment: $e',
        'cancelledToken': null,
        'updatedAppointments': 0,
      };
    }
  }

  // Update token numbers for all appointments after cancelled token
  Future<int> _updateTokenNumbers(
    Transaction transaction,
    String doctorId,
    String date,
    int cancelledTokenNumber,
  ) async {
    try {
      print('🔄 Updating token numbers after cancellation...');

      // Get all appointments with tokens greater than cancelled token
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: ['confirmed', 'pending'])
          .where('tokenNumber', isGreaterThan: cancelledTokenNumber)
          .get();

      final appointmentsToUpdate = appointmentsQuery.docs;
      int updateCount = 0;

      print('📝 Found ${appointmentsToUpdate.length} appointments to update');

      // Update each appointment's token number
      for (final doc in appointmentsToUpdate) {
        final currentToken = doc.data()['tokenNumber'] as int?;
        if (currentToken != null && currentToken > cancelledTokenNumber) {
          final newTokenNumber = currentToken - 1;
          transaction.update(doc.reference, {
            'tokenNumber': newTokenNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updateCount++;
          print('   Token updated: $currentToken → $newTokenNumber for ${doc.id}');
        }
      }

      print('✅ Updated $updateCount token numbers');
      return updateCount;

    } catch (e) {
      print('❌ Error updating token numbers: $e');
      return 0;
    }
  }

  // Update queue count in doctorDailyQueue
  Future<void> _updateQueueCount(
    Transaction transaction,
    String doctorId,
    String date,
  ) async {
    try {
      final queueDocRef = _firestore
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date');

      final queueDoc = await transaction.get(queueDocRef);
      
      if (queueDoc.exists) {
        transaction.update(queueDocRef, {
          'totalAppointments': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('📊 Queue count decreased by 1');
      }
    } catch (e) {
      print('⚠️ Error updating queue count: $e');
      // Continue with cancellation even if queue update fails
    }
  }

  // Handle refund process
  Future<void> _handleRefund(String appointmentId, Map<String, dynamic> appointmentData) async {
    try {
      print('💰 Processing refund for paid appointment...');
      
      // Create refund record
      final refundData = {
        'appointmentId': appointmentId,
        'patientId': appointmentData['patientId'],
        'patientName': appointmentData['patientName'],
        'doctorId': appointmentData['doctorId'],
        'doctorName': appointmentData['doctorName'],
        'amount': appointmentData['fees'],
        'originalToken': appointmentData['tokenNumber'],
        'refundStatus': 'pending',
        'cancelledAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('refunds').add(refundData);
      
      // Update appointment with refund info
      await _firestore.collection('appointments').doc(appointmentId).update({
        'refundStatus': 'pending',
        'refundRequestedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Refund record created');

    } catch (e) {
      print('⚠️ Error processing refund: $e');
      // Continue with cancellation even if refund process fails
    }
  }

  // Clear local storage
  Future<void> _clearLocalStorage(String appointmentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token_$appointmentId');
      print('🗑️ Cleared local token storage for $appointmentId');
    } catch (e) {
      print('⚠️ Error clearing local storage: $e');
    }
  }

  // Get appointment details for cancellation
  Future<Map<String, dynamic>?> getAppointmentDetails(String appointmentId) async {
    try {
      final doc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return doc.data();
    } catch (e) {
      print('❌ Error getting appointment details: $e');
      return null;
    }
  }

  // Check if appointment can be cancelled
  Future<Map<String, dynamic>> checkCancellationEligibility(String appointmentId) async {
    try {
      final appointmentData = await getAppointmentDetails(appointmentId);
      
      if (appointmentData == null) {
        return {
          'canCancel': false,
          'message': 'Appointment not found',
          'appointment': null,
        };
      }

      final status = appointmentData['status'] as String? ?? '';
      final date = appointmentData['date'] as String? ?? '';
      final time = appointmentData['time'] as String? ?? '';

      // Check if already cancelled
      if (status == 'cancelled') {
        return {
          'canCancel': false,
          'message': 'Appointment already cancelled',
          'appointment': appointmentData,
        };
      }

      // Check if appointment is in the past
      if (_isAppointmentInPast(date, time)) {
        return {
          'canCancel': false,
          'message': 'Cannot cancel past appointments',
          'appointment': appointmentData,
        };
      }

      // Check cancellation time window (e.g., cannot cancel within 1 hour)
      if (_isWithinCancellationWindow(date, time)) {
        return {
          'canCancel': false,
          'message': 'Cannot cancel within 1 hour of appointment',
          'appointment': appointmentData,
        };
      }

      return {
        'canCancel': true,
        'message': 'Appointment can be cancelled',
        'appointment': appointmentData,
      };

    } catch (e) {
      print('❌ Error checking cancellation eligibility: $e');
      return {
        'canCancel': false,
        'message': 'Error checking eligibility: $e',
        'appointment': null,
      };
    }
  }

  // Helper method to check if appointment is in the past
  bool _isAppointmentInPast(String date, String time) {
    try {
      final appointmentDateTime = _parseAppointmentDateTime(date, time);
      return appointmentDateTime.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // Helper method to check cancellation window
  bool _isWithinCancellationWindow(String date, String time) {
    try {
      final appointmentDateTime = _parseAppointmentDateTime(date, time);
      final oneHourBefore = appointmentDateTime.subtract(const Duration(hours: 1));
      return DateTime.now().isAfter(oneHourBefore);
    } catch (e) {
      return false;
    }
  }

  // Parse date and time strings to DateTime
  DateTime _parseAppointmentDateTime(String date, String time) {
    // Assuming date format: "YYYY-MM-DD" and time format: "HH:MM - HH:MM"
    final dateParts = date.split('-');
    final timeParts = time.split(' - ').first.split(':');
    
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  // Get current queue status after cancellation
  Future<Map<String, dynamic>> getQueueStatus(String doctorId, String date) async {
    try {
      // Get queue document
      final queueDoc = await _firestore
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date')
          .get();

      // Get all active appointments
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: ['confirmed', 'pending'])
          .orderBy('tokenNumber')
          .get();

      final activeAppointments = appointmentsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'patientName': data['patientName'],
          'tokenNumber': data['tokenNumber'],
          'time': data['time'],
          'status': data['status'],
        };
      }).toList();

      return {
        'queueExists': queueDoc.exists,
        'queueData': queueDoc.exists ? queueDoc.data() : null,
        'activeAppointments': activeAppointments,
        'totalActive': activeAppointments.length,
      };

    } catch (e) {
      print('❌ Error getting queue status: $e');
      return {
        'queueExists': false,
        'activeAppointments': [],
        'totalActive': 0,
        'error': e.toString(),
      };
    }
  }

  // Batch cancellation for multiple appointments
  Future<Map<String, dynamic>> cancelMultipleAppointments(List<String> appointmentIds) async {
    try {
      int successCount = 0;
      int failureCount = 0;
      List<Map<String, dynamic>> results = [];

      for (final appointmentId in appointmentIds) {
        try {
          // Get appointment details first
          final appointmentData = await getAppointmentDetails(appointmentId);
          
          if (appointmentData == null) {
            results.add({
              'appointmentId': appointmentId,
              'success': false,
              'message': 'Appointment not found',
            });
            failureCount++;
            continue;
          }

          final result = await cancelAppointment(
            appointmentId: appointmentId,
            scheduleId: appointmentData['scheduleId'] as String,
            doctorId: appointmentData['doctorId'] as String,
            date: appointmentData['date'] as String,
          );

          results.add({
            'appointmentId': appointmentId,
            'success': result['success'],
            'message': result['message'],
            'cancelledToken': result['cancelledToken'],
          });

          if (result['success'] == true) {
            successCount++;
          } else {
            failureCount++;
          }

        } catch (e) {
          results.add({
            'appointmentId': appointmentId,
            'success': false,
            'message': 'Error: $e',
          });
          failureCount++;
        }
      }

      return {
        'totalProcessed': appointmentIds.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'results': results,
      };

    } catch (e) {
      print('❌ Error in batch cancellation: $e');
      return {
        'totalProcessed': appointmentIds.length,
        'successCount': 0,
        'failureCount': appointmentIds.length,
        'results': [],
        'error': e.toString(),
      };
    }
  }

  // Restore cancelled appointment (Admin function)
  Future<Map<String, dynamic>> restoreAppointment(String appointmentId) async {
    try {
      // Get appointment details
      final appointmentData = await getAppointmentDetails(appointmentId);
      
      if (appointmentData == null) {
        return {'success': false, 'message': 'Appointment not found'};
      }

      final currentStatus = appointmentData['status'] as String? ?? '';
      if (currentStatus != 'cancelled') {
        return {'success': false, 'message': 'Appointment is not cancelled'};
      }

      final originalToken = appointmentData['tokenNumber'] as int?;
      final scheduleId = appointmentData['scheduleId'] as String;
      final doctorId = appointmentData['doctorId'] as String;
      final date = appointmentData['date'] as String;

      await _firestore.runTransaction((transaction) async {
        // 1. Restore appointment status
        transaction.update(
          _firestore.collection('appointments').doc(appointmentId),
          {
            'status': 'confirmed',
            'restoredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // 2. Update schedule count
        final scheduleDoc = await transaction.get(
          _firestore.collection('doctorSchedules').doc(scheduleId)
        );

        if (scheduleDoc.exists) {
          transaction.update(scheduleDoc.reference, {
            'bookedAppointments': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 3. If original token exists, we need to handle token reshuffling
        if (originalToken != null) {
          await _restoreTokenInQueue(
            transaction,
            doctorId,
            date,
            originalToken,
            appointmentId,
          );
        }
      });

      return {'success': true, 'message': 'Appointment restored successfully'};

    } catch (e) {
      print('❌ Error restoring appointment: $e');
      return {'success': false, 'message': 'Failed to restore: $e'};
    }
  }

  // Helper method to restore token in queue
  Future<void> _restoreTokenInQueue(
    Transaction transaction,
    String doctorId,
    String date,
    int originalToken,
    String appointmentId,
  ) async {
    try {
      // Get all appointments with tokens >= original token
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: ['confirmed', 'pending'])
          .where('tokenNumber', isGreaterThanOrEqualTo: originalToken)
          .get();

      // Increase token numbers to make space
      for (final doc in appointmentsQuery.docs.reversed) {
        final currentToken = doc.data()['tokenNumber'] as int?;
        if (currentToken != null) {
          transaction.update(doc.reference, {
            'tokenNumber': currentToken + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Restore original token for this appointment
      transaction.update(
        _firestore.collection('appointments').doc(appointmentId),
        {'tokenNumber': originalToken},
      );

      // Update queue count
      final queueDocRef = _firestore
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date');

      final queueDoc = await transaction.get(queueDocRef);
      if (queueDoc.exists) {
        transaction.update(queueDocRef, {
          'totalAppointments': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

    } catch (e) {
      print('⚠️ Error restoring token in queue: $e');
      rethrow;
    }
  }
}