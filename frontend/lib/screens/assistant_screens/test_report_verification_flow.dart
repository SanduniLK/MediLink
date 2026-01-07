import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TestReportVerificationFlow extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String medicalCenterId;
  final String medicalCenterName;
  final String fileName;
  final String fileUrl;
  final Map<String, dynamic> extractedData;
  final String testCategory;
  final String reportId;

  const TestReportVerificationFlow({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.fileName,
    required this.fileUrl,
    required this.extractedData,
    required this.testCategory,
    required this.reportId,
  });

  @override
  State<TestReportVerificationFlow> createState() => _TestReportVerificationFlowState();
}

class _TestReportVerificationFlowState extends State<TestReportVerificationFlow> {
  List<Map<String, dynamic>> _parameters = [];
  List<Map<String, dynamic>> _verifiedParameters = [];
  bool _isSaving = false;
  String? _errorMessage;
  String? _testDate;
  
  // Sections for categorized results
  List<Map<String, dynamic>> _criticalResults = [];
  List<Map<String, dynamic>> _abnormalResults = [];
  List<Map<String, dynamic>> _normalResults = [];

  @override
  void initState() {
    super.initState();
    _initializeParameters();
  }

  void _initializeParameters() {
    // Get extracted parameters from extractedData
    final extractedParams = (widget.extractedData['extractedParameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Get default parameters based on test category
    final defaultParams = _getDefaultParametersForCategory(widget.testCategory);
    
    // Combine extracted and default parameters
    _parameters = _mergeParameters(extractedParams, defaultParams);
    
    // Extract test date
    _testDate = widget.extractedData['testDate']?.toString() ?? 
                _extractTestDate(widget.extractedData['fullText']?.toString() ?? '');
    
    // Categorize initial results
    _categorizeResults();
  }

  List<Map<String, dynamic>> _getDefaultParametersForCategory(String category) {
    // Default parameters for each test category
    final Map<String, List<Map<String, dynamic>>> defaultParams = {
      'Full Blood Count (FBC)': [
        {'parameter': 'Hemoglobin (Hb)', 'unit': 'g/dL', 'normalRange': '13-17'},
        {'parameter': 'White Blood Cells (WBC)', 'unit': '/cmm', 'normalRange': '4000-11000'},
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
        {'parameter': 'Glucose', 'unit': '', 'normalRange': 'Negative'},
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
        {'parameter': 'Free T4', 'unit': 'ng/dL', 'normalRange': '0.8-1.8'},
        {'parameter': 'Free T3', 'unit': 'pg/mL', 'normalRange': '2.3-4.2'},
      ],
      'Lipid Profile': [
        {'parameter': 'Total Cholesterol', 'unit': 'mg/dL', 'normalRange': '<200'},
        {'parameter': 'HDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '>40'},
        {'parameter': 'LDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '<100'},
        {'parameter': 'VLDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '<30'},
        {'parameter': 'Triglycerides', 'unit': 'mg/dL', 'normalRange': '<150'},
        {'parameter': 'Total/HDL Ratio', 'unit': '', 'normalRange': '<5.0'},
      ],
      'Blood Sugar Test': [
        {'parameter': 'Fasting Glucose', 'unit': 'mg/dL', 'normalRange': '70-110'},
        {'parameter': 'Postprandial Glucose', 'unit': 'mg/dL', 'normalRange': '<140'},
        {'parameter': 'HbA1c', 'unit': '%', 'normalRange': '<5.7'},
        {'parameter': 'Random Glucose', 'unit': 'mg/dL', 'normalRange': '<200'},
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

    return defaultParams[category] ?? [
      {'parameter': 'Test Result', 'unit': '', 'normalRange': 'Refer to report'},
    ];
  }

  List<Map<String, dynamic>> _mergeParameters(
    List<Map<String, dynamic>> extracted,
    List<Map<String, dynamic>> defaults,
  ) {
    final List<Map<String, dynamic>> merged = [];
    
    // First add extracted parameters with their values
    for (var extractedParam in extracted) {
      final paramName = extractedParam['parameter']?.toString() ?? '';
      final defaultValue = defaults.firstWhere(
        (p) {
          final defaultParamName = p['parameter']?.toString() ?? '';
          return paramName.isNotEmpty && defaultParamName.isNotEmpty &&
                 (defaultParamName.toLowerCase().contains(paramName.toLowerCase()) ||
                  paramName.toLowerCase().contains(defaultParamName.toLowerCase()));
        },
        orElse: () => {'parameter': paramName, 'unit': '', 'normalRange': ''},
      );
      
      merged.add({
        'parameter': extractedParam['parameter'] ?? defaultValue['parameter'],
        'value': extractedParam['value']?.toString() ?? '',
        'unit': extractedParam['unit'] ?? defaultValue['unit'],
        'normalRange': defaultValue['normalRange'],
        'isExtracted': true,
        'confidence': extractedParam['confidence'] ?? 'medium',
        'needsVerification': true,
        'isVerified': false,
      });
    }
    
    // Add remaining default parameters that weren't extracted
    for (var defaultParam in defaults) {
      final paramName = defaultParam['parameter']?.toString() ?? '';
      final alreadyExists = merged.any((p) => 
          (p['parameter']?.toString() ?? '').toLowerCase() == paramName.toLowerCase());
      
      if (!alreadyExists) {
        merged.add({
          'parameter': defaultParam['parameter'],
          'value': '',
          'unit': defaultParam['unit'],
          'normalRange': defaultParam['normalRange'],
          'isExtracted': false,
          'confidence': 'low',
          'needsVerification': true,
          'isVerified': false,
        });
      }
    }
    
    return merged;
  }

  String _extractTestDate(String text) {
    try {
      final dateRegex = RegExp(r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b');
      final match = dateRegex.firstMatch(text);
      if (match != null) {
        return '${match.group(1)}/${match.group(2)}/${match.group(3)}';
      }
    } catch (e) {
      // Ignore
    }
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  void _updateParameter(int index, String value) {
    setState(() {
      _parameters[index]['value'] = value;
      _parameters[index]['isVerified'] = value.isNotEmpty;
      // Re-categorize results after update
      _categorizeResults();
    });
  }

  void _categorizeResults() {
    _criticalResults.clear();
    _abnormalResults.clear();
    _normalResults.clear();
    
    for (var param in _parameters) {
      final value = param['value']?.toString() ?? '';
      if (value.isEmpty) continue;
      
      final numericValue = double.tryParse(value) ?? 0;
      final normalRange = param['normalRange']?.toString() ?? '';
      final level = _getValueLevel(numericValue, normalRange);
      
      final categorizedParam = {
        ...param,
        'level': level,
      };
      
      if (level == 'critical') {
        _criticalResults.add(categorizedParam);
      } else if (level == 'abnormal') {
        _abnormalResults.add(categorizedParam);
      } else {
        _normalResults.add(categorizedParam);
      }
    }
  }

  Future<void> _saveVerifiedReport() async {
    // Filter out parameters with values
    _verifiedParameters = _parameters.where((p) => 
        (p['value']?.toString() ?? '').isNotEmpty).toList();
    
    if (_verifiedParameters.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter values for at least one parameter';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Parse test date
      DateTime testDate;
      try {
        testDate = DateFormat('dd/MM/yyyy').parse(_testDate ?? DateFormat('dd/MM/yyyy').format(DateTime.now()));
      } catch (e) {
        testDate = DateTime.now();
      }

      // Determine status based on values
      String overallStatus = 'normal';
      int abnormalCount = 0;
      final List<Map<String, dynamic>> abnormalResults = [];

      for (var param in _verifiedParameters) {
        final valueStr = param['value']?.toString() ?? '';
        final value = double.tryParse(valueStr) ?? 0;
        final normalRange = param['normalRange']?.toString() ?? '';
        
        if (normalRange.isNotEmpty && !_isValueInNormalRange(value, normalRange)) {
          abnormalCount++;
          final level = _getValueLevel(value, normalRange);
          abnormalResults.add({
            ...param,
            'isAbnormal': true,
            'level': level,
            'status': level,
          });
          
          if (level == 'critical') {
            overallStatus = 'critical';
          } else if (overallStatus != 'critical' && level == 'abnormal') {
            overallStatus = 'abnormal';
          }
        }
      }

      // =================== 1. UPDATE TEST REPORT DOCUMENT ===================
      final testReportData = {
        // Keep existing data
        'id': widget.reportId,
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'medicalCenterId': widget.medicalCenterId,
        'medicalCenterName': widget.medicalCenterName,
        
        // Test Details
        'testName': widget.testCategory.split('(').first.trim().toLowerCase(),
        'testType': widget.testCategory,
        'testReportCategory': widget.testCategory,
        
        // File Details
        'fileUrl': widget.fileUrl,
        'fileName': widget.fileName,
        
        // Dates
        'testDate': Timestamp.fromDate(testDate),
  'testDateFormatted': DateFormat('dd/MM/yyyy').format(testDate), // ADD THIS LINE
  'updatedAt': Timestamp.now(),
  
        
        // Uploader Info (keep original)
        'uploadedBy': currentUser?.uid ?? widget.medicalCenterId,
        'uploadedByName': currentUser?.email ?? 'Admin',
        
        // Verification Results
        'verifiedParameters': _verifiedParameters,
        'isProcessed': true,
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'verifiedBy': currentUser?.email ?? 'Admin',
        'verificationMethod': 'manual_entry',
        
        // Analysis Results
        'status': overallStatus,
        'abnormalCount': abnormalCount,
        'abnormalResults': abnormalResults,
        'criticalResults': _criticalResults,
        'normalResults': _normalResults,
        
        // Text Extraction
        'extractedText': widget.extractedData['fullText']?.toString() ?? '',
        'isTextExtracted': true,
        'textExtractedAt': Timestamp.now(),
        'medicalInfo': widget.extractedData['medicalInfo'] ?? {},
        
        'notes': 'Manually verified and entered',
        'description': 'Manually verified test report with parameter values',
      };

      // Update the existing test report
      await FirebaseFirestore.instance
          .collection('test_reports')
          .doc(widget.reportId)
          .update(testReportData);
      
      // =================== 2. CREATE DETAILED PATIENT NOTE ===================
      await _createDetailedPatientNote(
        reportId: widget.reportId,
        abnormalResults: abnormalResults,
        abnormalCount: abnormalCount,
        testDate: testDate,
      );

      // =================== 3. NAVIGATE BACK ===================
      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _isValueInNormalRange(double value, String normalRange) {
    if (normalRange.isEmpty) return true;
    
    try {
      if (normalRange.contains('-')) {
        final parts = normalRange.split('-');
        final minText = parts[0].replaceAll(RegExp(r'[^0-9.]'), '');
        final maxText = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
        
        final min = double.tryParse(minText) ?? 0;
        final max = double.tryParse(maxText) ?? 0;
        
        return value >= min && value <= max;
      } else if (normalRange.contains('<')) {
        final limitText = normalRange.replaceAll(RegExp(r'[^0-9.]'), '');
        final limit = double.tryParse(limitText) ?? 0;
        return value < limit;
      } else if (normalRange.contains('>')) {
        final limitText = normalRange.replaceAll(RegExp(r'[^0-9.]'), '');
        final limit = double.tryParse(limitText) ?? 0;
        return value > limit;
      }
    } catch (e) {
      // Ignore
    }
    return true;
  }

  String _getValueLevel(double value, String normalRange) {
    try {
      if (normalRange.contains('-')) {
        final parts = normalRange.split('-');
        final minText = parts[0].replaceAll(RegExp(r'[^0-9.]'), '');
        final maxText = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
        
        final min = double.tryParse(minText) ?? 0;
        final max = double.tryParse(maxText) ?? 0;
        
        if (min == 0 && max == 0) return 'normal';
        
        // Calculate percentage deviation
        final double deviation;
        if (value < min) {
          deviation = ((min - value) / min) * 100;
        } else if (value > max) {
          deviation = ((value - max) / max) * 100;
        } else {
          return 'normal';
        }
        
        if (deviation > 30) return 'critical';
        if (deviation > 10) return 'abnormal';
        return 'normal';
      } else if (normalRange.contains('<')) {
        final limitText = normalRange.replaceAll(RegExp(r'[^0-9.]'), '');
        final limit = double.tryParse(limitText) ?? 0;
        if (value > limit * 1.3) return 'critical';
        if (value > limit * 1.1) return 'abnormal';
        return 'normal';
      } else if (normalRange.contains('>')) {
        final limitText = normalRange.replaceAll(RegExp(r'[^0-9.]'), '');
        final limit = double.tryParse(limitText) ?? 0;
        if (value < limit * 0.7) return 'critical';
        if (value < limit * 0.9) return 'abnormal';
        return 'normal';
      }
    } catch (e) {
      // Ignore
    }
    return 'normal';
  }

  Future<void> _createDetailedPatientNote({
    required String reportId,
    required List<Map<String, dynamic>> abnormalResults,
    required int abnormalCount,
    required DateTime testDate,
  }) async {
    try {
      final noteId = FirebaseFirestore.instance.collection('patient_notes').doc().id;
      
      // Organize results by level
      final List<Map<String, dynamic>> allResults = [];
      final Map<String, List<Map<String, dynamic>>> resultsByLevel = {
        'critical': _criticalResults,
        'abnormal': _abnormalResults,
        'normal': _normalResults,
      };
      
      for (var param in _verifiedParameters) {
        final valueStr = param['value']?.toString() ?? '';
        final value = double.tryParse(valueStr) ?? 0;
        final normalRange = param['normalRange']?.toString() ?? '';
        final level = _getValueLevel(value, normalRange);
        
        final result = {
          'parameter': param['parameter']?.toString() ?? 'Unknown',
          'value': valueStr,
          'unit': param['unit']?.toString() ?? '',
          'numericValue': value,
          'isAbnormal': level != 'normal',
          'isVerified': true,
          'level': level,
          'status': level,
          'normalRange': normalRange,
          'note': level == 'normal' ? 'Within normal range' : 'Outside normal range',
        };
        
        allResults.add(result);
      }
      
      final normalCount = _normalResults.length;
      final criticalCount = _criticalResults.length;
      final abnormalCount = _abnormalResults.length;
      final totalResults = allResults.length;
      
      // Create analysis summary
      String analysisSummary = '${widget.testCategory} Report Analysis\n';
      analysisSummary += 'Total parameters: $totalResults\n';
      analysisSummary += 'Normal parameters: $normalCount\n';
      analysisSummary += 'Abnormal parameters: $abnormalCount\n';
      if (criticalCount > 0) {
        analysisSummary += 'Critical parameters: $criticalCount\n';
      }
      
      if (criticalCount > 0) {
        analysisSummary += '\n⚠️ CRITICAL RESULTS (Requires Immediate Attention):\n';
        for (var critical in _criticalResults) {
          analysisSummary += '  • ${critical['parameter']}: ${critical['value']} ${critical['unit']} (Normal: ${critical['normalRange']} ${critical['unit']})\n';
        }
      }
      
      if (abnormalCount > 0) {
        analysisSummary += '\n⚠️ ABNORMAL RESULTS (Requires Follow-up):\n';
        for (var abnormal in _abnormalResults) {
          analysisSummary += '  • ${abnormal['parameter']}: ${abnormal['value']} ${abnormal['unit']} (Normal: ${abnormal['normalRange']} ${abnormal['unit']})\n';
        }
      }
      
      if (normalCount > 0 && (criticalCount == 0 && abnormalCount == 0)) {
        analysisSummary += '\n✅ All results are within normal range.';
      }
      
      final currentUser = FirebaseAuth.instance.currentUser;
      
      final noteData = {
        'id': noteId,
        'patientId': widget.patientId,
        'medicalRecordId': reportId,
        'fileName': widget.fileName,
        'category': 'labResults',
        'testReportCategory': widget.testCategory,
        'testType': widget.testCategory.split('(').first.trim(),
        'testDate': Timestamp.fromDate(testDate),
        'testDateFormatted': DateFormat('dd/MM/yyyy').format(testDate),
        'analysisDate': Timestamp.now(),
        'noteType': 'verified_report_analysis',
        'isProcessed': true,
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'verifiedBy': currentUser?.email ?? 'Admin',
        'verificationMethod': 'manual_entry',
        
        // Analysis Data
        'extractedText': widget.extractedData['fullText']?.toString() ?? '',
        'results': allResults,
        'abnormalResults': abnormalResults,
        'criticalResults': _criticalResults,
        'abnormalResults': _abnormalResults,
        'normalResults': _normalResults,
        'verifiedParameters': _verifiedParameters,
        'resultsByLevel': resultsByLevel,
        
        // Counts
        'totalResults': totalResults,
        'normalCount': normalCount,
        'abnormalCount': abnormalCount,
        'criticalCount': criticalCount,
        'hasAbnormalResults': abnormalCount > 0,
        'hasCriticalResults': criticalCount > 0,
        
        // Summary
        'overallStatus': criticalCount > 0 ? 'Critical' : (abnormalCount > 0 ? 'Abnormal' : 'Normal'),
        'analysisSummary': analysisSummary,
        'recommendations': _generateRecommendations(),
        
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('patient_notes')
          .doc(noteId)
          .set(noteData);
      
    } catch (e) {
      // Don't rethrow - we don't want to fail the entire save process
    }
  }

  List<String> _generateRecommendations() {
    final recommendations = <String>[];
    
    if (_criticalResults.isNotEmpty) {
      recommendations.add('🚨 URGENT: Critical results detected. Please consult with a healthcare provider immediately.');
      recommendations.add('Consider repeating the test for confirmation if clinically indicated.');
    }
    
    if (_abnormalResults.isNotEmpty) {
      recommendations.add('⚠️ Abnormal results noted. Follow up with healthcare provider.');
      recommendations.add('Review patient symptoms and clinical history in context of abnormal findings.');
    }
    
    if (_criticalResults.isEmpty && _abnormalResults.isEmpty) {
      recommendations.add('✅ All test results are within normal limits.');
      recommendations.add('Continue with regular health monitoring as per standard guidelines.');
    }
    
    // Add test-specific recommendations
    if (widget.testCategory.contains('Blood Sugar')) {
      recommendations.add('For blood sugar tests: Monitor diet and exercise routine.');
    } else if (widget.testCategory.contains('Lipid')) {
      recommendations.add('For lipid profile: Consider dietary modifications if needed.');
    } else if (widget.testCategory.contains('Liver') || widget.testCategory.contains('Kidney')) {
      recommendations.add('Avoid hepatotoxic/nephrotoxic medications if possible.');
    }
    
    return recommendations;
  }

  Widget _buildParameterCard(Map<String, dynamic> param, int index) {
    final value = param['value']?.toString() ?? '';
    final isExtracted = param['isExtracted'] == true;
    final level = value.isNotEmpty ? _getValueLevel(double.tryParse(value) ?? 0, param['normalRange']?.toString() ?? '') : '';
    
    Color getBorderColor() {
      if (value.isEmpty) return Colors.grey.shade300;
      switch (level) {
        case 'critical': return Colors.red;
        case 'abnormal': return Colors.orange;
        case 'normal': return Colors.green;
        default: return Colors.grey.shade300;
      }
    }
    
    Color getBackgroundColor() {
      if (value.isEmpty) return Colors.white;
      switch (level) {
        case 'critical': return Colors.red.shade50;
        case 'abnormal': return Colors.orange.shade50;
        case 'normal': return Colors.green.shade50;
        default: return Colors.white;
      }
    }
    
    Widget getStatusIcon() {
      if (value.isEmpty) return const SizedBox();
      switch (level) {
        case 'critical': return const Icon(Icons.warning, color: Colors.red, size: 16);
        case 'abnormal': return const Icon(Icons.warning_amber, color: Colors.orange, size: 16);
        case 'normal': return const Icon(Icons.check_circle, color: Colors.green, size: 16);
        default: return const SizedBox();
      }
    }
    
    String getStatusText() {
      if (value.isEmpty) return '';
      switch (level) {
        case 'critical': return 'Critical';
        case 'abnormal': return 'Abnormal';
        case 'normal': return 'Normal';
        default: return '';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: getBackgroundColor(),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: getBorderColor(), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parameter Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    param['parameter']?.toString() ?? 'Parameter',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isExtracted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Auto-extracted',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Input Row with Status
            Row(
              children: [
                // Value Input
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: value,
                    decoration: InputDecoration(
                      labelText: 'Value',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.edit, size: 18),
                      suffixText: param['unit']?.toString(),
                      filled: value.isNotEmpty,
                      fillColor: Colors.white.withOpacity(0.8),
                    ),
                    onChanged: (newValue) => _updateParameter(index, newValue),
                  ),
                ),
                
                const SizedBox(width: 10),
                
                // Normal Range and Status
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Normal: ${param['normalRange']} ${param['unit']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (value.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      getStatusIcon(),
                                      const SizedBox(width: 4),
                                      Text(
                                        getStatusText(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: getBorderColor(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Confidence Indicator
            if (isExtracted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Confidence: ${param['confidence']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Results Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        
        // Critical Results Section
        if (_criticalResults.isNotEmpty)
          _buildResultSection(
            title: '🚨 Critical Results (${_criticalResults.length})',
            results: _criticalResults,
            color: Colors.red,
            icon: Icons.warning,
          ),
        
        // Abnormal Results Section
        if (_abnormalResults.isNotEmpty)
          _buildResultSection(
            title: '⚠️ Abnormal Results (${_abnormalResults.length})',
            results: _abnormalResults,
            color: Colors.orange,
            icon: Icons.warning_amber,
          ),
        
        // Normal Results Section
        if (_normalResults.isNotEmpty)
          _buildResultSection(
            title: '✅ Normal Results (${_normalResults.length})',
            results: _normalResults,
            color: Colors.green,
            icon: Icons.check_circle,
          ),
        
        // Empty State
        if (_criticalResults.isEmpty && _abnormalResults.isEmpty && _normalResults.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'No results entered yet. Please enter values above.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultSection({
    required String title,
    required List<Map<String, dynamic>> results,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...results.map((result) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result['parameter']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${result['value']} ${result['unit']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(Normal: ${result['normalRange']} ${result['unit']})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Test Report'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Patient: ${widget.patientName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.medical_services, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Test: ${widget.testCategory}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Test Date: ${_testDate ?? "Not specified"}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.description, color: Colors.purple),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'File: ${widget.fileName}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verify and enter values for each parameter. Results will be categorized automatically.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
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

            // Parameters Table
            const Text(
              'Test Parameters',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter values from the report for each parameter:',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Parameters List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _parameters.length,
              itemBuilder: (context, index) {
                return _buildParameterCard(_parameters[index], index);
              },
            ),

            // Results Summary
            _buildResultsSummary(),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveVerifiedReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
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
                          Icon(Icons.check_circle),
                          SizedBox(width: 10),
                          Text(
                            'Save Verified Report',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Info
            const Center(
              child: Text(
                'This will save the verified data to the patient\'s medical records',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}