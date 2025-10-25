class TelemedicineSession {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String date;
  final String timeSlot;
  final String status;
  final String videoLink;
  final String chatRoomId;
  final String consultationType;

  TelemedicineSession({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.videoLink,
    required this.chatRoomId,
    required this.consultationType,
  });

  factory TelemedicineSession.fromMap(Map<String, dynamic> data, String id) {
    return TelemedicineSession(
      id: id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      date: data['date'] ?? '',
      timeSlot: data['timeSlot'] ?? '',
      status: data['status'] ?? 'Scheduled',
      videoLink: data['videoLink'] ?? '',
      chatRoomId: data['chatRoomId'] ?? '',
      consultationType: data['consultationType'] ?? 'video',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'date': date,
      'timeSlot': timeSlot,
      'status': status,
      'videoLink': videoLink,
      'chatRoomId': chatRoomId,
      'consultationType': consultationType,
    };
  }
}