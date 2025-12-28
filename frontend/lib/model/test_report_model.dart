// lib/models/test_report_model.dart (UPDATED)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TestReportModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientEmail;
  final String? patientMobile;
  final String medicalCenterId;
  final String medicalCenterName;
  final String testName;
  final String testType;
  final String description;
  final String fileUrl;
  final String fileName;
  final String fileSize;
  final DateTime testDate;
  final DateTime uploadedAt;
  final String uploadedBy;
  final Map<String, dynamic> labFindings;
  final String status; // 'normal', 'abnormal', 'critical'
  final String notes;

  // Text extraction fields
  final String? extractedText;
  final Map<String, dynamic>? extractedData;
  final List<Map<String, dynamic>>? extractedParameters;
  final bool isTextExtracted;
  final DateTime? textExtractedAt;
  final String? testReportCategory;

  TestReportModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientEmail,
    this.patientMobile,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.testName,
    required this.testType,
    required this.description,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.testDate,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.labFindings,
    required this.status,
    required this.notes,
    
    // Text extraction fields
    this.extractedText,
    this.extractedData,
    this.extractedParameters,
    required this.isTextExtracted,
    this.textExtractedAt,
    this.testReportCategory,
  });

  // Factory constructor with better date handling
  factory TestReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse test date
    DateTime testDate;
    if (data['testDate'] is Timestamp) {
      testDate = (data['testDate'] as Timestamp).toDate();
    } else if (data['testDate'] is String) {
      try {
        testDate = DateFormat('dd/MM/yyyy').parse(data['testDate'] as String);
      } catch (e) {
        testDate = DateTime.now();
      }
    } else {
      testDate = DateTime.now();
    }
    
    // Parse uploaded date
    DateTime uploadedAt = (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    // Parse text extracted date
    DateTime? textExtractedAt;
    if (data['textExtractedAt'] != null) {
      textExtractedAt = (data['textExtractedAt'] as Timestamp).toDate();
    }
    
    return TestReportModel(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      patientEmail: data['patientEmail'],
      patientMobile: data['patientMobile'],
      medicalCenterId: data['medicalCenterId'] ?? '',
      medicalCenterName: data['medicalCenterName'] ?? '',
      testName: data['testName'] ?? '',
      testType: data['testType'] ?? '',
      description: data['description'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      fileSize: data['fileSize'] ?? '0 KB',
      testDate: testDate,
      uploadedAt: uploadedAt,
      uploadedBy: data['uploadedBy'] ?? 'Admin',
      labFindings: Map<String, dynamic>.from(data['labFindings'] ?? {}),
      status: data['status'] ?? 'normal',
      notes: data['notes'] ?? '',
      
      // Text extraction fields
      extractedText: data['extractedText'],
      extractedData: data['extractedData'] != null 
          ? Map<String, dynamic>.from(data['extractedData']) 
          : null,
      extractedParameters: data['extractedParameters'] != null
          ? List<Map<String, dynamic>>.from(data['extractedParameters'])
          : null,
      isTextExtracted: data['isTextExtracted'] ?? false,
      textExtractedAt: textExtractedAt,
      testReportCategory: data['testReportCategory'] ?? data['testType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'patientMobile': patientMobile,
      'medicalCenterId': medicalCenterId,
      'medicalCenterName': medicalCenterName,
      'testName': testName,
      'testType': testType,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'testDate': Timestamp.fromDate(testDate),
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
      'labFindings': labFindings,
      'status': status,
      'notes': notes,
      
      // Text extraction fields
      'extractedText': extractedText,
      'extractedData': extractedData,
      'extractedParameters': extractedParameters,
      'isTextExtracted': isTextExtracted,
      'textExtractedAt': textExtractedAt != null ? Timestamp.fromDate(textExtractedAt!) : null,
      'testReportCategory': testReportCategory,
    };
  }

  // Helper method for creating from upload data
  factory TestReportModel.fromUploadData({
    required String id,
    required String patientId,
    required String patientName,
    required String medicalCenterId,
    required String medicalCenterName,
    required String testName,
    required String testDateStr,
    required String fileName,
    required String fileUrl,
    required int fileSizeBytes,
    required String uploadedBy,
    String? extractedText,
    Map<String, dynamic>? extractedData,
    List<Map<String, dynamic>>? extractedParameters,
    String? notes,
    String? patientEmail,
    String? patientMobile,
  }) {
    // Parse test date
    DateTime testDate;
    try {
      testDate = DateFormat('dd/MM/yyyy').parse(testDateStr);
    } catch (e) {
      testDate = DateTime.now();
    }

    // Convert file size to readable format
    String fileSize;
    if (fileSizeBytes < 1024) {
      fileSize = '$fileSizeBytes B';
    } else if (fileSizeBytes < 1048576) {
      fileSize = '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      fileSize = '${(fileSizeBytes / 1048576).toStringAsFixed(1)} MB';
    }

    return TestReportModel(
      id: id,
      patientId: patientId,
      patientName: patientName,
      patientEmail: patientEmail,
      patientMobile: patientMobile,
      medicalCenterId: medicalCenterId,
      medicalCenterName: medicalCenterName,
      testName: testName,
      testType: testName, // Use testName as testType for now
      description: 'Lab test report',
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      testDate: testDate,
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
      labFindings: extractedData ?? {},
      status: 'normal', // Default status
      notes: notes ?? '',
      
      // Text extraction
      extractedText: extractedText,
      extractedData: extractedData,
      extractedParameters: extractedParameters,
      isTextExtracted: extractedText != null && extractedText.isNotEmpty,
      textExtractedAt: extractedText != null && extractedText.isNotEmpty ? DateTime.now() : null,
      testReportCategory: testName,
    );
  }

  // Get status color
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'abnormal':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get status icon
  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'normal':
        return Icons.check_circle;
      case 'abnormal':
        return Icons.warning;
      case 'critical':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  String get formattedTestDate {
    return DateFormat('MMM dd, yyyy').format(testDate);
  }

  String get formattedUploadDate {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(uploadedAt);
  }
}