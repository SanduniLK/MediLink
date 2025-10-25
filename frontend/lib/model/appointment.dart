class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final String medicalCenterId;
  final String date;
  final String startTime;
  final String endTime;
  final String consultationType; // 'physical', 'audio', 'video'
  final String status; // 'requested', 'confirmed', 'cancelled', 'completed'
  final String patientNotes;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional fields for display
  final String? doctorName;
  final String? doctorSpecialty;
  final String? medicalCenterName;
  final String? patientName;
  final String? patientPhone;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.medicalCenterId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.consultationType,
    required this.status,
    required this.patientNotes,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    this.doctorName,
    this.doctorSpecialty,
    this.medicalCenterName,
    this.patientName,
    this.patientPhone,
  });

  factory Appointment.fromMap(String id, Map<String, dynamic> data) {
    return Appointment(
      id: id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      medicalCenterId: data['medicalCenterId'] ?? '',
      date: data['date'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      consultationType: data['consultationType'] ?? 'physical',
      status: data['status'] ?? 'requested',
      patientNotes: data['patientNotes'] ?? '',
      adminNotes: data['adminNotes'],
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      doctorName: data['doctorName'],
      doctorSpecialty: data['doctorSpecialty'],
      medicalCenterName: data['medicalCenterName'],
      patientName: data['patientName'],
      patientPhone: data['patientPhone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'medicalCenterId': medicalCenterId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'consultationType': consultationType,
      'status': status,
      'patientNotes': patientNotes,
      'adminNotes': adminNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class DoctorAvailability {
  final String id;
  final String doctorId;
  final String date;
  final String startTime;
  final String endTime;
  final String medicalCenterId;
  final List<String> consultationType;
  final bool isActive;

  DoctorAvailability({
    required this.id,
    required this.doctorId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.medicalCenterId,
    required this.consultationType,
    required this.isActive,
  });

  factory DoctorAvailability.fromMap(String id, Map<String, dynamic> data) {
    return DoctorAvailability(
      id: id,
      doctorId: data['doctorId'] ?? '',
      date: data['date'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      medicalCenterId: data['medicalCenterId'] ?? '',
      consultationType: List<String>.from(data['consultationType'] ?? ['physical']),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'medicalCenterId': medicalCenterId,
      'consultationType': consultationType,
      'isActive': isActive,
    };
  }
}


