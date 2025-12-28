// lib/services/google_vision_service.dart - SIMPLIFIED AND FIXED
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

// Define TestPattern class outside
class _TestPattern {
  final RegExp regex;
  final String test;
  final String unit;
  
  _TestPattern(this.regex, this.test, this.unit);
}

class GoogleVisionService {
  static const String _apiKey = 'AIzaSyDJ7vNn-OmvNXYPh8o294vL9Io2ITFPYuE';
  
  // Extract text from both PDF and images
  static Future<Map<String, dynamic>> extractMedicalText(File file) async {
    try {
      // Check file type
      final String fileExtension = file.path.split('.').last.toLowerCase();
      
      if (fileExtension == 'pdf') {
        // For PDFs, use a simpler approach
        return await _extractTextFromPdfSimple(file);
      } else {
        // Handle image files (PNG, JPG, JPEG)
        return await _extractTextFromImage(file);
      }
    } catch (e) {
      _debugPrint('❌ Error in extractMedicalText: $e');
      return {
        'success': false,
        'fullText': '',
        'medicalInfo': {},
        'error': 'Failed to process file: $e',
      };
    }
  }
  
  // Extract text from image files
  static Future<Map<String, dynamic>> _extractTextFromImage(File imageFile) async {
    try {
      // Convert image to base64
      List<int> fileBytes = await imageFile.readAsBytes();
      String base64File = base64Encode(fileBytes);
      
      // Prepare request for Google Vision API
      Map<String, dynamic> request = {
        'requests': [
          {
            'image': {'content': base64File},
            'features': [
              {'type': 'TEXT_DETECTION', 'maxResults': 10}
            ],
            'imageContext': {
              'languageHints': ['en']
            }
          }
        ]
      };
      
      _debugPrint('📤 Sending request to Google Vision API...');
      
      // Call Google Vision API
      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);
        
        // Extract full text with proper null safety
        String fullText = '';
        if (result['responses'] != null && 
            result['responses'] is List &&
            (result['responses'] as List).isNotEmpty) {
          final firstResponse = (result['responses'] as List)[0];
          if (firstResponse is Map && firstResponse['fullTextAnnotation'] is Map) {
            final annotation = firstResponse['fullTextAnnotation'] as Map;
            fullText = (annotation['text'] as String?) ?? '';
          }
        }
        
        _debugPrint('✅ Text extraction successful. Text length: ${fullText.length}');
        
        // Extract medical information
        Map<String, dynamic> medicalInfo = _extractMedicalInfo(fullText);
        
        return {
          'success': true,
          'fullText': fullText,
          'medicalInfo': medicalInfo,
          'textLength': fullText.length,
          'fileType': 'image',
        };
      } else {
        _debugPrint('❌ Google Vision API Error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'fullText': '',
          'medicalInfo': {},
          'error': 'API Error ${response.statusCode}',
          'responseBody': response.body,
        };
      }
    } catch (e) {
      _debugPrint('❌ Error in _extractTextFromImage: $e');
      return {
        'success': false,
        'fullText': '',
        'medicalInfo': {},
        'error': 'Image extraction failed: $e',
      };
    }
  }
  
  // Simple PDF extraction
  static Future<Map<String, dynamic>> _extractTextFromPdfSimple(File pdfFile) async {
    try {
      _debugPrint('📄 Processing PDF file (simple method)...');
      
      return {
        'success': true,
        'fullText': '[PDF file uploaded - PDF text extraction requires additional setup]\n\n'
                   'For PDF text extraction, consider:\n'
                   '1. Convert PDF to images first, then use Google Vision\n'
                   '2. Use a PDF text extraction library\n'
                   '3. Upload as image format for immediate text extraction',
        'medicalInfo': {
          'medications': <String>[],
          'labResults': <Map<String, dynamic>>[],
          'patientInfo': <String, dynamic>{},
          'dates': <String>[],
        },
        'textLength': 0,
        'fileType': 'pdf',
        'note': 'PDF support limited. Please upload as image for better text extraction.',
      };
    } catch (e) {
      _debugPrint('❌ Error in _extractTextFromPdfSimple: $e');
      return {
        'success': false,
        'fullText': '',
        'medicalInfo': {},
        'error': 'PDF processing failed',
      };
    }
  }
  // Add this method to GoogleVisionService class
static List<Map<String, dynamic>> extractLabParameters(String text) {
  final List<Map<String, dynamic>> parameters = [];
  
  if (text.isEmpty) return parameters;
  
  final lowerText = text.toLowerCase();
  
  // Define patterns for common lab tests
  final patterns = [
    // Hemoglobin
    {
      'regex': RegExp(r'(?:haemoglobin|hemoglobin|hb|hgb)\s*[:\-]?\s*(\d+\.?\d*)\s*(?:g/dl|g/dL|g%)', caseSensitive: false),
      'parameter': 'Hemoglobin (Hb)',
      'unit': 'g/dL',
      'normalRange': '13-17'
    },
    // WBC
    {
      'regex': RegExp(r'(?:wbc|white blood cells?)\s*[:\-]?\s*(\d+\.?\d*)\s*(?:/cmm|/cumm|x10\^9/l)', caseSensitive: false),
      'parameter': 'White Blood Cells (WBC)',
      'unit': '/cmm',
      'normalRange': '4000-11000'
    },
    // Platelets
    {
      'regex': RegExp(r'(?:platelet|plt)\s*[:\-]?\s*(\d+\.?\d*)\s*(?:/cmm|/cumm|x10\^9/l)', caseSensitive: false),
      'parameter': 'Platelets',
      'unit': '/cmm',
      'normalRange': '150000-450000'
    },
    // RBC
    {
      'regex': RegExp(r'(?:rbc|red blood cells?)\s*[:\-]?\s*(\d+\.?\d*)\s*(?:million/cmm|10\^6/μl)', caseSensitive: false),
      'parameter': 'Red Blood Cells (RBC)',
      'unit': 'million/cmm',
      'normalRange': '4.5-5.9'
    },
    // Glucose
    {
      'regex': RegExp(r'(?:glucose|blood sugar)\s*[:\-]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)', caseSensitive: false),
      'parameter': 'Glucose',
      'unit': 'mg/dL',
      'normalRange': '70-110'
    },
    // Creatinine
    {
      'regex': RegExp(r'creatinine\s*[:\-]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)', caseSensitive: false),
      'parameter': 'Creatinine',
      'unit': 'mg/dL',
      'normalRange': '0.6-1.2'
    },
    // Cholesterol
    {
      'regex': RegExp(r'total cholesterol\s*[:\-]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)', caseSensitive: false),
      'parameter': 'Total Cholesterol',
      'unit': 'mg/dL',
      'normalRange': '<200'
    },
    // LDL
    {
      'regex': RegExp(r'ldl\s*[:\-]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)', caseSensitive: false),
      'parameter': 'LDL Cholesterol',
      'unit': 'mg/dL',
      'normalRange': '<100'
    },
    // HDL
    {
      'regex': RegExp(r'hdl\s*[:\-]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)', caseSensitive: false),
      'parameter': 'HDL Cholesterol',
      'unit': 'mg/dL',
      'normalRange': '>40'
    },
    // TSH
    {
      'regex': RegExp(r'tsh\s*[:\-]?\s*(\d+\.?\d*)\s*(?:μiu/ml|miu/l)', caseSensitive: false),
      'parameter': 'TSH',
      'unit': 'μIU/mL',
      'normalRange': '0.4-4.0'
    },
  ];

  for (var pattern in patterns) {
    final regex = pattern['regex'] as RegExp;
    final matches = regex.allMatches(lowerText);
    
    for (var match in matches) {
      if (match.group(1) != null) {
        String value = match.group(1)!;
        // Clean the value
        value = value.replaceAll(RegExp(r'[^\d\.]'), '');
        
        if (value.isNotEmpty) {
          parameters.add({
            'parameter': pattern['parameter'] as String,
            'value': value,
            'unit': pattern['unit'] as String,
            'normalRange': pattern['normalRange'] as String,
            'confidence': 'high',
            'source': 'google_vision',
          });
        }
      }
    }
  }
  
  return parameters;
}
  // Enhanced medical information extraction
// Enhanced medical information extraction
static Map<String, dynamic> _extractMedicalInfo(String text) {
  // Initialize with proper types
  Map<String, dynamic> medicalInfo = {
    'medications': <String>[],
    'labResults': <Map<String, dynamic>>[],
    'patientInfo': <String, dynamic>{},
    'dates': <String>[],
  };
  
  if (text.isEmpty) return medicalInfo;
  
  final lowerText = text.toLowerCase();
  
  // Get references to the lists/maps for easier access
  final medications = medicalInfo['medications'] as List<String>;
  final labResults = medicalInfo['labResults'] as List<Map<String, dynamic>>;
  final patientInfo = medicalInfo['patientInfo'] as Map<String, dynamic>;
  final dates = medicalInfo['dates'] as List<String>;
  
  // ========== PATIENT INFO EXTRACTION ==========
  
  // Extract patient name - multiple patterns
  final namePatterns = [
    RegExp(r'patient\s*[:\-]\s*([^\n\r]+)', caseSensitive: false),
    RegExp(r'name\s*[:\-]\s*([^\n\r]+)', caseSensitive: false),
    RegExp(r'patient name\s*[:\-]\s*([^\n\r]+)', caseSensitive: false),
  ];
  
  for (var pattern in namePatterns) {
    var match = pattern.firstMatch(text);
    if (match != null && match.group(1) != null) {
      String name = match.group(1)!.trim();
      // Clean up name (remove age/gender if included)
      if (name.contains(':')) {
        name = name.split(':').first.trim();
      }
      if (name.isNotEmpty) {
        patientInfo['name'] = name;
        break;
      }
    }
  }
  
  // Extract age - multiple patterns
  final agePatterns = [
    RegExp(r'age\s*[:\-]\s*(\d+)\s*(?:years|yrs|y|year)?', caseSensitive: false),
    RegExp(r'(\d+)\s*(?:years|yrs|y|year)\s*old', caseSensitive: false),
    RegExp(r'\b(\d{1,2})[/-](?:m|f|male|female)', caseSensitive: false),
  ];
  
  for (var pattern in agePatterns) {
    var match = pattern.firstMatch(text);
    if (match != null && match.group(1) != null) {
      patientInfo['age'] = match.group(1);
      break;
    }
  }
  
  // Extract gender
  if (lowerText.contains('male') || lowerText.contains('m/') || lowerText.contains('/m')) {
    patientInfo['gender'] = 'Male';
  } else if (lowerText.contains('female') || lowerText.contains('f/') || lowerText.contains('/f')) {
    patientInfo['gender'] = 'Female';
  }
  
  // ========== LAB RESULTS EXTRACTION - IMPROVED ==========
  
  // First, try to find lab values in common formats
  
  // Pattern 1: "Parameter: value unit" format
  final pattern1 = RegExp(r'([A-Za-z\s]+(?:\([^)]+\))?)\s*[:=]\s*(\d+\.?\d*)\s*([A-Za-z/%]+)', caseSensitive: false);
  final matches1 = pattern1.allMatches(text);
  
  for (var match in matches1) {
    if (match.group(1) != null && match.group(2) != null && match.group(3) != null) {
      String test = match.group(1)!.trim();
      String value = match.group(2)!.trim();
      String unit = match.group(3)!.trim();
      
      // Clean up test name
      test = test.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      if (test.isNotEmpty && value.isNotEmpty) {
        labResults.add({
          'test': test,
          'value': value,
          'unit': unit,
          'source': 'pattern1',
          'confidence': 'high',
        });
        
        _debugPrint('✅ Found via pattern1: $test = $value $unit');
      }
    }
  }
  
  // Pattern 2: "Parameter value unit" format (without colon)
  final pattern2 = RegExp(r'\b([A-Z]{2,}|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(\d+\.?\d*)\s+([A-Za-z/%]+)\b');
  final matches2 = pattern2.allMatches(text);
  
  for (var match in matches2) {
    if (match.group(1) != null && match.group(2) != null && match.group(3) != null) {
      String test = match.group(1)!.trim();
      String value = match.group(2)!.trim();
      String unit = match.group(3)!.trim();
      
      // Only add if it looks like a medical parameter
      final commonTests = ['Hb', 'WBC', 'RBC', 'Platelet', 'Glucose', 'Creatinine', 'Cholesterol', 'TSH', 'Bilirubin'];
      if (commonTests.any((t) => test.toLowerCase().contains(t.toLowerCase()))) {
        labResults.add({
          'test': test,
          'value': value,
          'unit': unit,
          'source': 'pattern2',
          'confidence': 'medium',
        });
        
        _debugPrint('✅ Found via pattern2: $test = $value $unit');
      }
    }
  }
  
  // Pattern 3: Look for common test abbreviations with values
  final commonPatterns = [
    // Hemoglobin
    {
      'regex': RegExp(r'\b(?:Hb|HGB|Hemoglobin)\s*[:=]?\s*(\d+\.?\d*)\s*(?:g/dl|g/dL|g%)?', caseSensitive: false),
      'test': 'Hemoglobin',
      'unit': 'g/dL'
    },
    // WBC
    {
      'regex': RegExp(r'\b(?:WBC|White Blood Cells)\s*[:=]?\s*(\d+\.?\d*)\s*(?:/cmm|/mm3)?', caseSensitive: false),
      'test': 'White Blood Cells',
      'unit': '/cmm'
    },
    // Platelets
    {
      'regex': RegExp(r'\b(?:Platelet|PLT|Platelet Count)\s*[:=]?\s*(\d+\.?\d*)\s*(?:/cmm|/mm3)?', caseSensitive: false),
      'test': 'Platelets',
      'unit': '/cmm'
    },
    // Glucose
    {
      'regex': RegExp(r'\b(?:Glucose|Blood Sugar|FBS|RBS)\s*[:=]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)?', caseSensitive: false),
      'test': 'Glucose',
      'unit': 'mg/dL'
    },
    // Creatinine
    {
      'regex': RegExp(r'\b(?:Creatinine|Cr)\s*[:=]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)?', caseSensitive: false),
      'test': 'Creatinine',
      'unit': 'mg/dL'
    },
    // Cholesterol
    {
      'regex': RegExp(r'\b(?:Cholesterol|Chol)\s*[:=]?\s*(\d+\.?\d*)\s*(?:mg/dl|mg/dL)?', caseSensitive: false),
      'test': 'Cholesterol',
      'unit': 'mg/dL'
    },
  ];
  
  for (var pattern in commonPatterns) {
    final regex = pattern['regex'] as RegExp;
    final matches = regex.allMatches(text);
    
    for (var match in matches) {
      if (match.group(1) != null) {
        String value = match.group(1)!;
        labResults.add({
          'test': pattern['test'] as String,
          'value': value,
          'unit': pattern['unit'] as String,
          'source': 'commonPattern',
          'confidence': 'high',
        });
        
        _debugPrint('✅ Found via commonPattern: ${pattern['test']} = $value ${pattern['unit']}');
      }
    }
  }
  
  // Also look for medication patterns
  final medPatterns = [
    RegExp(r'(?:rx|prescription|medication|tablet|capsule)[:\s]*([^\n\.;]+)', caseSensitive: false),
    RegExp(r'take\s+([^\n\.]+)\s+(?:once|twice|thrice|daily)', caseSensitive: false),
  ];
  
  for (var pattern in medPatterns) {
    var matches = pattern.allMatches(text);
    for (var match in matches) {
      if (match.group(1) != null) {
        String med = match.group(1)!.trim();
        if (med.isNotEmpty && med.length < 100 && !med.contains('http')) {
          medications.add(med);
        }
      }
    }
  }
  
  // ========== DATE EXTRACTION ==========
  
  // Extract dates with various formats
  final datePatterns = [
    RegExp(r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b'), // DD/MM/YYYY, MM/DD/YYYY
    RegExp(r'\b(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})\b'), // YYYY/MM/DD
    RegExp(r'\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* \d{1,2},? \d{4}\b', caseSensitive: false),
  ];
  
  for (var pattern in datePatterns) {
    var matches = pattern.allMatches(text);
    for (var match in matches) {
      if (match.group(0) != null) {
        String date = match.group(0)!;
        if (!dates.contains(date)) {
          dates.add(date);
        }
      }
    }
  }
  
  // Also look for specific date labels
  final labeledDatePatterns = [
    RegExp(r'(?:date|report date|collection date|test date)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),
    RegExp(r'(?:date|report date|collection date|test date)[:\s]*(\d{4}[/\-\.]\d{1,2}[/\-\.]\d{1,2})', caseSensitive: false),
  ];
  
  for (var pattern in labeledDatePatterns) {
    var match = pattern.firstMatch(text);
    if (match != null && match.group(1) != null) {
      String date = match.group(1)!;
      if (!dates.contains(date)) {
        dates.add(date);
      }
    }
  }
  
  // Limit dates to avoid too many entries
  if (dates.length > 5) {
    medicalInfo['dates'] = dates.sublist(0, 5);
  }
  
  // Log extraction results
  if (_isDebugMode()) {
    _debugPrint('📊 Extracted medical info:');
    _debugPrint('  - Medications: ${medications.length}');
    _debugPrint('  - Lab Results: ${labResults.length}');
    _debugPrint('  - Dates: ${dates.length}');
    _debugPrint('  - Patient Age: ${patientInfo['age'] ?? "Not found"}');
    _debugPrint('  - Patient Gender: ${patientInfo['gender'] ?? "Not found"}');
    
    // Show all lab results found
    if (labResults.isNotEmpty) {
      _debugPrint('\n🔬 Lab Results Found:');
      for (var result in labResults) {
        _debugPrint('  - ${result['test']}: ${result['value']} ${result['unit']} (${result['source']})');
      }
    }
  }
  
  return medicalInfo;
}
  // Helper method to check if we're in debug mode
  static bool _isDebugMode() {
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug;
  }
  
  // Debug print wrapper (only prints in debug mode)
  static void _debugPrint(String message) {
    if (_isDebugMode()) {
      print(message);
    }
  }
}