import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScheduleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String schedulesCollection = 'doctorSchedules';
  static const String appointmentSlotsCollection = 'appointmentSlots';

  // Get schedules count for specific medical center
  static Future<Map<String, int>> getSchedulesCount(String medicalCenterId) async {
    try {
      final snapshot = await _firestore.collection(schedulesCollection).get();
      final docs = snapshot.docs;

      int pending = 0;
      int approved = 0;
      int rejected = 0;

      for (final doc in docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? '';
        final scheduleMedicalCenterId = data['medicalCenterId']?.toString() ?? '';
        
        // Only count schedules for this medical center
        if (scheduleMedicalCenterId == medicalCenterId) {
          switch (status) {
            case 'pending':
              pending++;
              break;
            case 'confirmed':
              approved++;
              break;
            case 'rejected':
              rejected++;
              break;
          }
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'total': pending + approved + rejected,
      };
    } catch (e) {
      print('Error getting schedules count: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0, 'total': 0};
    }
  }

  // Get pending schedules for specific medical center
  static Stream<List<Map<String, dynamic>>> getPendingSchedules(String medicalCenterId) {
    return _firestore
        .collection(schedulesCollection)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['status'] == 'pending' && 
                       data['medicalCenterId'] == medicalCenterId;
              })
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  ...data,
                  'createdAt': data['createdAt']?.toDate(),
                  'date': data['date']?.toDate(),
                };
              })
              .toList()
            ..sort((a, b) {
              final aDate = a['createdAt'] as DateTime?;
              final bDate = b['createdAt'] as DateTime?;
              return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
            });
        });
  }

  // Get approved schedules for specific medical center
  static Stream<List<Map<String, dynamic>>> getApprovedSchedules(String medicalCenterId) {
    return _firestore
        .collection(schedulesCollection)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['status'] == 'confirmed' && 
                       data['medicalCenterId'] == medicalCenterId;
              })
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  ...data,
                  'createdAt': data['createdAt']?.toDate(),
                  'date': data['date']?.toDate(),
                };
              })
              .toList()
            ..sort((a, b) {
              final aDate = a['createdAt'] as DateTime?;
              final bDate = b['createdAt'] as DateTime?;
              return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
            });
        });
  }

  // Get rejected schedules for specific medical center
  static Stream<List<Map<String, dynamic>>> getRejectedSchedules(String medicalCenterId) {
    return _firestore
        .collection(schedulesCollection)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['status'] == 'rejected' && 
                       data['medicalCenterId'] == medicalCenterId;
              })
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  ...data,
                  'createdAt': data['createdAt']?.toDate(),
                  'date': data['date']?.toDate(),
                };
              })
              .toList()
            ..sort((a, b) {
              final aDate = a['createdAt'] as DateTime?;
              final bDate = b['createdAt'] as DateTime?;
              return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
            });
        });
  }

  // Approve a schedule
  static Future<void> approveSchedule(String scheduleId) async {
    try {
      await _firestore.collection(schedulesCollection).doc(scheduleId).update({
        'status': 'confirmed',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Schedule $scheduleId approved successfully');
      
      // Create appointment slots for patients
      await _createAppointmentSlots(scheduleId);
      
    } catch (e) {
      print('❌ Error approving schedule: $e');
      throw Exception('Failed to approve schedule: $e');
    }
  }

  // Reject a schedule
  static Future<void> rejectSchedule(String scheduleId) async {
    try {
      await _firestore.collection(schedulesCollection).doc(scheduleId).update({
        'status': 'rejected',
        'adminNotes': 'Schedule rejected by admin',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('❌ Schedule $scheduleId rejected');
    } catch (e) {
      print('❌ Error rejecting schedule: $e');
      throw Exception('Failed to reject schedule: $e');
    }
  }

  // Create appointment slots when schedule is approved
  static Future<void> _createAppointmentSlots(String scheduleId) async {
    try {
      final scheduleDoc = await _firestore.collection(schedulesCollection).doc(scheduleId).get();
      final scheduleData = scheduleDoc.data() as Map<String, dynamic>?;
      
      if (scheduleData == null) return;
      
      await _firestore.collection(appointmentSlotsCollection).add({
        'scheduleId': scheduleId,
        'doctorId': scheduleData['doctorId'],
        'doctorName': scheduleData['doctorName'],
        'medicalCenterId': scheduleData['medicalCenterId'],
        'medicalCenterName': scheduleData['medicalCenterName'],
        'date': scheduleData['date'],
        'startTime': scheduleData['startTime'],
        'endTime': scheduleData['endTime'],
        'slotDuration': scheduleData['slotDuration'],
        'appointmentType': scheduleData['appointmentType'],
        'maxAppointments': scheduleData['maxAppointments'],
        'availableSlots': scheduleData['availableSlots'] ?? scheduleData['maxAppointments'],
        'bookedAppointments': 0,
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Created appointment slot for schedule $scheduleId');
    } catch (e) {
      print('❌ Error creating appointment slots: $e');
    }
  }
}