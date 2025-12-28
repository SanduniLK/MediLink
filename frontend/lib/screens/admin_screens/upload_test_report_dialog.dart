import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/screens/assistant_screens/test_report_verification_flow.dart';
import 'package:frontend/services/google_vision_service.dart';
// Remove this import if you don't use it: import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:intl/intl.dart';

class UploadTestReportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> patients;
  final String medicalCenterId;
  final String medicalCenterName;
  final VoidCallback? onReportUploaded;
   final String reportId;

  const UploadTestReportDialog({
    super.key,
    required this.patients,
    required this.medicalCenterId,
    required this.medicalCenterName,
    this.onReportUploaded,
    this.reportId = '',
  });

  @override
  State<UploadTestReportDialog> createState() => _UploadTestReportDialogState();
}

class _UploadTestReportDialogState extends State<UploadTestReportDialog> {
  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedTestType;
  final TextEditingController _testDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
   
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Test categories
  final List<String> _testCategories = [
    'Full Blood Count (FBC)',
    'Urine Analysis',
    'Thyroid (TSH) Test',
    'Lipid Profile',
    'Blood Sugar Test',
    'Liver Function Test',
    'Kidney Function Test',
    'Other Blood Test',
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _testDateController.text = '${today.day}/${today.month}/${today.year}';
  }

  @override
  void dispose() {
    _testDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileName = result.files.first.name;
        
        // Check file size (max 20MB)
        final fileSize = await file.length();
        if (fileSize > 20 * 1024 * 1024) {
          _showError('File size too large. Please select a file smaller than 20MB.');
          return;
        }
        
        setState(() {
          _selectedFile = file;
          _fileName = fileName;
          _errorMessage = null;
        });
        
        print('📁 File selected: $fileName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      }
    } catch (e) {
      _showError('Error selecting file: ${e.toString()}');
    }
  }
Future<void> _uploadTestReport() async {
  // Clear messages
  setState(() {
    _errorMessage = null;
    _successMessage = null;
  });

  // Validation
  if (_selectedPatientId == null) {
    _showError('Please select a patient');
    return;
  }

  if (_selectedFile == null) {
    _showError('Please select a file');
    return;
  }

  if (_selectedTestType == null) {
    _showError('Please select a test type');
    return;
  }

  setState(() {
    _isUploading = true;
  });

  try {
    // Get selected patient info
    final selectedPatient = widget.patients.firstWhere(
      (p) => p['id'] == _selectedPatientId,
    );

    print('🚀 Starting upload process...');

    // =================== 1. UPLOAD FILE TO FIREBASE STORAGE ===================
    print('📤 Uploading file to Firebase Storage...');
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final String safeFileName = _fileName!.replaceAll(' ', '_');
    final String storagePath = 'test_reports/${timestamp}_$safeFileName';
    final Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);
    
    final UploadTask uploadTask = storageRef.putFile(_selectedFile!);
    
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();
    final int fileSize = await _selectedFile!.length();
    
    print('✅ File uploaded successfully!');

    if (!mounted) return;

    // =================== 2. USE GOOGLE VISION API FOR REAL EXTRACTION ===================
print('🔍 Using Google Vision API for REAL text extraction...');

Map<String, dynamic> extractionResult = {};
String finalCategory = _selectedTestType!;

try {
  // Use Google Vision API to extract REAL text
  extractionResult = await GoogleVisionService.extractMedicalText(_selectedFile!);
  
  print('✅ Google Vision extraction completed:');
  print('   Success: ${extractionResult['success']}');
  print('   File Type: ${extractionResult['fileType']}');
  print('   Text Length: ${extractionResult['textLength'] ?? 0} chars');
  
  // Get the extracted parameters from Google Vision
  final extractedParameters = GoogleVisionService.extractLabParameters(extractionResult['fullText'] ?? '');
  
  // Add extracted parameters to the result
  extractionResult['extractedParameters'] = extractedParameters;
  
  print('🔍 Parameters extracted: ${extractedParameters.length}');
  
  // Debug: Show what was extracted
  if (extractionResult['success'] == true && extractedParameters.isNotEmpty) {
    print('\n📊 GOOGLE VISION EXTRACTED DATA:');
    print('=' * 50);
    print('FULL TEXT (first 200 chars):');
    final fullText = extractionResult['fullText']?.toString() ?? '';
    if (fullText.isNotEmpty) {
      print(fullText.substring(0, min(200, fullText.length)));
    }
    
    print('\nEXTRACTED PARAMETERS:');
    for (var param in extractedParameters) {
      print('  - ${param['parameter']}: ${param['value']} ${param['unit']}');
    }
    print('=' * 50);
  }
  
  // If extraction failed, handle it
  if (extractionResult['success'] != true) {
    print('⚠️ Google Vision extraction failed: ${extractionResult['error']}');
    
    // Fallback: Try to read file as text if it's a text file
    final fileExtension = _selectedFile!.path.split('.').last.toLowerCase();
    if (fileExtension == 'txt') {
      print('🔄 Trying to read as text file...');
      try {
        final textContent = await _selectedFile!.readAsString();
        extractionResult = {
          'success': true,
          'fullText': textContent,
          'fileType': 'txt',
          'textLength': textContent.length,
          'extractedParameters': GoogleVisionService.extractLabParameters(textContent),
        };
        print('✅ Text file read successfully');
      } catch (e) {
        print('❌ Failed to read text file: $e');
      }
    }
  }
  
} catch (e, stackTrace) {
  print('❌ Error in Google Vision extraction: $e');
  print('❌ Stack trace: $stackTrace');
  
  extractionResult = {
    'success': false,
    'fullText': '',
    'extractedParameters': [],
    'error': 'Google Vision API error: $e',
  };
}

// Ensure extractionResult has the right structure
if (extractionResult['extractedParameters'] == null) {
  extractionResult['extractedParameters'] = [];
}

// Now continue with the rest of your code...

    // =================== 3. CREATE TEST REPORT ===================
    final String reportId = FirebaseFirestore.instance.collection('test_reports').doc().id;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    
    DateTime testDate;
    try {
      testDate = DateFormat('dd/MM/yyyy').parse(_testDateController.text);
    } catch (e) {
      testDate = DateTime.now();
    }

    String testName = _selectedTestType!;
    if (testName.contains('(')) {
      testName = testName.split('(').first.trim();
    }

    // Format file size
    String fileSizeFormatted;
    if (fileSize < 1024) {
      fileSizeFormatted = '$fileSize B';
    } else if (fileSize < 1048576) {
      fileSizeFormatted = '${(fileSize / 1024).toStringAsFixed(2)} KB';
    } else {
      fileSizeFormatted = '${(fileSize / 1048576).toStringAsFixed(2)} MB';
    }

    final testReportData = {
      'id': reportId,
      'patientId': _selectedPatientId,
      'patientName': _selectedPatientName ?? selectedPatient['fullname'] ?? 'Unknown Patient',
      'medicalCenterId': widget.medicalCenterId,
      'medicalCenterName': widget.medicalCenterName,
      
      // Test Details
      'testName': testName.toLowerCase(),
      'testType': _selectedTestType,
      'testReportCategory': _selectedTestType,
      
      // File Details
      'fileUrl': downloadUrl,
      'fileName': _fileName,
      'fileSize': fileSizeFormatted,
      'fileType': _selectedFile!.path.split('.').last.toLowerCase(),
      
      // Dates
      'testDate': Timestamp.fromDate(testDate),
      'uploadedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      
      // Uploader Info
      'uploadedBy': currentUser?.uid ?? widget.medicalCenterId,
      'uploadedByName': currentUser?.email ?? 'Admin',
      
      // Text Extraction Results
      'extractedText': extractionResult['fullText']?.toString() ?? '',
      'isTextExtracted': true,
      'textExtractedAt': Timestamp.now(),
      'extractionMethod': extractionResult['extractionMethod'] ?? 'manual',
      
      // Medical Info
      'medicalInfo': extractionResult['medicalInfo'] ?? {},
      'extractedParameters': extractionResult['extractedParameters'] ?? [],
      
      // Status
      'status': 'pending_verification',
      'notes': _notesController.text,
      'requiresVerification': true,
      'isProcessed': false,
    };

    // =================== 4. SAVE TO FIRESTORE ===================
    print('💾 Saving test report...');
    await FirebaseFirestore.instance
        .collection('test_reports')
        .doc(reportId)
        .set(testReportData);
    
    print('✅ Test report saved with ID: $reportId');

    if (!mounted) return;

    // =================== 5. NAVIGATE TO VERIFICATION SCREEN ===================
    print('✅ Navigating to verification screen...');
    
    // IMPORTANT: Show extracted data in console for debugging
    print('=' * 50);
    print('EXTRACTION RESULT FOR VERIFICATION:');
    print('Success: ${extractionResult['success']}');
    print('Extracted Parameters: ${extractionResult['extractedParameters']?.length ?? 0}');
    
    final extractedParams = extractionResult['extractedParameters'] as List?;
    if (extractedParams != null) {
      for (var param in extractedParams) {
        print('  - ${param['parameter']}: ${param['value']} ${param['unit']}');
      }
    }
    print('=' * 50);
    
    // Close the dialog
    Navigator.of(context).pop();
    
    // Navigate to verification
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TestReportVerificationFlow(
          patientId: _selectedPatientId!,
          patientName: _selectedPatientName ?? selectedPatient['fullname'] ?? 'Unknown',
          medicalCenterId: widget.medicalCenterId,
          medicalCenterName: widget.medicalCenterName,
          fileName: _fileName!,
          fileUrl: downloadUrl,
          extractedData: extractionResult,
          testCategory: finalCategory,
          reportId: reportId,
        ),
      ),
    ).then((success) {
      if (success == true) {
        widget.onReportUploaded?.call();
      }
    });

  } catch (e, stackTrace) {
    print('❌ UPLOAD ERROR: $e');
    print('❌ Stack trace: $stackTrace');
    
    if (mounted) {
      _showError('Upload failed: ${e.toString()}');
      setState(() {
        _isUploading = false;
      });
    }
  }
}

// Fallback extraction data if Google Vision fails
Future<Map<String, dynamic>> _createFallbackExtractionData() async {
  print('🔄 Creating fallback extraction data...');
  
  return {
    'success': true,
    'fullText': '⚠️ Text extraction could not be performed automatically.\n'
               'Please manually enter the test values below.\n'
               'File was uploaded successfully.',
    'medicalInfo': {
      'medications': [],
      'labResults': [],
      'patientInfo': {},
      'dates': [],
    },
    'extractedParameters': [],
    'textLength': 0,
    'fileType': _selectedFile!.path.split('.').last.toLowerCase(),
    'note': 'Manual entry required',
  };
}
  // Simulate text extraction for testing
  Future<Map<String, dynamic>> _simulateTextExtraction() async {
    // Always return success with mock data
    return {
      'success': true,
      'fullText': '''
      COMPLETE BLOOD COUNT REPORT
      Patient: ${_selectedPatientName ?? 'Patient'}
      Date: ${_testDateController.text}
      
      PARAMETER            VALUE      UNIT     REFERENCE RANGE
      Hemoglobin (Hb)      14.5      g/dL     13.0-17.0
      WBC                  7.8       /cmm     4.0-11.0
      Platelets            250       /cmm     150-450
      RBC                  5.2       million  4.5-5.9
      Hematocrit (HCT)     42        %        40-54
      MCV                  85        fL       80-100
      MCH                  28        pg       27-32
      MCHC                 33        g/dL     32-36
      Neutrophils          55        %        40-75
      Lymphocytes          35        %        20-45
      Monocytes            6         %        2-10
      Eosinophils          3         %        1-6
      Basophils            1         %        0-2
      
      Interpretation: All parameters within normal limits.
      ''',
      'medicalInfo': {
        'patientName': _selectedPatientName,
        'testDate': _testDateController.text,
      },
      'extractedParameters': [
        {'parameter': 'Hemoglobin (Hb)', 'value': '14.5', 'unit': 'g/dL', 'confidence': 'high'},
        {'parameter': 'White Blood Cells (WBC)', 'value': '7.8', 'unit': '/cmm', 'confidence': 'high'},
        {'parameter': 'Platelets', 'value': '250', 'unit': '/cmm', 'confidence': 'high'},
        {'parameter': 'Red Blood Cells (RBC)', 'value': '5.2', 'unit': 'million/cmm', 'confidence': 'high'},
        {'parameter': 'Hematocrit (HCT)', 'value': '42', 'unit': '%', 'confidence': 'medium'},
        {'parameter': 'MCV', 'value': '85', 'unit': 'fL', 'confidence': 'medium'},
        {'parameter': 'MCH', 'value': '28', 'unit': 'pg', 'confidence': 'medium'},
        {'parameter': 'MCHC', 'value': '33', 'unit': 'g/dL', 'confidence': 'medium'},
        {'parameter': 'Neutrophils', 'value': '55', 'unit': '%', 'confidence': 'medium'},
        {'parameter': 'Lymphocytes', 'value': '35', 'unit': '%', 'confidence': 'medium'},
        {'parameter': 'Monocytes', 'value': '6', 'unit': '%', 'confidence': 'medium'},
        {'parameter': 'Eosinophils', 'value': '3', 'unit': '%', 'confidence': 'medium'},
        {'parameter': 'Basophils', 'value': '1', 'unit': '%', 'confidence': 'medium'},
      ],
      'testDate': _testDateController.text,
    };
  }

  Future<void> _createBasicPatientNote({
    required String patientId,
    required String recordId,
    required Map<String, dynamic> testReportData,
    required Map<String, dynamic> selectedPatient,
  }) async {
    try {
      final noteId = FirebaseFirestore.instance.collection('patient_notes').doc().id;
      
      final noteData = {
        'id': noteId,
        'patientId': patientId,
        'medicalRecordId': recordId,
        'fileName': testReportData['fileName'],
        'category': 'labResults',
        'testReportCategory': testReportData['testReportCategory'],
        'testType': testReportData['testName'],
        'testDate': testReportData['testDate'],
        'testDateFormatted': DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'analysisDate': Timestamp.now(),
        'noteType': 'admin_uploaded_report',
        'isProcessed': false,
        'isVerified': false,
        'uploadSource': 'admin',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        
        // Empty analysis fields
        'extractedText': '',
        'results': [],
        'normalResults': [],
        'abnormalResults': [],
        'criticalFindings': [],
        'verifiedParameters': [],
        'resultsByLevel': {'high': [], 'normal': [], 'low': []},
        'totalResults': 0,
        'normalCount': 0,
        'abnormalCount': 0,
        'lowCount': 0,
        'highCount': 0,
        'hasAbnormalResults': false,
        'overallStatus': 'Pending Analysis',
        'recommendations': [],
        'verificationMethod': 'pending',
        'verifiedAt': null,
        'verifiedBy': '',
        'analysisSummary': 'Report uploaded. Awaiting text extraction and analysis.',
      };

      await FirebaseFirestore.instance
          .collection('patient_notes')
          .doc(noteId)
          .set(noteData);
      
    } catch (e) {
      print('❌ Error creating patient note: $e');
      rethrow;
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_upload,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Upload Test Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Selected Patient Display
                if (_selectedPatientName != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: $_selectedPatientName',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Patient Selection
                const Text(
                  'Select Patient *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Patient List - Clickable Cards
                if (widget.patients.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Center(
                      child: Text(
                        'No patients available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Column(
                    children: widget.patients.map((patient) {
                      final String patientId = patient['id']?.toString() ?? '';
                      final String patientName = patient['fullname']?.toString() ?? 'Unknown';
                      final String patientMobile = patient['mobile']?.toString() ?? '';
                      final bool isSelected = _selectedPatientId == patientId;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isSelected ? Colors.blue.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPatientId = patientId;
                                _selectedPatientName = patientName;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        patientName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patientName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isSelected ? Colors.blue : Colors.black,
                                          ),
                                        ),
                                        if (patientMobile.isNotEmpty)
                                          Text(
                                            patientMobile,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 20),

                // Test Type
                const Text(
                  'Test Type *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedTestType,
                    hint: const Text('Select test type'),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _testCategories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedTestType = value;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Test Date
                const Text(
                  'Test Date *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _testDateController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'DD/MM/YYYY',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                  ),
                ),

                const SizedBox(height: 20),

                // FILE UPLOAD SECTION
                const Text(
                  'Report File *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectFile,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedFile == null ? Colors.grey.shade300 : Colors.green.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: _selectedFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Click to select file',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'PDF, JPG, PNG (Max 20MB)',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 40,
                                  color: Colors.green.shade500,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fileName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFile = null;
                                      _fileName = null;
                                    });
                                  },
                                  child: const Text(
                                    'Remove file',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Notes (Optional)
                const Text(
                  'Notes (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Any additional notes about this report...',
                  ),
                ),

                const SizedBox(height: 30),

                // Upload Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selectedPatientId == null || 
                                _selectedTestType == null || 
                                _selectedFile == null || 
                                _isUploading)
                        ? null
                        : _uploadTestReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Upload Test Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 10),

                // Info
                const Center(
                  child: Text(
                    'Report will be saved to the patient\'s medical records',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}