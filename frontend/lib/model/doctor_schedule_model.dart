// frontend/lib/models/doctor_schedule_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TimeSlot {
  final String startTime;
  final String endTime;
  final int slotDuration;
  final int maxAppointments;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.slotDuration = 30,
    required this.maxAppointments,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'slotDuration': slotDuration,
      'maxAppointments': maxAppointments,
    };
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      slotDuration: json['slotDuration'] ?? 30,
      maxAppointments: json['maxAppointments'] ?? 10,
    );
  }
}

class DailySchedule {
  final String day;
  final bool available;
  final List<TimeSlot> timeSlots;
  final int maxAppointments;

  DailySchedule({
    required this.day,
    required this.available,
    required this.timeSlots,
    required this.maxAppointments,
  });

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'available': available,
      'timeSlots': timeSlots.map((slot) => slot.toJson()).toList(),
      'maxAppointments': maxAppointments,
      
    };
  }

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
    return DailySchedule(
      day: json['day'] ?? '',
      available: json['available'] ?? false,
      timeSlots: (json['timeSlots'] as List? ?? [])
          .map((slot) => TimeSlot.fromJson(slot))
          .toList(),
          maxAppointments: json['maxAppointments'] ?? 10,
    );
  }
}

class DoctorSchedule {
  final String id;
  final String doctorId;
  final String doctorName;
  final String medicalCenterId;
  final String medicalCenterName;
  final List<DailySchedule> weeklySchedule;
  final bool adminApproved;
  final String? adminNotes;
  final bool isActive;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime scheduleDate; // The actual booking date
  final String availableDate; // For easy querying (YYYY-MM-DD format)

  DoctorSchedule({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.weeklySchedule,
    this.adminApproved = false,
    this.adminNotes,
    this.isActive = true,
    required this.status,
    this.submittedAt,
    this.approvedAt,
    this.rejectedAt,
    required this.scheduleDate,
    required this.availableDate,
  });

  // For backend API - when submitting new schedule
  Map<String, dynamic> toBackendJson() {
    return {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'medicalCenterId': medicalCenterId,
      'medicalCenterName': medicalCenterName,
      'weeklySchedule': weeklySchedule.map((day) => day.toJson()).toList(),
      'scheduleDate': Timestamp.fromDate(scheduleDate),
      'availableDate': availableDate,
    };
  }

  // For converting to JSON for other uses
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'medicalCenterId': medicalCenterId,
      'medicalCenterName': medicalCenterName,
      'weeklySchedule': weeklySchedule.map((day) => day.toJson()).toList(),
      'adminApproved': adminApproved,
      'adminNotes': adminNotes,
      'isActive': isActive,
      'status': status,
      'submittedAt': submittedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'scheduleDate': scheduleDate.toIso8601String(),
      'availableDate': availableDate,
    };
  }

  // Factory method to create from Firebase document
  factory DoctorSchedule.fromFirebase(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Helper function to convert Firestore Timestamp to DateTime
    DateTime? convertTimestamp(dynamic timestamp) {
      if (timestamp == null) return null;
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      // Handle case where timestamp might be a Map (from JSON)
      if (timestamp is Map<String, dynamic> && timestamp['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
      }
      return null;
    }

    return DoctorSchedule(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      medicalCenterId: data['medicalCenterId'] ?? '',
      medicalCenterName: data['medicalCenterName'] ?? '',
      weeklySchedule: (data['weeklySchedule'] as List? ?? [])
          .map((dayJson) => DailySchedule.fromJson(dayJson))
          .toList(),
      adminApproved: data['adminApproved'] ?? false,
      adminNotes: data['adminNotes'],
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? 'pending',
      submittedAt: convertTimestamp(data['submittedAt']),
      approvedAt: convertTimestamp(data['approvedAt']),
      rejectedAt: convertTimestamp(data['rejectedAt']),
      scheduleDate: convertTimestamp(data['scheduleDate']) ?? DateTime.now(),
      availableDate: data['availableDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }

  // Factory method to create from JSON (for API responses)
  factory DoctorSchedule.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic dateString) {
      if (dateString == null) return null;
      if (dateString is String) {
        try {
          return DateTime.parse(dateString);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return DoctorSchedule(
      id: json['id'] ?? '',
      doctorId: json['doctorId'] ?? '',
      doctorName: json['doctorName'] ?? '',
      medicalCenterId: json['medicalCenterId'] ?? '',
      medicalCenterName: json['medicalCenterName'] ?? '',
      weeklySchedule: (json['weeklySchedule'] as List? ?? [])
          .map((dayJson) => DailySchedule.fromJson(dayJson))
          .toList(),
      adminApproved: json['adminApproved'] ?? false,
      adminNotes: json['adminNotes'],
      isActive: json['isActive'] ?? true,
      status: json['status'] ?? 'pending',
      submittedAt: parseDateTime(json['submittedAt']),
      approvedAt: parseDateTime(json['approvedAt']),
      rejectedAt: parseDateTime(json['rejectedAt']),
      scheduleDate: parseDateTime(json['scheduleDate']) ?? DateTime.now(),
      availableDate: json['availableDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }

  // Create a copy with updated fields
  DoctorSchedule copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    String? medicalCenterId,
    String? medicalCenterName,
    List<DailySchedule>? weeklySchedule,
    bool? adminApproved,
    String? adminNotes,
    bool? isActive,
    String? status,
    DateTime? submittedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    DateTime? scheduleDate,
    String? availableDate,
  }) {
    return DoctorSchedule(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      medicalCenterId: medicalCenterId ?? this.medicalCenterId,
      medicalCenterName: medicalCenterName ?? this.medicalCenterName,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      adminApproved: adminApproved ?? this.adminApproved,
      adminNotes: adminNotes ?? this.adminNotes,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      scheduleDate: scheduleDate ?? this.scheduleDate,
      availableDate: availableDate ?? this.availableDate,
    );
  }

  // Helper method to check if schedule is pending
  bool get isPending => status == 'pending';

  // Helper method to check if schedule is approved
  bool get isApproved => status == 'approved';

  // Helper method to check if schedule is rejected
  bool get isRejected => status == 'rejected';

  // Get available days
  List<String> get availableDays {
    return weeklySchedule
        .where((day) => day.available && day.timeSlots.isNotEmpty)
        .map((day) => day.day)
        .toList();
  }

  // Get time slots for a specific day
  List<TimeSlot> getTimeSlotsForDay(String day) {
  final dailySchedule = weeklySchedule.firstWhere(
    (schedule) => schedule.day == day,
    orElse: () => DailySchedule(
      day: day, 
      available: false, 
      timeSlots: [],
      maxAppointments: 10, // ✅ ADD THIS
    ),
  );
  return dailySchedule.timeSlots;
}
}