// models/report_model.dart
class MedicalReport {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String reportType; // 'prescription', 'lab', 'diagnosis', 'summary'
  final String title;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String? appointmentId;
  final String? scheduleId;

  MedicalReport({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.reportType,
    required this.title,
    required this.data,
    required this.createdAt,
    this.appointmentId,
    this.scheduleId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'reportType': reportType,
      'title': title,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'appointmentId': appointmentId,
      'scheduleId': scheduleId,
    };
  }

  factory MedicalReport.fromMap(Map<String, dynamic> map) {
    return MedicalReport(
      id: map['id'],
      patientId: map['patientId'],
      patientName: map['patientName'],
      doctorId: map['doctorId'],
      doctorName: map['doctorName'],
      reportType: map['reportType'],
      title: map['title'],
      data: Map<String, dynamic>.from(map['data']),
      createdAt: DateTime.parse(map['createdAt']),
      appointmentId: map['appointmentId'],
      scheduleId: map['scheduleId'],
    );
  }
}