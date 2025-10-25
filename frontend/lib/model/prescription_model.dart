// models/prescription_model.dart
import 'dart:typed_data';

class Prescription {
  final String id;
  final String doctorId;
  final String patientName;
  final String patientId;
  final int? patientAge;
  final DateTime date;
  final List<Medicine> medicines;
  final String description;
  final String? diagnosis;
  final String? notes;
  final String? signatureUrl;
  final String status; // draft, completed, shared, dispensed
  final List<String> sharedPharmacies;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Uint8List? drawingImage;
  final Uint8List? signatureImage;
  final String? prescriptionImageUrl;

  Prescription({
    required this.id,
    required this.doctorId,
    required this.patientName,
    required this.patientId,
    this.patientAge,
    required this.date,
    required this.medicines,
    required this.description,
    this.diagnosis,
    this.notes,
    this.signatureUrl,
    this.status = 'draft',
    this.sharedPharmacies = const [],
    this.createdAt,
    this.updatedAt,
    this.drawingImage,
    this.signatureImage,
    this.prescriptionImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorId': doctorId,
      'patientName': patientName,
      'patientId': patientId,
      'patientAge': patientAge,
      'date': date.millisecondsSinceEpoch,
      'medicines': medicines.map((med) => med.toMap()).toList(),
      'description': description,
      'diagnosis': diagnosis,
      'notes': notes,
      'signatureUrl': signatureUrl,
      'status': status,
      'sharedPharmacies': sharedPharmacies,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'drawingImage': drawingImage,
      'signatureImage': signatureImage,
      'prescriptionImageUrl': prescriptionImageUrl,
    };
  }

  static Prescription fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'],
      doctorId: map['doctorId'],
      patientName: map['patientName'],
      patientId: map['patientId'],
      patientAge: map['patientAge'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      medicines: List<Medicine>.from(
          map['medicines']?.map((x) => Medicine.fromMap(x)) ?? []),
      description: map['description'],
      diagnosis: map['diagnosis'],
      notes: map['notes'],
      signatureUrl: map['signatureUrl'],
      status: map['status'] ?? 'draft',
      sharedPharmacies: List<String>.from(map['sharedPharmacies'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
      drawingImage: map['drawingImage'],
      signatureImage: map['signatureImage'],
      prescriptionImageUrl: map['prescriptionImageUrl'],
    );
  }
}

class Medicine {
  final String name;
  final String dosage;
  final String duration;
  final String? frequency;
  final String? instructions;

  Medicine({
    required this.name,
    required this.dosage,
    required this.duration,
    this.frequency,
    this.instructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'duration': duration,
      'frequency': frequency,
      'instructions': instructions,
    };
  }

  static Medicine fromMap(Map<String, dynamic> map) {
    return Medicine(
      name: map['name'],
      dosage: map['dosage'],
      duration: map['duration'],
      frequency: map['frequency'],
      instructions: map['instructions'],
    );
  }
}