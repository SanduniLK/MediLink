// lib/models/feedback_model.dart
class MedicalFeedback {
  final String id;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String medicalCenterId;
  final String medicalCenterName;
  final String doctorId;
  final String doctorName;
  final String? appointmentId;
  final int rating;
  final String comment;
  final bool wouldRecommend;
  final List<String> categories;
  final bool anonymous;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalFeedback({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.doctorId,
    required this.doctorName,
    this.appointmentId,
    required this.rating,
    required this.comment,
    required this.wouldRecommend,
    required this.categories,
    required this.anonymous,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MedicalFeedback.fromMap(String id, Map<String, dynamic> map) {
    return MedicalFeedback(
      id: id,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      patientEmail: map['patientEmail'] ?? '',
      medicalCenterId: map['medicalCenterId'] ?? '',
      medicalCenterName: map['medicalCenterName'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      appointmentId: map['appointmentId'],
      rating: map['rating'] ?? 0,
      comment: map['comment'] ?? '',
      wouldRecommend: map['wouldRecommend'] ?? false,
      categories: List<String>.from(map['categories'] ?? []),
      anonymous: map['anonymous'] ?? false,
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'medicalCenterId': medicalCenterId,
      'medicalCenterName': medicalCenterName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'appointmentId': appointmentId,
      'rating': rating,
      'comment': comment,
      'wouldRecommend': wouldRecommend,
      'categories': categories,
      'anonymous': anonymous,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class RatingSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;

  RatingSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory RatingSummary.fromMap(Map<String, dynamic> map) {
    return RatingSummary(
      averageRating: (map['averageRating'] ?? 0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      ratingDistribution: Map<int, int>.from(map['ratingDistribution'] ?? {}),
    );
  }
}