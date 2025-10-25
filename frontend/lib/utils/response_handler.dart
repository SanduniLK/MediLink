import 'dart:convert';

class ResponseHandler {
  // Parse response safely
  static dynamic parseResponse(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (e) {
      // Check if it's a timestamp
      if (_isTimestamp(responseBody)) {
        try {
          return DateTime.parse(responseBody);
        } catch (e2) {
          return responseBody;
        }
      }
      return responseBody;
    }
  }

  static bool _isTimestamp(String text) {
    return text.contains('T') && 
           text.length >= 19 && 
           RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(text);
  }

  // Handle different response types in UI
  static String getDisplayText(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response.toString();
    } else if (response is DateTime) {
      return response.toIso8601String();
    } else if (response is String) {
      return response;
    } else {
      return response.toString();
    }
  }
}