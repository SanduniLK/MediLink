// utils/firestore_setup.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a telemedicine session
  static Future<void> createTelemedicineSession() async {
    try {
      await _firestore.collection('telemedicine_sessions').doc('T1001').set({
        'telemedicineId': 'T1001',
        'doctorId': 'U001',
        'patientId': 'U050',
        'chatRoomId': 'C1001',
        'videoLink': 'https://medilink.app/call/T1001',
        'date': '2025-10-21',
        'timeSlot': '10:00 AM - 10:30 AM',
        'status': 'Scheduled',
        'createdAt': DateTime.now().toIso8601String(),
      });
      print('✅ Telemedicine session created!');
    } catch (e) {
      print('❌ Error creating session: $e');
    }
  }

  // Create chat room and add first message
  static Future<void> createChatRoomWithMessage() async {
    try {
      // Create chat room document
      await _firestore.collection('chat_messages').doc('C1001').set({
        'chatRoomId': 'C1001',
        'telemedicineId': 'T1001',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Add first message to subcollection
      await _firestore
          .collection('chat_messages')
          .doc('C1001')
          .collection('messages')
          .add({
        'senderId': 'U050',
        'text': 'Good morning doctor!',
        'timestamp': DateTime.now().toIso8601String(),
        'chatRoomId': 'C1001',
      });

      print('✅ Chat room and message created!');
    } catch (e) {
      print('❌ Error creating chat room: $e');
    }
  }

  // Initialize all data
  static Future<void> initializeData() async {
    await createTelemedicineSession();
    await createChatRoomWithMessage();
  }
}