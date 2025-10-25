// Enhanced Token Service with Dynamic Queue - FIXED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DynamicTokenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Assign token number - always adds to the end
  Future<int> assignTokenNumber(String doctorId, String date) async {
    try {
      final queueDocRef = _firestore
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date');

      return await _firestore.runTransaction<int>((transaction) async {
        final queueDoc = await transaction.get(queueDocRef);
        
        int newTokenNumber;
        
        if (queueDoc.exists) {
          newTokenNumber = (queueDoc.data()!['lastTokenNumber'] ?? 0) + 1;
          transaction.update(queueDocRef, {
            'lastTokenNumber': newTokenNumber,
            'totalAppointments': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          newTokenNumber = 1;
          transaction.set(queueDocRef, {
            'doctorId': doctorId,
            'date': date,
            'lastTokenNumber': newTokenNumber,
            'currentServingToken': 0,
            'totalAppointments': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        print('🎫 Token assigned: $newTokenNumber for Dr. $doctorId on $date');
        return newTokenNumber;
      });
    } catch (e) {
      print('Error assigning token number: $e');
      rethrow;
    }
  }

  // ✅ FIXED: Cancel appointment and dynamically update tokens
  Future<void> cancelAppointmentAndUpdateTokens({
    required String appointmentId,
    required String scheduleId,
    required String doctorId,
    required String date,
    required int cancelledTokenNumber,
  }) async {
    try {
      print('🔄 Starting dynamic token cancellation...');
      print('   Cancelled Token: $cancelledTokenNumber');
      print('   Doctor: $doctorId, Date: $date');

      // Use batch write for better reliability than transaction
      final batch = _firestore.batch();

      // 1. Update appointment status
      final appointmentRef = _firestore.collection('appointments').doc(appointmentId);
      batch.update(appointmentRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'queueStatus': 'cancelled',
      });

      // 2. Update schedule slot count
      final scheduleRef = _firestore.collection('doctorSchedules').doc(scheduleId);
      batch.update(scheduleRef, {
        'bookedAppointments': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Get all appointments for this doctor/date that need token updates
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: ['confirmed', 'pending'])
          .where('tokenNumber', isGreaterThan: cancelledTokenNumber)
          .orderBy('tokenNumber')
          .get();

      final appointmentsToUpdate = appointmentsQuery.docs;
      print('📝 Found ${appointmentsToUpdate.length} appointments to update');

      // 4. Update token numbers for all subsequent appointments
      for (final doc in appointmentsToUpdate) {
        final currentToken = doc.data()['tokenNumber'] as int?;
        if (currentToken != null && currentToken > cancelledTokenNumber) {
          final newTokenNumber = currentToken - 1;
          batch.update(doc.reference, {
            'tokenNumber': newTokenNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('   Token updated: $currentToken → $newTokenNumber for ${doc.id}');
        }
      }

      // 5. Update queue document
      final queueDocRef = _firestore.collection('doctorDailyQueue').doc('${doctorId}_$date');
      final queueDoc = await queueDocRef.get();
      
      if (queueDoc.exists) {
        batch.update(queueDocRef, {
          'lastTokenNumber': FieldValue.increment(-1),
          'totalAppointments': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit all changes
      await batch.commit();

      print('🎉 Dynamic token update completed successfully');

    } catch (e) {
      print('❌ Error in dynamic token cancellation: $e');
      rethrow;
    }
  }

  // ✅ NEW: Simple token adjustment method for MyAppointmentsPage
  Future<void> adjustTokensAfterCancellationSimple({
    required String doctorId,
    required String date,
    required int cancelledTokenNumber,
  }) async {
    try {
      print('🔄 Starting simple token adjustment...');
      print('   Doctor: $doctorId, Date: $date, Cancelled Token: $cancelledTokenNumber');

      // Get all appointments that need updating
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: ['confirmed', 'pending'])
          .where('tokenNumber', isGreaterThan: cancelledTokenNumber)
          .orderBy('tokenNumber')
          .get();

      if (appointmentsQuery.docs.isEmpty) {
        print('ℹ️ No appointments need token adjustment');
        // Still update the queue document
        final queueDocRef = _firestore.collection('doctorDailyQueue').doc('${doctorId}_$date');
        final queueDoc = await queueDocRef.get();
        if (queueDoc.exists) {
          await queueDocRef.update({
            'lastTokenNumber': FieldValue.increment(-1),
            'totalAppointments': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      // Use batch write for updates
      final batch = _firestore.batch();

      // Update each appointment's token number
      for (final doc in appointmentsQuery.docs) {
        final currentToken = doc.data()['tokenNumber'] as int?;
        if (currentToken != null && currentToken > cancelledTokenNumber) {
          final newTokenNumber = currentToken - 1;
          batch.update(doc.reference, {
            'tokenNumber': newTokenNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('   🔄 Token $currentToken → $newTokenNumber');
        }
      }

      // Update queue document
      final queueDocRef = _firestore.collection('doctorDailyQueue').doc('${doctorId}_$date');
      batch.update(queueDocRef, {
        'lastTokenNumber': FieldValue.increment(-1),
        'totalAppointments': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('✅ Simple token adjustment completed');

    } catch (e) {
      print('❌ Error in simple token adjustment: $e');
      // Don't rethrow - allow cancellation to complete
    }
  }

  // Get current queue status for display
  Future<Map<String, dynamic>> getQueueStatus(String doctorId, String date) async {
    try {
      final queueDoc = await _firestore
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date')
          .get();

      if (!queueDoc.exists) {
        return {
          'totalAppointments': 0,
          'currentServingToken': 0,
          'lastTokenNumber': 0,
        };
      }

      return queueDoc.data()!;
    } catch (e) {
      print('Error getting queue status: $e');
      return {
        'totalAppointments': 0,
        'currentServingToken': 0,
        'lastTokenNumber': 0,
      };
    }
  }

  // Local storage methods
  Future<void> storeTokenLocally(String scheduleId, int tokenNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('token_$scheduleId', tokenNumber);
    print('💾 Token stored locally: $tokenNumber for schedule $scheduleId');
  }

  Future<int?> getStoredToken(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getInt('token_$scheduleId');
    print('📖 Retrieved local token: $token for schedule $scheduleId');
    return token;
  }

  Future<void> clearStoredToken(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token_$scheduleId');
    print('🗑️ Cleared local token for schedule $scheduleId');
  }
}