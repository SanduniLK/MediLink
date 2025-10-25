import 'package:dio/dio.dart';

class PatientService {
  static const String baseUrl = "http://10.222.212.133:5001/api";
  static final Dio _dio = Dio();

  // Get patient appointments
  static Future<Map<String, dynamic>> getPatientAppointments(String patientId) async {
    try {
      print('📋 Getting appointments for patient: $patientId');
      
      final response = await _dio.get(
        '$baseUrl/patients/$patientId/appointments',
      );

      print('✅ Patient appointments response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get patient appointments: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Dio error getting patient appointments: ${e.message}');
      throw Exception('Dio error: ${e.message}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}