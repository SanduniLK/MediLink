// frontend/lib/model/telemedicine_session.dart

class TelemedicineSession {
  final String id;
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String consultationType;
  final String chatRoomId;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double fees;
  final String paymentStatus;
  final String? medicalCenterId;
  final String? medicalCenterName;
  final String? doctorSpecialty;
  final String? date;
  final String? timeSlot;
  final int? tokenNumber;
  final String? videoLink;
  final bool doctorHasJoined;
  final bool patientHasJoined;
 

  TelemedicineSession({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.consultationType,
    required this.chatRoomId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.fees,
    required this.paymentStatus,
    this.medicalCenterId,
    this.medicalCenterName,
    this.doctorSpecialty,
    this.date,
    this.timeSlot,
    this.tokenNumber,
    this.videoLink,
   this.doctorHasJoined=false,
   this.patientHasJoined=false,

    
  });

  factory TelemedicineSession.fromMap(Map<String, dynamic> map) {
    return TelemedicineSession(
      id: map['id'] ?? map['appointmentId'] ?? '',
      appointmentId: map['appointmentId'] ?? map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      consultationType: map['consultationType'] ?? 'audio',
      chatRoomId: map['chatRoomId'] ?? '',
      status: map['status'] ?? 'Scheduled',
      createdAt: _parseDateTime(map['createdAt']),
      startedAt: _parseDateTime(map['startedAt']),
      endedAt: _parseDateTime(map['endedAt']),
      fees: (map['fees'] ?? 0).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'pending',
      medicalCenterId: map['medicalCenterId'],
      medicalCenterName: map['medicalCenterName'],
      doctorSpecialty: map['doctorSpecialty'],
      date: map['date'],
      timeSlot: map['timeSlot'],
      tokenNumber: map['tokenNumber'],
      videoLink: map['videoLink'],
      doctorHasJoined: map['doctorHasJoined'] ?? false,
      patientHasJoined: map['patientHasJoined'] ?? false,
    );
  }

  static DateTime _parseDateTime(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        // Try to handle different date formats
        if (date.contains('(')) {
          // Handle "Today (4/11/2025)" format
          final match = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(date);
          if (match != null) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          }
        }
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'consultationType': consultationType,
      'chatRoomId': chatRoomId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'fees': fees,
      'paymentStatus': paymentStatus,
      'medicalCenterId': medicalCenterId,
      'medicalCenterName': medicalCenterName,
      'doctorSpecialty': doctorSpecialty,
      'date': date,
      'timeSlot': timeSlot,
      'tokenNumber': tokenNumber,
      'videoLink': videoLink,
      'doctorHasJoined': doctorHasJoined,
      'patientHasJoined': patientHasJoined,
    };
  }

  bool get canStart => status == 'Scheduled' || status == 'In-Progress';
  bool get isCompleted => status == 'Completed';
  bool get isAudioCall => consultationType == 'audio';
  bool get isVideoCall => consultationType == 'video';
  bool get isInProgress => status == 'In-Progress';
  bool get isScheduled => status == 'Scheduled';
}