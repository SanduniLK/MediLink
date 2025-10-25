import 'package:frontend/services/api_service.dart';

class DoctorBackendService {
  // 1. Get ALL Doctors with Schedules and Appointments
  static Future<Map<String, dynamic>?> getAllDoctorsQueueDashboard() async {
    try {
      print('🔄 BACKEND SERVICE: Calling /api/doctors/queue-dashboard');
      
      final response = await ApiService.getJson('/doctors/queue-dashboard');
      
      print('✅ BACKEND SERVICE: Response received');
      print('   Success: ${response['success']}');
      print('   Message: ${response['message']}');
      print('   Data type: ${response['data']?.runtimeType}');
      print('   Data length: ${response['data'] is List ? (response['data'] as List).length : 'N/A'}');
      
      if (response['success'] == true && response['data'] is List) {
        final doctors = response['data'] as List;
        print('🎯 BACKEND SERVICE: Returning REAL DATA with ${doctors.length} doctors');
        return response;
      } else {
        print('❌ BACKEND SERVICE: Invalid response format');
        return null;
      }
    } catch (e) {
      print('❌ BACKEND SERVICE ERROR: $e');
      return null;
    }
  }
}