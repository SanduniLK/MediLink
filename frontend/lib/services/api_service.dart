// frontend/lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
    static const String baseUrl = "http://10.222.212.133:5001/api";
  static String? authToken;

  // Safe JSON parser that handles string responses like timestamps
  static dynamic safeJsonParse(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (e) {
      // If it's a timestamp string like "2025-10-03T04:33:38.1722"
      if (responseBody.contains('T') && responseBody.length >= 19) {
        try {
          return DateTime.parse(responseBody);
        } catch (e2) {
          // Return as string if not a valid date
          return responseBody;
        }
      }
      // Return as string if not JSON
      return responseBody;
    }
  }

  // POST request
  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // GET request - UPDATED to return dynamic instead of Map
  static Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // PUT request
  static Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // DELETE request
  static Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Handle response - UPDATED to handle different response types
  static dynamic _handleResponse(http.Response response) {
    // Use safe JSON parser that handles strings
    final data = safeJsonParse(response.body);
    
    // Debug logging
    print('API Response - Status: ${response.statusCode}');
    print('API Response - Type: ${data.runtimeType}');
    print('API Response - Data: $data');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      // Handle error response - could be string or map
      String errorMessage;
      if (data is String) {
        errorMessage = data;
      } else if (data is Map<String, dynamic>) {
        errorMessage = data['message'] ?? 'Request failed with status ${response.statusCode}';
      } else {
        errorMessage = 'Request failed with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  // Helper method for specific endpoints that should return JSON
  static Future<Map<String, dynamic>> getJson(String endpoint) async {
    final response = await get(endpoint);
    
    if (response is Map<String, dynamic>) {
      return response;
    } else {
      throw Exception('Expected JSON response but got ${response.runtimeType}');
    }
  }

  // Helper method for endpoints that might return timestamps
  static Future<DateTime> getTimestamp(String endpoint) async {
    final response = await get(endpoint);
    
    if (response is DateTime) {
      return response;
    } else if (response is String) {
      try {
        return DateTime.parse(response);
      } catch (e) {
        throw Exception('Invalid timestamp format: $response');
      }
    } else {
      throw Exception('Expected timestamp but got ${response.runtimeType}');
    }
  }
}