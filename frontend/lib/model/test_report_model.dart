// lib/models/test_report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TestReportModel {
  final String id;
  final String patientId;
  final String patientName;
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

  TestReportModel({
    required this.id,
    required this.patientId,
    required this.patientName,
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
  });

  factory TestReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TestReportModel(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      medicalCenterId: data['medicalCenterId'] ?? '',
      medicalCenterName: data['medicalCenterName'] ?? '',
      testName: data['testName'] ?? '',
      testType: data['testType'] ?? '',
      description: data['description'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      fileSize: data['fileSize'] ?? '',
      testDate: (data['testDate'] as Timestamp).toDate(),
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      uploadedBy: data['uploadedBy'] ?? '',
      labFindings: Map<String, dynamic>.from(data['labFindings'] ?? {}),
      status: data['status'] ?? 'normal',
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
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
    };
  }

  // Get status color
  Color get statusColor {
    switch (status) {
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
    switch (status) {
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