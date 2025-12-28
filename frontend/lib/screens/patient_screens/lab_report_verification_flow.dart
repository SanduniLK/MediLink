// screens/patient_screens/lab_report_verification_flow.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/medical_record.dart';
import 'package:frontend/screens/patient_screens/enhanced_medical_dashboard.dart';
import 'package:frontend/services/medical_records_service.dart';
import 'package:intl/intl.dart';

class LabReportVerificationFlow extends StatefulWidget {
  final MedicalRecord record;
  final String patientId;
  final String? testReportCategory;
  final String? testDate;
   final List<dynamic>? extractedParameters; 

  const LabReportVerificationFlow({
    super.key,
    required this.record,
    required this.patientId,
    this.testReportCategory,
    this.testDate,
    this.extractedParameters, // ADD THIS
  });

  @override
  State<LabReportVerificationFlow> createState() => _LabReportVerificationFlowState();
}

class _LabReportVerificationFlowState extends State<LabReportVerificationFlow> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MedicalRecordsService _recordsService = MedicalRecordsService();
  
  final TextEditingController _dateController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  bool _showExtractedText = false;
  
  // Store parameters for current category
  List<Map<String, dynamic>> _categoryParameters = [];
  
  // For editing parameters
  List<TextEditingController> _parameterValueControllers = [];
  
  // Define test categories
  final List<String> _testCategories = TestCategoryParameters.defaultParameters.keys.toList();

  @override
  void initState() {
  super.initState();
  
  // Use provided category or auto-detect from text
  _selectedCategory = widget.testReportCategory;
  
  // Auto-extract date if not provided
  if (widget.testDate?.isEmpty ?? true) {
    final extractedDate = _extractTestDateFromText(widget.record.extractedText ?? '');
    if (extractedDate.isNotEmpty) {
      _dateController.text = extractedDate;
    } else {
      _dateController.text = widget.testDate ?? '';
    }
  } else {
    _dateController.text = widget.testDate!;
  }
  
  // Load default parameters for the category
  if (_selectedCategory != null) {
    _loadCategoryParameters();
  } else {
    // Try to auto-detect category from text
    final autoDetectedCategory = _autoDetectTestCategoryFromText(widget.record.extractedText ?? '');
    if (autoDetectedCategory != null) {
      _selectedCategory = autoDetectedCategory;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCategoryParameters();
      });
    }
  }
  
  // If we have extracted parameters, try to fill them
  if (widget.extractedParameters != null && widget.extractedParameters!.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillFromExtractedParameters(widget.extractedParameters!);
    });
  }
}
String? _autoDetectTestCategoryFromText(String text) {
  if (text.isEmpty) return null;
  
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

  
  return null;
}
String _extractTestDateFromText(String text) {
  try {
    final cleanText = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
    
    // Look for date patterns with various formats
    final datePatterns = [
      // Pattern for "DD/MM/YYYY" or "DD-MM-YYYY"
      RegExp(r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4}|\d{2})\b'),
      // Pattern for "Date: DD/MM/YYYY"
      RegExp(r'(?:date|report date|collection date|test date|d[:\s]*)\s*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4})', caseSensitive: false),
      // Pattern for "MM/DD/YYYY"
      RegExp(r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})\b'),
      // Pattern for "YYYY-MM-DD"
      RegExp(r'\b(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})\b'),
    ];
    
    for (var pattern in datePatterns) {
      final matches = pattern.allMatches(cleanText);
      for (var match in matches) {
        if (match.groupCount >= 3) {
          String? day, month, year;
          
          if (pattern == datePatterns[2] || pattern == datePatterns[3]) {
            // For patterns where year might be first
            if (match.group(1)!.length == 4) {
              // YYYY-MM-DD format
              year = match.group(1);
              month = match.group(2);
              day = match.group(3);
            } else {
              // MM/DD/YYYY format
              month = match.group(1);
              day = match.group(2);
              year = match.group(3);
            }
          } else {
            // DD/MM/YYYY format
            day = match.group(1);
            month = match.group(2);
            year = match.group(3);
          }
          
          // Format the date
          if (day != null && month != null && year != null) {
            // Ensure year has 4 digits
            if (year.length == 2) {
              year = '20$year';
            }
            
            // Ensure two digits for day and month
            if (day.length == 1) day = '0$day';
            if (month.length == 1) month = '0$month';
            
            return '$day/$month/$year';
          }
        }
      }
    }
    
    // If no specific pattern found, look for any date-like string
    final anyDatePattern = RegExp(
      r'\b(\d{1,2}[\-/\.]\d{1,2}[\-/\.]\d{2,4})\b|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* \d{1,2},? \d{4}\b',
      caseSensitive: false,
    );
    
    final match = anyDatePattern.firstMatch(cleanText);
    if (match != null && match.group(0) != null) {
      return match.group(0)!;
    }
    
    return '';
  } catch (e) {
    print('❌ Error extracting date: $e');
    return '';
  }
}
  void _loadCategoryParameters() {
    // Get default parameters for selected category
    _categoryParameters = TestCategoryParameters.defaultParameters[_selectedCategory!] ?? [];
    
    // Initialize value controllers with empty values
    _parameterValueControllers.clear();
    for (var param in _categoryParameters) {
      _parameterValueControllers.add(TextEditingController());
    }
    
    // Try to auto-fill values from extracted text
    _autoFillParameters();
  }

void _autoFillParameters() {
  final extractedText = widget.record.extractedText?.toLowerCase() ?? '';
  
  print('🔍 Starting auto-fill from extracted text...');
  
  // Clean and normalize the text
  String cleanedText = _cleanLabReportText(extractedText);
  
  // DEBUG: Print cleaned text snippet
  print('📄 Cleaned text (first 1000 chars): ${cleanedText.substring(0, min(1000, cleanedText.length))}');
  
  for (int i = 0; i < _categoryParameters.length; i++) {
    final param = _categoryParameters[i];
    final paramName = param['parameter'].toString();
    
    // Skip if already filled by user
    if (_parameterValueControllers[i].text.isEmpty) {
      String? extractedValue = _extractSpecificParameterValue(cleanedText, paramName);
      
      if (extractedValue != null) {
        _parameterValueControllers[i].text = extractedValue;
        print('✅ Auto-filled $paramName: $extractedValue');
      } else {
        print('❌ Could not auto-fill $paramName');
      }
    }
  }
  
  setState(() {});
}
String? _extractSpecificParameterValue(String text, String parameterName) {
  // Based on your actual lab report format
  final Map<String, List<RegExp>> extractionPatterns = {
    'Hemoglobin (Hb)': [
      // Look for pattern: "Haemoglobin 15 13-17 g/dL"
      RegExp(r'haemoglobin[^\d]*(\d+\.?\d*)[^\d]*(\d+\.?\d*)[-\s]*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'hemoglobin[^\d]*(\d+\.?\d*)[^\d]*(\d+\.?\d*)[-\s]*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'hb[^\d]*(\d+\.?\d*)\s*g/dl', caseSensitive: false),
    ],
    'White Blood Cells (WBC)': [
      // Look for pattern: "Total Leucocyte Count 5000 4000-10000 /cumm"
      RegExp(r'total leucocyte count[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
      RegExp(r'leucocyte[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
      RegExp(r'wbc[^\d]*(\d+)\s*/cumm', caseSensitive: false),
    ],
    'Platelets': [
      // Look for pattern: "Platelet Count 300000 150000 - 410000 /cumm"
      RegExp(r'platelet count[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
      RegExp(r'platelets[^\d]*(\d+)\s*/cumm', caseSensitive: false),
      RegExp(r'plt[^\d]*(\d+)', caseSensitive: false),
    ],
    'Red Blood Cells (RBC)': [
      // Look for pattern: "RBC Count 5.00 4.5-5.5 million/cumm"
      RegExp(r'rbc count[^\d]*(\d+\.?\d*)[^\d]*(\d+\.?\d*)[-\s]*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'rbc[^\d]*(\d+\.?\d*)\s*million', caseSensitive: false),
    ],
    'Hematocrit (HCT)': [
      RegExp(r'hematocrit[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
      RegExp(r'hct[^\d]*(\d+)\s*%', caseSensitive: false),
    ],
    'MCV': [
      RegExp(r'mcv[^\d]*(\d+\.?\d*)[^\d]*(\d+\.?\d*)[-\s]*(\d+\.?\d*)', caseSensitive: false),
    ],
    'MCH': [
      RegExp(r'mch[^\d]*(\d+\.?\d*)[^\d]*(\d+\.?\d*)[-\s]*(\d+\.?\d*)', caseSensitive: false),
    ],
    'MCHC': [
      RegExp(r'mchc[^\d]*(\d+\.?\d*)[^\d]*(\d+\.?\d*)[-\s]*(\d+\.?\d*)', caseSensitive: false),
    ],
    'Neutrophils': [
      RegExp(r'neutrophils[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
    ],
    'Lymphocytes': [
      RegExp(r'lymphocytes[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
    ],
    'Monocytes': [
      RegExp(r'monocytes[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
    ],
    'Eosinophils': [
      RegExp(r'eosinophils[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
    ],
    'Basophils': [
      RegExp(r'basophils[^\d]*(\d+)[^\d]*(\d+)[-\s]*(\d+)', caseSensitive: false),
    ],
  };
  
  final patterns = extractionPatterns[parameterName] ?? [];
  
  for (var pattern in patterns) {
    try {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        if (match.group(1) != null) {
          String value = match.group(1)!.trim();
          
          // Validate it's a reasonable value
          if (_isReasonableValue(parameterName, value)) {
            print('🎯 Found $parameterName: $value (using pattern: ${pattern.pattern.substring(0, 30)}...)');
            return value;
          }
        }
      }
    } catch (e) {
      print('Pattern error for $parameterName: $e');
    }
  }
  
  return null;
}

bool _isReasonableValue(String parameter, String value) {
  try {
    final doubleValue = double.tryParse(value);
    if (doubleValue == null) return false;
    
    // Define reasonable ranges based on units and common sense
    final Map<String, List<double>> reasonableRanges = {
      'Hemoglobin (Hb)': [5.0, 25.0],          // g/dL
      'White Blood Cells (WBC)': [1000, 50000], // /cmm
      'Platelets': [50000, 1000000],           // /cmm
      'Red Blood Cells (RBC)': [2.0, 8.0],     // million/cmm
      'Hematocrit (HCT)': [20.0, 70.0],        // %
      'MCV': [60.0, 120.0],                    // fL
      'MCH': [20.0, 40.0],                     // pg
      'MCHC': [25.0, 40.0],                    // g/dL
      'Neutrophils': [0.0, 100.0],             // %
      'Lymphocytes': [0.0, 100.0],             // %
      'Monocytes': [0.0, 100.0],               // %
      'Eosinophils': [0.0, 100.0],             // %
      'Basophils': [0.0, 100.0],               // %
    };
    
    final range = reasonableRanges[parameter];
    if (range != null) {
      final isValid = doubleValue >= range[0] && doubleValue <= range[1];
      if (!isValid) {
        print('⚠️ Value $value for $parameter is outside reasonable range ${range[0]}-${range[1]}');
      }
      return isValid;
    }
    
    return true;
  } catch (e) {
    return false;
  }
}
void _fillFromExtractedParameters(List<dynamic> extractedParameters) {
  if (_categoryParameters.isEmpty) return;
  
  for (int i = 0; i < _categoryParameters.length; i++) {
    final param = _categoryParameters[i];
    final paramName = param['parameter']?.toString() ?? '';
    
    // Try to find matching parameter in extracted data
    for (var extractedParam in extractedParameters) {
      if (extractedParam is Map) {
        final extractedParamName = extractedParam['parameter']?.toString() ?? '';
        final extractedValue = extractedParam['value']?.toString();
        
        // Check if parameter names match
        if (_doParametersMatch(paramName, extractedParamName) && 
            extractedValue != null && extractedValue.isNotEmpty) {
          // Set the value in controller
          if (i < _parameterValueControllers.length) {
            _parameterValueControllers[i].text = extractedValue;
            print('✅ Filled from extracted: $paramName = $extractedValue');
          }
          break;
        }
      }
    }
  }
  
  setState(() {});
}

bool _doParametersMatch(String param1, String param2) {
  // Simple matching - you can make this more sophisticated
  final clean1 = param1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final clean2 = param2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  
  return clean1.contains(clean2) || clean2.contains(clean1);
}
String _cleanLabReportText(String text) {
  // Remove garbage text and clean up OCR errors
  String cleaned = text;
  
  // Fix common OCR errors
  cleaned = cleaned.replaceAll('lion/cumm', 'million/cumm');
  cleaned = cleaned.replaceAll('fab', '');
  cleaned = cleaned.replaceAll('flabs', '');
  cleaned = cleaned.replaceAll('www', '');
  cleaned = cleaned.replaceAll('re', '');
  
  // Normalize spaces and newlines
  cleaned = cleaned.replaceAll('\n', ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  
  // Normalize units
  cleaned = cleaned.replaceAll('g/dl', 'g/dL');
  cleaned = cleaned.replaceAll('g%', 'g/dL');
  cleaned = cleaned.replaceAll('/cumm', '/cmm');
  
  return cleaned;
}


Map<String, String> _extractParameterValueAndRange(String text, String fullParamName) {
  final cleanText = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
  final keywords = _getParameterSearchKeywords(fullParamName);
  
  for (var keyword in keywords) {
    // Pattern for "Parameter: 12.3 (4.0-11.0)" or "Parameter 12.3 [4.0-11.0]"
    final pattern = RegExp(
      '$keyword[\\s:]*([\\d\\.]+)[\\s]*[\\(\\[]?([\\d\\.\\-]+)[\\)\\]]?',
      caseSensitive: false
    );
    
    final matches = pattern.allMatches(cleanText);
    for (var match in matches) {
      if (match.group(1) != null && match.group(2) != null) {
        final value = match.group(1)!;
        final range = match.group(2)!;
        
        // Validate value
        final doubleValue = double.tryParse(value);
        if (doubleValue != null && _isValidParameterValue(fullParamName, doubleValue)) {
          return {
            'value': value,
            'range': range,
          };
        }
      }
    }
    
    // Try pattern without range
    final simplePattern = RegExp(
      '$keyword[\\s:]*([\\d\\.]+)',
      caseSensitive: false
    );
    
    final simpleMatches = simplePattern.allMatches(cleanText);
    for (var match in simpleMatches) {
      if (match.group(1) != null) {
        final value = match.group(1)!;
        final doubleValue = double.tryParse(value);
        if (doubleValue != null && _isValidParameterValue(fullParamName, doubleValue)) {
          return {
            'value': value,
            'range': '', // No range found
          };
        }
      }
    }
  }
  
  return {'value': '', 'range': ''};
}

  String? _extractParameterValue(String text, String paramName, String fullParamName) {
  final cleanText = text.toLowerCase();
  print('🔍 Searching for: $fullParamName in text');
  
  // Based on your logs, the text has values but messy formatting
  // Let me create patterns based on what I see in your logs
  
  final Map<String, List<String>> valuePatterns = {
    'White Blood Cells (WBC)': [
      r'total leucocyte count.*?(\d+)', // Matches "total leucocyte count 10000"
      r'wbc.*?(\d+)',
      r'leucocyte.*?(\d+)',
    ],
    'Hemoglobin (Hb)': [
      r'haemoglobin.*?(\d+\.?\d*)', // Matches "haemoglobin 17"
      r'hemoglobin.*?(\d+\.?\d*)',
      r'hb.*?(\d+\.?\d*)',
    ],
    'Platelets': [
      r'platelet count.*?(\d+)', // Matches "platelet count 410000"
      r'platelets.*?(\d+)',
      r'plt.*?(\d+)',
    ],
    'Red Blood Cells (RBC)': [
      r'rbc.*?(\d+\.?\d*)', // Matches "rbc 5.5" (lion/cumm is actually "million/cumm")
      r'red blood.*?(\d+\.?\d*)',
    ],
    'Hematocrit (HCT)': [
      r'hct.*?(\d+)', // Matches "hct 46"
      r'hematocrit.*?(\d+)',
    ],
    'MCV': [
      r'mcv.*?(\d+\.?\d*)', // Matches "mcv 101"
    ],
    'MCH': [
      r'mch.*?(\d+\.?\d*)', // Matches "mch 32"
    ],
    'MCHC': [
      r'mchc.*?(\d+\.?\d*)', // Matches "mchc 34.5"
    ],
    'Neutrophils': [
      r'neutrophils.*?(\d+)', // Matches "neutrophils 7000" from your logs
      r'neutrophil.*?(\d+)',
      r'neut.*?(\d+)',
    ],
    'Lymphocytes': [
      r'lymphocytes.*?(\d+)', // Matches "lymphocytes 3000"
      r'lymphocyte.*?(\d+)',
      r'lymph.*?(\d+)',
    ],
    'Monocytes': [
      r'monocytes.*?(\d+)', // Matches "monocytes 500"
      r'monocyte.*?(\d+)',
      r'mono.*?(\d+)',
    ],
    'Eosinophils': [
      r'eosinophils.*?(\d+)', // Matches "eosinophils 1000"
      r'eosinophil.*?(\d+)',
      r'eos.*?(\d+)',
    ],
    'Basophils': [
      r'basophils.*?(\d+)',
      r'basophil.*?(\d+)',
      r'baso.*?(\d+)',
    ],
  };
  
  final patterns = valuePatterns[fullParamName] ?? [r'$fullParamName.*?(\d+\.?\d*)'];
  
  for (var pattern in patterns) {
    try {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(cleanText);
      
      if (match != null && match.group(1) != null) {
        final value = match.group(1)!;
        print('✅ Pattern "$pattern" matched for $fullParamName: $value');
        return value;
      }
    } catch (e) {
      print('❌ Pattern error for $fullParamName: $e');
    }
  }
  
  print('❌ No pattern matched for $fullParamName');
  return null;
}
List<String> _getParameterSearchKeywords(String fullParamName) {
  // More comprehensive keyword patterns
  final Map<String, List<String>> keywords = {
    'White Blood Cells (WBC)': [
      'wbc', 
      'white blood cells', 
      'total leucocyte count', 
      'tlc', 
      'white blood cell count',
      'wbc count',
      'leucocytes',
      'total wbc'
    ],
    'Hemoglobin (Hb)': [
      'haemoglobin', 
      'hemoglobin', 
      'hb', 
      'hgb',
      'hb\\(g/dl\\)',
      'haemoglobin \\(g/dl\\)',
      'hemoglobin level'
    ],
    'Platelets': [
      'platelet', 
      'plt', 
      'platelet count', 
      'platelets count',
      'platelet count \\(plt\\)',
      'platelets \\(plt\\)'
    ],
    'Red Blood Cells (RBC)': [
      'rbc', 
      'red blood cells', 
      'erythrocyte count', 
      'rbc count',
      'red blood cell count',
      'rbc \\(million/cmm\\)'
    ],
    'Hematocrit (HCT)': [
      'hematocrit', 
      'hct', 
      'packed cell volume', 
      'pcv',
      'hematocrit \\(%\\)',
      'hct \\(%\\)'
    ],
    'MCV': ['mcv', 'mean corpuscular volume', 'mcv \\(fl\\)'],
    'MCH': ['mch', 'mean corpuscular hemoglobin', 'mch \\(pg\\)'],
    'MCHC': ['mchc', 'mean corpuscular hemoglobin concentration', 'mchc \\(g/dl\\)'],
    'Neutrophils': ['neutrophil', 'neut', 'polymorphs', 'neutrophils', 'neutrophils \\(%\\)'],
    'Lymphocytes': ['lymphocyte', 'lymph', 'lymphocytes', 'lymphocytes \\(%\\)'],
    'Monocytes': ['monocyte', 'mono', 'monocytes', 'monocytes \\(%\\)'],
    'Eosinophils': ['eosinophil', 'eos', 'eosinophils', 'eosinophils \\(%\\)'],
    'Basophils': ['basophil', 'baso', 'basophils', 'basophils \\(%\\)'],
  };
  
  return keywords[fullParamName] ?? [fullParamName.toLowerCase()];
}

bool _isValidParameterValue(String parameter, double value) {
  // Filter out unreasonable values
  switch (parameter) {
    case 'White Blood Cells (WBC)':
      return value > 1 && value < 100; // WBC usually 4-11
    case 'Hemoglobin (Hb)':
      return value > 5 && value < 25; // Hb usually 13-17
    case 'Platelets':
      return value > 50 && value < 1000; // Platelets in thousands
    case 'Red Blood Cells (RBC)':
      return value > 2 && value < 8; // RBC in millions
    case 'Hematocrit (HCT)':
      return value > 20 && value < 70; // HCT in percentage
    case 'MCV':
      return value > 60 && value < 120; // MCV in fL
    case 'MCH':
      return value > 20 && value < 40; // MCH in pg
    case 'MCHC':
      return value > 25 && value < 40; // MCHC in g/dL
    case 'Neutrophils':
    case 'Lymphocytes':
    case 'Monocytes':
    case 'Eosinophils':
    case 'Basophils':
      return value >= 0 && value <= 100; // Differential counts in percentage
    case 'TSH':
      return value > 0 && value < 20; // TSH in μIU/mL
    case 'T3':
      return value > 50 && value < 300; // T3 in ng/dL
    case 'T4':
      return value > 2 && value < 20; // T4 in μg/dL
    case 'Glucose':
      return value > 20 && value < 500; // Glucose in mg/dL
    case 'Creatinine':
      return value > 0.1 && value < 10; // Creatinine in mg/dL
    case 'Urea':
      return value > 5 && value < 100; // Urea in mg/dL
    case 'Cholesterol':
    case 'LDL Cholesterol':
    case 'HDL Cholesterol':
    case 'Triglycerides':
      return value > 10 && value < 500; // Lipids in mg/dL
    default:
      return value > 0;
  }
}

  String _getParameterKeywords(String fullParamName) {
    // Return search keywords for each parameter
    final Map<String, List<String>> keywords = {
      'White Blood Cells (WBC)': ['wbc', 'total leucocyte count', 'tlc', 'white blood cells'],
      'Hemoglobin (Hb)': ['haemoglobin', 'hemoglobin', 'hb', 'hgb'],
      'Platelets': ['platelet', 'plt', 'platelet count'],
      'Red Blood Cells (RBC)': ['rbc', 'red blood cells', 'erythrocyte count'],
      'Hematocrit (HCT)': ['hematocrit', 'hct', 'packed cell volume', 'pcv'],
      'MCV': ['mcv', 'mean corpuscular volume'],
      'MCH': ['mch', 'mean corpuscular hemoglobin'],
      'MCHC': ['mchc', 'mean corpuscular hemoglobin concentration'],
      'Neutrophils': ['neutrophil', 'neut', 'polymorphs'],
      'Lymphocytes': ['lymphocyte', 'lymph'],
      'Monocytes': ['monocyte', 'mono'],
      'Eosinophils': ['eosinophil', 'eos'],
      'Basophils': ['basophil', 'baso'],
      'TSH': ['tsh', 'thyroid stimulating hormone'],
      'T3': ['t3', 'triiodothyronine'],
      'T4': ['t4', 'thyroxine'],
      'Glucose': ['glucose', 'blood sugar', 'sugar'],
      'Creatinine': ['creatinine', 'serum creatinine'],
      'Urea': ['urea', 'blood urea'],
    };
    
    return keywords[fullParamName]?.join('|') ?? fullParamName.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final extractedText = widget.record.extractedText ?? 'No text extracted';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm Lab Report'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File Info and Category Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.file_present, color: Color(0xFF18A3B6)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.record.fileName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    // Test Category Selection
                    Text(
                      'Test Category*',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select test category',
                      ),
                      items: _testCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _loadCategoryParameters();
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Test Date
                    TextField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Test Date (DD/MM/YYYY)*',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                        hintText: 'e.g., 24/06/2023',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // ========== CATEGORY PARAMETERS SECTION ==========
            if (_selectedCategory != null && _categoryParameters.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 ${_selectedCategory} Parameters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      Text(
                        'Values have been auto-filled from the document. Please review and edit if needed:',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Parameters Table
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Parameter',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Your Value',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Unit',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Normal Range',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Parameter Rows
                       ...List.generate(_categoryParameters.length, (index) {
  // Make sure index is valid
  if (index < 0 || index >= _categoryParameters.length) {
    return SizedBox.shrink(); // Return empty widget if index is invalid
  }
  
  final param = _categoryParameters[index];
  
  // Make sure we have a controller for this index
  if (index >= _parameterValueControllers.length) {
    return SizedBox.shrink(); // Return empty widget if controller missing
  }
  
  final hasValue = _parameterValueControllers[index].text.isNotEmpty;
  
  // RETURN A WIDGET - This is what was missing
  return Container(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(
      color: index % 2 == 0 ? Colors.white : Colors.grey[50],
      border: Border(
        bottom: BorderSide(
          color: index < _categoryParameters.length - 1 
              ? Colors.grey[200]! 
              : Colors.transparent
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                param['parameter']?.toString() ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: hasValue ? Colors.black87 : Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Normal: ${param['normalRange']?.toString() ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Value',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              TextField(
                controller: _parameterValueControllers[index],
                decoration: InputDecoration(
                  hintText: 'Enter value',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  filled: hasValue,
                  fillColor: hasValue ? Colors.green[50] : null,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: hasValue ? Colors.green[800] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                param['unit']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}).toList()
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Auto-fill Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _autoFillParameters,
                            icon: Icon(Icons.autorenew, size: 16),
                            label: Text('Re-scan for Values'),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '${_parameterValueControllers.where((c) => c.text.isNotEmpty).length}/${_categoryParameters.length} filled',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 20),
            
            // ========== EXTRACTED TEXT SECTION ==========
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📝 Full Extracted Text',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showExtractedText ? Icons.visibility_off : Icons.visibility,
                            color: Color(0xFF18A3B6),
                          ),
                          onPressed: () {
                            setState(() {
                              _showExtractedText = !_showExtractedText;
                            });
                          },
                        ),
                      ],
                    ),
                    
                    if (_showExtractedText)
                      Column(
                        children: [
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            constraints: BoxConstraints(maxHeight: 200),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                extractedText,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Text extracted for auto-filling values. Tap to view.',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // ========== ACTION BUTTONS ==========
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveLabReport,
                    icon: Icon(Icons.check, size: 20),
                    label: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : Text('Confirm & Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF18A3B6),
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

 Future<void> _saveLabReport() async {
  // ========== HELPER FUNCTIONS ==========
  
  // Helper: Extract unit from text
  String _extractUnitFromText(String text, String parameter) {
    final lowerText = text.toLowerCase();
    final paramPatterns = {
      'White Blood Cells (WBC)': [
        RegExp(r'white.*?cell.*?count.*?(\d+\.?\d*)\s*(10\^9/l|10\^9|l)', caseSensitive: false),
        RegExp(r'wbc.*?(\d+\.?\d*)\s*(10\^9/l|10\^9)', caseSensitive: false),
      ],
      'Red Blood Cells (RBC)': [
        RegExp(r'red.*?blood.*?cells.*?(\d+\.?\d*)\s*(10\^12/l|10\^12)', caseSensitive: false),
        RegExp(r'rbc.*?(\d+\.?\d*)\s*(10\^12/l|10\^12)', caseSensitive: false),
      ],
      'Platelets': [
        RegExp(r'platelet.*?count.*?(\d+\.?\d*)\s*(10\^9/l|10\^9)', caseSensitive: false),
        RegExp(r'platelets.*?(\d+\.?\d*)\s*(10\^9/l|10\^9)', caseSensitive: false),
      ],
    };
    
    final patterns = paramPatterns[parameter];
    if (patterns != null) {
      for (var pattern in patterns) {
        final match = pattern.firstMatch(lowerText);
        if (match != null && match.group(2) != null) {
          return match.group(2)!;
        }
      }
    }
    
    return '';
  }
  
  // Helper: Convert value based on unit
  double _convertValueBasedOnUnit(String parameter, String value, String unitFromText) {
    try {
      double numValue = double.tryParse(value) ?? 0;
      
      // Convert based on unit patterns
      if (parameter == 'White Blood Cells (WBC)' || 
          parameter == 'Platelets' || 
          parameter == 'Red Blood Cells (RBC)') {
        
        // Handle scientific notation and unit conversions
        if (unitFromText.toLowerCase().contains('10^9/l') || 
            unitFromText.toLowerCase().contains('10^9')) {
          // Convert from 10^9/L to /cmm (multiply by 1000)
          return numValue * 1000;
        } else if (unitFromText.toLowerCase().contains('10^12/l') ||
                  unitFromText.toLowerCase().contains('10^12')) {
          // Convert from 10^12/L to million/cmm (same for RBC)
          return numValue;
        }
      }
      
      return numValue;
    } catch (e) {
      return double.tryParse(value) ?? 0;
    }
  }
  
  // Helper: Format date for sorting
  String _formatDateForSorting(String dateStr) {
    try {
      // Handle different date formats
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          String day, month, year;
          
          // Check if it's DD/MM/YY or DD/MM/YYYY
          if (parts[0].length == 4) {
            // YYYY/MM/DD
            year = parts[0];
            month = parts[1].padLeft(2, '0');
            day = parts[2].padLeft(2, '0');
          } else {
            // Assume DD/MM/YY or DD/MM/YYYY
            day = parts[0].padLeft(2, '0');
            month = parts[1].padLeft(2, '0');
            year = parts[2];
            
            // Fix 2-digit year
            if (year.length == 2) {
              // Convert YY to YYYY
              int yearNum = int.tryParse(year) ?? 0;
              if (yearNum >= 0 && yearNum <= 30) {
                year = '20$year';
              } else {
                year = '19$year';
              }
            }
          }
          
          return '$year-$month-$day';
        }
      }
      
      return dateStr;
    } catch (e) {
      print('❌ Error formatting date $dateStr: $e');
      return dateStr;
    }
  }
  
  // ========== MAIN SAVE LOGIC ==========
  
  if (_selectedCategory == null || _selectedCategory!.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please select a test category'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  if (_dateController.text.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please enter the test date'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    // Collect verified parameters with value validation
    final verifiedParameters = <Map<String, dynamic>>[];
    final abnormalResults = <Map<String, dynamic>>[];
    final normalResults = <Map<String, dynamic>>[];
    
    int highCount = 0;
    int lowCount = 0;
    int normalCount = 0;
    
    for (int i = 0; i < _categoryParameters.length; i++) {
      final param = _categoryParameters[i];
      final value = _parameterValueControllers[i].text.trim();
      final parameterName = param['parameter']?.toString() ?? 'Unknown';
      
      if (value.isNotEmpty) {
        // Get the unit from the text (not from default)
        final unitFromText = _extractUnitFromText(widget.record.extractedText ?? '', parameterName);
        
        // Convert value based on unit
        final convertedValue = _convertValueBasedOnUnit(parameterName, value, unitFromText);
        
        final doubleValue = convertedValue;
        final unit = param['unit']?.toString() ?? '';
        final normalRange = param['normalRange']?.toString() ?? '';
        
        // Fix WBC unit display - show in thousands if needed
        String displayValue = value;
        String displayUnit = unit;
        
        if (parameterName == 'White Blood Cells (WBC)' && doubleValue >= 1000) {
          displayValue = (doubleValue / 1000).toStringAsFixed(1);
          displayUnit = '10^3/cmm';
        }
        
        // Determine result status
        String status = 'normal';
        String level = 'normal';
        
        if (doubleValue != null && normalRange.isNotEmpty) {
          final rangeResult = _compareWithNormalRange(doubleValue, normalRange, parameterName);
          status = rangeResult['status'] ?? 'normal';
          level = rangeResult['level'] ?? 'normal';
          
          // Count abnormal results
          if (status == 'high') {
            highCount++;
            level = 'high';
          } else if (status == 'low') {
            lowCount++;
            level = 'low';
          } else {
            normalCount++;
            level = 'normal';
          }
        }
        
        final parameterData = {
          'parameter': parameterName,
          'value': displayValue,
          'numericValue': doubleValue,
          'unit': displayUnit,
          'normalRange': normalRange,
          'status': status,
          'level': level,
          'isVerified': true,
          'isAbnormal': status != 'normal',
          'note': _generateParameterNote(parameterName, doubleValue, status),
        };
        
        verifiedParameters.add(parameterData);
        
        // Organize by abnormal/normal
        if (status != 'normal') {
          abnormalResults.add(parameterData);
        } else {
          normalResults.add(parameterData);
        }
      }
    }

    if (verifiedParameters.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter at least one parameter value'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Format date for sorting
    final formattedDateForSorting = _formatDateForSorting(_dateController.text);

    // Update the medical record
    await _firestore.collection('medical_records').doc(widget.record.id).update({
      'textExtractionStatus': 'verified',
      'testReportCategory': _selectedCategory,
      'testDate': _dateController.text,
      'verifiedAt': Timestamp.now(),
      'verifiedParameters': verifiedParameters,
      'verificationSummary': {
        'totalParameters': verifiedParameters.length,
        'abnormalCount': abnormalResults.length,
        'normalCount': normalResults.length,
        'highCount': highCount,
        'lowCount': lowCount,
        'hasAbnormalResults': abnormalResults.isNotEmpty,
      },
    });

    // Save to patient_notes for analysis
    final noteId = _firestore.collection('patient_notes').doc().id;
    
    // Generate overall analysis
    final overallAnalysis = _generateOverallAnalysis(
      verifiedParameters,
      abnormalResults,
      _selectedCategory!,
    );
    
    final noteData = {
      'id': noteId,
      'patientId': widget.patientId,
      'medicalRecordId': widget.record.id,
      'fileName': widget.record.fileName,
      'category': 'labResults',
      'testReportCategory': _selectedCategory,
      'testType': _selectedCategory!.split('(').first.trim(),
      'testDate': _dateController.text,
      'testDateFormatted': formattedDateForSorting, // Use properly formatted date
      'extractedText': widget.record.extractedText,
      'verifiedParameters': verifiedParameters,
      'analysisDate': Timestamp.now(),
      'verifiedAt': Timestamp.now(),
      'noteType': 'verified_report_analysis',
      'isProcessed': true,
      'isVerified': true,
      
      // Organized results
      'results': verifiedParameters,
      'abnormalResults': abnormalResults,
      'normalResults': normalResults,
      'resultsByLevel': {
        'high': verifiedParameters.where((p) => p['status'] == 'high').toList(),
        'normal': verifiedParameters.where((p) => p['status'] == 'normal').toList(),
        'low': verifiedParameters.where((p) => p['status'] == 'low').toList(),
      },
      
      // Statistics
      'totalResults': verifiedParameters.length,
      'abnormalCount': abnormalResults.length,
      'normalCount': normalResults.length,
      'highCount': highCount,
      'lowCount': lowCount,
      'hasAbnormalResults': abnormalResults.isNotEmpty,
      
      // Analysis
      'overallStatus': abnormalResults.isEmpty ? 'Normal' : 'Abnormal',
      'analysisSummary': overallAnalysis['summary'],
      'recommendations': overallAnalysis['recommendations'],
      'criticalFindings': overallAnalysis['criticalFindings'],
      
      // Additional metadata
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'verifiedBy': 'User',
      'verificationMethod': 'manual_entry',
    };

    await _firestore.collection('patient_notes').doc(noteId).set(noteData);

    // Show success message with abnormal count
    final message = abnormalResults.isEmpty 
        ? '✅ All ${verifiedParameters.length} parameters are within normal range!'
        : '⚠️ ${abnormalResults.length} abnormal findings detected out of ${verifiedParameters.length} parameters.';
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: abnormalResults.isEmpty ? Colors.green : Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );

    // Navigate back to medical records
    if (!mounted) return;
    Navigator.pop(context);
    
    // Show detailed results dialog if abnormalities found
    if (abnormalResults.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAbnormalResultsDialog(abnormalResults);
        }
      });
    }

    // Navigate to dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedMedicalDashboard(),
          ),
        );
      }
    });

  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
String _formatDate(String dateStr) {
  try {
    // Handle different date formats
    if (dateStr.contains('/')) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        String day, month, year;
        
        // Check if it's DD/MM/YY or DD/MM/YYYY
        if (parts[0].length == 4) {
          // YYYY/MM/DD
          year = parts[0];
          month = parts[1].padLeft(2, '0');
          day = parts[2].padLeft(2, '0');
        } else {
          // Assume DD/MM/YY or DD/MM/YYYY
          day = parts[0].padLeft(2, '0');
          month = parts[1].padLeft(2, '0');
          year = parts[2];
          
          // Fix 2-digit year
          if (year.length == 2) {
            // Convert YY to YYYY
            int yearNum = int.tryParse(year) ?? 0;
            if (yearNum >= 0 && yearNum <= 30) {
              year = '20$year';
            } else {
              year = '19$year';
            }
          }
        }
        
        return '$year-$month-$day';
      }
    }
    
    return dateStr;
  } catch (e) {
    print('❌ Error formatting date $dateStr: $e');
    return dateStr;
  }
}
Map<String, String> _compareWithNormalRange(double value, String normalRange, String parameterName) {
  try {
    // Clean the normal range string
    normalRange = normalRange.trim().replaceAll(' ', '');
    
    // For WBC, Platelets, RBC - convert ranges if needed
    double min = 0;
    double max = 0;
    
    if (normalRange.contains('-')) {
      final rangeParts = normalRange.split('-');
      if (rangeParts.length == 2) {
        final minStr = rangeParts[0].trim();
        final maxStr = rangeParts[1].trim();
        
        min = double.tryParse(minStr) ?? 0;
        max = double.tryParse(maxStr) ?? 0;
        
        // Adjust for WBC if value is in 10^9/L but range is in /cmm
        if (parameterName == 'White Blood Cells (WBC)' && value < 1000 && max > 1000) {
          // Value is in 10^9/L, convert to /cmm for comparison
          value = value * 1000;
        }
        
        if (value < min) {
          return {'status': 'low', 'level': 'low'};
        } else if (value > max) {
          return {'status': 'high', 'level': 'high'};
        } else {
          return {'status': 'normal', 'level': 'normal'};
        }
      }
    }
    
    return {'status': 'normal', 'level': 'normal'};
  } catch (e) {
    print('❌ Error comparing value $value with range $normalRange: $e');
    return {'status': 'error', 'level': 'normal'};
  }
}

String _generateParameterNote(String parameter, double? value, String status) {
  if (value == null) return 'Value not available';
  
  final Map<String, Map<String, String>> notes = {
    'Hemoglobin (Hb)': {
      'low': 'Low hemoglobin may indicate anemia. Consider iron studies.',
      'high': 'High hemoglobin may indicate polycythemia or dehydration.',
      'normal': 'Normal hemoglobin level.'
    },
    'White Blood Cells (WBC)': {
      'low': 'Low WBC may indicate bone marrow issue or infection risk.',
      'high': 'High WBC may indicate infection, inflammation, or leukemia.',
      'normal': 'Normal white blood cell count.'
    },
    'Platelets': {
      'low': 'Low platelets increase bleeding risk.',
      'high': 'High platelets may increase clotting risk.',
      'normal': 'Normal platelet count.'
    },
    'Glucose': {
      'low': 'Low glucose may indicate hypoglycemia.',
      'high': 'High glucose may indicate diabetes or prediabetes.',
      'normal': 'Normal glucose level.'
    },
    'Creatinine': {
      'low': 'Low creatinine may indicate low muscle mass.',
      'high': 'High creatinine may indicate kidney dysfunction.',
      'normal': 'Normal creatinine level.'
    },
    'TSH': {
      'low': 'Low TSH may indicate hyperthyroidism.',
      'high': 'High TSH may indicate hypothyroidism.',
      'normal': 'Normal thyroid function.'
    },
    'LDL Cholesterol': {
      'low': 'Optimal LDL cholesterol level.',
      'high': 'High LDL increases cardiovascular risk.',
      'normal': 'Normal LDL cholesterol level.'
    },
  };
  
  final parameterNotes = notes[parameter];
  if (parameterNotes != null && parameterNotes.containsKey(status)) {
    return parameterNotes[status]!;
  }
  
  return status == 'low' ? 'Below normal range' :
         status == 'high' ? 'Above normal range' :
         'Within normal range';
}

Map<String, dynamic> _generateOverallAnalysis(
  List<Map<String, dynamic>> parameters,
  List<Map<String, dynamic>> abnormalResults,
  String testCategory,
) {
  final summary = StringBuffer();
  final recommendations = <String>[];
  final criticalFindings = <String>[];
  
  // Add category-specific analysis
  summary.writeln('$testCategory Report Analysis');
  summary.writeln('Total parameters: ${parameters.length}');
  summary.writeln('Abnormal findings: ${abnormalResults.length}');
  
  if (abnormalResults.isEmpty) {
    summary.writeln('\nAll results are within normal ranges.');
    recommendations.add('Continue routine monitoring as recommended.');
  } else {
    summary.writeln('\nAbnormal Results:');
    for (var result in abnormalResults) {
      final param = result['parameter'];
      final value = result['value'];
      final unit = result['unit'];
      final normalRange = result['normalRange'];
      final status = result['status'];
      
      summary.writeln('- $param: $value $unit ($status, Normal: $normalRange $unit)');
      
      // Identify critical findings
      if (_isCriticalFinding(param, value, status)) {
        criticalFindings.add('$param is critically $status ($value $unit)');
      }
    }
    
    // Generate recommendations based on abnormal findings
    if (abnormalResults.any((r) => r['parameter'].toString().contains('Glucose'))) {
      recommendations.add('Consider follow-up glucose testing and HbA1c.');
    }
    if (abnormalResults.any((r) => r['parameter'].toString().contains('Creatinine'))) {
      recommendations.add('Consider renal function assessment.');
    }
    if (abnormalResults.any((r) => r['parameter'].toString().contains('TSH'))) {
      recommendations.add('Consider thyroid panel and endocrinology consult.');
    }
    if (abnormalResults.any((r) => r['parameter'].toString().contains('Cholesterol'))) {
      recommendations.add('Consider lipid management and dietary counseling.');
    }
    
    recommendations.add('Follow up with healthcare provider for abnormal results.');
  }
  
  return {
    'summary': summary.toString(),
    'recommendations': recommendations,
    'criticalFindings': criticalFindings,
  };
}

bool _isCriticalFinding(String parameter, dynamic value, String status) {
  // Define critical thresholds for different parameters
  final Map<String, Map<String, double>> criticalThresholds = {
    'Hemoglobin (Hb)': {'low': 7.0, 'high': 20.0},
    'White Blood Cells (WBC)': {'low': 1.0, 'high': 30.0},
    'Platelets': {'low': 50000, 'high': 1000000},
    'Glucose': {'low': 54, 'high': 400},
    'Creatinine': {'high': 4.0},
    'Potassium': {'low': 2.5, 'high': 6.5},
  };
  
  final thresholds = criticalThresholds[parameter];
  if (thresholds != null && value is num) {
    if (status == 'low' && thresholds.containsKey('low') && value < thresholds['low']!) {
      return true;
    }
    if (status == 'high' && thresholds.containsKey('high') && value > thresholds['high']!) {
      return true;
    }
  }
  
  return false;
}



void _showAbnormalResultsDialog(List<Map<String, dynamic>> abnormalResults) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('⚠️ Abnormal Results Found'),
      content: Container(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: abnormalResults.length,
          itemBuilder: (context, index) {
            final result = abnormalResults[index];
            final isHigh = result['status'] == 'high';
            
            return ListTile(
              leading: Icon(
                isHigh ? Icons.arrow_upward : Icons.arrow_downward,
                color: isHigh ? Colors.red : Colors.orange,
              ),
              title: Text(result['parameter']),
              subtitle: Text('${result['value']} ${result['unit']} (Normal: ${result['normalRange']})'),
              tileColor: (isHigh ? Colors.red[50] : Colors.orange[50]),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}

  @override
  void dispose() {
    _dateController.dispose();
    for (var controller in _parameterValueControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}