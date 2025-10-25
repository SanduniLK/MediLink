import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/chat_message.dart';

class ChatService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Ensure chat room exists in Realtime Database
  Future<void> ensureChatRoomExists(String chatRoomId) async {
    try {
      final chatRoomRef = _database.ref().child('chatRooms').child(chatRoomId);
      final snapshot = await chatRoomRef.get();
      
      if (!snapshot.exists) {
        await chatRoomRef.set({
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'participants': {
            'doctor': true,
            'patient': true,
          },
          'lastMessage': '',
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
        });
        debugPrint('✅ Realtime DB: Chat room created: $chatRoomId');
      } else {
        debugPrint('✅ Realtime DB: Chat room already exists: $chatRoomId');
      }
    } catch (e) {
      debugPrint('❌ Realtime DB Error ensuring chat room: $e');
      rethrow;
    }
  }

  // Send message to Realtime Database
  Future<void> sendMessage({
    required String chatRoomId,
    required String messageText,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    required String senderRole,
    String? filePath,
    bool isFileMessage = false,
  }) async {
    try {
      final messagesRef = _database.ref()
        .child('chatRooms')
        .child(chatRoomId)
        .child('messages');
      
      // Generate unique message ID
      final newMessageRef = messagesRef.push();
      
      final messageData = {
        'text': messageText,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
        'chatRoomId': chatRoomId,
        'isFileMessage': isFileMessage,
        'filePath': filePath,
      };
      
      await newMessageRef.set(messageData);
      
      // Update last message in chat room
      await _database.ref()
        .child('chatRooms')
        .child(chatRoomId)
        .update({
          'lastMessage': messageText,
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
        });
      
      debugPrint('✅ Realtime DB: Message sent successfully');
      
    } catch (e) {
      debugPrint('❌ Realtime DB Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream from Realtime Database
  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    try {
      final messagesRef = _database.ref()
        .child('chatRooms')
        .child(chatRoomId)
        .child('messages')
        .orderByChild('timestamp');
      
      return messagesRef.onValue.map((event) {
        final messages = <ChatMessage>[];
        
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          
          if (data != null) {
            data.forEach((key, value) {
              try {
                final messageData = Map<String, dynamic>.from(value as Map);
                final message = ChatMessage.fromMap(messageData, key.toString());
                messages.add(message);
              } catch (e) {
                debugPrint('❌ Realtime DB Error parsing message $key: $e');
              }
            });
          }
        }
        
        // Sort by timestamp (oldest first)
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        debugPrint('📥 Realtime DB: Stream update - ${messages.length} messages');
        
        return messages;
      });
    } catch (e) {
      debugPrint('❌ Realtime DB Error getting messages stream: $e');
      return Stream.value([]);
    }
  }

  // Mark messages as read in Realtime Database
  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      final messagesRef = _database.ref()
        .child('chatRooms')
        .child(chatRoomId)
        .child('messages');
      
      final snapshot = await messagesRef.get();
      
      if (snapshot.exists) {
        final updates = <String, dynamic>{};
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        data.forEach((key, value) {
          final messageData = Map<String, dynamic>.from(value as Map);
          if (messageData['senderId'] != userId && (messageData['read'] == false || messageData['read'] == null)) {
            updates['$key/read'] = true;
          }
        });
        
        if (updates.isNotEmpty) {
          await messagesRef.update(updates);
          debugPrint('✅ Realtime DB: Marked messages as read');
        }
      }
    } catch (e) {
      debugPrint('❌ Realtime DB Error marking messages as read: $e');
    }
  }

  // File message methods for Realtime Database
  Future<void> sendFileMessageSimple({
    required String chatRoomId,
    required String fileName,
    required String fileType,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    required String senderRole,
  }) async {
    await sendMessage(
      chatRoomId: chatRoomId,
      messageText: '📎 $fileName',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      senderRole: senderRole,
      filePath: 'simple://$fileName',
      isFileMessage: true,
    );
  }

  // Check file in Realtime Database
  Future<Map<String, dynamic>> checkFileInRealtimeDB(String filePath) async {
    // For Realtime Database file storage check
    return {'exists': filePath.contains('chat_files/')};
  }

  // Download file from Realtime Database
  Future<Uint8List> downloadFileFromRealtimeDB(String filePath) async {
    // This would need your actual file download logic
    // For now, return dummy data
    return Uint8List.fromList('Demo file content from Realtime DB'.codeUnits);
  }

  // Pick and send file with Realtime Database
  Future<void> pickAndSendFileWithRealtimeDB({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    required String senderRole,
  }) async {
    // Your file picking logic here
    // For now, send a demo file message
    await sendFileMessageSimple(
      chatRoomId: chatRoomId,
      fileName: 'document.pdf',
      fileType: 'pdf',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      senderRole: senderRole,
    );
  }

  // TEST METHOD: Check Realtime Database connection
  Future<void> testRealtimeDBConnection(String chatRoomId) async {
    try {
      final ref = _database.ref().child('chatRooms').child(chatRoomId);
      final snapshot = await ref.get();
      
      debugPrint('🧪 REALTIME DB TEST:');
      debugPrint('   ✅ Connection successful');
      debugPrint('   📊 Chat room exists: ${snapshot.exists}');
      
      if (snapshot.exists) {
        debugPrint('   📊 Chat room data: ${snapshot.value}');
      }
    } catch (e) {
      debugPrint('❌ REALTIME DB TEST FAILED: $e');
    }
  }
}