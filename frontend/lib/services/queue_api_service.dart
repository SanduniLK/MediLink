import 'package:dio/dio.dart';

class QueueApiService {
  static const String baseUrl = "http://10.222.212.133:5001/api";
  static final Dio _dio = Dio();

  // Start consultation queue
 // In QueueApiService.dart
static Future<Map<String, dynamic>> startConsultation({
  required String scheduleId,
  required String doctorId,
  required String medicalCenterId,
  required String doctorName,
  required String medicalCenterName,
  required List<Map<String, dynamic>> appointments, // Add this parameter
}) async {
  try {
    print('🚀 Starting consultation with Dio...');
    print('   Appointments to send: ${appointments.length}');
    
    //  Include appointments in the request
    final response = await _dio.post(
      '$baseUrl/queue/start',
      data: {
        'scheduleId': scheduleId,
        'doctorId': doctorId,
        'medicalCenterId': medicalCenterId,
        'doctorName': doctorName,
        'medicalCenterName': medicalCenterName,
        'appointments': appointments, // Include appointments
      },
      options: Options(
        contentType: 'application/json',
      ),
    );

    print('✅ Queue start response: ${response.statusCode}');
    print('📦 Response data: ${response.data}');

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to start queue: ${response.statusCode}');
    }
  } on DioException catch (e) {
    print('❌ Dio error: ${e.message}');
    if (e.response != null) {
      print('❌ Response data: ${e.response?.data}');
      print('❌ Response status: ${e.response?.statusCode}');
    }
    throw Exception('Dio error: ${e.message}');
  } catch (e) {
    print('❌ General error: $e');
    throw Exception('Network error: $e');
  }
}

  // Get queue by schedule
  static Future<Map<String, dynamic>> getQueueBySchedule(String scheduleId) async {
    try {
      print('📋 Getting queue for schedule: $scheduleId');
      
      final response = await _dio.get(
        '$baseUrl/queue/schedule/$scheduleId',
      );

      print('✅ Queue get response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get queue: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Dio error getting queue: ${e.message}');
      throw Exception('Dio error: ${e.message}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get queue for patient
  static Future<Map<String, dynamic>> getQueueForPatient(String patientId) async {
    try {
      print('📋 Getting queue for patient: $patientId');
      
      final response = await _dio.get(
        '$baseUrl/queue/patient/$patientId',
      );

      print('✅ Patient queue response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get patient queue: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Dio error getting patient queue: ${e.message}');
      throw Exception('Dio error: ${e.message}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Patient check-in
  static Future<Map<String, dynamic>> patientCheckIn(String patientId, String scheduleId) async {
    try {
      print('👤 Patient check-in: $patientId, Schedule: $scheduleId');
      
      final response = await _dio.post(
        '$baseUrl/queue/checkin',
        data: {
          'patientId': patientId,
          'scheduleId': scheduleId,
        },
        options: Options(
          contentType: 'application/json',
        ),
      );

      print('✅ Check-in response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to check in patient: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Dio error check-in: ${e.message}');
      throw Exception('Dio error: ${e.message}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Move to next patient
  static Future<Map<String, dynamic>> nextPatient(String queueId) async {
    try {
      print('⏭️ Moving to next patient in queue: $queueId');
      
      final response = await _dio.post(
        '$baseUrl/queue/next',
        data: {'queueId': queueId},
        options: Options(
          contentType: 'application/json',
        ),
      );

      print('✅ Next patient response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to move to next patient: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Dio error next patient: ${e.message}');
      throw Exception('Dio error: ${e.message}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}