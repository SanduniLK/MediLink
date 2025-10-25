import 'doctor.dart';

class MedicalCenter {
  final String id;
  final String name;
  final List<Doctor> doctors;

  MedicalCenter({
    required this.id,
    required this.name,
    required this.doctors,
  });

  factory MedicalCenter.fromMap(String id, Map<String, dynamic> data) {
    return MedicalCenter(
      id: id,
      name: data['name'] ?? '',
      doctors: (data['doctors'] as List<dynamic>?)
              ?.map((doc) => Doctor.fromMap(doc['id'], doc))
              .toList() ??
          [],
    );
  }
}
