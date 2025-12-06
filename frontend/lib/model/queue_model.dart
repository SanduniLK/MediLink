// queue_model.dart
class QueueAppointment {
  String? id;
  String patientId;
  String patientName;
  String doctorId;
  String doctorName;
  String scheduleId;
  int tokenNumber;
  String status;
  String? queueStatus;
  DateTime? appointmentTime;
  Map<String, dynamic>? vitals;
  String? arrivalStatus;
  DateTime? arrivedAt;
  String? assistantStatus;
  bool? checkedByAssistant;

  QueueAppointment({
    this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.scheduleId,
    required this.tokenNumber,
    required this.status,
    this.queueStatus,
    this.appointmentTime,
    this.vitals,
    this.arrivalStatus,
    this.arrivedAt,
    this.assistantStatus,
    this.checkedByAssistant,
  });

  factory QueueAppointment.fromMap(Map<String, dynamic> map) {
    return QueueAppointment(
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      scheduleId: map['scheduleId'] ?? '',
      tokenNumber: map['tokenNumber'] ?? 0,
      status: map['status'] ?? 'pending',
      queueStatus: map['queueStatus'],
      appointmentTime: map['appointmentTime']?.toDate(),
      vitals: map['vitals'],
      arrivalStatus: map['arrivalStatus'],
      arrivedAt: map['arrivedAt']?.toDate(),
      assistantStatus: map['assistantStatus'],
      checkedByAssistant: map['checkedByAssistant'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'scheduleId': scheduleId,
      'tokenNumber': tokenNumber,
      'status': status,
      'queueStatus': queueStatus,
      'appointmentTime': appointmentTime,
      'vitals': vitals,
      'arrivalStatus': arrivalStatus,
      'arrivedAt': arrivedAt,
      'assistantStatus': assistantStatus,
      'checkedByAssistant': checkedByAssistant,
    };
  }
}