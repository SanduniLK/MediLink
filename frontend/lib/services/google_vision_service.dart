// lib/services/google_vision_service.dart - UPDATED
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class GoogleVisionService {
  static const String _apiKey = 'AIzaSyDJ7vNn-OmvNXYPh8o294vL9Io2ITFPYuE';
  
  // Extract text from both PDF and images
  static Future<Map<String, dynamic>> extractMedicalText(File file) async {
    try {
      // Check file type
      final String fileExtension = file.path.split('.').last.toLowerCase();
      
      if (fileExtension == 'pdf') {
        // Handle PDF files
        return await _extractTextFromPdf(file);
      } else {
        // Handle image files (PNG, JPG, JPEG)
        return await _extractTextFromImage(file);
      }
    } catch (e) {
      print('❌ Error in extractMedicalText: $e');
      return {
        'success': false,
        'fullText': '',
        'medicalInfo': {},
        'error': 'Failed to process file',
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
      
      // Call Google Vision API
      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      );
      
      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);
        
        // Extract full text
        String fullText = '';
        if (result['responses'] != null && 
            result['responses'].isNotEmpty &&
            result['responses'][0]['fullTextAnnotation'] != null) {
          fullText = result['responses'][0]['fullTextAnnotation']['text'] ?? '';
        }
        
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
        print('❌ Google Vision API Error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'fullText': '',
          'medicalInfo': {},
          'error': 'API Error ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error in _extractTextFromImage: $e');
      return {
        'success': false,
        'fullText': '',
        'medicalInfo': {},
        'error': 'Image extraction failed',
      };
    }
  }
  
  // Extract text from PDF files (convert first page to image)
  static Future<Map<String, dynamic>> _extractTextFromPdf(File pdfFile) async {
    try {
      print('📄 Processing PDF file...');
      
      // Option 1: Try to extract text directly using a PDF library
      // For now, let's use Google Vision on the first page converted to image
      
      // Read PDF bytes
      final pdfBytes = await pdfFile.readAsBytes();
      
      // For simplicity, we'll extract text from first page only
      // In production, you might want to extract from all pages
      
      // Call Google Vision API with PDF content
      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/files:asyncBatchAnnotate?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [{
            'inputConfig': {
              'mimeType': 'application/pdf',
              'content': base64Encode(pdfBytes),
            },
            'features': [{'type': 'DOCUMENT_TEXT_DETECTION'}],
            'pages': [1], // Extract from first page only for speed
          }],
        }),
      );
      
      if (response.statusCode == 200) {
        // This is an async operation, we need to check the operation
        final Map<String, dynamic> result = jsonDecode(response.body);
        
        // The async operation will return an operation name
        // You would need to poll for results in production
        print('✅ PDF processing started. Operation: ${result['name']}');
        
        // For now, return partial success
        return {
          'success': true,
          'fullText': '[PDF file - text extraction in progress]',
          'medicalInfo': {},
          'textLength': 0,
          'fileType': 'pdf',
          'note': 'PDF processing started, check operation later',
        };
      } else {
        print('❌ PDF API Error: ${response.statusCode} - ${response.body}');
        
        // Fallback: Try converting PDF to image and then extract
        return await _extractTextFromPdfFallback(pdfFile);
      }
    } catch (e) {
      print('❌ Error in _extractTextFromPdf: $e');
      
      // Try fallback method
      return await _extractTextFromPdfFallback(pdfFile);
    }
  }
  
  // Fallback method for PDF: Convert to image then extract
  static Future<Map<String, dynamic>> _extractTextFromPdfFallback(File pdfFile) async {
    try {
      print('🔄 Using fallback PDF extraction...');
      
      // For a complete solution, you'd need:
      // 1. A PDF rendering library to convert PDF pages to images
      // 2. Convert each page to image and send to Google Vision
      
      // Since PDF-to-image conversion is complex, here's a simplified approach:
      // Just return basic info and log that we received a PDF
      
      return {
        'success': true,
        'fullText': '[PDF file received - advanced extraction needed]',
        'medicalInfo': {},
        'textLength': 0,
        'fileType': 'pdf',
        'note': 'PDF file uploaded, consider adding PDF text extraction library',
      };
    } catch (e) {
      print('❌ Fallback PDF extraction failed: $e');
      return {
        'success': false,
        'fullText': '',
        'medicalInfo': {},
        'error': 'PDF processing failed',
      };
    }
  }
  
  // Extract medical information from text (unchanged)
  static Map<String, dynamic> _extractMedicalInfo(String text) {
    final medicalInfo = {
      'medications': <String>[],
      'labResults': <Map<String, dynamic>>[],
      'patientInfo': <String, dynamic>{},
      'dates': <String>[],
    };
    
    // Extract medications
    RegExp medRegex = RegExp(r'(?:Take|Rx|Prescription|Tablet|Capsule|Medication)[:\s]*([^\n\.;]+)', 
        caseSensitive: false);
    Iterable<RegExpMatch> medMatches = medRegex.allMatches(text);
    for (var match in medMatches) {
      String med = match.group(1)?.trim() ?? '';
      if (med.isNotEmpty && !med.contains('http') && med.length < 100) {
        (medicalInfo['medications'] as List<String>).add(med);
      }
    }
    
    // Extract lab results
    RegExp glucoseRegex = RegExp(r'Glucose[:\s]*(\d+\.?\d*)', caseSensitive: false);
    var glucoseMatch = glucoseRegex.firstMatch(text);
    if (glucoseMatch != null) {
      (medicalInfo['labResults'] as List<Map<String, dynamic>>).add({
        'test': 'Glucose',
        'value': glucoseMatch.group(1),
        'unit': 'mg/dL'
      });
    }
    
    // Extract cholesterol
    RegExp cholRegex = RegExp(r'Cholesterol[:\s]*(\d+\.?\d*)', caseSensitive: false);
    var cholMatch = cholRegex.firstMatch(text);
    if (cholMatch != null) {
      (medicalInfo['labResults'] as List<Map<String, dynamic>>).add({
        'test': 'Cholesterol',
        'value': cholMatch.group(1),
        'unit': 'mg/dL'
      });
    }
    
    // Extract dates
    RegExp dateRegex = RegExp(r'\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b');
    medicalInfo['dates'] = dateRegex.allMatches(text)
        .map((m) => m.group(0) ?? '')
        .where((date) => date.isNotEmpty)
        .toList();
    
    return medicalInfo;
  }
}