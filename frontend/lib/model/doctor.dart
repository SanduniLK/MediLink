class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String imageUrl;
  final double rating;
  final String bio;
  final String experience;
  final List<String> availableTimes;
  final List<Map<String, dynamic>> schedules; 

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.imageUrl,
    required this.rating,
    required this.bio,
    required this.experience,
    required this.availableTimes,
    this.schedules = const [],
  });

  // from Firestore
  factory Doctor.fromMap(String id, Map<String, dynamic> data) {
    return Doctor(
      id: id,
      name: data['name'] ?? '',
      specialty: data['specialty'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      bio: data['bio'] ?? '',
      experience: data['experience'] ?? '',
      availableTimes: List<String>.from(data['availableTimes'] ?? []),
       schedules: List<Map<String, dynamic>>.from(['schedules'] ?? []),
    );
  }
}
