// lib/services/medical_records_service.dart - FIXED VERSION
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/screens/patient_screens/LabReportConfirmationScreen.dart';
import 'package:frontend/screens/patient_screens/lab_report_verification_flow.dart';
import 'package:intl/intl.dart';
import 'package:frontend/model/medical_record.dart';
import 'package:frontend/model/record_category.dart'; 
import 'package:frontend/services/google_vision_service.dart';

// ========== ADD MISSING CLASSES ==========

class TestResult {
  final String parameter;
  final double value;
  final String unit;
  final String level;
  final String normalRange;
  final String? note;

  TestResult({
    required this.parameter,
    required this.value,
    required this.unit,
    required this.level,
    required this.normalRange,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'parameter': parameter,
      'value': value,
      'unit': unit,
      'level': level,
      'normalRange': normalRange,
      'note': note,
    };
  }
}

class TestReportAnalysis {
  final String testType;
  final String fileName;
  final DateTime analysisDate;
  final List<TestResult> results;
  final List<String> abnormalities;

  TestReportAnalysis({
    required this.testType,
    required this.fileName,
    required this.analysisDate,
    this.results = const [],
    this.abnormalities = const [],
  });
}

// Stub implementation for missing extractor classes
class MedicalReportExtractor {
  static Map<String, dynamic> extractParameters(String text) {
    debugPrint('🔍 Extracting parameters from text (${text.length} chars)');
    
    final Map<String, dynamic> extracted = {
      'rawText': text,
      'parameters': [],
      'confidence': 'medium',
    };
    
    try {
      final lowerText = text.toLowerCase();
      
      // Extract hemoglobin
      RegExp hbRegex = RegExp(r'haemoglobin.*?(\d+\.?\d*)\s*(?:g/dl|g/dl|g%)', caseSensitive: false);
      var hbMatch = hbRegex.firstMatch(lowerText);
      if (hbMatch != null) {
        double value = double.tryParse(hbMatch.group(1)?.trim() ?? '0') ?? 0;
        if (value > 0) {
          (extracted['parameters'] as List).add({
            'parameter': 'Hemoglobin',
            'value': value,
            'unit': 'g/dL',
            'confidence': 'high',
            'normalRange': '13-17',
          });
        }
      }
      
      // Extract WBC
      RegExp wbcRegex = RegExp(r'(?:total leucocyte count|wbc|tlc).*?(\d+)\s*(?:/cumm|cells/μl)', caseSensitive: false);
      var wbcMatch = wbcRegex.firstMatch(lowerText);
      if (wbcMatch != null) {
        double value = double.tryParse(wbcMatch.group(1)?.trim() ?? '0') ?? 0;
        if (value > 0) {
          (extracted['parameters'] as List).add({
            'parameter': 'White Blood Cells',
            'value': value,
            'unit': '/cumm',
            'confidence': 'medium',
            'normalRange': '4000-10000',
          });
        }
      }
      
    } catch (e) {
      debugPrint('❌ Error in parameter extraction: $e');
    }
    
    return extracted;
  }

  static Map<String, dynamic> createVerificationForm(Map<String, dynamic> params) {
    final List<Map<String, dynamic>> parameters = [];
    
    if (params['parameters'] is List) {
      for (var param in (params['parameters'] as List)) {
        if (param is Map) {
          parameters.add({
            'parameter': param['parameter'] ?? 'Unknown',
            'value': param['value'] ?? 0,
            'unit': param['unit'] ?? '',
            'confidence': param['confidence'] ?? 'low',
            'normalRange': param['normalRange'] ?? 'Not specified',
            'needsVerification': (param['confidence'] as String?)?.toLowerCase() != 'high',
          });
        }
      }
    }
    
    return {
      'parameters': parameters,
      'totalParameters': parameters.length,
      'needsVerification': parameters.any((p) => p['needsVerification'] == true),
    };
  }
}


class MedicalReportAnalyzer {
  static TestReportAnalysis analyzeReport(String text) {
    debugPrint('🔬 Analyzing report text (${text.length} chars)');
    
    final analysis = TestReportAnalysis(
      testType: 'Unknown',
      fileName: 'Unknown',
      analysisDate: DateTime.now(),
      results: [],
      abnormalities: [],
    );
    
    try {
      final lowerText = text.toLowerCase();
      
      // Check for hemoglobin
      RegExp hbRegex = RegExp(r'haemoglobin.*?(\d+\.?\d*)\s*(?:g/dl|g/dl|g%)', caseSensitive: false);
      var hbMatch = hbRegex.firstMatch(lowerText);
      if (hbMatch != null) {
        double value = double.tryParse(hbMatch.group(1)?.trim() ?? '0') ?? 0;
        if (value > 0) {
          String level = _getHemoglobinLevel(value);
          analysis.results.add(TestResult(
            parameter: 'Hemoglobin',
            value: value,
            unit: 'g/dL',
            level: level,
            normalRange: '13-17',
            note: level == 'low' ? 'Low hemoglobin may indicate anemia' : 
                   level == 'high' ? 'High hemoglobin may indicate polycythemia' : 
                   'Normal hemoglobin level',
          ));
          
          if (level != 'normal') {
            analysis.abnormalities.add('Hemoglobin ${level.toUpperCase()}: $value g/dL (Normal: 13-17 g/dL)');
          }
        }
      }
      
      // Check for glucose
      RegExp glucoseRegex = RegExp(r'glucose.*?(\d+)\s*(?:mg/dl)', caseSensitive: false);
      var glucoseMatch = glucoseRegex.firstMatch(lowerText);
      if (glucoseMatch != null) {
        double value = double.tryParse(glucoseMatch.group(1)?.trim() ?? '0') ?? 0;
        if (value > 0) {
          String level = _getFastingGlucoseLevel(value);
          analysis.results.add(TestResult(
            parameter: 'Glucose',
            value: value,
            unit: 'mg/dL',
            level: level,
            normalRange: '70-99',
            note: level == 'low' ? 'Low glucose may indicate hypoglycemia' : 
                   level.contains('diabetes') ? 'High glucose may indicate diabetes' : 
                   'Normal glucose level',
          ));
          
          if (level != 'normal') {
            analysis.abnormalities.add('Glucose ${level.toUpperCase()}: $value mg/dL (Normal: 70-99 mg/dL)');
          }
        }
      }
      
    } catch (e) {
      debugPrint('❌ Error in report analysis: $e');
    }
    
    return analysis;
  }
  
  static String _getHemoglobinLevel(double value) {
    if (value < 13.5) return 'low';
    if (value > 17.5) return 'high';
    return 'normal';
  }
  
  static String _getFastingGlucoseLevel(double value) {
    if (value < 70) return 'low';
    if (value < 100) return 'normal';
    if (value < 126) return 'prediabetes';
    return 'diabetes';
  }
}
// Add this to your MedicalRecordsService or create a new utility file
class TestCategoryParameters {
  static Map<String, List<Map<String, dynamic>>> get defaultParameters {
    return {
      'Full Blood Count (FBC)': [
        {'parameter': 'White Blood Cells (WBC)', 'unit': '/cmm', 'normalRange': '4000-11000'},
        {'parameter': 'Hemoglobin (Hb)', 'unit': 'g/dL', 'normalRange': '13-17'},
        {'parameter': 'Platelets', 'unit': '/cmm', 'normalRange': '150000-450000'},
        {'parameter': 'Red Blood Cells (RBC)', 'unit': 'million/cmm', 'normalRange': '4.5-5.9'},
        {'parameter': 'Hematocrit (HCT)', 'unit': '%', 'normalRange': '40-54'},
        {'parameter': 'MCV', 'unit': 'fL', 'normalRange': '80-100'},
        {'parameter': 'MCH', 'unit': 'pg', 'normalRange': '27-32'},
        {'parameter': 'MCHC', 'unit': 'g/dL', 'normalRange': '32-36'},
        {'parameter': 'Neutrophils', 'unit': '%', 'normalRange': '40-75'},
        {'parameter': 'Lymphocytes', 'unit': '%', 'normalRange': '20-45'},
        {'parameter': 'Monocytes', 'unit': '%', 'normalRange': '2-10'},
        {'parameter': 'Eosinophils', 'unit': '%', 'normalRange': '1-6'},
        {'parameter': 'Basophils', 'unit': '%', 'normalRange': '0-2'},
      ],
      'Urine Analysis': [
        {'parameter': 'Color', 'unit': '', 'normalRange': 'Straw/Yellow'},
        {'parameter': 'Appearance', 'unit': '', 'normalRange': 'Clear'},
        {'parameter': 'Specific Gravity', 'unit': '', 'normalRange': '1.003-1.030'},
        {'parameter': 'pH', 'unit': '', 'normalRange': '4.5-8.0'},
        {'parameter': 'sugar', 'unit': '', 'normalRange': 'Negative'},
        {'parameter': 'Proteins', 'unit': '', 'normalRange': 'Negative/Trace'},
        {'parameter': 'Ketone Bodies', 'unit': '', 'normalRange': 'Negative'},
        
        {'parameter': 'Blood', 'unit': '', 'normalRange': 'Negative'},
        {'parameter': 'Nitrite', 'unit': '', 'normalRange': 'Negative'},
        {'parameter': 'Leukocytes', 'unit': '', 'normalRange': 'Negative'},
        {'parameter': 'Epithelial Cells', 'unit': '/HPF', 'normalRange': '0-5'},
        {'parameter': 'Crystals', 'unit': '', 'normalRange': 'None'},
      ],
      'Thyroid (TSH) Test': [
        {'parameter': 'TSH', 'unit': 'μIU/mL', 'normalRange': '0.4-4.0'},
       
      ],
      'Cholesterol (LDL) Test': [
        {'parameter': 'Total Cholesterol', 'unit': 'mg/dL', 'normalRange': '<300'},
        {'parameter': 'LDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '<190'},
        {'parameter': 'HDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '>30'},
        {'parameter': 'Triglycerides', 'unit': 'mg/dL', 'normalRange': '<200'},
      ],
      'Blood Sugar Test': [
        {'parameter': 'Fasting Glucose', 'unit': 'mg/dL', 'normalRange': '70-110'},
        
      ],
      'Lipid Profile': [
        {'parameter': 'Total Cholesterol', 'unit': 'mg/dL', 'normalRange': '<200'},
        {'parameter': 'HDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '>40'},
        {'parameter': 'LDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '<100'},
        {'parameter': 'VLDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '<30'},
        {'parameter': 'Triglycerides', 'unit': 'mg/dL', 'normalRange': '<150'},
        {'parameter': 'Total/HDL Ratio', 'unit': '', 'normalRange': '<5.0'},
      ],
      'Liver Function Test': [
        {'parameter': 'Total Bilirubin', 'unit': 'mg/dL', 'normalRange': '0.2-1.2'},
        {'parameter': 'Direct Bilirubin', 'unit': 'mg/dL', 'normalRange': '0.0-0.3'},
        {'parameter': 'Indirect Bilirubin', 'unit': 'mg/dL', 'normalRange': '0.2-0.8'},
        {'parameter': 'SGOT (AST)', 'unit': 'U/L', 'normalRange': '5-40'},
        {'parameter': 'SGPT (ALT)', 'unit': 'U/L', 'normalRange': '7-56'},
        {'parameter': 'Alkaline Phosphatase', 'unit': 'U/L', 'normalRange': '40-129'},
        {'parameter': 'Total Protein', 'unit': 'g/dL', 'normalRange': '6.0-8.3'},
        {'parameter': 'Albumin', 'unit': 'g/dL', 'normalRange': '3.5-5.0'},
        {'parameter': 'Globulin', 'unit': 'g/dL', 'normalRange': '2.0-3.5'},
        {'parameter': 'A/G Ratio', 'unit': '', 'normalRange': '1.0-2.0'},
      ],
      'Kidney Function Test': [
        {'parameter': 'Blood Urea', 'unit': 'mg/dL', 'normalRange': '10-50'},
        {'parameter': 'Blood Urea Nitrogen', 'unit': 'mg/dL', 'normalRange': '7-20'},
        {'parameter': 'Serum Creatinine', 'unit': 'mg/dL', 'normalRange': '0.6-1.2'},
        {'parameter': 'eGFR', 'unit': 'mL/min', 'normalRange': '>60'},
        {'parameter': 'Uric Acid', 'unit': 'mg/dL', 'normalRange': '3.5-7.2'},
        {'parameter': 'Sodium', 'unit': 'mEq/L', 'normalRange': '135-145'},
        {'parameter': 'Potassium', 'unit': 'mEq/L', 'normalRange': '3.5-5.0'},
        {'parameter': 'Chloride', 'unit': 'mEq/L', 'normalRange': '98-106'},
        {'parameter': 'Calcium', 'unit': 'mg/dL', 'normalRange': '8.5-10.2'},
        {'parameter': 'Phosphorus', 'unit': 'mg/dL', 'normalRange': '2.5-4.5'},
      ],
    };
  }
}

class ReportVerificationScreen extends StatelessWidget {
  final Map<String, dynamic> extractedData;
  final String fileName;
  final RecordCategory category;
  final String? testReportCategory;
  final String? testDate;
  final String recordId;
  final String fileUrl;
  final int fileSize;
  final String patientId; // ADD THIS

  const ReportVerificationScreen({
    super.key,
    required this.extractedData,
    required this.fileName,
    required this.category,
    this.testReportCategory,
    this.testDate,
    required this.recordId,
    required this.fileUrl,
    required this.fileSize,
    required this.patientId, // ADD THIS
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Lab Report Details'),
        backgroundColor: Color(0xFF18A3B6),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify Extracted Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('File: $fileName'),
            Text('Category: ${testReportCategory ?? "Not specified"}'),
            Text('Date: ${testDate ?? "Not specified"}'),
            SizedBox(height: 24),
            
            if ((extractedData['parameters'] as List?)?.isNotEmpty ?? false)
              ...(extractedData['parameters'] as List).map((param) {
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(param['parameter']?.toString() ?? 'Unknown'),
                    subtitle: Text('${param['value']} ${param['unit']}'),
                    trailing: Chip(
                      label: Text(param['confidence']?.toString() ?? 'low'),
                      backgroundColor: (param['confidence'] as String?)?.toLowerCase() == 'high'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                );
              }).toList(),
            
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Navigate to detailed verification screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LabReportConfirmationScreen(
                      record: MedicalRecord(
                        id: recordId,
                        patientId: patientId,
                        fileName: fileName,
                        fileUrl: fileUrl,
                        fileType: fileName.split('.').last,
                        category: category,
                        uploadDate: DateTime.now(),
                        fileSize: fileSize,
                        extractedText: extractedData['rawText']?.toString(),
                        medicalInfo: extractedData,
                        textExtractionStatus: 'pending_verification',
                        textExtractedAt: DateTime.now(),
                        testReportCategory: testReportCategory,
                        testDate: testDate,
                      ),
                      extractedData: extractedData,
                      category: testReportCategory ?? 'Unknown',
                      testDate: testDate,
                      patientId: patientId,
                    ),
                  ),
                );
              },
              child: Text('Review and Confirm Details'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Color(0xFF18A3B6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stub widget for dashboard
class MedicalReportDashboard extends StatelessWidget {
  final String reportText;
  final Map<String, dynamic>? verifiedParameters;
  final Map<String, dynamic>? reportInfo;

  const MedicalReportDashboard({
    super.key,
    required this.reportText,
    this.verifiedParameters,
    this.reportInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Analysis Dashboard'),
        backgroundColor: Color(0xFF18A3B6),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Analysis',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted Text:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Text(
                          reportText.length > 1000 
                            ? '${reportText.substring(0, 1000)}...' 
                            : reportText,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== MAIN MEDICAL RECORDS SERVICE ==========

class MedicalRecordsService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test report categories
  static const List<String> testReportCategories = [
    'Urine Analysis',
    'Full Blood Count (FBC)',
    'Thyroid (TSH) Test',
    'Cholesterol (LDL) Test',
    'Blood Sugar Test',
    'Lipid Profile',
    
    
    'Other Blood Test'
  ];

  Future<MedicalRecord> uploadMedicalRecord({
  required File file,
  required String patientId,
  required String fileName,
  required RecordCategory category,
  required BuildContext context,
  String? description,
  String? testReportCategory,
  String? testDate,
}) async {
  String? downloadUrl;
  
  try {
    debugPrint('📤 === STARTING HYBRID UPLOAD ===');
    debugPrint('📋 File: $fileName');
    debugPrint('📋 Category: ${category.displayName}');
    debugPrint('📋 Patient ID: $patientId');
    debugPrint('📋 Patient provided category: $testReportCategory');
    debugPrint('📋 Patient provided date: $testDate');
    
    // ========== STEP 1: VALIDATE FILE ==========
    debugPrint('🔍 Step 1: Validating file...');
    
    final String fileExtension = fileName.split('.').last.toLowerCase();
    if (!_isValidFileType(fileExtension)) {
      throw Exception('Invalid file type. Please upload PDF, JPG, JPEG, or PNG files only.');
    }
    
    final int fileSize = await file.length();
    debugPrint('📊 File size: ${getFileSizeString(fileSize)}');
    
    if (fileSize > 20 * 1024 * 1024) {
      throw Exception('File size too large. Please select a file smaller than 20MB.');
    }
    
    // ========== STEP 2: UPLOAD TO STORAGE ==========
    debugPrint('☁️ Step 2: Uploading original file to storage...');
    
    final String storagePath = 'medical_records/$patientId/${category.name}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final Reference storageRef = _storage.ref().child(storagePath);
    
    final UploadTask uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: _getContentType(fileExtension)),
    );
    
    // Show upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
      debugPrint('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
    });
    
    final TaskSnapshot snapshot = await uploadTask;
    downloadUrl = await snapshot.ref.getDownloadURL();
    debugPrint('✅ File uploaded to: $downloadUrl');
    
    // ========== STEP 3: EXTRACT TEXT (AUTOMATIC) ==========
    debugPrint('🔍 Step 3: Extracting text from document...');
    
    Map<String, dynamic> extractedData = await GoogleVisionService.extractMedicalText(file);
    String? extractedText = extractedData['success'] ? extractedData['fullText'] : null;
    Map<String, dynamic>? medicalInfo = extractedData['success'] ? extractedData['medicalInfo'] : null;
    
    if (extractedText == null || extractedText.isEmpty) {
      debugPrint('⚠️ No text extracted from document');
      
      // Create minimal record if no text extracted
      final String recordId = _firestore.collection('medical_records').doc().id;
      
      final MedicalRecord record = MedicalRecord(
        id: recordId,
        patientId: patientId,
        fileName: fileName,
        fileUrl: downloadUrl,
        fileType: fileExtension,
        category: category,
        uploadDate: DateTime.now(),
        description: description,
        fileSize: fileSize,
        extractedText: null,
        medicalInfo: medicalInfo,
        textExtractionStatus: 'failed',
        textExtractedAt: DateTime.now(),
        testReportCategory: testReportCategory,
        testDate: testDate,
      );
      
      await _firestore.collection('medical_records').doc(recordId).set(record.toMap());
      debugPrint('✅ Record saved (no text extracted)');
      
      return record;
    }
    
    debugPrint('✅ Text extracted: ${extractedText.length} characters');
    
    // ========== STEP 4: CHECK IF LAB RESULTS NEED HYBRID PROCESSING ==========
  if (category == RecordCategory.labResults && extractedText.isNotEmpty) {
  debugPrint('🔬 Step 4: Processing lab results...');
  
  // Extract parameters
  final extractedParams = MedicalReportExtractor.extractParameters(extractedText);
  
  // Auto-detect test category if not provided
  final autoDetectedCategory = testReportCategory ?? _autoDetectTestCategory(extractedText);
  
  // Auto-extract test date
  final autoExtractedDate = testDate ?? _extractTestDateFromText(extractedText);
  
  // Get parameters list
  final parameters = (extractedParams['parameters'] as List?) ?? [];
  debugPrint('📊 Extracted ${parameters.length} parameters');
  
  // Create record with extracted parameters
  final String recordId = _firestore.collection('medical_records').doc().id;
  
  final MedicalRecord record = MedicalRecord(
    id: recordId,
    patientId: patientId,
    fileName: fileName,
    fileUrl: downloadUrl,
    fileType: fileExtension,
    category: category,
    uploadDate: DateTime.now(),
    description: description,
    fileSize: fileSize,
    extractedText: extractedText,
    medicalInfo: extractedParams, // Save extracted parameters here
    textExtractionStatus: 'pending_verification',
    textExtractedAt: DateTime.now(),
    testReportCategory: autoDetectedCategory,
    testDate: autoExtractedDate,
  );
  
  // Save to medical_records
  await _firestore.collection('medical_records').doc(recordId).set(record.toMap());
  
  debugPrint('📝 Record saved. ID: $recordId');
  debugPrint('📊 Auto-detected category: $autoDetectedCategory');
  debugPrint('📅 Auto-extracted date: $autoExtractedDate');
  
  // Navigate DIRECTLY to verification flow WITH EXTRACTED PARAMETERS
  if (context.mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LabReportVerificationFlow(
            record: record,
            patientId: patientId,
            testReportCategory: autoDetectedCategory,
            testDate: autoExtractedDate,
            extractedParameters: parameters,
          ),
        ),
      );
    });
  }
  
  return record;
} else {
      // ========== STEP 5: NON-LAB RESULTS OR GENERIC UPLOAD ==========
      debugPrint('📄 Step 5: Processing non-lab record...');
      
      final String recordId = _firestore.collection('medical_records').doc().id;
      
      final MedicalRecord record = MedicalRecord(
        id: recordId,
        patientId: patientId,
        fileName: fileName,
        fileUrl: downloadUrl,
        fileType: fileExtension,
        category: category,
        uploadDate: DateTime.now(),
        description: description,
        fileSize: fileSize,
        extractedText: extractedText,
        medicalInfo: medicalInfo,
        textExtractionStatus: extractedData['success'] ? 'extracted' : 'failed',
        textExtractedAt: DateTime.now(),
        testReportCategory: testReportCategory,
        testDate: testDate,
      );
      
      // Save to Firestore
      await _firestore.collection('medical_records').doc(recordId).set(record.toMap());
      
      // For non-lab results with text, save to patient_notes as well
      if (extractedText.isNotEmpty) {
        await _saveExtractedTextToPatientNotes(
          patientId: patientId,
          recordId: recordId,
          fileName: fileName,
          category: category,
          extractedText: extractedText,
          medicalInfo: medicalInfo,
        );
      }
      
      debugPrint('✅ Non-lab record saved. ID: $recordId');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${category.displayName} uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      return record;
    }
    
  } catch (e) {
    debugPrint('❌ === UPLOAD ERROR ===');
    debugPrint('❌ Error: $e');
    debugPrint('❌ Stack trace: ${e.toString()}');
    
    // Clean up if file was uploaded but something else failed
    try {
      if (downloadUrl != null) {
        final Reference storageRef = _storage.refFromURL(downloadUrl);
        await storageRef.delete();
        debugPrint('🗑️ Deleted orphaned file from storage');
      }
    } catch (deleteError) {
      debugPrint('⚠️ Could not delete orphaned file: $deleteError');
    }
    
    throw Exception('Upload failed: $e');
  }
}
  // ============ ADD MISSING METHODS ============

  // Auto-detect test category from text
  String _autoDetectTestCategory(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('haemoglobin') || lowerText.contains('hemoglobin') || 
        lowerText.contains('wbc') || lowerText.contains('rbc') ||
        lowerText.contains('platelet') || lowerText.contains('cbc') ||
        lowerText.contains('complete blood count') || lowerText.contains('fbc')) {
      return 'Full Blood Count (FBC)';
    }
    
    if (lowerText.contains('urine') || lowerText.contains('u/a') ||
        lowerText.contains('specific gravity') || lowerText.contains('urine ph')) {
      return 'Urine Analysis';
    }
    
    if (lowerText.contains('tsh') || lowerText.contains('thyroid') ||
        lowerText.contains('t3') || lowerText.contains('t4')) {
      return 'Thyroid (TSH) Test';
    }
    
    if (lowerText.contains('ldl') || lowerText.contains('cholesterol') ||
        lowerText.contains('hdl') || lowerText.contains('triglyceride')) {
      return 'Cholesterol (LDL) Test';
    }
    
    if (lowerText.contains('glucose') || lowerText.contains('sugar') ||
        lowerText.contains('hba1c') || lowerText.contains('fasting')) {
      return 'Blood Sugar Test';
    }
    
    if (lowerText.contains('lipid') || lowerText.contains('lipoprotein')) {
      return 'Lipid Profile';
    }
    
    if (lowerText.contains('liver') || lowerText.contains('alt') ||
        lowerText.contains('ast') || lowerText.contains('bilirubin')) {
      return 'Liver Function Test';
    }
    
    if (lowerText.contains('kidney') || lowerText.contains('creatinine') ||
        lowerText.contains('urea') || lowerText.contains('egfr')) {
      return 'Kidney Function Test';
    }
    
    return 'Other Blood Test';
  }

  // Extract test date from text
  String _extractTestDateFromText(String text) {
    try {
      // Look for date patterns
      RegExp dateRegex = RegExp(
        r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4}\b',
        caseSensitive: false,
      );
      
      // Also look for specific patterns like "Date:", "Report Date:", etc.
      RegExp specificDateRegex = RegExp(
        r'(?:date|report date|collection date|test date)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})',
        caseSensitive: false,
      );
      
      var match = specificDateRegex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
      
      // Fallback to general date pattern
      match = dateRegex.firstMatch(text);
      if (match != null) {
        return match.group(0) ?? 'Date not found';
      }
      
      return 'Date not found';
    } catch (e) {
      debugPrint('❌ Error extracting date: $e');
      return 'Date extraction error';
    }
  }

  // ============ END OF ADDED METHODS ============

  // Analyze test report based on category
  Future<TestReportAnalysis?> _analyzeTestReport({
    required String extractedText,
    required String? testReportCategory,
    required String fileName,
  }) async {
    try {
      if (testReportCategory == null) return null;
      
      debugPrint('🔬 Analyzing test report: $testReportCategory');
      
      // Create analysis object
      TestReportAnalysis analysis = TestReportAnalysis(
        testType: testReportCategory,
        fileName: fileName,
        analysisDate: DateTime.now(),
        results: [],
        abnormalities: [],
      );
      
      // Analyze based on category
      switch (testReportCategory) {
        case 'Full Blood Count (FBC)':
          analysis = _analyzeFBC(extractedText, analysis);
          break;
        case 'Urine Analysis':
          analysis = _analyzeUrine(extractedText, analysis);
          break;
        case 'Thyroid (TSH) Test':
          analysis = _analyzeTSH(extractedText, analysis);
          break;
        case 'Cholesterol (LDL) Test':
          analysis = _analyzeLDL(extractedText, analysis);
          break;
        case 'Blood Sugar Test':
          analysis = _analyzeBloodSugar(extractedText, analysis);
          break;
        default:
          analysis = _analyzeGenericBloodTest(extractedText, analysis);
      }
      
      return analysis;
    } catch (e) {
      debugPrint('❌ Error analyzing test report: $e');
      return null;
    }
  }

  TestReportAnalysis _analyzeFBC(String text, TestReportAnalysis analysis) {
    final lowerText = text.toLowerCase();
    
    // Hemoglobin - Fixed regex to match your document format
    RegExp hbRegex = RegExp(
      r'haemoglobin.*?(\d+\.?\d*)\s*(?:g/dl|g/dl|g%)', 
      caseSensitive: false,
      dotAll: true
    );
    var hbMatch = hbRegex.firstMatch(lowerText);
    if (hbMatch != null) {
      double value = double.tryParse(hbMatch.group(1)?.trim() ?? '0') ?? 0;
      if (value > 0) {
        String level = _getHemoglobinLevel(value);
        analysis.results.add(TestResult(
          parameter: 'Hemoglobin',
          value: value,
          unit: 'g/dL',
          level: level,
          normalRange: '13-17',
          note: level == 'low' ? 'Low hemoglobin may indicate anemia' : 
                 level == 'high' ? 'High hemoglobin may indicate polycythemia' : 
                 'Normal hemoglobin level',
        ));
      }
    }
    
    // White Blood Cells - Look for WBC or Total Leucocyte Count
    RegExp wbcRegex = RegExp(
      r'(?:total leucocyte count|wbc|tlc).*?(\d+)\s*(?:/cumm|cells/μl)', 
      caseSensitive: false,
      dotAll: true
    );
    var wbcMatch = wbcRegex.firstMatch(lowerText);
    if (wbcMatch == null) {
      // Try alternative pattern
      wbcRegex = RegExp(r'total leucocyte count.*?(\d{4,5})', caseSensitive: false);
      wbcMatch = wbcRegex.firstMatch(lowerText);
    }
    if (wbcMatch != null) {
      double value = double.tryParse(wbcMatch.group(1)?.trim() ?? '0') ?? 0;
      if (value > 0) {
        String level = _getWBCLevel(value);
        analysis.results.add(TestResult(
          parameter: 'White Blood Cells',
          value: value,
          unit: '/cumm',
          level: level,
          normalRange: '4000-10000',
          note: level == 'low' ? 'Low WBC may indicate infection or bone marrow problem' : 
                 level == 'high' ? 'High WBC may indicate infection or inflammation' : 
                 'Normal WBC level',
        ));
      }
    }
    
    // Platelets - Fixed regex
    RegExp pltRegex = RegExp(
      r'platelet count.*?(\d+)\s*(?:/cumm)', 
      caseSensitive: false,
      dotAll: true
    );
    var pltMatch = pltRegex.firstMatch(lowerText);
    if (pltMatch != null) {
      double value = double.tryParse(pltMatch.group(1)?.trim() ?? '0') ?? 0;
      if (value > 0) {
        String level = _getPlateletLevel(value);
        analysis.results.add(TestResult(
          parameter: 'Platelets',
          value: value,
          unit: '/cumm',
          level: level,
          normalRange: '150000-410000',
          note: level == 'low' ? 'Low platelets may indicate bleeding risk' : 
                 level == 'high' ? 'High platelets may indicate clotting risk' : 
                 'Normal platelet count',
        ));
      }
    }
    
    // RBC Count
    RegExp rbcRegex = RegExp(
      r'rbc count.*?(\d+\.?\d*)\s*(?:million/cumm|10\^6/μl)', 
      caseSensitive: false,
      dotAll: true
    );
    var rbcMatch = rbcRegex.firstMatch(lowerText);
    if (rbcMatch != null) {
      double value = double.tryParse(rbcMatch.group(1)?.trim() ?? '0') ?? 0;
      if (value > 0) {
        String level = _getRBCLevel(value);
        analysis.results.add(TestResult(
          parameter: 'RBC Count',
          value: value,
          unit: 'million/cumm',
          level: level,
          normalRange: '4.5-5.5',
          note: level == 'low' ? 'Low RBC count may indicate anemia' : 
                 level == 'high' ? 'High RBC count may indicate polycythemia' : 
                 'Normal RBC count',
        ));
      }
    }
    
    // MCV
    RegExp mcvRegex = RegExp(
      r'mcv.*?(\d+\.?\d*)\s*(?:fl|fL)', 
      caseSensitive: false,
      dotAll: true
    );
    var mcvMatch = mcvRegex.firstMatch(lowerText);
    if (mcvMatch != null) {
      double value = double.tryParse(mcvMatch.group(1)?.trim() ?? '0') ?? 0;
      if (value > 0) {
        String level = _getMCVLevel(value);
        analysis.results.add(TestResult(
          parameter: 'MCV',
          value: value,
          unit: 'fL',
          level: level,
          normalRange: '81-101',
          note: level == 'low' ? 'Low MCV indicates microcytic anemia' : 
                 level == 'high' ? 'High MCV indicates macrocytic anemia' : 
                 'Normal MCV',
        ));
      }
    }
    
    // MCH
    RegExp mchRegex = RegExp(
      r'mch.*?(\d+\.?\d*)\s*(?:pg)', 
      caseSensitive: false,
      dotAll: true
    );
    var mchMatch = mchRegex.firstMatch(lowerText);
    if (mchMatch != null) {
      double value = double.tryParse(mchMatch.group(1)?.trim() ?? '0') ?? 0;
      if (value > 0) {
        String level = _getMCHLevel(value);
        analysis.results.add(TestResult(
          parameter: 'MCH',
          value: value,
          unit: 'pg',
          level: level,
          normalRange: '27-32',
          note: level == 'low' ? 'Low MCH indicates hypochromic anemia' : 
                 level == 'high' ? 'High MCH may indicate macrocytic anemia' : 
                 'Normal MCH',
        ));
      }
    }
    
    // Hematocrit (Hct)
    RegExp hctRegex = RegExp(
      r'(?:hct|hematocrit).*?(\d+)\s*(?:%)', 
      caseSensitive: false,
      dotAll: true
    );
    var hctMatch = hctRegex.firstMatch(lowerText);
    if (hctMatch != null) {
      double value = double.tryParse(hctMatch.group(1)?.trim() ?? '0') ?? 0;
      if (value > 0) {
        String level = _getHematocritLevel(value);
        analysis.results.add(TestResult(
          parameter: 'Hematocrit',
          value: value,
          unit: '%',
          level: level,
          normalRange: '40-50',
          note: level == 'low' ? 'Low hematocrit may indicate anemia' : 
                 level == 'high' ? 'High hematocrit may indicate dehydration or polycythemia' : 
                 'Normal hematocrit',
        ));
      }
    }
    
    return analysis;
  }

  // Add new level determination methods
  String _getRBCLevel(double value) {
    if (value < 4.5) return 'low';
    if (value > 5.5) return 'high';
    return 'normal';
  }

  String _getMCVLevel(double value) {
    if (value < 81) return 'low';
    if (value > 101) return 'high';
    return 'normal';
  }

  String _getMCHLevel(double value) {
    if (value < 27) return 'low';
    if (value > 32) return 'high';
    return 'normal';
  }

  String _getHematocritLevel(double value) {
    if (value < 40) return 'low';
    if (value > 50) return 'high';
    return 'normal';
  }

  // Analyze Urine report
  TestReportAnalysis _analyzeUrine(String text, TestReportAnalysis analysis) {
    final lowerText = text.toLowerCase();
    
    // Specific Gravity
    RegExp sgRegex = RegExp(r'specific gravity\s*[:\-]?\s*(\d+\.?\d*)', caseSensitive: false);
    var sgMatch = sgRegex.firstMatch(lowerText);
    if (sgMatch != null) {
      double value = double.tryParse(sgMatch.group(1) ?? '0') ?? 0;
      String level = _getSpecificGravityLevel(value);
      analysis.results.add(TestResult(
        parameter: 'Specific Gravity',
        value: value,
        unit: '',
        level: level,
        normalRange: '1.005-1.030',
      ));
    }
    
    // pH
    RegExp phRegex = RegExp(r'ph\s*[:\-]?\s*(\d+\.?\d*)', caseSensitive: false);
    var phMatch = phRegex.firstMatch(lowerText);
    if (phMatch != null) {
      double value = double.tryParse(phMatch.group(1) ?? '0') ?? 0;
      String level = _getUrinePHLevel(value);
      analysis.results.add(TestResult(
        parameter: 'pH',
        value: value,
        unit: '',
        level: level,
        normalRange: '4.5-8.0',
      ));
    }
    
    // Check for abnormalities
    if (lowerText.contains('protein') && (lowerText.contains('positive') || lowerText.contains('+'))) {
      analysis.abnormalities.add('Proteinuria detected');
    }
    if (lowerText.contains('glucose') && (lowerText.contains('positive') || lowerText.contains('+'))) {
      analysis.abnormalities.add('Glycosuria detected');
    }
    if (lowerText.contains('blood') && (lowerText.contains('positive') || lowerText.contains('+'))) {
      analysis.abnormalities.add('Hematuria detected');
    }
    
    return analysis;
  }

  // Analyze TSH report
  TestReportAnalysis _analyzeTSH(String text, TestReportAnalysis analysis) {
    final lowerText = text.toLowerCase();
    
    RegExp tshRegex = RegExp(r'tsh\s*[:\-]?\s*(\d+\.?\d*)\s*(?:miu/l|μiu/ml)', caseSensitive: false);
    var tshMatch = tshRegex.firstMatch(lowerText);
    if (tshMatch != null) {
      double value = double.tryParse(tshMatch.group(1) ?? '0') ?? 0;
      String level = _getTSHLevel(value);
      analysis.results.add(TestResult(
        parameter: 'TSH',
        value: value,
        unit: 'μIU/mL',
        level: level,
        normalRange: '0.4-4.0',
      ));
    }
    
    return analysis;
  }

  // Analyze LDL report
  TestReportAnalysis _analyzeLDL(String text, TestReportAnalysis analysis) {
    final lowerText = text.toLowerCase();
    
    RegExp ldlRegex = RegExp(r'ldl\s*[:\-]?\s*(\d+)\s*(?:mg/dl)', caseSensitive: false);
    var ldlMatch = ldlRegex.firstMatch(lowerText);
    if (ldlMatch != null) {
      double value = double.tryParse(ldlMatch.group(1) ?? '0') ?? 0;
      String level = _getLDLCholesterolLevel(value);
      analysis.results.add(TestResult(
        parameter: 'LDL Cholesterol',
        value: value,
        unit: 'mg/dL',
        level: level,
        normalRange: '<100 (Optimal)',
      ));
    }
    
    return analysis;
  }

  // Analyze Blood Sugar report
  TestReportAnalysis _analyzeBloodSugar(String text, TestReportAnalysis analysis) {
    final lowerText = text.toLowerCase();
    
    // Fasting
    RegExp fastingRegex = RegExp(r'fasting glucose\s*[:\-]?\s*(\d+)\s*(?:mg/dl)', caseSensitive: false);
    var fastingMatch = fastingRegex.firstMatch(lowerText);
    if (fastingMatch != null) {
      double value = double.tryParse(fastingMatch.group(1) ?? '0') ?? 0;
      String level = _getFastingGlucoseLevel(value);
      analysis.results.add(TestResult(
        parameter: 'Fasting Glucose',
        value: value,
        unit: 'mg/dL',
        level: level,
        normalRange: '70-99',
      ));
    }
    
    // Postprandial
    RegExp ppRegex = RegExp(r'postprandial|pp\s*[:\-]?\s*(\d+)\s*(?:mg/dl)', caseSensitive: false);
    var ppMatch = ppRegex.firstMatch(lowerText);
    if (ppMatch != null) {
      double value = double.tryParse(ppMatch.group(1) ?? '0') ?? 0;
      String level = _getPostprandialGlucoseLevel(value);
      analysis.results.add(TestResult(
        parameter: 'Postprandial Glucose',
        value: value,
        unit: 'mg/dL',
        level: level,
        normalRange: '<140',
      ));
    }
    
    // HbA1c
    RegExp hba1cRegex = RegExp(r'hba1c|a1c\s*[:\-]?\s*(\d+\.?\d*)\s*(?:%)', caseSensitive: false);
    var hba1cMatch = hba1cRegex.firstMatch(lowerText);
    if (hba1cMatch != null) {
      double value = double.tryParse(hba1cMatch.group(1) ?? '0') ?? 0;
      String level = _getHbA1cLevel(value);
      analysis.results.add(TestResult(
        parameter: 'HbA1c',
        value: value,
        unit: '%',
        level: level,
        normalRange: '<5.7%',
      ));
    }
    
    return analysis;
  }

  // Helper methods for level determination
  String _getHemoglobinLevel(double value) {
    if (value < 13.5) return 'low';
    if (value > 17.5) return 'high';
    return 'normal';
  }
  
  String _getWBCLevel(double value) {
    if (value < 4.0) return 'low';
    if (value > 11.0) return 'high';
    return 'normal';
  }
  
  String _getPlateletLevel(double value) {
    if (value < 150) return 'low';
    if (value > 450) return 'high';
    return 'normal';
  }
  
  String _getTSHLevel(double value) {
    if (value < 0.4) return 'low';
    if (value > 4.0) return 'high';
    return 'normal';
  }
  
  String _getLDLCholesterolLevel(double value) {
    if (value < 100) return 'optimal';
    if (value < 130) return 'near optimal';
    if (value < 160) return 'borderline high';
    if (value < 190) return 'high';
    return 'very high';
  }
  
  String _getFastingGlucoseLevel(double value) {
    if (value < 70) return 'low';
    if (value < 100) return 'normal';
    if (value < 126) return 'prediabetes';
    return 'diabetes';
  }
  
  String _getPostprandialGlucoseLevel(double value) {
    if (value < 140) return 'normal';
    if (value < 200) return 'prediabetes';
    return 'diabetes';
  }
  
  String _getHbA1cLevel(double value) {
    if (value < 5.7) return 'normal';
    if (value < 6.5) return 'prediabetes';
    return 'diabetes';
  }
  
  String _getSpecificGravityLevel(double value) {
    if (value < 1.005) return 'low';
    if (value > 1.030) return 'high';
    return 'normal';
  }
  
  String _getUrinePHLevel(double value) {
    if (value < 4.5) return 'acidic';
    if (value > 8.0) return 'alkaline';
    return 'normal';
  }

  // Generic blood test analyzer
  TestReportAnalysis _analyzeGenericBloodTest(String text, TestReportAnalysis analysis) {
    final lowerText = text.toLowerCase();
    
    // Look for common patterns
    Map<String, RegExp> patterns = {
      'Creatinine': RegExp(r'creatinine\s*[:\-]?\s*(\d+\.?\d*)\s*(?:mg/dl)', caseSensitive: false),
      'BUN': RegExp(r'bun|blood urea nitrogen\s*[:\-]?\s*(\d+)\s*(?:mg/dl)', caseSensitive: false),
      'ALT': RegExp(r'alt\s*[:\-]?\s*(\d+)', caseSensitive: false),
      'AST': RegExp(r'ast\s*[:\-]?\s*(\d+)', caseSensitive: false),
      'Total Protein': RegExp(r'total protein\s*[:\-]?\s*(\d+\.?\d*)\s*(?:g/dl)', caseSensitive: false),
      'Albumin': RegExp(r'albumin\s*[:\-]?\s*(\d+\.?\d*)\s*(?:g/dl)', caseSensitive: false),
    };
    
    patterns.forEach((parameter, regex) {
      var match = regex.firstMatch(lowerText);
      if (match != null) {
        double value = double.tryParse(match.group(1) ?? '0') ?? 0;
        analysis.results.add(TestResult(
          parameter: parameter,
          value: value,
          unit: _getUnitForParameter(parameter),
          level: 'measured',
          normalRange: _getNormalRangeForParameter(parameter),
        ));
      }
    });
    
    return analysis;
  }
  
  String _getUnitForParameter(String parameter) {
    switch (parameter) {
      case 'Creatinine':
      case 'BUN':
        return 'mg/dL';
      case 'ALT':
      case 'AST':
        return 'U/L';
      case 'Total Protein':
      case 'Albumin':
        return 'g/dL';
      default:
        return '';
    }
  }
  
  String _getNormalRangeForParameter(String parameter) {
    switch (parameter) {
      case 'Creatinine':
        return '0.6-1.2 mg/dL';
      case 'BUN':
        return '7-20 mg/dL';
      case 'ALT':
        return '7-56 U/L';
      case 'AST':
        return '10-40 U/L';
      case 'Total Protein':
        return '6.0-8.3 g/dL';
      case 'Albumin':
        return '3.5-5.0 g/dL';
      default:
        return 'Refer to lab reference';
    }
  }

  Future<void> _saveTestReportToPatientNotes({
    required String patientId,
    required String recordId,
    required String fileName,
    required RecordCategory category,
    required String extractedText,
    required Map<String, dynamic>? medicalInfo,
    required String? testReportCategory,
    required String? testDate,
    required TestReportAnalysis? analysis,
  }) async {
    try {
      final noteId = _firestore.collection('patient_notes').doc().id;
      
      // Get patient age from user profile
      final patientDoc = await _firestore.collection('users').doc(patientId).get();
      final patientData = patientDoc.data();
      final patientAge = patientData?['age'] ?? 'Not specified';
      final patientGender = patientData?['gender'] ?? 'Not specified';
      
      // Extract patient age from text if available
      String extractedAge = _extractAgeFromText(extractedText);
      
      // Organize results by level
      Map<String, dynamic> organizedResults = {
        'high': [],
        'normal': [],
        'low': [],
      };
      
      if (analysis != null && analysis.results.isNotEmpty) {
        for (var result in analysis.results) {
          // Ensure we have valid results
          if (result.value > 0) {
            if (result.level.toLowerCase().contains('high')) {
              (organizedResults['high'] as List).add(result.toMap());
            } else if (result.level.toLowerCase().contains('low')) {
              (organizedResults['low'] as List).add(result.toMap());
            } else {
              (organizedResults['normal'] as List).add(result.toMap());
            }
          }
        }
      } else {
        // If no structured results, try to extract from medicalInfo
        _extractFromMedicalInfo(medicalInfo, organizedResults);
      }
      
      // Extract test date from document if not provided
      String finalTestDate = testDate ?? _extractTestDateFromText(extractedText);
      
      // Determine test report category automatically if not provided
      String finalTestCategory = testReportCategory ?? _determineTestCategory(extractedText);
      
      final noteData = {
        'id': noteId,
        'patientId': patientId,
        'medicalRecordId': recordId,
        'fileName': fileName,
        'category': category.name,
        'testReportCategory': finalTestCategory,
        'testType': finalTestCategory.split('(').first.trim(),
        'extractedText': extractedText,
        'medicalInfo': medicalInfo ?? {},
        'testDate': finalTestDate,
        'analysisDate': Timestamp.now(),
        'patientAge': extractedAge.isNotEmpty ? extractedAge : patientAge,
        'patientGender': patientGender,
        'extractedPatientAge': extractedAge,
        'extractedPatientGender': _extractGenderFromText(extractedText),
        
        // Organized results
        'results': analysis?.results.where((r) => r.value > 0).map((r) => r.toMap()).toList() ?? [],
        'resultsByLevel': organizedResults,
        'abnormalities': analysis?.abnormalities ?? [],
        
        // Statistics
        'totalResults': analysis?.results.length ?? 0,
        'highCount': (organizedResults['high'] as List).length,
        'normalCount': (organizedResults['normal'] as List).length,
        'lowCount': (organizedResults['low'] as List).length,
        'abnormalCount': (organizedResults['high'] as List).length + (organizedResults['low'] as List).length,
        
        'noteType': 'test_report_analysis',
        'isProcessed': true,
        'hasAbnormalResults': (organizedResults['high'] as List).isNotEmpty || 
                             (organizedResults['low'] as List).isNotEmpty,
      };

      await _firestore.collection('patient_notes').doc(noteId).set(noteData);
      
      debugPrint('📝 Saved test report analysis to patient_notes: $noteId');
      debugPrint('📝 Test Category: $finalTestCategory');
      debugPrint('📝 Test Date: $finalTestDate');
      debugPrint('📝 Results found: ${analysis?.results.length ?? 0}');
      debugPrint('📝 High: ${(organizedResults['high'] as List).length}');
      debugPrint('📝 Normal: ${(organizedResults['normal'] as List).length}');
      debugPrint('📝 Low: ${(organizedResults['low'] as List).length}');
      
    } catch (e) {
      debugPrint('❌ Error saving test report to patient_notes: $e');
      debugPrint('❌ Stack trace: ${e.toString()}');
    }
  }

  String _extractAgeFromText(String text) {
    try {
      RegExp ageRegex = RegExp(r'age.*?[:/]?\s*(\d+)\s*(?:years|yrs|y|year)', caseSensitive: false);
      var match = ageRegex.firstMatch(text.toLowerCase());
      if (match != null) {
        return match.group(1) ?? '';
      }
      
      // Try simpler pattern
      ageRegex = RegExp(r'\b(\d{1,2})\s*(?:year|yrs|y)\b', caseSensitive: false);
      match = ageRegex.firstMatch(text.toLowerCase());
      if (match != null) {
        return match.group(1) ?? '';
      }
      
      return '';
    } catch (e) {
      return '';
    }
  }

  String _extractGenderFromText(String text) {
    try {
      if (text.toLowerCase().contains('male')) return 'Male';
      if (text.toLowerCase().contains('female')) return 'Female';
      return '';
    } catch (e) {
      return '';
    }
  }

  // Helper method to determine test category automatically
  String _determineTestCategory(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('haemoglobin') || lowerText.contains('cbc') || 
        lowerText.contains('complete blood count') || lowerText.contains('hematology')) {
      return 'Full Blood Count (FBC)';
    }
    if (lowerText.contains('urine') || lowerText.contains('u/a')) {
      return 'Urine Analysis';
    }
    if (lowerText.contains('tsh') || lowerText.contains('thyroid')) {
      return 'Thyroid (TSH) Test';
    }
    if (lowerText.contains('ldl') || lowerText.contains('cholesterol')) {
      return 'Cholesterol (LDL) Test';
    }
    if (lowerText.contains('glucose') || lowerText.contains('sugar') || lowerText.contains('hba1c')) {
      return 'Blood Sugar Test';
    }
    
    return 'Other Blood Test';
  }

  void _extractFromMedicalInfo(Map<String, dynamic>? medicalInfo, Map<String, dynamic> organizedResults) {
    if (medicalInfo == null) return;
    
    // Extract from labResults in medicalInfo
    final labResults = medicalInfo['labResults'] as List?;
    if (labResults != null && labResults.isNotEmpty) {
      for (var lab in labResults) {
        if (lab is Map) {
          final test = lab['test']?.toString() ?? '';
          final value = double.tryParse(lab['value']?.toString() ?? '0') ?? 0;
          final unit = lab['unit']?.toString() ?? '';
          
          if (value > 0) {
            // Determine level based on test type
            String level = 'normal';
            if (test.toLowerCase().contains('glucose')) {
              level = _getFastingGlucoseLevel(value);
            } else if (test.toLowerCase().contains('cholesterol')) {
              level = _getLDLCholesterolLevel(value);
            }
            
            final result = TestResult(
              parameter: test,
              value: value,
              unit: unit,
              level: level,
              normalRange: 'Refer to lab reference',
            ).toMap();
            
            if (level.contains('high')) {
              (organizedResults['high'] as List).add(result);
            } else if (level.contains('low')) {
              (organizedResults['low'] as List).add(result);
            } else {
              (organizedResults['normal'] as List).add(result);
            }
          }
        }
      }
    }
  }

  // Existing methods remain the same...
  Future<void> _saveExtractedTextToPatientNotes({
    required String patientId,
    required String recordId,
    required String fileName,
    required RecordCategory category,
    required String extractedText,
    Map<String, dynamic>? medicalInfo,
  }) async {
    try {
      final noteId = _firestore.collection('patient_notes').doc().id;
      
      final noteData = {
        'id': noteId,
        'patientId': patientId,
        'medicalRecordId': recordId,
        'fileName': fileName,
        'category': category.name,
        'extractedText': extractedText,
        'medicalInfo': medicalInfo ?? {},
        'extractedAt': Timestamp.now(),
        'wordCount': extractedText.split(' ').length,
        'charCount': extractedText.length,
        'hasMedications': (medicalInfo?['medications'] as List?)?.isNotEmpty ?? false,
        'hasLabResults': (medicalInfo?['labResults'] as List?)?.isNotEmpty ?? false,
        'noteType': 'extracted_from_document',
        'isProcessed': false,
      };

      await _firestore.collection('patient_notes').doc(noteId).set(noteData);
      
      debugPrint('📝 Saved extracted text to patient_notes: $noteId');
      
    } catch (e) {
      debugPrint('❌ Error saving to patient_notes: $e');
    }
  }

  // 🔥 NEW: Get extracted notes for a patient
  Stream<List<Map<String, dynamic>>> getPatientExtractedNotes(String patientId) {
    return _firestore
        .collection('patient_notes')
        .where('patientId', isEqualTo: patientId)
        .orderBy('extractedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  // 🔥 NEW: Search in extracted notes
  Stream<List<Map<String, dynamic>>> searchInPatientNotes(String patientId, String query) {
    return _firestore
        .collection('patient_notes')
        .where('patientId', isEqualTo: patientId)
        .orderBy('extractedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final notes = snapshot.docs.map((doc) => doc.data()).toList();
          return notes.where((note) {
            final text = note['extractedText']?.toString().toLowerCase() ?? '';
            return text.contains(query.toLowerCase());
          }).toList();
        });
  }

  // NEW: Get notes by category
  Stream<List<Map<String, dynamic>>> getPatientNotesByCategory(
      String patientId, String category) {
    return _firestore
        .collection('patient_notes')
        .where('patientId', isEqualTo: patientId)
        .where('category', isEqualTo: category)
        .orderBy('extractedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  // Existing methods remain the same...
  Stream<List<MedicalRecord>> getPatientMedicalRecords(String patientId) {
    return _firestore
        .collection('medical_records')
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicalRecord.fromMap(doc.data()))
            .toList());
  }
Future<void> saveVerifiedLabReport({
  required String recordId,
  required String patientId,
  required Map<String, dynamic> verifiedData,
  required String category,
  required String fileName,
  required String? extractedText,
}) async {
  try {
    // Update the medical record
    await _firestore.collection('medical_records').doc(recordId).update({
      'textExtractionStatus': 'verified',
      'verifiedParameters': verifiedData,
      'verifiedAt': Timestamp.now(),
    });

    // Save to patient_notes
    final noteId = _firestore.collection('patient_notes').doc().id;
    final noteData = {
      'id': noteId,
      'patientId': patientId,
      'medicalRecordId': recordId,
      'fileName': fileName,
      'category': 'labResults',
      'testReportCategory': category,
      'testDate': verifiedData['testDate'],
      'extractedText': extractedText,
      'verifiedParameters': verifiedData,
      'results': verifiedData['results'] ?? [],
      'analysisDate': Timestamp.now(),
      'verifiedAt': Timestamp.now(),
      'noteType': 'verified_report_analysis',
      'isProcessed': true,
      
      // Analysis data
      'totalResults': (verifiedData['results'] as List).length,
      'abnormalCount': _calculateAbnormalCount(verifiedData['results'] as List),
    };

    await _firestore.collection('patient_notes').doc(noteId).set(noteData);

    debugPrint('✅ Verified lab report saved: $noteId');
  } catch (e) {
    debugPrint('❌ Error saving verified report: $e');
    rethrow;
  }
}

int _calculateAbnormalCount(List<dynamic> results) {
  // Implement your logic to determine abnormal results
  return 0;
}
  Stream<List<MedicalRecord>> getPatientMedicalRecordsByCategory(
      String patientId, RecordCategory category) {
    return _firestore
        .collection('medical_records')
        .where('patientId', isEqualTo: patientId)
        .where('category', isEqualTo: category.name)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicalRecord.fromMap(doc.data()))
            .toList());
  }

  Future<void> deleteMedicalRecord(MedicalRecord record) async {
    try {
      // Delete from Firebase Storage
      final Reference storageRef = _storage.refFromURL(record.fileUrl);
      await storageRef.delete();

      // Delete from Firestore (medical_records)
      await _firestore.collection('medical_records').doc(record.id).delete();

      // 🔥 ALSO DELETE FROM PATIENT_NOTES COLLECTION
      final notesQuery = await _firestore
          .collection('patient_notes')
          .where('medicalRecordId', isEqualTo: record.id)
          .get();
      
      for (final doc in notesQuery.docs) {
        await doc.reference.delete();
      }

      debugPrint('✅ Medical record deleted: ${record.fileName}');
      debugPrint('✅ Associated notes deleted from patient_notes');
    } catch (e) {
      debugPrint('❌ Error deleting medical record: $e');
      rethrow;
    }
  }

  Future<File?> pickMedicalRecord() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Validate file size
        if (await file.length() > 20 * 1024 * 1024) {
          throw Exception('File size too large. Please select a file smaller than 20MB.');
        }
        
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error picking file: $e');
      rethrow;
    }
  }

  // Helper methods
  bool _isValidFileType(String extension) {
    return ['pdf', 'jpg', 'jpeg', 'png'].contains(extension);
  }

  String _getContentType(String extension) {
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

  String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1048576) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
  }
}