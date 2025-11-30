import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/doctor_schedule_model.dart';
import 'package:intl/intl.dart';

class DoctorScheduleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'doctorSchedules';

  // ADD THIS METHOD: Get schedules for patients (approved + confirmed)
  static Stream<List<DoctorSchedule>> getSchedulesForPatients() {
    return _firestore
        .collection(collectionName)
        .where('adminApproved', isEqualTo: true)
        .where('doctorConfirmed', isEqualTo: true)
        .where('status', isEqualTo: 'approved')
        .orderBy('medicalCenterName')
        .snapshots()
        .map((snapshot) {
          print('👥 Found ${snapshot.docs.length} schedules for patients');
          return snapshot.docs
              .map((doc) => DoctorSchedule.fromFirebase(doc))
              .toList();
        });
  }

  // Get doctor's current approved schedule
  static Future<DoctorSchedule?> getMySchedule(String doctorId) async {
    try {
      print('🔍 Getting schedule for doctor: $doctorId');
      
      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'approved')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print('✅ Found approved schedule for doctor');
        return DoctorSchedule.fromFirebase(querySnapshot.docs.first);
      } else {
        print('ℹ️ No approved schedule found for doctor');
        return null;
      }
    } catch (e) {
      print('❌ Error in getMySchedule: $e');
      return null;
    }
  }

  // Save new schedule
  static Future<void> saveSchedule({
    required String doctorId,
    required String doctorName,
    required String medicalCenterId,
    required String medicalCenterName,
    required String medicalCenterAdminId,
    required List<DailySchedule> weeklySchedule,
    required String appointmentType, // ADD THIS PARAMETER
    required List<String> telemedicineTypes, // ADD THIS PARAMETER
    required DateTime scheduleDate,
    required int maxAppointments,
   
  }) async {
    try {
       print('💾 Saving schedule for doctor: $doctorName');
      print('📝 Appointment Type: $appointmentType');
      if (appointmentType == 'telemedicine') {
        print('📱 Telemedicine Types: $telemedicineTypes');
      }
      
      final scheduleData = {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'medicalCenterId': medicalCenterId,
        'medicalCenterName': medicalCenterName,
        'medicalCenterAdminId': medicalCenterAdminId,
        'weeklySchedule': weeklySchedule.map((day) => day.toJson()).toList(),
        'appointmentType': appointmentType, 
        'telemedicineTypes': telemedicineTypes, 
        'scheduleDate': Timestamp.fromDate(scheduleDate), 
        'availableDate': DateFormat('yyyy-MM-dd').format(scheduleDate), 
        'maxAppointments': maxAppointments,
        'adminApproved': false,
        'doctorConfirmed': false,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(collectionName).add(scheduleData);
      print('✅ Schedule saved successfully! Waiting for admin approval.');
    } catch (e) {
      print('❌ Error saving schedule: $e');
      throw Exception('Failed to save schedule: $e');
    }
  }

  // Get pending schedules for medical center admin
  static Stream<List<DoctorSchedule>> getPendingSchedulesForMedicalCenterAdmin(String adminId) {
    return _firestore
        .collection(collectionName)
        .where('medicalCenterAdminId', isEqualTo: adminId)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('📋 Found ${snapshot.docs.length} pending schedules for admin');
          return snapshot.docs
              .map((doc) => DoctorSchedule.fromFirebase(doc))
              .toList();
        });
  }

  // Medical center admin approves schedule
  static Future<void> approveScheduleByMedicalCenterAdmin(String scheduleId) async {
    try {
      await _firestore.collection(collectionName).doc(scheduleId).update({
        'adminApproved': true,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Schedule $scheduleId approved by medical center admin');
    } catch (e) {
      print('❌ Error approving schedule: $e');
      throw Exception('Failed to approve schedule: $e');
    }
  }

  // Medical center admin rejects schedule
  static Future<void> rejectScheduleByMedicalCenterAdmin(String scheduleId) async {
    try {
      await _firestore.collection(collectionName).doc(scheduleId).update({
        'adminApproved': false,
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('❌ Schedule $scheduleId rejected by medical center admin');
    } catch (e) {
      print('❌ Error rejecting schedule: $e');
      throw Exception('Failed to reject schedule: $e');
    }
  }

  // Doctor confirms availability
  static Future<void> confirmDoctorAvailability(String scheduleId) async {
    try {
      await _firestore.collection(collectionName).doc(scheduleId).update({
        'doctorConfirmed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Doctor confirmed availability for schedule $scheduleId');
    } catch (e) {
      print('❌ Error confirming availability: $e');
      throw Exception('Failed to confirm availability: $e');
    }
  }
  static List<DateTime> generateAvailableDatesFromWeeklySchedule(List<DailySchedule> weeklySchedule, {int daysAhead = 30}) {
    final List<DateTime> availableDates = [];
    final now = DateTime.now();
    
    for (int i = 0; i < daysAhead; i++) {
      final date = now.add(Duration(days: i));
      final dayName = DateFormat('EEEE').format(date).toLowerCase();
      
      // Check if this day is available in the weekly schedule
      for (var daySchedule in weeklySchedule) {
        if (daySchedule.day.toLowerCase() == dayName && daySchedule.available) {
          availableDates.add(date);
          break;
        }
      }
    }
    
    return availableDates;
  }
 static List<TimeSlot> getAvailableTimeSlotsForDate(List<DailySchedule> weeklySchedule, DateTime date) {
    final dayName = DateFormat('EEEE').format(date).toLowerCase();
    
    for (var daySchedule in weeklySchedule) {
      if (daySchedule.day.toLowerCase() == dayName && daySchedule.available) {
        return daySchedule.timeSlots;
      }
    }
    
    return [];
  }
  // ADD THIS METHOD to DoctorScheduleService - Get available schedules for patients
static Stream<List<DoctorSchedule>> getAvailableSchedulesForBooking() {
  final today = DateTime.now();
  final todayString = DateFormat('yyyy-MM-dd').format(today);
  
  return _firestore
      .collection(collectionName)
      .where('adminApproved', isEqualTo: true)
      .where('doctorConfirmed', isEqualTo: true)
      .where('status', isEqualTo: 'approved')
      .where('availableDate', isGreaterThanOrEqualTo: todayString) // ADD THIS
      .orderBy('availableDate')
      .orderBy('medicalCenterName')
      .snapshots()
      .map((snapshot) {
        print('📅 Found ${snapshot.docs.length} available schedules for booking');
        return snapshot.docs
            .map((doc) => DoctorSchedule.fromFirebase(doc))
            .toList();
      });
}
}
