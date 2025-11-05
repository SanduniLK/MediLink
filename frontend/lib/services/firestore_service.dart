// frontend/lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get telemedicine sessions for patient (simple query without ordering to avoid index)
  static Stream<List<Map<String, dynamic>>> getPatientSessionsStream(String patientId) {
    return _firestore
        .collection('telemedicine_sessions')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs.map((doc) {
            final data = doc.data();
            return _parseSessionData(doc.id, data);
          }).toList();
          
          // Manual sorting by createdAt in memory
          sessions.sort((a, b) {
            final dateA = a['createdAt'] as DateTime;
            final dateB = b['createdAt'] as DateTime;
            return dateB.compareTo(dateA); // Descending (newest first)
          });
          
          return sessions;
        });
  }

  // Get telemedicine sessions for doctor (simple query without ordering to avoid index)
  static Stream<List<Map<String, dynamic>>> getDoctorSessionsStream(String doctorId) {
    return _firestore
        .collection('telemedicine_sessions')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs.map((doc) {
            final data = doc.data();
            return _parseSessionData(doc.id, data);
          }).toList();
          
          // Manual sorting by createdAt in memory
          sessions.sort((a, b) {
            final dateA = a['createdAt'] as DateTime;
            final dateB = b['createdAt'] as DateTime;
            return dateB.compareTo(dateA); // Descending (newest first)
          });
          
          return sessions;
        });
  }

  // Parse session data with proper date handling
  static Map<String, dynamic> _parseSessionData(String docId, Map<String, dynamic> data) {
    debugPrint('📋 Raw Firestore data for $docId:');
    data.forEach((key, value) {
      debugPrint('   $key: $value (${value.runtimeType})');
    });
    
    return {
      'id': docId,
      ...data,
      // Use the new safe date parser
      'createdAt': _safeParseDate(data['createdAt']),
      'startedAt': _safeParseDate(data['startedAt']),
      'endedAt': _safeParseDate(data['endedAt']),
      'updatedAt': _safeParseDate(data['updatedAt']),
    };
  }

  // Safe date parser that handles all possible formats
  static DateTime _safeParseDate(dynamic dateValue) {
    if (dateValue == null) {
      debugPrint('⚠️ Date value is null, using current time');
      return DateTime.now();
    }
    
    debugPrint('🔍 Parsing date: $dateValue (${dateValue.runtimeType})');
    
    // If it's already a DateTime, return it
    if (dateValue is DateTime) {
      debugPrint('✅ Already DateTime: $dateValue');
      return dateValue;
    }
    
    // If it's a Firestore Timestamp, convert to DateTime
    if (dateValue is Timestamp) {
      final dateTime = dateValue.toDate();
      debugPrint('✅ Converted Timestamp to DateTime: $dateTime');
      return dateTime;
    }
    
    // If it's a String, try to parse it
    if (dateValue is String) {
      try {
        final dateTime = DateTime.parse(dateValue);
        debugPrint('✅ Parsed String to DateTime: $dateTime');
        return dateTime;
      } catch (e) {
        debugPrint('❌ Failed to parse date string: "$dateValue", error: $e');
        
        // Try alternative date formats
        final alternative = _tryAlternativeDateFormats(dateValue);
        if (alternative != null) {
          return alternative;
        }
        
        debugPrint('⚠️ Using current time as fallback');
        return DateTime.now();
      }
    }
    
    debugPrint('❌ Unknown date type: ${dateValue.runtimeType}, using current time');
    return DateTime.now();
  }

  // Try alternative date formats
  static DateTime? _tryAlternativeDateFormats(String dateString) {
    try {
      // Handle "Today (4/11/2025)" format
      if (dateString.toLowerCase().contains('today') || dateString.toLowerCase().contains('tomorrow')) {
        final match = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(dateString);
        if (match != null) {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final year = int.parse(match.group(3)!);
          final dateTime = DateTime(year, month, day);
          debugPrint('✅ Parsed alternative format: $dateTime');
          return dateTime;
        }
      }
      
      // Handle Unix timestamp (milliseconds)
      if (RegExp(r'^\d+$').hasMatch(dateString)) {
        final timestamp = int.tryParse(dateString);
        if (timestamp != null) {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          debugPrint('✅ Parsed Unix timestamp: $dateTime');
          return dateTime;
        }
      }
    } catch (e) {
      debugPrint('❌ Alternative date parsing failed: $e');
    }
    
    return null;
  }

  // Get single session by appointment ID
  static Future<Map<String, dynamic>?> getSessionByAppointmentId(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        return _parseSessionData(doc.id, data);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting session: $e');
      return null;
    }
  }

  // Update session status
  static Future<void> updateSessionStatus({
    required String appointmentId,
    required String status,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (startedAt != null) {
        updateData['startedAt'] = Timestamp.fromDate(startedAt);
      }

      if (endedAt != null) {
        updateData['endedAt'] = Timestamp.fromDate(endedAt);
      }

      // Find the document by appointmentId
      final snapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update(updateData);
        debugPrint('✅ Session status updated to: $status');
      } else {
        debugPrint('❌ Session not found with appointmentId: $appointmentId');
      }
    } catch (e) {
      debugPrint('❌ Error updating session status: $e');
      rethrow;
    }
  }
}