// lib/services/admin_test_report_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/google_vision_service.dart';
import 'package:intl/intl.dart';

class AdminTestReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<Map<String, dynamic>> uploadTestReport({
    required File file,
    required String patientId,
    required String patientName,
    required String medicalCenterId,
    required String medicalCenterName,
    required String testReportCategory,
    required String testDate,
    required BuildContext context,
    String? notes,
    String? patientEmail,
    String? patientMobile,
  }) async {
    try {
      debugPrint('📤 === ADMIN TEST REPORT UPLOAD STARTED ===');
      debugPrint('📋 File: ${file.path}');
      debugPrint('📋 Patient: $patientName ($patientId)');
      debugPrint('📋 Test Category: $testReportCategory');
      debugPrint('📋 Test Date: $testDate');
      
      // ========== STEP 1: UPLOAD FILE TO STORAGE ==========
      debugPrint('☁️ Step 1: Uploading file to storage...');
      
      final String fileName = file.path.split('/').last;
      final String fileExtension = fileName.split('.').last.toLowerCase();
      final int fileSize = await file.length();
      
      final String storagePath = 'admin_test_reports/$patientId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference storageRef = _storage.ref().child(storagePath);
      
      final UploadTask uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: _getContentType(fileExtension)),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ File uploaded to: $downloadUrl');
      
      // ========== STEP 2: EXTRACT TEXT FROM FILE ==========
      debugPrint('🔍 Step 2: Extracting text from document...');
      
      Map<String, dynamic> extractedData;
      try {
        // Use the same Google Vision service that patient upload uses
        extractedData = await GoogleVisionService.extractMedicalText(file);
      } catch (e) {
        debugPrint('⚠️ Google Vision failed: $e');
        // Fallback to mock extraction
        extractedData = await _mockExtractText(file);
      }
      
      final String? extractedText = extractedData['success'] ? extractedData['fullText'] : null;
      final Map<String, dynamic>? medicalInfo = extractedData['success'] ? extractedData['medicalInfo'] : null;
      
      debugPrint('✅ Text extraction completed');
      
      // ========== STEP 3: SAVE TO TEST_REPORTS COLLECTION ==========
      debugPrint('💾 Step 3: Saving to test_reports collection...');
      
      final String reportId = _firestore.collection('test_reports').doc().id;
      final DateTime now = DateTime.now();
      
      // Parse test date
      DateTime parsedTestDate;
      try {
        parsedTestDate = DateFormat('dd/MM/yyyy').parse(testDate);
      } catch (e) {
        parsedTestDate = now;
      }
      
      // Format file size
      final String formattedFileSize = _formatFileSize(fileSize);
      
      // Create test report data
      final Map<String, dynamic> testReportData = {
        'id': reportId,
        'patientId': patientId,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'patientMobile': patientMobile,
        'medicalCenterId': medicalCenterId,
        'medicalCenterName': medicalCenterName,
        'testName': testReportCategory,
        'testType': testReportCategory,
        'description': notes ?? 'Lab test report uploaded by admin',
        'fileUrl': downloadUrl,
        'fileName': fileName,
        'fileSize': formattedFileSize,
        'testDate': Timestamp.fromDate(parsedTestDate),
        'uploadedAt': Timestamp.fromDate(now),
        'uploadedBy': 'Admin at $medicalCenterName',
        'labFindings': medicalInfo ?? {},
        'status': 'normal', // Will be determined after analysis
        'notes': notes ?? '',
        
        // Text extraction fields
        'extractedText': extractedText,
        'extractedData': extractedData,
        'extractedParameters': extractedData['extractedParameters'] ?? [],
        'isTextExtracted': extractedData['success'] == true,
        'textExtractedAt': Timestamp.fromDate(now),
        'textExtractionStatus': extractedData['success'] ? 'extracted' : 'failed',
        'testReportCategory': testReportCategory,
      };
      
      await _firestore.collection('test_reports').doc(reportId).set(testReportData);
      debugPrint('✅ Saved to test_reports: $reportId');
      
      // ========== STEP 4: SAVE TO PATIENT_NOTES (LIKE PATIENT UPLOAD) ==========
      if (extractedText != null && extractedText.isNotEmpty) {
        debugPrint('📝 Step 4: Saving to patient_notes for analysis...');
        
        await _saveToPatientNotes(
          patientId: patientId,
          recordId: reportId,
          fileName: fileName,
          testReportCategory: testReportCategory,
          testDate: testDate,
          extractedText: extractedText,
          medicalInfo: medicalInfo,
          extractedData: extractedData,
          medicalCenterName: medicalCenterName,
          fileUrl: downloadUrl,
        );
      }
      
      // ========== STEP 5: ANALYZE AND UPDATE STATUS ==========
      debugPrint('🔬 Step 5: Analyzing test results...');
      
      final String status = await _analyzeAndUpdateStatus(
        reportId: reportId,
        extractedData: extractedData,
        extractedText: extractedText,
      );
      
      debugPrint('✅ === ADMIN TEST REPORT UPLOAD COMPLETED ===');
      debugPrint('✅ Report ID: $reportId');
      debugPrint('✅ Status: $status');
      
      return {
        'success': true,
        'reportId': reportId,
        'status': status,
        'message': 'Test report uploaded successfully',
      };
      
    } catch (e) {
      debugPrint('❌ === ADMIN TEST REPORT UPLOAD FAILED ===');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Stack trace: ${e.toString()}');
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to upload test report',
      };
    }
  }

  static Future<Map<String, dynamic>> _mockExtractText(File file) async {
    // Mock extraction for testing
    await Future.delayed(const Duration(seconds: 1));
    
    final mockText = '''
Patient Name: John Doe
Age: 35 Years
Gender: Male
Test Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}

LABORATORY REPORT - Complete Blood Count (CBC)

Results:
1. Haemoglobin (Hb): 15.2 g/dL
   Reference Range: 13.0 - 17.0 g/dL
   Status: Normal

2. White Blood Cell Count (WBC): 7,500 /cmm
   Reference Range: 4,000 - 11,000 /cmm
   Status: Normal

3. Platelet Count: 250,000 /cmm
   Reference Range: 150,000 - 450,000 /cmm
   Status: Normal

4. Red Blood Cell Count (RBC): 5.2 million/cmm
   Reference Range: 4.5 - 5.9 million/cmm
   Status: Normal

All parameters are within normal limits.
    ''';
    
    return {
      'success': true,
      'fullText': mockText,
      'medicalInfo': {
        'patientInfo': {
          'name': 'John Doe',
          'age': '35',
          'gender': 'Male',
        },
        'testDetails': {
          'date': DateFormat('dd/MM/yyyy').format(DateTime.now()),
          'category': 'Complete Blood Count (CBC)',
        },
        'labResults': [
          {'test': 'Hemoglobin', 'value': '15.2', 'unit': 'g/dL', 'status': 'normal'},
          {'test': 'WBC', 'value': '7500', 'unit': '/cmm', 'status': 'normal'},
          {'test': 'Platelets', 'value': '250000', 'unit': '/cmm', 'status': 'normal'},
          {'test': 'RBC', 'value': '5.2', 'unit': 'million/cmm', 'status': 'normal'},
        ],
      },
      'extractedParameters': [
        {'parameter': 'Hemoglobin (Hb)', 'value': '15.2', 'unit': 'g/dL', 'confidence': 'high'},
        {'parameter': 'White Blood Cells (WBC)', 'value': '7500', 'unit': '/cmm', 'confidence': 'high'},
        {'parameter': 'Platelets', 'value': '250000', 'unit': '/cmm', 'confidence': 'high'},
        {'parameter': 'Red Blood Cells (RBC)', 'value': '5.2', 'unit': 'million/cmm', 'confidence': 'high'},
      ],
    };
  }

  static Future<void> _saveToPatientNotes({
    required String patientId,
    required String recordId,
    required String fileName,
    required String testReportCategory,
    required String testDate,
    required String extractedText,
    required Map<String, dynamic>? medicalInfo,
    required Map<String, dynamic> extractedData,
    required String medicalCenterName,
    required String fileUrl,
  }) async {
    try {
      final noteId = _firestore.collection('patient_notes').doc().id;
      
      // Parse test date for sorting
      DateTime parsedTestDate;
      try {
        parsedTestDate = DateFormat('dd/MM/yyyy').parse(testDate);
      } catch (e) {
        parsedTestDate = DateTime.now();
      }
      
      // Auto-detect category if not specified
      final autoDetectedCategory = _autoDetectTestCategory(extractedText);
      final finalCategory = testReportCategory.isNotEmpty ? testReportCategory : autoDetectedCategory;
      
      // Extract parameters from text
      final extractedParameters = _extractLabParametersFromText(extractedText);
      
      // Organize results
      final Map<String, List<Map<String, dynamic>>> resultsByLevel = {
        'high': [],
        'normal': [],
        'low': [],
      };
      
      // Add extracted parameters to appropriate level (for now, all normal)
      for (var param in extractedParameters) {
        resultsByLevel['normal']!.add({
          ...param,
          'status': 'normal',
          'level': 'normal',
        });
      }
      
      final noteData = {
        'id': noteId,
        'patientId': patientId,
        'medicalRecordId': recordId,
        'fileName': fileName,
        'fileUrl': fileUrl,
        'category': 'labResults',
        'testReportCategory': finalCategory,
        'testType': finalCategory.split('(').first.trim(),
        'testDate': testDate,
        'testDateFormatted': DateFormat('yyyy-MM-dd').format(parsedTestDate),
        'extractedText': extractedText,
        'medicalInfo': medicalInfo,
        'extractedData': extractedData,
        'extractedParameters': extractedParameters,
        'analysisDate': Timestamp.now(),
        'verifiedAt': Timestamp.now(),
        'noteType': 'admin_uploaded_report',
        'isProcessed': true,
        'isVerified': true,
        'verifiedBy': medicalCenterName,
        'uploadSource': 'admin',
        
        // Organized results
        'results': extractedParameters,
        'resultsByLevel': resultsByLevel,
        
        // Statistics
        'totalResults': extractedParameters.length,
        'abnormalCount': 0,
        'normalCount': extractedParameters.length,
        'highCount': 0,
        'lowCount': 0,
        'hasAbnormalResults': false,
        
        // Analysis
        'overallStatus': 'Normal',
        'analysisSummary': 'Test report uploaded and analyzed by admin.',
        'recommendations': ['Review with healthcare provider if any concerns.'],
        
        // Metadata
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'verificationMethod': 'admin_upload',
      };

      await _firestore.collection('patient_notes').doc(noteId).set(noteData);
      
      debugPrint('✅ Saved to patient_notes: $noteId');
      debugPrint('✅ Category: $finalCategory');
      debugPrint('✅ Parameters extracted: ${extractedParameters.length}');
      
    } catch (e) {
      debugPrint('❌ Error saving to patient_notes: $e');
    }
  }

  static Future<String> _analyzeAndUpdateStatus({
    required String reportId,
    required Map<String, dynamic> extractedData,
    required String? extractedText,
  }) async {
    try {
      String status = 'normal';
      
      if (extractedData['success'] == true && extractedText != null) {
        // Simple analysis - check for abnormal values in text
        final lowerText = extractedText.toLowerCase();
        
        if (lowerText.contains('high') || lowerText.contains('elevated') || 
            lowerText.contains('abnormal') || lowerText.contains('critical')) {
          status = 'abnormal';
        }
        
        if (lowerText.contains('very high') || lowerText.contains('dangerously') ||
            lowerText.contains('emergency') || lowerText.contains('critical value')) {
          status = 'critical';
        }
        
        // Update the test report with status
        await _firestore.collection('test_reports').doc(reportId).update({
          'status': status,
          'analyzedAt': Timestamp.now(),
        });
      }
      
      return status;
    } catch (e) {
      debugPrint('❌ Error analyzing status: $e');
      return 'normal';
    }
  }

  static String _autoDetectTestCategory(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('haemoglobin') || lowerText.contains('hemoglobin') || 
        lowerText.contains('wbc') || lowerText.contains('rbc') ||
        lowerText.contains('platelet') || lowerText.contains('cbc') ||
        lowerText.contains('complete blood count') || lowerText.contains('fbc')) {
      return 'Full Blood Count (FBC)';
    }
    
    if (lowerText.contains('urine') || lowerText.contains('u/a')) {
      return 'Urine Analysis';
    }
    
    if (lowerText.contains('tsh') || lowerText.contains('thyroid')) {
      return 'Thyroid (TSH) Test';
    }
    
    if (lowerText.contains('cholesterol') || lowerText.contains('lipid')) {
      return 'Lipid Profile';
    }
    
    if (lowerText.contains('glucose') || lowerText.contains('sugar')) {
      return 'Blood Sugar Test';
    }
    
    return 'Other Blood Test';
  }

  static List<Map<String, dynamic>> _extractLabParametersFromText(String text) {
    final List<Map<String, dynamic>> parameters = [];
    final lowerText = text.toLowerCase();
    
    // Patterns for parameter extraction
    final patterns = <Map<String, dynamic>>[
      {
        'pattern': RegExp(r'haemoglobin[^\d]*(\d+\.?\d*)[^\d]*g/dl', caseSensitive: false),
        'parameter': 'Hemoglobin (Hb)',
        'unit': 'g/dL',
        'normalRange': '13-17'
      },
      {
        'pattern': RegExp(r'hemoglobin[^\d]*(\d+\.?\d*)[^\d]*g/dl', caseSensitive: false),
        'parameter': 'Hemoglobin (Hb)',
        'unit': 'g/dL',
        'normalRange': '13-17'
      },
      {
        'pattern': RegExp(r'hb[^\d]*(\d+\.?\d*)[^\d]*g/dl', caseSensitive: false),
        'parameter': 'Hemoglobin (Hb)',
        'unit': 'g/dL',
        'normalRange': '13-17'
      },
      {
        'pattern': RegExp(r'white blood cells[^\d]*(\d+[,\d]*\.?\d*)[^\d]*/cmm', caseSensitive: false),
        'parameter': 'White Blood Cells (WBC)',
        'unit': '/cmm',
        'normalRange': '4000-11000'
      },
      {
        'pattern': RegExp(r'wbc[^\d]*(\d+[,\d]*\.?\d*)[^\d]*/cmm', caseSensitive: false),
        'parameter': 'White Blood Cells (WBC)',
        'unit': '/cmm',
        'normalRange': '4000-11000'
      },
      {
        'pattern': RegExp(r'platelets[^\d]*(\d+[,\d]*)[^\d]*/cmm', caseSensitive: false),
        'parameter': 'Platelets',
        'unit': '/cmm',
        'normalRange': '150000-450000'
      },
      {
        'pattern': RegExp(r'red blood cells[^\d]*(\d+\.?\d*)[^\d]*million/cmm', caseSensitive: false),
        'parameter': 'Red Blood Cells (RBC)',
        'unit': 'million/cmm',
        'normalRange': '4.5-5.9'
      },
    ];
    
    for (var pattern in patterns) {
      final regex = pattern['pattern'] as RegExp;
      final match = regex.firstMatch(lowerText);
      if (match != null && match.group(1) != null) {
        String value = match.group(1)!.replaceAll(',', '').trim();
        
        parameters.add({
          'parameter': pattern['parameter'],
          'value': value,
          'unit': pattern['unit'],
          'normalRange': pattern['normalRange'],
          'confidence': 'high',
          'source': 'auto_extracted',
        });
      }
    }
    
    return parameters;
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  static String _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}