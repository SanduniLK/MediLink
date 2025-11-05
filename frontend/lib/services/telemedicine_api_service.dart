// frontend/lib/services/telemedicine_api_service.dart
import 'package:http/http.dart' as http;
import 'api_service.dart';

class TelemedicineApiService {
  static const String baseUrl = "http://10.222.212.133:5001/api";

  // ==================== TELEMEDICINE SESSION MANAGEMENT ====================

  // Get telemedicine sessions for user (patient or doctor)
 static Future<List<dynamic>> getUserSessions(String userId, {String? userType}) async {
    try {
      print('🔍 Fetching telemedicine sessions for $userType: $userId');
      
      final endpoint = userType == 'doctor' 
          ? '/telemedicine/doctor/$userId/sessions'
          : '/telemedicine/patient/$userId/sessions';
      
      final response = await ApiService.getJson(endpoint);
      
      print('✅ Telemedicine sessions response: ${response['sessions']?.length ?? 0} sessions found');
      
      return response['sessions'] ?? [];
    } catch (e) {
      print('❌ Error fetching telemedicine sessions: $e');
      // Fall back to direct Firestore query if API fails
      return await _getSessionsFromFirestore(userId, userType: userType);
    }
  }
  static Future<List<dynamic>> _getSessionsFromFirestore(String userId, {String? userType}) async {
    try {
      print('🔄 Falling back to direct Firestore query for $userType: $userId');
      
      final endpoint = userType == 'doctor' 
          ? '/firestore/telemedicine-sessions?doctorId=$userId'
          : '/firestore/telemedicine-sessions?patientId=$userId';
      
      final response = await ApiService.getJson(endpoint);
      return response['sessions'] ?? [];
    } catch (e) {
      print('❌ Firestore fallback also failed: $e');
      return [];
    }
  }


  // Start telemedicine consultation
  static Future<Map<String, dynamic>> startConsultation({
    required String appointmentId,
    required String doctorId,
    required String consultationType,
  }) async {
    try {
      print('🎬 Starting consultation for appointment: $appointmentId');
      
      final response = await ApiService.post('/telemedicine/start', {
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'consultationType': consultationType,
      });
      
      print('✅ Start consultation response: $response');
      return response;
    } catch (e) {
      print('❌ Error starting consultation: $e');
      rethrow;
    }
  }

  // Join telemedicine consultation
  static Future<Map<String, dynamic>> joinConsultation({
    required String appointmentId,
    required String userId,
  }) async {
    try {
      print('🎯 Joining consultation for appointment: $appointmentId');
      
      final response = await ApiService.post('/telemedicine/join', {
        'appointmentId': appointmentId,
        'userId': userId,
      });
      
      print('✅ Join consultation response: $response');
      return response;
    } catch (e) {
      print('❌ Error joining consultation: $e');
      rethrow;
    }
  }

  // End telemedicine consultation
  static Future<Map<String, dynamic>> endConsultation({
    required String appointmentId,
    required String endedBy,
  }) async {
    try {
      final response = await ApiService.post('/telemedicine/end', {
        'appointmentId': appointmentId,
        'endedBy': endedBy,
      });
      return response;
    } catch (e) {
      print('❌ Error ending consultation: $e');
      rethrow;
    }
  }

  // Get telemedicine session status
  static Future<Map<String, dynamic>> getSession(String appointmentId) async {
    try {
      final response = await ApiService.getJson('/telemedicine/session/$appointmentId');
      return response;
    } catch (e) {
      print('❌ Error getting session: $e');
      rethrow;
    }
  }

  // Get telemedicine service health
  static Future<Map<String, dynamic>> getHealth() async {
    return await ApiService.getJson('/telemedicine/health');
  }

  // Create telemedicine session (if not exists)
  static Future<Map<String, dynamic>> createSession({
    required String appointmentId,
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required String consultationType,
    required String chatRoomId,
    required double fees,
    required String medicalCenterId,
    required String medicalCenterName,
  }) async {
    return await ApiService.post('/telemedicine/create-session', {
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'consultationType': consultationType,
      'chatRoomId': chatRoomId,
      'fees': fees,
      'medicalCenterId': medicalCenterId,
      'medicalCenterName': medicalCenterName,
      'paymentStatus': 'paid',
      'status': 'Scheduled',
    });
  }

  // Check server connectivity
 static Future<bool> checkServerConnectivity() async {
  try {
    // Try multiple endpoints and shorter timeout
    final endpoints = [
      'http://10.222.212.133:5001/health',
      'http://localhost:5001/health',
      'http://127.0.0.1:5001/health',
    ];

    for (final endpoint in endpoints) {
      try {
        print('🔍 Testing connectivity to: $endpoint');
        final response = await http.get(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 3)); // Shorter timeout
        
        if (response.statusCode == 200) {
          print('✅ Server is reachable at: $endpoint');
          return true;
        }
      } catch (e) {
        print('❌ Failed to connect to $endpoint: $e');
        continue; // Try next endpoint
      }
    }
    
    print('❌ All connection attempts failed');
    return false;
  } catch (e) {
    print('❌ Server connectivity check failed: $e');
    return false;
  }
}

  // ==================== ACTIVE CALLS MANAGEMENT ====================

  // Get active calls for user
  static Future<List<dynamic>> getActiveCalls(String userId) async {
    final response = await ApiService.getJson('/telemedicine/active-calls/$userId');
    return response['calls'] ?? [];
  }

  // Update call status
  static Future<Map<String, dynamic>> updateCallStatus({
    required String appointmentId,
    required String status, // 'connecting', 'connected', 'ended'
  }) async {
    return await ApiService.put('/telemedicine/call-status', {
      'appointmentId': appointmentId,
      'status': status,
    });
  }

  // ==================== SESSION MANAGEMENT ====================

  // Check if telemedicine session exists
  static Future<bool> checkSessionExists(String appointmentId) async {
    try {
      final response = await ApiService.getJson('/telemedicine/session/$appointmentId');
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Update telemedicine session
  static Future<Map<String, dynamic>> updateSession({
    required String appointmentId,
    required Map<String, dynamic> updates,
  }) async {
    return await ApiService.put('/telemedicine/session/$appointmentId', updates);
  }

  // ==================== CALL HISTORY ====================

  // Get call history for user
  static Future<List<dynamic>> getCallHistory(String userId, {int limit = 50}) async {
    final response = await ApiService.getJson('/telemedicine/history/$userId?limit=$limit');
    return response['calls'] ?? [];
  }

  // Save call recording metadata
  static Future<Map<String, dynamic>> saveCallRecording({
    required String appointmentId,
    required String recordingUrl,
    required int duration,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    return await ApiService.post('/telemedicine/recording', {
      'appointmentId': appointmentId,
      'recordingUrl': recordingUrl,
      'duration': duration,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
    });
  }

  // ==================== WEBRTC SIGNALING HTTP METHODS ====================

  // Send WebRTC offer to server (HTTP fallback)
  static Future<void> sendWebRTCOffer({
    required String roomId,
    required Map<String, dynamic> offer,
    required String targetUserId,
  }) async {
    await ApiService.post('/webrtc/offer', {
      'roomId': roomId,
      'offer': offer,
      'targetUserId': targetUserId,
    });
  }

  // Send WebRTC answer to server (HTTP fallback)
  static Future<void> sendWebRTCAnswer({
    required String roomId,
    required Map<String, dynamic> answer,
  }) async {
    await ApiService.post('/webrtc/answer', {
      'roomId': roomId,
      'answer': answer,
    });
  }

  // Send ICE candidate to server (HTTP fallback)
  static Future<void> sendICECandidate({
    required String roomId,
    required Map<String, dynamic> candidate,
  }) async {
    await ApiService.post('/webrtc/ice-candidate', {
      'roomId': roomId,
      'candidate': candidate,
    });
  }

  // ==================== UTILITY METHODS ====================

  // Generate unique chat room ID
  static String generateChatRoomId(String patientId, String doctorId) {
    return 'chat_${patientId}_${doctorId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Generate telemedicine session ID
  static String generateSessionId() {
    return 'T${DateTime.now().millisecondsSinceEpoch}';
  }

  // Validate consultation type
  static bool isValidConsultationType(String type) {
    return ['audio', 'video'].contains(type.toLowerCase());
  }

  // Format consultation data for display
  static Map<String, dynamic> formatConsultationData(Map<String, dynamic> session) {
    return {
      'id': session['id'] ?? session['appointmentId'],
      'patientName': session['patientName'],
      'doctorName': session['doctorName'],
      'consultationType': session['consultationType'] ?? 'audio',
      'status': session['status'] ?? 'Scheduled',
      'date': session['date'] ?? session['createdAt'],
      'fees': session['fees'] ?? 0,
      'duration': session['duration'] ?? 0,
      'canStart': session['status'] == 'Scheduled' || session['status'] == 'In-Progress',
    };
  }

  // Enhanced error handling for telemedicine calls
  static Future<Map<String, dynamic>> safeApiCall(
    Future<Map<String, dynamic>> Function() apiCall,
  ) async {
    try {
      return await apiCall();
    } catch (e) {
      print('Telemedicine API Error: $e');
      rethrow;
    }
  }
}