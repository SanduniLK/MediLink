// frontend/lib/models/appointment_slot_model.dart


class AppointmentSlot {
  final String id;
  final String scheduleId;
  final String doctorId;
  final String doctorName;
  final String medicalCenterId;
  final String medicalCenterName;
  final String date;
  final String startTime;
  final String endTime;
  final int slotDuration;
  final String appointmentType;
  final int maxAppointments;
  final int bookedAppointments;
  final String status;
  final DateTime? createdAt;

  AppointmentSlot({
    required this.id,
    required this.scheduleId,
    required this.doctorId,
    required this.doctorName,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.slotDuration = 30,
    this.appointmentType = 'physical',
    this.maxAppointments = 10,
    this.bookedAppointments = 0,
    required this.status,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'medicalCenterId': medicalCenterId,
      'medicalCenterName': medicalCenterName,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'slotDuration': slotDuration,
      'appointmentType': appointmentType,
      'maxAppointments': maxAppointments,
      'bookedAppointments': bookedAppointments,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory AppointmentSlot.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDateTime(dynamic dateString) {
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

    return AppointmentSlot(
      id: json['id'] ?? '',
      scheduleId: json['scheduleId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      doctorName: json['doctorName'] ?? '',
      medicalCenterId: json['medicalCenterId'] ?? '',
      medicalCenterName: json['medicalCenterName'] ?? '',
      date: json['date'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      slotDuration: json['slotDuration'] ?? 30,
      appointmentType: json['appointmentType'] ?? 'physical',
      maxAppointments: json['maxAppointments'] ?? 10,
      bookedAppointments: json['bookedAppointments'] ?? 0,
      status: json['status'] ?? 'confirmed',
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  bool get isAvailable => status == 'confirmed' && bookedAppointments < maxAppointments;
  int get availableSlots => maxAppointments - bookedAppointments;

  DateTime get dateTime {
    try {
      return DateTime.parse(date);
    } catch (e) {
      return DateTime.now();
    }
  }

  String get formattedDate {
    final dateTime = this.dateTime;
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String get dayName {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[dateTime.weekday % 7];
  }
}