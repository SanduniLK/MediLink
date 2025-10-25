import 'package:dio/dio.dart';

class DioService {
  static final Dio _dio = Dio();
  
  // For Android emulator
  static const String baseUrl = 'http://10.222.212.133:5001';
  
  static void initialize() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }
  
  static Future<dynamic> post(String endpoint, dynamic data) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return response.data;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  static Future<dynamic> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      return response.data;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}