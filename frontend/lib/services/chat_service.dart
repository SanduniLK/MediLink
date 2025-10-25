// services/chat_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  late final FirebaseDatabase _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ChatService() {
    _database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: 'https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );
  }

  // ========== DATABASE CONNECTION & TESTING ==========
  
  Future<bool> testDatabaseConnection() async {
    try {
      debugPrint('🔌 Testing Realtime Database connection...');
      debugPrint('📡 Database URL: https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app/');
      
      final testRef = _database.ref('connection_test');
      await testRef.set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'connected',
        'message': 'Database is working!',
        'test': 'success'
      });
      
      final snapshot = await testRef.get();
      if (snapshot.exists) {
        debugPrint('✅ Realtime Database connection SUCCESSFUL!');
        await testRef.remove();
        return true;
      } else {
        debugPrint('❌ Realtime Database connection FAILED');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Realtime Database ERROR: $e');
      return false;
    }
  }

  // ========== CHAT ROOM MANAGEMENT ==========

  String generateChatRoomId(String patientId, String doctorId) {
    List<String> ids = [patientId, doctorId]..sort();
    return 'chat_${ids.join('_')}';
  }

  Future<void> ensureChatRoomExists({
    required String chatRoomId,
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    String? appointmentId,
  }) async {
    try {
      final chatRoomRef = _database.ref('chatRooms/$chatRoomId');
      final snapshot = await chatRoomRef.get();
      
      if (!snapshot.exists) {
        debugPrint('🚀 Creating new chat room: $chatRoomId');
        
        await chatRoomRef.set({
          'id': chatRoomId,
          'patientId': patientId,
          'patientName': patientName,
          'doctorId': doctorId,
          'doctorName': doctorName,
          'appointmentId': appointmentId ?? '',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'lastMessage': 'Chat started',
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
          'lastMessageSender': '',
          'participants': {
            patientId: true,
            doctorId: true,
          }
        });

        debugPrint('✅ Chat room created successfully: $chatRoomId');
      } else {
        debugPrint('✅ Chat room already exists: $chatRoomId');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring chat room: $e');
      rethrow;
    }
  }

  // ========== MESSAGE MANAGEMENT ==========

  Future<void> sendMessage({
    required String chatRoomId,
    required String message,
    required String senderId,
    required String senderName,
    required String senderRole,
  }) async {
    try {
      final messagesRef = _database.ref('chatRooms/$chatRoomId/messages').push();
      final messageId = messagesRef.key!;
      
      await messagesRef.set({
        'id': messageId,
        'text': message,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      });

      // Update last message
      await _database.ref('chatRooms/$chatRoomId').update({
        'lastMessage': message,
        'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
        'lastMessageSender': senderName,
      });

      debugPrint('✅ Message sent to: $chatRoomId');
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  // ========== STREAMS FOR REAL-TIME UPDATES ==========

  Stream<List<Map<String, dynamic>>> getMessages(String chatRoomId) {
    return _database.ref('chatRooms/$chatRoomId/messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final messages = <Map<String, dynamic>>[];
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            final messageData = Map<String, dynamic>.from(value as Map);
            messages.add(messageData);
          });
        }
      }
      
      // Sort by timestamp (oldest first)
      messages.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
      return messages;
    });
  }

  Stream<List<Map<String, dynamic>>> getDoctorChatRooms(String doctorId) {
    return _database.ref('chatRooms')
        .orderByChild('doctorId')
        .equalTo(doctorId)
        .onValue
        .map((event) {
      final chatRooms = <Map<String, dynamic>>[];
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            final chatRoomData = Map<String, dynamic>.from(value as Map);
            chatRoomData['id'] = key.toString();
            chatRooms.add(chatRoomData);
          });
        }
      }
      
      // Sort by last message time (newest first)
      chatRooms.sort((a, b) => (b['lastMessageTime'] ?? 0).compareTo(a['lastMessageTime'] ?? 0));
      return chatRooms;
    });
  }

  Stream<List<Map<String, dynamic>>> getPatientChatRooms(String patientId) {
    return _database.ref('chatRooms')
        .orderByChild('patientId')
        .equalTo(patientId)
        .onValue
        .map((event) {
      final chatRooms = <Map<String, dynamic>>[];
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            final chatRoomData = Map<String, dynamic>.from(value as Map);
            chatRoomData['id'] = key.toString();
            chatRooms.add(chatRoomData);
          });
        }
      }
      
      // Sort by last message time (newest first)
      chatRooms.sort((a, b) => (b['lastMessageTime'] ?? 0).compareTo(a['lastMessageTime'] ?? 0));
      return chatRooms;
    });
  }

  // ========== REAL PATIENT/DOCTOR DATA ==========

  Future<List<Map<String, dynamic>>> getRealPatientsForDoctor(String doctorId) async {
    try {
      debugPrint('👥 Fetching real patients for doctor: $doctorId');
      
      final appointmentsSnapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', whereIn: ['Scheduled', 'confirmed', 'In-Progress'])
          .get();

      final patients = <Map<String, dynamic>>[];
      
      for (final appointment in appointmentsSnapshot.docs) {
        final appointmentData = appointment.data();
        final patientId = appointmentData['patientId'];
        final patientName = appointmentData['patientName'];
        final sessionId = appointment.id;
        
        if (patientId != null && patientName != null) {
          patients.add({
            'patientId': patientId,
            'patientName': patientName,
            'sessionId': sessionId,
            'appointmentData': appointmentData,
          });
        }
      }
      
      debugPrint('✅ Found ${patients.length} real patients');
      return patients;
    } catch (e) {
      debugPrint('❌ Error fetching real patients: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRealDoctorsForPatient(String patientId) async {
    try {
      debugPrint('👨‍⚕️ Fetching real doctors for patient: $patientId');
      
      final appointmentsSnapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('patientId', isEqualTo: patientId)
          .where('status', whereIn: ['Scheduled', 'confirmed', 'In-Progress'])
          .get();

      final doctors = <Map<String, dynamic>>[];
      
      for (final appointment in appointmentsSnapshot.docs) {
        final appointmentData = appointment.data();
        final doctorId = appointmentData['doctorId'];
        final doctorName = appointmentData['doctorName'];
        final sessionId = appointment.id;
        
        if (doctorId != null && doctorName != null) {
          doctors.add({
            'doctorId': doctorId,
            'doctorName': doctorName,
            'sessionId': sessionId,
            'appointmentData': appointmentData,
          });
        }
      }
      
      debugPrint('✅ Found ${doctors.length} real doctors');
      return doctors;
    } catch (e) {
      debugPrint('❌ Error fetching real doctors: $e');
      return [];
    }
  }

  Future<void> createChatRoomsFromRealAppointments(String doctorId) async {
    try {
      debugPrint('🎯 Creating chat rooms from real appointments for doctor: $doctorId');
      
      final realPatients = await getRealPatientsForDoctor(doctorId);
      
      if (realPatients.isEmpty) {
        debugPrint('📭 No real patients found with active appointments');
        return;
      }

      for (final patient in realPatients) {
        final chatRoomId = generateChatRoomId(patient['patientId'], doctorId);
        
        await ensureChatRoomExists(
          chatRoomId: chatRoomId,
          patientId: patient['patientId'],
          patientName: patient['patientName'],
          doctorId: doctorId,
          doctorName: 'Dr. Reshika',
          appointmentId: patient['sessionId'],
        );

        debugPrint('✅ Chat room ready for ${patient['patientName']}');
      }

      debugPrint('✅ Created ${realPatients.length} chat rooms from real appointments');
    } catch (e) {
      debugPrint('❌ Error creating chat rooms from appointments: $e');
    }
  }

  // ========== SAMPLE DATA (FOR TESTING) ==========

  Future<void> createSampleChatRooms(String doctorId) async {
    try {
      debugPrint('🎯 Creating sample chat rooms for doctor: $doctorId');
      
      final samples = [
        {
          'patientId': 'patient_sample_1',
          'patientName': 'John Smith',
        },
        {
          'patientId': 'patient_sample_2', 
          'patientName': 'Sarah Johnson',
        },
        {
          'patientId': 'patient_sample_3',
          'patientName': 'Michael Brown',
        }
      ];

      for (final patient in samples) {
        final chatRoomId = generateChatRoomId(patient['patientId']!, doctorId);
        
        await ensureChatRoomExists(
          chatRoomId: chatRoomId,
          patientId: patient['patientId']!,
          patientName: patient['patientName']!,
          doctorId: doctorId,
          doctorName: 'Dr. Reshika',
        );

        // Add welcome message
        await sendMessage(
          chatRoomId: chatRoomId,
          message: 'Hello ${patient['patientName']}! How can I help you today?',
          senderId: doctorId,
          senderName: 'Dr. Reshika',
          senderRole: 'doctor',
        );

        // Add sample patient response
        await Future.delayed(Duration(milliseconds: 500));
        await sendMessage(
          chatRoomId: chatRoomId,
          message: 'Hello Doctor, I have a question about my prescription.',
          senderId: patient['patientId']!,
          senderName: patient['patientName']!,
          senderRole: 'patient',
        );
      }

      debugPrint('✅ Created ${samples.length} sample chat rooms');
    } catch (e) {
      debugPrint('❌ Error creating samples: $e');
    }
  }

  // ========== SYNC & INITIALIZATION ==========

  Future<void> syncChatRoomsFromSessions(String userId) async {
    try {
      debugPrint('🔄 Syncing chat rooms for user: $userId');
      
      // Test connection first
      final isConnected = await testDatabaseConnection();
      if (!isConnected) {
        debugPrint('❌ Database not available, skipping sync');
        return;
      }

      // Check user role
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final role = userData?['role'] ?? '';
      
      if (role == 'doctor') {
        debugPrint('👨‍⚕️ User is doctor, creating chat rooms from real appointments');
        await createChatRoomsFromRealAppointments(userId);
      } else if (role == 'patient') {
        debugPrint('👤 User is patient, chat rooms will be created from doctor side');
        // For patients, we just ensure existing chat rooms are accessible
      }
      
      debugPrint('✅ Chat rooms synced successfully');
    } catch (e) {
      debugPrint('❌ Error syncing chat rooms: $e');
    }
  }

  // ========== DEBUG & UTILITY METHODS ==========

  Future<void> debugViewChatRooms() async {
    try {
      debugPrint('🔍 === DEBUG: VIEWING ALL CHAT ROOMS ===');
      
      final chatRoomsRef = _database.ref('chatRooms');
      final snapshot = await chatRoomsRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          debugPrint('📊 Found ${data.length} chat rooms:');
          data.forEach((key, value) {
            debugPrint('   - $key: ${value.toString()}');
          });
        } else {
          debugPrint('📊 No chat rooms found');
        }
      } else {
        debugPrint('📊 No chat rooms found in database');
      }
    } catch (e) {
      debugPrint('❌ Error debugging chat rooms: $e');
    }
  }
Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
  try {
    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages');
    final snapshot = await messagesRef.get();
    
    if (snapshot.exists) {
      final updates = <String, dynamic>{};
      final data = snapshot.value as Map<dynamic, dynamic>;
      
      data.forEach((key, value) {
        final message = Map<String, dynamic>.from(value as Map);
        if (message['senderId'] != userId && (message['read'] == false || message['read'] == null)) {
          updates['$key/read'] = true;
        }
      });
      
      if (updates.isNotEmpty) {
        await messagesRef.update(updates);
        debugPrint('✅ Marked messages as read in $chatRoomId');
      }
    }
  } catch (e) {
    debugPrint('❌ Error marking messages as read: $e');
  }
}

// Get unread message count
Stream<int> getUnreadMessageCount(String chatRoomId, String userId) {
  return _database.ref('chatRooms/$chatRoomId/messages')
      .onValue
      .map((event) {
    int unreadCount = 0;
    
    if (event.snapshot.exists) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        data.forEach((key, value) {
          final message = Map<String, dynamic>.from(value as Map);
          if (message['senderId'] != userId && (message['read'] == false || message['read'] == null)) {
            unreadCount++;
          }
        });
      }
    }
    
    return unreadCount;
  });
}
  

  // Get doctor name from Firestore
  Future<String> getDoctorName(String doctorId) async {
    try {
      final doctorDoc = await _firestore.collection('users').doc(doctorId).get();
      final doctorData = doctorDoc.data();
      return doctorData?['name'] ?? doctorData?['displayName'] ?? 'Dr. Reshika';
    } catch (e) {
      debugPrint('❌ Error getting doctor name: $e');
      return 'Dr. Reshika';
    }
  }

  // Get patient name from Firestore
  Future<String> getPatientName(String patientId) async {
    try {
      final patientDoc = await _firestore.collection('users').doc(patientId).get();
      final patientData = patientDoc.data();
      return patientData?['name'] ?? patientData?['displayName'] ?? 'Patient';
    } catch (e) {
      debugPrint('❌ Error getting patient name: $e');
      return 'Patient';
    }
  }
}