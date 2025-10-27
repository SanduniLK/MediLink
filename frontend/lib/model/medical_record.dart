// models/medical_record.dart
class MedicalRecord {
  final String id;
  final String patientId;
  final String fileName;
  final String fileUrl;
  final String fileType; // pdf, jpg, png, etc.
  final RecordCategory category;
  final DateTime uploadDate;
  final String? description;
  final int fileSize;

  MedicalRecord({
    required this.id,
    required this.patientId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.category,
    required this.uploadDate,
    this.description,
    required this.fileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'category': category.name,
      'uploadDate': uploadDate.millisecondsSinceEpoch,
      'description': description,
      'fileSize': fileSize,
    };
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    return MedicalRecord(
      id: map['id'],
      patientId: map['patientId'],
      fileName: map['fileName'],
      fileUrl: map['fileUrl'],
      fileType: map['fileType'],
      category: RecordCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => RecordCategory.other,
      ),
      uploadDate: DateTime.fromMillisecondsSinceEpoch(map['uploadDate']),
      description: map['description'],
      fileSize: map['fileSize'],
    );
  }
}

enum RecordCategory {
  labResults,
  pastPrescriptions,
  other,
}

extension RecordCategoryExtension on RecordCategory {
  String get displayName {
    switch (this) {
      case RecordCategory.labResults:
        return 'Lab Test Results';
      case RecordCategory.pastPrescriptions:
        return 'Past Prescriptions';
      case RecordCategory.other:
        return 'Other Medical Records';
    }
  }

  String get icon {
    switch (this) {
      case RecordCategory.labResults:
        return '🧪';
      case RecordCategory.pastPrescriptions:
        return '💊';
      case RecordCategory.other:
        return '📁';
    }
  }
}