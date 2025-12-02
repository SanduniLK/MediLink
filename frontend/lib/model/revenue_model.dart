class Appointment {
  final String id;
   final double doctorFees; // Doctor's portion from doctor collection
  final double totalFees;
  final DateTime? paidAt;
  final String date;
  final String? medicalCenterId;
  final String? medicalCenterName;
  final String? patientName;
  final String? patientId; 
  final String? doctorName;
  final String? consultationType;

  Appointment({
    required this.id,
    required this.doctorFees,
    required this.totalFees,
    required this.paidAt,
    required this.date,
    this.medicalCenterId,
    this.medicalCenterName,
    this.patientName,
    this.patientId,
    this.doctorName,
    this.consultationType,
  });
}

class MedicalCenter {
  final String id;
  final String name;

  MedicalCenter({
    required this.id,
    required this.name,
  });
}

class RevenueData {
  final String label;
  final double value;
  final DateTime date;

  RevenueData({
    required this.label,
    required this.value,
    required this.date,
  });
}