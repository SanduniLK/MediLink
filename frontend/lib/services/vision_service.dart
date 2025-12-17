// lib/services/vision_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GoogleVisionService {
  static const String _apiKey = 'YOUR_API_KEY_HERE'; // Get from Google Cloud
  static const String _apiUrl = 'https://vision.googleapis.com/v1/images:annotate';
  
  // Extract text from image file
  static Future<String> extractTextFromImage(File imageFile) async {
    try {
      // Convert image to base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      
      // Prepare request
      Map<String, dynamic> request = {
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'TEXT_DETECTION'}
            ]
          }
        ]
      };
      
      // Call Google Vision API directly
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      );
      
      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);
        String text = result['responses'][0]['textAnnotations'][0]['description'] ?? '';
        return text;
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Vision API error: $e');
      return '';
    }
  }
  
  // Extract text from PDF (convert to images first)
  static Future<String> extractTextFromPDF(File pdfFile) async {
    // For PDFs, you'd convert pages to images
    // Use package: pdf_image_renderer or similar
    // Then call extractTextFromImage for each page
    return 'PDF text extraction requires image conversion';
  }
}