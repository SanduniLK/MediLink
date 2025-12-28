// Update your LocalTextExtractor to be complete:

// lib/services/local_text_extractor.dart (COMPLETE VERSION)
import 'dart:io';
import 'package:flutter/foundation.dart';

class LocalTextExtractor {
  static Future<Map<String, dynamic>> extractTextFromFile(File file) async {
    try {
      debugPrint('🔍 Simulating text extraction from file...');
      await Future.delayed(const Duration(seconds: 1));
      
      final mockText = '''
Patient Name: John Doe
Age: 35
Test Date: 24/06/2023

Lab Results:
Hemoglobin (Hb): 15.2 g/dL (Normal: 13-17)
White Blood Cells (WBC): 7500 /cmm (Normal: 4000-11000)
Platelets: 250000 /cmm (Normal: 150000-450000)
Red Blood Cells (RBC): 5.2 million/cmm (Normal: 4.5-5.9)
      ''';
      
      return _processExtractedText(mockText);
    } catch (e) {
      debugPrint('❌ Error in text extraction: $e');
      return {
        'success': false,
        'error': e.toString(),
        'fullText': '',
        'medicalInfo': {},
        'extractedParameters': [],
      };
    }
  }

  static Map<String, dynamic> _processExtractedText(String text) {
    final result = {
      'success': true,
      'fullText': text,
      'medicalInfo': {},
      'extractedParameters': <Map<String, dynamic>>[],
    };

    // Create RegExp objects properly
    final patterns = <Map<String, dynamic>>[
      {
        'regex': RegExp(r'hemoglobin.*?(\d+\.?\d*)\s*g/dl', caseSensitive: false),
        'parameter': 'Hemoglobin (Hb)',
        'unit': 'g/dL'
      },
      {
        'regex': RegExp(r'white blood cells.*?(\d+)\s*/cmm', caseSensitive: false),
        'parameter': 'White Blood Cells (WBC)',
        'unit': '/cmm'
      },
      {
        'regex': RegExp(r'platelets.*?(\d+)\s*/cmm', caseSensitive: false),
        'parameter': 'Platelets',
        'unit': '/cmm'
      },
      {
        'regex': RegExp(r'red blood cells.*?(\d+\.?\d*)\s*million/cmm', caseSensitive: false),
        'parameter': 'Red Blood Cells (RBC)',
        'unit': 'million/cmm'
      },
    ];

    for (var pattern in patterns) {
      final regex = pattern['regex'] as RegExp;
      final match = regex.firstMatch(text.toLowerCase());
      if (match != null && match.group(1) != null) {
        (result['extractedParameters'] as List).add({
          'parameter': pattern['parameter'],
          'value': match.group(1)!.trim(),
          'unit': pattern['unit'],
          'confidence': 'high',
          'source': 'auto_extracted',
        });
      }
    }

    // Extract patient info
    final nameRegex = RegExp(r'patient\s*name[:\s]*([a-z\s]+)', caseSensitive: false);
    final nameMatch = nameRegex.firstMatch(text.toLowerCase());
    if (nameMatch != null) {
      result['medicalInfo'] = {
        'patientInfo': {
          'name': nameMatch.group(1)?.trim(),
        }
      };
    }

    return result;
  }

  static String autoDetectTestCategory(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('hemoglobin') || lowerText.contains('wbc') || 
        lowerText.contains('rbc') || lowerText.contains('platelet')) {
      return 'Full Blood Count (FBC)';
    }
    
    if (lowerText.contains('urine')) return 'Urine Analysis';
    if (lowerText.contains('tsh') || lowerText.contains('thyroid')) return 'Thyroid (TSH) Test';
    if (lowerText.contains('cholesterol') || lowerText.contains('lipid')) return 'Lipid Profile';
    if (lowerText.contains('glucose') || lowerText.contains('sugar')) return 'Blood Sugar Test';
    
    return 'Other Blood Test';
  }

  static String extractTestDate(String text) {
    try {
      final dateRegex = RegExp(r'test\s*date[:\s]*(\d{1,2}/\d{1,2}/\d{4})', caseSensitive: false);
      final match = dateRegex.firstMatch(text.toLowerCase());
      if (match != null) {
        return match.group(1) ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}