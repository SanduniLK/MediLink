// lib/model/medical_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/record_category.dart'; // Add this import

class MedicalRecord {
  final String id;
  final String patientId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final RecordCategory category;
  final DateTime uploadDate;
  final String? description;
  final int fileSize;
  
  // Extracted data
  final String? extractedText;
  final Map<String, dynamic>? medicalInfo;
  final String? textExtractionStatus;
  final DateTime? textExtractedAt;

  final String? testReportCategory; 
  final String? testDate;

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
    this.extractedText,
    this.medicalInfo,
    this.textExtractionStatus,
    this.textExtractedAt,
    this.testReportCategory,
    this.testDate,
  });

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    // Handle uploadDate - could be Timestamp, DateTime, or int
    DateTime parseUploadDate(dynamic dateData) {
      try {
        if (dateData is Timestamp) {
          return dateData.toDate();
        } else if (dateData is DateTime) {
          return dateData;
        } else if (dateData is int) {
          return DateTime.fromMillisecondsSinceEpoch(dateData);
        } else if (dateData is String) {
          return DateTime.parse(dateData);
        } else {
          print('⚠️ Unknown uploadDate type: ${dateData.runtimeType}');
          return DateTime.now();
        }
      } catch (e) {
        print('❌ Error parsing uploadDate: $e');
        return DateTime.now();
      }
    }

    // Handle textExtractedAt - could be Timestamp, DateTime, int, or null
    DateTime? parseTextExtractedAt(dynamic dateData) {
      if (dateData == null) return null;
      
      try {
        if (dateData is Timestamp) {
          return dateData.toDate();
        } else if (dateData is DateTime) {
          return dateData;
        } else if (dateData is int) {
          return DateTime.fromMillisecondsSinceEpoch(dateData);
        } else if (dateData is String) {
          return DateTime.parse(dateData);
        } else {
          print('⚠️ Unknown textExtractedAt type: ${dateData.runtimeType}');
          return null;
        }
      } catch (e) {
        print('❌ Error parsing textExtractedAt: $e');
        return null;
      }
    }

    // Handle category
    RecordCategory parseCategory(dynamic categoryData) {
      try {
        if (categoryData is String) {
          return RecordCategory.values.firstWhere(
            (e) => e.name == categoryData,
            orElse: () => RecordCategory.other,
          );
        }
        return RecordCategory.other;
      } catch (e) {
        print('❌ Error parsing category: $e');
        return RecordCategory.other;
      }
    }

    return MedicalRecord(
      id: map['id']?.toString() ?? '',
      patientId: map['patientId']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      fileUrl: map['fileUrl']?.toString() ?? '',
      fileType: map['fileType']?.toString() ?? '',
      category: parseCategory(map['category']),
      uploadDate: parseUploadDate(map['uploadDate']),
      description: map['description']?.toString(),
      fileSize: (map['fileSize'] is int) 
          ? map['fileSize'] as int 
          : int.tryParse(map['fileSize']?.toString() ?? '0') ?? 0,
      extractedText: map['extractedText']?.toString(),
      medicalInfo: map['medicalInfo'] != null 
          ? Map<String, dynamic>.from(map['medicalInfo']) 
          : null,
      textExtractionStatus: map['textExtractionStatus']?.toString(),
      textExtractedAt: parseTextExtractedAt(map['textExtractedAt']),
      testReportCategory: map['testReportCategory']?.toString(),
      testDate: map['testDate']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'category': category.name,
      'uploadDate': Timestamp.fromDate(uploadDate), // Always save as Timestamp
      'description': description,
      'fileSize': fileSize,
      'extractedText': extractedText,
      'medicalInfo': medicalInfo,
      'textExtractionStatus': textExtractionStatus,
      'textExtractedAt': textExtractedAt != null 
          ? Timestamp.fromDate(textExtractedAt!) 
          : null,
      'testReportCategory': testReportCategory,
      'testDate': testDate,
    };
  }
}