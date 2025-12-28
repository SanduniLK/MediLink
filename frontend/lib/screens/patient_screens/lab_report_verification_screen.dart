// lib/screens/patient_screens/lab_report_verification_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/medical_record.dart';
import 'package:intl/intl.dart';

class LabReportVerificationScreen extends StatefulWidget {
  final MedicalRecord record;
  final Map<String, dynamic> extractedData;
  final String extractedText;
  final String category;
  final String? testDate;
  final Function(Map<String, dynamic>) onVerified;
  final String patientId;

  const LabReportVerificationScreen({
    super.key,
    required this.record,
    required this.extractedData,
    required this.extractedText,
    required this.category,
    this.testDate,
    required this.onVerified,
    required this.patientId,
  });

  @override
  _LabReportVerificationScreenState createState() => _LabReportVerificationScreenState();
}

class _LabReportVerificationScreenState extends State<LabReportVerificationScreen> {
  List<Map<String, dynamic>> _parameters = [];
  Map<String, TextEditingController> _controllers = {};
  Map<String, String> _units = {};
  Map<String, String> _normalRanges = {};
  String? _autoDetectedDate;
  String? _selectedDate;
  final TextEditingController _dateController = TextEditingController();
  
  // Predefined test parameters dictionary
  static const Map<String, Map<String, dynamic>> _parameterDictionary = {
    'haemoglobin': {'displayName': 'Hemoglobin (Hb)', 'unit': 'g/dL', 'normalRange': '13-17'},
    'hb': {'displayName': 'Hemoglobin (Hb)', 'unit': 'g/dL', 'normalRange': '13-17'},
    'hemoglobin': {'displayName': 'Hemoglobin (Hb)', 'unit': 'g/dL', 'normalRange': '13-17'},
    
    'wbc': {'displayName': 'White Blood Cells (WBC)', 'unit': 'x10^9/L', 'normalRange': '4-11'},
    'white blood cells': {'displayName': 'White Blood Cells (WBC)', 'unit': 'x10^9/L', 'normalRange': '4-11'},
    'total wbc': {'displayName': 'White Blood Cells (WBC)', 'unit': 'x10^9/L', 'normalRange': '4-11'},
    
    'platelets': {'displayName': 'Platelet Count', 'unit': 'x10^9/L', 'normalRange': '150-450'},
    'platelet count': {'displayName': 'Platelet Count', 'unit': 'x10^9/L', 'normalRange': '150-450'},
    'plt': {'displayName': 'Platelet Count', 'unit': 'x10^9/L', 'normalRange': '150-450'},
    
    'rbc': {'displayName': 'Red Blood Cells (RBC)', 'unit': 'x10^12/L', 'normalRange': '4.5-6.5'},
    'red blood cells': {'displayName': 'Red Blood Cells (RBC)', 'unit': 'x10^12/L', 'normalRange': '4.5-6.5'},
    
    'hct': {'displayName': 'Hematocrit (HCT)', 'unit': '%', 'normalRange': '40-54'},
    'hematocrit': {'displayName': 'Hematocrit (HCT)', 'unit': '%', 'normalRange': '40-54'},
    
    'mcv': {'displayName': 'Mean Corpuscular Volume (MCV)', 'unit': 'fL', 'normalRange': '80-100'},
    'mch': {'displayName': 'Mean Corpuscular Hemoglobin (MCH)', 'unit': 'pg', 'normalRange': '27-32'},
    'mchc': {'displayName': 'Mean Corpuscular Hemoglobin Concentration (MCHC)', 'unit': 'g/dL', 'normalRange': '32-36'},
    
    'glucose': {'displayName': 'Glucose', 'unit': 'mg/dL', 'normalRange': '70-99'},
    'blood glucose': {'displayName': 'Glucose', 'unit': 'mg/dL', 'normalRange': '70-99'},
    'fasting glucose': {'displayName': 'Glucose (Fasting)', 'unit': 'mg/dL', 'normalRange': '70-99'},
    
    'hba1c': {'displayName': 'Hemoglobin A1c (HbA1c)', 'unit': '%', 'normalRange': '4.0-5.6'},
    'a1c': {'displayName': 'Hemoglobin A1c (HbA1c)', 'unit': '%', 'normalRange': '4.0-5.6'},
    
    'creatinine': {'displayName': 'Creatinine', 'unit': 'mg/dL', 'normalRange': '0.6-1.2'},
    'urea': {'displayName': 'Urea', 'unit': 'mg/dL', 'normalRange': '10-50'},
    'bun': {'displayName': 'Blood Urea Nitrogen (BUN)', 'unit': 'mg/dL', 'normalRange': '7-20'},
    
    'ast': {'displayName': 'AST (SGOT)', 'unit': 'U/L', 'normalRange': '5-40'},
    'sgot': {'displayName': 'AST (SGOT)', 'unit': 'U/L', 'normalRange': '5-40'},
    'alt': {'displayName': 'ALT (SGPT)', 'unit': 'U/L', 'normalRange': '7-56'},
    'sgpt': {'displayName': 'ALT (SGPT)', 'unit': 'U/L', 'normalRange': '7-56'},
    
    'cholesterol': {'displayName': 'Total Cholesterol', 'unit': 'mg/dL', 'normalRange': '<200'},
    'total cholesterol': {'displayName': 'Total Cholesterol', 'unit': 'mg/dL', 'normalRange': '<200'},
    'hdl': {'displayName': 'HDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '>40'},
    'ldl': {'displayName': 'LDL Cholesterol', 'unit': 'mg/dL', 'normalRange': '<100'},
    'triglycerides': {'displayName': 'Triglycerides', 'unit': 'mg/dL', 'normalRange': '<150'},
    
    'tsh': {'displayName': 'Thyroid Stimulating Hormone (TSH)', 'unit': 'μIU/mL', 'normalRange': '0.4-4.0'},
    't3': {'displayName': 'Triiodothyronine (T3)', 'unit': 'ng/dL', 'normalRange': '80-200'},
    't4': {'displayName': 'Thyroxine (T4)', 'unit': 'μg/dL', 'normalRange': '5-12'},
    
    'sodium': {'displayName': 'Sodium (Na)', 'unit': 'mEq/L', 'normalRange': '135-145'},
    'potassium': {'displayName': 'Potassium (K)', 'unit': 'mEq/L', 'normalRange': '3.5-5.0'},
    'chloride': {'displayName': 'Chloride (Cl)', 'unit': 'mEq/L', 'normalRange': '98-106'},
    'bicarbonate': {'displayName': 'Bicarbonate (HCO3)', 'unit': 'mEq/L', 'normalRange': '22-28'},
    
    'calcium': {'displayName': 'Calcium', 'unit': 'mg/dL', 'normalRange': '8.5-10.2'},
    'phosphorus': {'displayName': 'Phosphorus', 'unit': 'mg/dL', 'normalRange': '2.5-4.5'},
    'magnesium': {'displayName': 'Magnesium', 'unit': 'mg/dL', 'normalRange': '1.7-2.2'},
  };

  @override
  void initState() {
    super.initState();
    _initializeParameters();
    _autoDetectedDate = _extractDateFromText();
    _selectedDate = widget.testDate ?? _autoDetectedDate;
    if (_selectedDate != null) {
      _dateController.text = _selectedDate!;
    }
  }

  void _initializeParameters() {
    debugPrint('🔍 Initializing parameters from extracted data...');
    
    // Get parameters from extracted data
    final rawParams = widget.extractedData['parameters'] as List? ?? [];
    final rawResults = widget.extractedData['labResults'] as List? ?? [];
    
    List<Map<String, dynamic>> allParams = [];
    if (rawParams.isNotEmpty) {
      allParams.addAll(rawParams.whereType<Map<String, dynamic>>());
    }
    if (rawResults.isNotEmpty) {
      allParams.addAll(rawResults.whereType<Map<String, dynamic>>());
    }
    
    debugPrint('📋 Found ${allParams.length} parameters in extracted data');
    
    if (allParams.isEmpty) {
      debugPrint('⚠️ No parameters found in extracted data. Auto-extracting from text...');
      _extractParametersFromText();
    } else {
      for (var param in allParams) {
        _addParameterFromData(param);
      }
    }
    
    // If still no parameters, add common ones based on category
    if (_parameters.isEmpty) {
      _addDefaultParametersForCategory();
    }
  }

  void _addParameterFromData(Map<String, dynamic> param) {
    try {
      final paramNameRaw = param['parameter']?.toString().toLowerCase() ?? '';
      final initialValue = param['value']?.toString() ?? '';
      final unit = param['unit']?.toString() ?? '';
      final normalRange = param['normalRange']?.toString() ?? '';
      final confidence = param['confidence']?.toString() ?? 'low';
      
      // Find the best matching parameter from dictionary
      String? matchedKey;
      Map<String, dynamic>? matchedInfo;
      
      for (var entry in _parameterDictionary.entries) {
        if (paramNameRaw.contains(entry.key.toLowerCase())) {
          matchedKey = entry.key;
          matchedInfo = entry.value;
          break;
        }
      }
      
      String displayName;
      String finalUnit;
      String finalNormalRange;
      
      if (matchedInfo != null && matchedKey != null) {
        displayName = matchedInfo['displayName']!;
        finalUnit = unit.isNotEmpty ? unit : matchedInfo['unit']!;
        finalNormalRange = normalRange.isNotEmpty ? normalRange : matchedInfo['normalRange']!;
      } else {
        displayName = _capitalizeFirstLetter(paramNameRaw);
        finalUnit = unit;
        finalNormalRange = normalRange;
      }
      
      _parameters.add({
        'parameter': displayName,
        'initialValue': initialValue,
        'unit': finalUnit,
        'normalRange': finalNormalRange,
        'verifiedValue': initialValue,
        'needsVerification': confidence.toLowerCase() != 'high',
        'extractedParameter': paramNameRaw,
        'confidence': confidence,
      });
      
      _controllers[displayName] = TextEditingController(text: initialValue);
      _units[displayName] = finalUnit;
      _normalRanges[displayName] = finalNormalRange;
      
      debugPrint('✅ Added parameter: $displayName = $initialValue $finalUnit (${confidence.toUpperCase()})');
      
    } catch (e) {
      debugPrint('❌ Error adding parameter from data: $e');
    }
  }

  void _extractParametersFromText() {
    final text = widget.extractedText.toLowerCase();
    
    // Regex patterns for parameter extraction
    final patterns = [
      // Pattern: Parameter name followed by value and unit
      RegExp(r'([a-z\s]+?)\s*([\d\.]+)\s*([a-z\/\%μ\^]+)', caseSensitive: false),
      // Pattern: Value followed by unit then parameter
      RegExp(r'([\d\.]+)\s*([a-z\/\%μ\^]+)\s*([a-z\s]+)', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        try {
          String paramName = match.group(1)?.trim() ?? '';
          String value = match.group(2)?.trim() ?? '';
          String unit = match.group(3)?.trim() ?? '';
          
          if (paramName.isNotEmpty && value.isNotEmpty) {
            _addExtractedParameter(paramName, value, unit);
          }
        } catch (e) {
          debugPrint('❌ Error in pattern matching: $e');
        }
      }
    }
  }

  void _addExtractedParameter(String rawName, String value, String unit) {
    // Try to match with dictionary
    String? matchedKey;
    Map<String, dynamic>? matchedInfo;
    
    for (var entry in _parameterDictionary.entries) {
      if (rawName.contains(entry.key.toLowerCase())) {
        matchedKey = entry.key;
        matchedInfo = entry.value;
        break;
      }
    }
    
    String displayName;
    String finalUnit;
    String finalNormalRange;
    
    if (matchedInfo != null && matchedKey != null) {
      displayName = matchedInfo['displayName']!;
      finalUnit = unit.isNotEmpty ? unit : matchedInfo['unit']!;
      finalNormalRange = matchedInfo['normalRange']!;
    } else {
      displayName = _capitalizeFirstLetter(rawName);
      finalUnit = unit;
      finalNormalRange = '';
    }
    
    // Check if parameter already exists
    if (!_parameters.any((p) => p['parameter'] == displayName)) {
      _parameters.add({
        'parameter': displayName,
        'initialValue': value,
        'unit': finalUnit,
        'normalRange': finalNormalRange,
        'verifiedValue': value,
        'needsVerification': true,
        'extractedParameter': rawName,
        'confidence': 'medium',
      });
      
      _controllers[displayName] = TextEditingController(text: value);
      _units[displayName] = finalUnit;
      _normalRanges[displayName] = finalNormalRange;
      
      debugPrint('📝 Extracted parameter: $displayName = $value $finalUnit');
    }
  }

  void _addDefaultParametersForCategory() {
    debugPrint('➕ Adding default parameters for category: ${widget.category}');
    
    final Map<String, List<String>> categoryDefaults = {
      'Full Blood Count (FBC)': ['Hemoglobin (Hb)', 'White Blood Cells (WBC)', 'Platelet Count', 'Red Blood Cells (RBC)'],
      'Blood Sugar Test': ['Glucose', 'Hemoglobin A1c (HbA1c)'],
      'Lipid Profile': ['Total Cholesterol', 'HDL Cholesterol', 'LDL Cholesterol', 'Triglycerides'],
      'Liver Function Test': ['AST (SGOT)', 'ALT (SGPT)', 'Total Bilirubin', 'Albumin'],
      
      'Thyroid (TSH) Test': ['Thyroid Stimulating Hormone (TSH)', 'Triiodothyronine (T3)', 'Thyroxine (T4)'],
    };
    
    final defaultParams = categoryDefaults[widget.category] ?? ['Hemoglobin (Hb)', 'Glucose', 'Creatinine'];
    
    for (var paramName in defaultParams) {
      if (!_parameters.any((p) => p['parameter'] == paramName)) {
        _parameters.add({
          'parameter': paramName,
          'initialValue': '',
          'unit': '',
          'normalRange': '',
          'verifiedValue': '',
          'needsVerification': true,
          'isDefault': true,
        });
        _controllers[paramName] = TextEditingController();
      }
    }
  }

  String? _extractDateFromText() {
    try {
      final text = widget.extractedText;
      
      // Multiple date patterns to try
      final patterns = [
        r'\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b',  // DD/MM/YYYY or DD-MM-YYYY
        r'\b(\d{4}[-/]\d{1,2}[-/]\d{1,2})\b',  // YYYY/MM/DD
        r'date[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
        r'report date[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
        r'test date[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
        r'collected[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
      ];
      
      for (var pattern in patterns) {
        final regex = RegExp(pattern, caseSensitive: false);
        final match = regex.firstMatch(text);
        if (match != null && match.group(1) != null) {
          final extractedDate = match.group(1)!;
          debugPrint('📅 Auto-detected date: $extractedDate');
          return extractedDate;
        }
      }
    } catch (e) {
      debugPrint('❌ Error extracting date: $e');
    }
    return null;
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Lab Report'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _saveVerifiedData,
            tooltip: 'Save Verified Data',
          ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File Info Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: Color(0xFF18A3B6)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lab Report Details',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.record.fileName,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Date Selection
                  Text(
                    'Test Date*',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dateController,
                          decoration: InputDecoration(
                            hintText: 'DD/MM/YYYY',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedDate = value;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      if (_autoDetectedDate != null)
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = _autoDetectedDate;
                              _dateController.text = _autoDetectedDate!;
                            });
                          },
                          child: Text('Auto-fill'),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Auto-detected from document: ${_autoDetectedDate ?? "Not found"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Test Category
                  Text(
                    'Test Category',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.science, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.category,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 20),
          
          // Parameters Section Header
          Row(
            children: [
              Text(
                'Lab Parameters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Chip(
                label: Text('${_parameters.length} parameters'),
                backgroundColor: Colors.blue[50],
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          Text(
            'Verify or edit the auto-detected values below:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          
          SizedBox(height: 16),
          
          // Parameters List
          if (_parameters.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 12),
                  Text(
                    'No parameters detected',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No lab parameters could be automatically detected from this report.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ..._parameters.map((param) {
              final paramName = param['parameter'] as String;
              final needsVerification = param['needsVerification'] as bool;
              final isDefault = param['isDefault'] as bool? ?? false;
              
              return _buildParameterCard(paramName, needsVerification, isDefault);
            }).toList(),
          
          SizedBox(height: 16),
          
          // Add Custom Parameter Button
          OutlinedButton.icon(
            onPressed: _addCustomParameter,
            icon: Icon(Icons.add_circle_outline),
            label: Text('Add Custom Parameter'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
          ),
          
          SizedBox(height: 80), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildParameterCard(String paramName, bool needsVerification, bool isDefault) {
    final controller = _controllers[paramName] ?? TextEditingController();
    final unit = _units[paramName] ?? '';
    final normalRange = _normalRanges[paramName] ?? '';
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    paramName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: needsVerification ? Colors.orange[800] : Colors.green,
                    ),
                  ),
                ),
                if (isDefault)
                  Chip(
                    label: Text('Default'),
                    backgroundColor: Colors.grey[100],
                    labelStyle: TextStyle(fontSize: 10),
                  ),
                SizedBox(width: 8),
                if (needsVerification)
                  Chip(
                    label: Text('Needs Verify'),
                    backgroundColor: Colors.orange[100],
                    labelStyle: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[800],
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Value Input
            TextField(
  controller: controller, // Use the controller from the map
  decoration: InputDecoration(
    hintText: 'Enter value',
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    filled: controller.text.isNotEmpty, // Check if controller text is not empty
    fillColor: controller.text.isNotEmpty 
        ? Colors.green[50] 
        : Colors.blue[50], // Blue for empty fields that can be auto-filled
    hintStyle: TextStyle(
      color: controller.text.isEmpty 
          ? Colors.blue[600] 
          : Colors.grey[400],
      fontStyle: controller.text.isEmpty 
          ? FontStyle.italic 
          : FontStyle.normal,
    ),
  ),
  keyboardType: TextInputType.numberWithOptions(decimal: true),
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: controller.text.isNotEmpty 
        ? Colors.green[800] 
        : Colors.black87,
  ),
  onChanged: (value) {
    // Update the parameter's verified value when user types
    final paramIndex = _parameters.indexWhere((p) => p['parameter'] == paramName);
    if (paramIndex != -1) {
      setState(() {
        _parameters[paramIndex]['verifiedValue'] = value;
        _parameters[paramIndex]['needsVerification'] = false;
      });
    }
  },
),
            
            SizedBox(height: 12),
            
            // Unit and Normal Range
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        Text(
                          unit.isNotEmpty ? unit : 'Not specified',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Normal Range',
                          style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                        ),
                        Text(
                          normalRange.isNotEmpty ? normalRange : 'N/A',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Notes (Optional)
            TextField(
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
              onChanged: (value) {
                final paramIndex = _parameters.indexWhere((p) => p['parameter'] == paramName);
                if (paramIndex != -1) {
                  _parameters[paramIndex]['notes'] = value;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
void _debugExtractedText() {
  final extractedText = widget.record.extractedText ?? '';
  print('=== DEBUG: EXTRACTED TEXT ===');
  print('Length: ${extractedText.length} characters');
  
  // Print first 1000 characters to see format
  print('First 1000 chars:');
  print(extractedText.length > 1000 
      ? extractedText.substring(0, 1000) + '...' 
      : extractedText);
  
  print('=== END DEBUG ===');
}

void _debugPatternMatching(String paramName, List<String> keywords) {
  final extractedText = widget.record.extractedText?.toLowerCase() ?? '';
  
  print('=== DEBUG PATTERN MATCHING for: $paramName ===');
  print('Keywords: $keywords');
  
  for (var keyword in keywords) {
    // Try the patterns we're using
    final pattern1 = RegExp('$keyword[\\s:]*([\\d\\.]+)', caseSensitive: false);
    final pattern2 = RegExp('$keyword\\s+([\\d\\.]+)', caseSensitive: false);
    final pattern3 = RegExp('([\\d\\.]+)\\s*$keyword', caseSensitive: false);
    
    print('Trying keyword: $keyword');
    
    final matches1 = pattern1.allMatches(extractedText);
    if (matches1.isNotEmpty) {
      print('✅ Pattern1 matched:');
      for (var match in matches1) {
        print('  Found: ${match.group(0)}');
        print('  Value: ${match.group(1)}');
      }
    }
    
    final matches2 = pattern2.allMatches(extractedText);
    if (matches2.isNotEmpty) {
      print('✅ Pattern2 matched:');
      for (var match in matches2) {
        print('  Found: ${match.group(0)}');
        print('  Value: ${match.group(1)}');
      }
    }
    
    final matches3 = pattern3.allMatches(extractedText);
    if (matches3.isNotEmpty) {
      print('✅ Pattern3 matched:');
      for (var match in matches3) {
        print('  Found: ${match.group(0)}');
        print('  Value: ${match.group(1)}');
      }
    }
  }
  
  print('=== END DEBUG ===');
}
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parameters: ${_parameters.length}',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Date: ${_selectedDate ?? "Not set"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _saveVerifiedData,
                icon: Icon(Icons.check_circle),
                label: Text('Save Verified Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Note: All verified data will be saved and available for analysis',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _addCustomParameter() {
    showDialog(
      context: context,
      builder: (context) => AddCustomParameterDialog(
        onAdd: (paramName, value, unit, normalRange) {
          setState(() {
            _parameters.add({
              'parameter': paramName,
              'initialValue': value,
              'unit': unit,
              'normalRange': normalRange,
              'verifiedValue': value,
              'needsVerification': false,
              'isCustom': true,
            });
            _controllers[paramName] = TextEditingController(text: value);
            _units[paramName] = unit;
            _normalRanges[paramName] = normalRange;
          });
        },
      ),
    );
  }

  void _saveVerifiedData() async {
    if (_selectedDate == null || _selectedDate!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the test date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Collect verified parameters
    final verifiedParameters = <String, dynamic>{};
    final verifiedResults = <Map<String, dynamic>>[];
    
    for (var param in _parameters) {
      final paramName = param['parameter'] as String;
      final valueStr = _controllers[paramName]?.text.trim() ?? '';
      
      if (valueStr.isNotEmpty) {
        final value = double.tryParse(valueStr) ?? 0;
        final unit = param['unit'] as String;
        final normalRange = param['normalRange'] as String;
        final notes = param['notes'] as String? ?? '';
        
        // Determine level (high, normal, low)
        String level = 'normal';
        if (normalRange.isNotEmpty && !normalRange.contains('-') && !normalRange.contains('<') && !normalRange.contains('>')) {
          // Simple range like "13-17"
          final rangeParts = normalRange.split('-');
          if (rangeParts.length == 2) {
            final low = double.tryParse(rangeParts[0].trim());
            final high = double.tryParse(rangeParts[1].trim());
            if (low != null && high != null) {
              if (value < low) level = 'low';
              else if (value > high) level = 'high';
            }
          }
        }
        
        verifiedResults.add({
          'parameter': paramName,
          'value': value,
          'unit': unit,
          'normalRange': normalRange,
          'level': level,
          'notes': notes,
          'isVerified': true,
          'isCustom': param['isCustom'] ?? false,
          'isDefault': param['isDefault'] ?? false,
        });
      }
    }
    
    // Prepare verified data
    verifiedParameters['testDate'] = _selectedDate;
    verifiedParameters['testCategory'] = widget.category;
    verifiedParameters['patientId'] = widget.patientId;
    verifiedParameters['medicalRecordId'] = widget.record.id;
    verifiedParameters['fileName'] = widget.record.fileName;
    verifiedParameters['results'] = verifiedResults;
    verifiedParameters['verifiedAt'] = Timestamp.now();
    verifiedParameters['extractedText'] = widget.extractedText;
    
    // Calculate statistics
    final highResults = verifiedResults.where((r) => r['level'] == 'high').length;
    final lowResults = verifiedResults.where((r) => r['level'] == 'low').length;
    final normalResults = verifiedResults.where((r) => r['level'] == 'normal').length;
    
    verifiedParameters['statistics'] = {
      'total': verifiedResults.length,
      'high': highResults,
      'low': lowResults,
      'normal': normalResults,
      'abnormal': highResults + lowResults,
    };
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Saving...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF18A3B6)),
            SizedBox(height: 16),
            Text('Saving verified report data...'),
          ],
        ),
      ),
    );
    
    try {
      // Save to patient_notes as verified analysis
      final noteId = FirebaseFirestore.instance.collection('patient_notes').doc().id;
      
      await FirebaseFirestore.instance.collection('patient_notes').doc(noteId).set({
        'id': noteId,
        'patientId': widget.patientId,
        'medicalRecordId': widget.record.id,
        'fileName': widget.record.fileName,
        'category': 'labResults',
        'testReportCategory': widget.category,
        'testDate': _selectedDate,
        'extractedText': widget.extractedText,
        'results': verifiedResults,
        'resultsByLevel': {
          'high': verifiedResults.where((r) => r['level'] == 'high').toList(),
          'normal': verifiedResults.where((r) => r['level'] == 'normal').toList(),
          'low': verifiedResults.where((r) => r['level'] == 'low').toList(),
        },
        'statistics': {
          'total': verifiedResults.length,
          'high': highResults,
          'low': lowResults,
          'normal': normalResults,
          'abnormal': highResults + lowResults,
        },
        'analysisDate': Timestamp.now(),
        'verifiedAt': Timestamp.now(),
        'noteType': 'verified_report_analysis',
        'isProcessed': true,
        'isVerified': true,
        'verifiedBy': widget.patientId, // Patient verified it themselves
      });
      
      // Update the original record
      await FirebaseFirestore.instance.collection('medical_records').doc(widget.record.id).update({
        'textExtractionStatus': 'verified',
        'verifiedParameters': verifiedParameters,
        'verifiedAt': Timestamp.now(),
        'testDate': _selectedDate,
        'testReportCategory': widget.category,
      });
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Lab report verified and saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Navigate back and call callback
      widget.onVerified(verifiedParameters);
      Navigator.pop(context);
      
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving verified report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}

class AddCustomParameterDialog extends StatefulWidget {
  final Function(String, String, String, String) onAdd;

  const AddCustomParameterDialog({super.key, required this.onAdd});

  @override
  _AddCustomParameterDialogState createState() => _AddCustomParameterDialogState();
}

class _AddCustomParameterDialogState extends State<AddCustomParameterDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _rangeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Custom Parameter'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Parameter Name*',
                border: OutlineInputBorder(),
                hintText: 'e.g., Hemoglobin, Glucose',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: 'Value*',
                border: OutlineInputBorder(),
                hintText: 'e.g., 12.5',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _unitController,
              decoration: InputDecoration(
                labelText: 'Unit*',
                border: OutlineInputBorder(),
                hintText: 'e.g., g/dL, mg/dL, %',
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _rangeController,
              decoration: InputDecoration(
                labelText: 'Normal Range',
                border: OutlineInputBorder(),
                hintText: 'e.g., 13-17 or <100',
                prefixIcon: Icon(Icons.trending_up),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _valueController.text.isNotEmpty &&
                _unitController.text.isNotEmpty) {
              widget.onAdd(
                _nameController.text,
                _valueController.text,
                _unitController.text,
                _rangeController.text,
              );
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please fill all required fields (*)'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF18A3B6),
          ),
          child: Text('Add Parameter'),
        ),
      ],
    );
  }
}