import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class ChatService {
   late final FirebaseDatabase _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  ChatService() {
   _database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: 'https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );
    debugPrint('✅ ChatService initialized with asia-southeast1 region');
  }
    

  



  Future<bool> testDatabaseConnection() async {
    try {
      debugPrint('🔌 Testing Realtime Database connection to asia-southeast1...');
      
      final testRef = _database.ref('connection_test');
      await testRef.set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'connected',
        'region': 'asia-southeast1'
      });
      
      final snapshot = await testRef.get();
      if (snapshot.exists) {
        debugPrint('✅ Realtime Database connection SUCCESSFUL! (asia-southeast1)');
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
    // Get chat room details to identify receiver
    final chatRoomRef = _database.ref('chatRooms/$chatRoomId');
    final chatRoomSnapshot = await chatRoomRef.get();
    
    if (!chatRoomSnapshot.exists) {
      throw Exception('Chat room not found');
    }

    final chatRoomData = Map<String, dynamic>.from(
      chatRoomSnapshot.value as Map<dynamic, dynamic>
    );

    String receiverId = '';
    String receiverName = '';

    // Determine receiver based on sender role
    if (senderRole == 'doctor') {
      receiverId = chatRoomData['patientId'] ?? '';
      receiverName = await getPatientName(receiverId);
    } else {
      receiverId = chatRoomData['doctorId'] ?? '';
      receiverName = await getDoctorName(receiverId);
    }
     final actualSenderName = senderRole == 'doctor' 
        ? await getDoctorName(senderId)
        : await getPatientName(senderId);

    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages').push();
    final messageId = messagesRef.key!;
    
    final messageData = {
      'id': messageId,
      'text': message,
      'senderId': senderId,
      'senderName': actualSenderName,
      
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'read': false,
      'chatRoomId': chatRoomId,
    };

    await messagesRef.set(messageData);

    // Update last message
    await _database.ref('chatRooms/$chatRoomId').update({
      'lastMessage': message,
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
      'lastMessageSender': senderName,
    });

    debugPrint('✅ Message sent to: $chatRoomId');
    debugPrint('   Sender: $senderName ($senderId)');
    debugPrint('   Receiver: $receiverName ($receiverId)');
  } catch (e) {
    debugPrint('❌ Error sending message: $e');
    rethrow;
  }
}
Future<List<Map<String, dynamic>>> getUserChatRooms(String userId) async {
  try {
    debugPrint('🔍 Fetching chat rooms for user: $userId');
    
    final chatRoomsRef = _database.ref('chatRooms');
    final snapshot = await chatRoomsRef.get();
    
    final chatRooms = <Map<String, dynamic>>[];
    
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>?;
      
      if (data != null) {
        data.forEach((key, value) {
          try {
            final chatRoomData = Map<String, dynamic>.from(value as Map);
            
            // Check if user is participant in this chat room
            final participants = chatRoomData['participants'] as Map<dynamic, dynamic>? ?? {};
            final patientId = chatRoomData['patientId'];
            final doctorId = chatRoomData['doctorId'];
            
            if (participants[userId] == true || patientId == userId || doctorId == userId) {
              chatRoomData['id'] = key.toString();
              chatRooms.add(chatRoomData);
            }
          } catch (e) {
            debugPrint('❌ Error parsing chat room $key: $e');
          }
        });
      }
    }
    
    // Sort by last message time (newest first)
    chatRooms.sort((a, b) {
      final timeA = a['lastMessageTime'] ?? 0;
      final timeB = b['lastMessageTime'] ?? 0;
      return timeB.compareTo(timeA);
    });
    
    debugPrint('✅ Found ${chatRooms.length} chat rooms for user: $userId');
    return chatRooms;
  } catch (e) {
    debugPrint('❌ Error getting user chat rooms: $e');
    return [];
  }
}
  // ========== FILE UPLOAD METHODS ==========

  Future<String> uploadFile({
    required File file,
    required String chatRoomId,
    required String fileName,
    required String senderId,
  }) async {
    try {
      debugPrint('📤 Uploading file: $fileName to chat: $chatRoomId');
      
      final String fileExtension = fileName.split('.').last.toLowerCase();
      final String storagePath = 'chat_files/$chatRoomId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference storageRef = _storage.ref().child(storagePath);

      final String contentType = _getContentType(fileExtension);

      final UploadTask uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ File uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading file: $e');
      rethrow;
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
// ========== STREAMS FOR REAL-TIME UPDATES ==========

Stream<List<Map<String, dynamic>>> getMessages(String chatRoomId) {
  try {
    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages');
    
    return messagesRef.onValue.map((event) {
      final messages = <Map<String, dynamic>>[];
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        
        if (data != null) {
          data.forEach((key, value) {
            try {
              final messageData = Map<String, dynamic>.from(value as Map);
              messageData['id'] = key.toString(); // Ensure ID is included
              messages.add(messageData);
            } catch (e) {
              debugPrint('❌ Error parsing message $key: $e');
            }
          });
        }
      }
      
      // Sort by timestamp (oldest first)
      messages.sort((a, b) {
        final timestampA = a['timestamp'] ?? 0;
        final timestampB = b['timestamp'] ?? 0;
        return timestampA.compareTo(timestampB);
      });
      
      debugPrint('📥 Realtime DB: Stream update - ${messages.length} messages');
      
      return messages;
    });
  } catch (e) {
    debugPrint('❌ Realtime DB Error getting messages stream: $e');
    return Stream.value([]);
  }
}
Future<void> debugChatRoom(String chatRoomId) async {
  try {
    final ref = _database.ref('chatRooms/$chatRoomId');
    final snapshot = await ref.get();
    
    debugPrint('🔍 DEBUG CHAT ROOM: $chatRoomId');
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      debugPrint('📊 Chat room data: $data');
    } else {
      debugPrint('📊 Chat room does not exist');
    }
  } catch (e) {
    debugPrint('❌ Error debugging chat room: $e');
  }
}

Future<void> debugAllMessages(String chatRoomId) async {
  try {
    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages');
    final snapshot = await messagesRef.get();
    
    debugPrint('🔍 DEBUG MESSAGES FOR: $chatRoomId');
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>?;
      debugPrint('📨 Messages count: ${data?.length ?? 0}');
      if (data != null) {
        data.forEach((key, value) {
          debugPrint('   - $key: ${value.toString()}');
        });
      }
    } else {
      debugPrint('📨 No messages found');
    }
  } catch (e) {
    debugPrint('❌ Error debugging messages: $e');
  }
}

Future<int> getTotalUnreadCountForDoctor(String doctorId) async {
  try {
    debugPrint('🔍 Getting total unread count for doctor: $doctorId');
    
    int totalUnread = 0;
    
    // Get all chat rooms where this doctor is a participant
    final chatRoomsRef = _database.ref('chatRooms');
    final chatRoomsSnapshot = await chatRoomsRef.get();
    
    if (chatRoomsSnapshot.exists) {
      final data = chatRoomsSnapshot.value as Map<dynamic, dynamic>?;
      
      if (data != null) {
        for (final chatRoomEntry in data.entries) {
          final chatRoomId = chatRoomEntry.key;
          final chatRoomData = Map<String, dynamic>.from(chatRoomEntry.value as Map);
          
          // Check if this doctor is in this chat room
          final chatRoomDoctorId = chatRoomData['doctorId'];
          if (chatRoomDoctorId == doctorId) {
            // Get unread count for this specific chat room
            
          }
        }
      }
    }
    
    debugPrint('✅ Total doctor unread count: $totalUnread');
    return totalUnread;
  } catch (e) {
    debugPrint('❌ Error getting total doctor unread count: $e');
    return 0;
  }
}

  // ========== FILE PICKER METHODS ==========

 Future<File?> pickImage() async {
  try {
    // Check and request permission
    if (!kIsWeb) {
      final PermissionStatus status = await Permission.photos.status;
      if (!status.isGranted) {
        final PermissionStatus requestedStatus = await Permission.photos.request();
        if (!requestedStatus.isGranted) {
          throw Exception('Photo library permission denied. Please enable it in settings.');
        }
      }
    }

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  } catch (e) {
    debugPrint('❌ Error picking image: $e');
    rethrow;
  }
}


Future<File?> pickDocument() async {
  try {
    // For document picking, we don't need storage permission on newer Android versions
    // FilePicker handles permissions internally
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      
      // Check file size (limit to 10MB)
      if (await file.length() > 10 * 1024 * 1024) {
        throw Exception('File size too large. Please select a file smaller than 10MB.');
      }
      
      return file;
    }
    return null;
  } catch (e) {
    debugPrint('❌ Error picking document: $e');
    rethrow;
  }
}


  Future<File?> pickCameraImage() async {
  try {
    // Check and request camera permission
    if (!kIsWeb) {
      final PermissionStatus cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        final PermissionStatus requestedStatus = await Permission.camera.request();
        if (!requestedStatus.isGranted) {
          throw Exception('Camera permission denied. Please enable it in settings.');
        }
      }
    }

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  } catch (e) {
    debugPrint('❌ Error taking photo: $e');
    rethrow;
  }
}
  // ========== SEND FILE MESSAGE ==========

  Future<void> sendFileMessage({
    required String chatRoomId,
    required File file,
    required String fileName,
    required String senderId,
    required String senderName,
    required String senderRole,
  }) async {
    try {
      debugPrint('📨 Sending file message: $fileName');

      final String fileUrl = await uploadFile(
        file: file,
        chatRoomId: chatRoomId,
        fileName: fileName,
        senderId: senderId,
      );

      final String fileExtension = fileName.split('.').last.toLowerCase();
      final String fileType = _getFileType(fileExtension);

      final messagesRef = _database.ref('chatRooms/$chatRoomId/messages').push();
      final messageId = messagesRef.key!;

      await messagesRef.set({
        'id': messageId,
        'type': 'file',
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': await file.length(),
        'text': 'Sent a file: $fileName',
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      });

      await _database.ref('chatRooms/$chatRoomId').update({
        'lastMessage': '📎 $fileName',
        'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
        'lastMessageSender': senderName,
      });

      debugPrint('✅ File message sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending file message: $e');
      rethrow;
    }
  }

  String _getFileType(String extension) {
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      return 'image';
    } else if (extension == 'pdf') {
      return 'pdf';
    } else if (['doc', 'docx'].contains(extension)) {
      return 'document';
    } else if (extension == 'txt') {
      return 'text';
    } else {
      return 'file';
    }
  }

  // ========== DOWNLOAD AND OPEN FILES ==========

 Future<void> downloadAndOpenFile(String fileUrl, String fileName) async {
  try {
    debugPrint('📥 Downloading file: $fileName from: $fileUrl');

    // For web, just open the URL in new tab
    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(fileUrl))) {
        await launchUrl(
          Uri.parse(fileUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch $fileUrl');
      }
      return;
    }

    // For Android/iOS - download and open
    try {
      // Get the download directory
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/$fileName');

      debugPrint('💾 Saving file to: ${tempFile.path}');

      // Download the file
      final http.Response response = await http.get(Uri.parse(fileUrl));
      
      if (response.statusCode == 200) {
        // Write to file
        await tempFile.writeAsBytes(response.bodyBytes);
        debugPrint('✅ File downloaded successfully: ${tempFile.path}');

        // Open the file
        final OpenResult result = await OpenFile.open(tempFile.path);
        
        if (result.type != ResultType.done) {
          debugPrint('❌ Error opening file: ${result.message}');
          
          // If opening fails, try to save to downloads folder
          await _saveToDownloads(tempFile, fileName);
        } else {
          debugPrint('✅ File opened successfully');
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error with file operations: $e');
      // Fallback: try to open the URL directly
      if (await canLaunchUrl(Uri.parse(fileUrl))) {
        await launchUrl(Uri.parse(fileUrl));
      } else {
        rethrow;
      }
    }
  } catch (e) {
    debugPrint('❌ Error downloading/opening file: $e');
    rethrow;
  }
}
Future<void> _saveToDownloads(File tempFile, String fileName) async {
  try {
    if (Platform.isAndroid) {
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final File newFile = File('${downloadsDir.path}/$fileName');
        await tempFile.copy(newFile.path);
        debugPrint('✅ File saved to downloads: ${newFile.path}');
        
        // Try to open the saved file
        final OpenResult result = await OpenFile.open(newFile.path);
        if (result.type != ResultType.done) {
          throw Exception('Could not open file even after saving to downloads');
        }
      } else {
        throw Exception('Could not access downloads directory');
      }
    } else {
      throw Exception('File opening not supported on this platform');
    }
  } catch (e) {
    debugPrint('❌ Error saving to downloads: $e');
    rethrow;
  }
}

  // ========== GET FILE SIZE FORMAT ==========

  String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1048576) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
  }

  // ========== DELETE FILE ==========

  Future<void> deleteFile(String fileUrl) async {
    try {
      final Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      debugPrint('✅ File deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      rethrow;
    }
  }

  // ========== STREAMS FOR REAL-TIME UPDATES ==========

  

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

        await sendMessage(
          chatRoomId: chatRoomId,
          message: 'Hello ${patient['patientName']}! How can I help you today?',
          senderId: doctorId,
          senderName: 'Dr. Reshika',
          senderRole: 'doctor',
        );

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
      
      final isConnected = await testDatabaseConnection();
      if (!isConnected) {
        debugPrint('❌ Database not available, skipping sync');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final role = userData?['role'] ?? '';
      
      if (role == 'doctor') {
        debugPrint('👨‍⚕️ User is doctor, creating chat rooms from real appointments');
        await createChatRoomsFromRealAppointments(userId);
      } else if (role == 'patient') {
        debugPrint('👤 User is patient, chat rooms will be created from doctor side');
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
      
      // Get chat room info to identify roles
      final chatRoomSnapshot = await _database.ref('chatRooms/$chatRoomId').get();
      String? patientId = '';
      String? doctorId = '';
      
      if (chatRoomSnapshot.exists) {
        final chatRoomData = Map<String, dynamic>.from(
          chatRoomSnapshot.value as Map<dynamic, dynamic>
        );
        patientId = chatRoomData['patientId'];
        doctorId = chatRoomData['doctorId'];
      }
      
      data.forEach((key, value) {
        final message = Map<String, dynamic>.from(value as Map);
        
        // FIXED: Mark as read if:
        // If user is doctor, mark patient's messages as read
        // If user is patient, mark doctor's messages as read
        if (userId == doctorId && message['senderId'] == patientId && 
            (message['read'] == false || message['read'] == null)) {
          updates['$key/read'] = true;
          updates['$key/readAt'] = DateTime.now().millisecondsSinceEpoch;
        } else if (userId == patientId && message['senderId'] == doctorId && 
            (message['read'] == false || message['read'] == null)) {
          updates['$key/read'] = true;
          updates['$key/readAt'] = DateTime.now().millisecondsSinceEpoch;
        }
      });
      
      if (updates.isNotEmpty) {
        await messagesRef.update(updates);
        debugPrint('✅ Marked ${updates.length ~/ 2} messages as read in $chatRoomId');
      }
    }
  } catch (e) {
    debugPrint('❌ Error marking messages as read: $e');
  }
}
Future<void> debugUnreadMessages(String chatRoomId, String doctorId) async {
  try {
    debugPrint('🔍 DEBUG: Unread messages analysis for doctor $doctorId');
    
    final chatRoomSnapshot = await _database.ref('chatRooms/$chatRoomId').get();
    if (!chatRoomSnapshot.exists) {
      debugPrint('   ❌ Chat room not found');
      return;
    }
    
    final chatRoomData = Map<String, dynamic>.from(
      chatRoomSnapshot.value as Map<dynamic, dynamic>
    );
    
    final patientId = chatRoomData['patientId'];
    final doctorIdInChat = chatRoomData['doctorId'];
    
    debugPrint('   👤 Patient ID: $patientId');
    debugPrint('   👨‍⚕️ Doctor ID in chat: $doctorIdInChat');
    debugPrint('   👨‍⚕️ Current doctor: $doctorId');
    
    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages');
    final snapshot = await messagesRef.get();
    
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        debugPrint('   📊 Total messages: ${data.length}');
        
        int patientMessages = 0;
        int doctorMessages = 0;
        int unreadFromPatient = 0;
        
        data.forEach((key, value) {
          final message = Map<String, dynamic>.from(value as Map);
          final senderId = message['senderId'];
          final readStatus = message['read'];
          final text = message['text']?.toString().substring(0, math.min(30, message['text']?.toString().length ?? 0)) ?? '';
          
          if (senderId == patientId) {
            patientMessages++;
            if (readStatus == false || readStatus == null) {
              unreadFromPatient++;
              debugPrint('   🔴 UNREAD from patient: "$text..." (read: $readStatus)');
            } else {
              debugPrint('   ✅ READ from patient: "$text..." (read: $readStatus)');
            }
          } else if (senderId == doctorId) {
            doctorMessages++;
            debugPrint('   💬 From doctor: "$text..." (read: $readStatus)');
          } else {
            debugPrint('   ❓ From unknown ($senderId): "$text..."');
          }
        });
        
        debugPrint('   📊 Summary:');
        debugPrint('     - Patient messages: $patientMessages');
        debugPrint('     - Doctor messages: $doctorMessages');
        debugPrint('     - Unread from patient: $unreadFromPatient');
        
        // Calculate what should be shown
        final correctUnreadCount = unreadFromPatient;
        debugPrint('   ✅ Correct unread count should be: $correctUnreadCount');
      }
    } else {
      debugPrint('   📭 No messages in chat room');
    }
  } catch (e) {
    debugPrint('❌ Debug error: $e');
  }
}


  Stream<int> getUnreadCount(String chatRoomId, String userId) {
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
    
    debugPrint('📊 Unread count for $chatRoomId: $unreadCount');
    return unreadCount;
  });
}
Future<int> getTotalUnreadCount(String userId, String userType) async {
  try {
    debugPrint('📊 Getting total unread count for user: $userId ($userType)');
    
    int totalUnread = 0;
    
    // Get all chat rooms where this user is a participant
    final chatRoomsRef = _database.ref('chatRooms');
    final chatRoomsSnapshot = await chatRoomsRef.get();
    
    if (chatRoomsSnapshot.exists) {
      final data = chatRoomsSnapshot.value as Map<dynamic, dynamic>?;
      
      if (data != null) {
        // Filter chat rooms where user is a participant
        for (final chatRoomEntry in data.entries) {
          final chatRoomId = chatRoomEntry.key;
          final chatRoomData = Map<String, dynamic>.from(chatRoomEntry.value as Map);
          
          // Check if user is in this chat room
          final participants = chatRoomData['participants'] as Map<dynamic, dynamic>? ?? {};
          final patientId = chatRoomData['patientId'];
          final doctorId = chatRoomData['doctorId'];
          
          bool isUserInChat = false;
          if (userType == 'doctor') {
            isUserInChat = doctorId == userId || participants[userId] == true;
          } else if (userType == 'patient') {
            isUserInChat = patientId == userId || participants[userId] == true;
          } else {
            // For admin, check if they have access to this medical center
            // You'll need to implement admin logic based on your structure
          }
          
          if (isUserInChat) {
            // Get unread messages count for this chat room
            final unreadCount = await getUnreadCountForUser(chatRoomId, userId);
            totalUnread += unreadCount;
          }
        }
      }
    }
    
    debugPrint('📊 Total unread messages: $totalUnread');
    return totalUnread;
  } catch (e) {
    debugPrint('❌ Error getting total unread count: $e');
    return 0;
  }
}
Future<int> getUnreadCountForUser(String chatRoomId, String userId) async {
  try {
    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages');
    final snapshot = await messagesRef.get();
    
    int unreadCount = 0;
    
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        data.forEach((key, value) {
          final message = Map<String, dynamic>.from(value as Map);
          // Count as unread if:
          // 1. Message is from other user
          // 2. Message is not read (read == false or null)
          if (message['senderId'] != userId && 
              (message['read'] == false || message['read'] == null)) {
            unreadCount++;
          }
        });
      }
    }
    
    return unreadCount;
  } catch (e) {
    debugPrint('❌ Error getting unread count for user: $e');
    return 0;
  }
}
Future<int> getUnreadCountForDoctorInChatRoom(String chatRoomId, String doctorId) async {
  try {
    debugPrint('🔍 Getting unread count for doctor $doctorId in chat room $chatRoomId');
    
    // First, get the chat room to identify patient ID
    final chatRoomRef = _database.ref('chatRooms/$chatRoomId');
    final chatRoomSnapshot = await chatRoomRef.get();
    
    if (!chatRoomSnapshot.exists) {
      return 0;
    }
    
    final chatRoomData = Map<String, dynamic>.from(
      chatRoomSnapshot.value as Map<dynamic, dynamic>
    );
    final patientId = chatRoomData['patientId'];
    
    if (patientId == null) {
      return 0;
    }
    
    // Get all messages
    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages');
    final messagesSnapshot = await messagesRef.get();
    
    int unreadCount = 0;
    
    if (messagesSnapshot.exists) {
      final messagesData = messagesSnapshot.value as Map<dynamic, dynamic>?;
      
      if (messagesData != null) {
        messagesData.forEach((key, value) {
          final message = Map<String, dynamic>.from(value as Map);
          final senderId = message['senderId'];
          final readStatus = message['read'] ?? false;
          
          // Count as unread if:
          // 1. Message is from patient (not doctor)
          // 2. Message is not read
          if (senderId == patientId && readStatus == false) {
            unreadCount++;
          }
        });
      }
    }
    
    debugPrint('✅ Unread count for doctor in $chatRoomId: $unreadCount');
    return unreadCount;
  } catch (e) {
    debugPrint('❌ Error getting unread count: $e');
    return 0;
  }
}

Stream<int> getTotalUnreadCountStream(String userId, String userType) {
  return Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
    return await getTotalUnreadCount(userId, userType);
  }).distinct();
}
Stream<int> getUnreadCountStream(String chatRoomId, String doctorId) {
  return _database.ref('chatRooms/$chatRoomId/messages')
      .onValue
      .asyncMap((event) async {
    try {
      // Get the patient ID from chat room
      final chatRoomRef = _database.ref('chatRooms/$chatRoomId');
      final chatRoomSnapshot = await chatRoomRef.get();
      
      if (!chatRoomSnapshot.exists) {
        return 0;
      }
      
      final chatRoomData = Map<String, dynamic>.from(
        chatRoomSnapshot.value as Map<dynamic, dynamic>
      );
      final patientId = chatRoomData['patientId'];
      
      if (patientId == null) {
        return 0;
      }
      
      int unreadCount = 0;
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          data.forEach((key, value) {
            final message = Map<String, dynamic>.from(value as Map);
            final senderId = message['senderId'];
            final readStatus = message['read'] ?? false;
            
            if (senderId == patientId && readStatus == false) {
              unreadCount++;
            }
          });
        }
      }
      
      return unreadCount;
    } catch (e) {
      debugPrint('❌ Error in unread count stream: $e');
      return 0;
    }
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
Future<bool> hasUnreadMessagesForDoctor(String chatRoomId, String doctorId) async {
  try {
    debugPrint('🔍 Checking for unread messages in $chatRoomId for doctor: $doctorId');
    
    // Get the chat room to identify patient ID
    final chatRoomRef = _database.ref('chatRooms/$chatRoomId');
    final chatRoomSnapshot = await chatRoomRef.get();
    
    if (!chatRoomSnapshot.exists) {
      return false;
    }
    
    final chatRoomData = Map<String, dynamic>.from(
      chatRoomSnapshot.value as Map<dynamic, dynamic>
    );
    final patientId = chatRoomData['patientId'];
    
    if (patientId == null) {
      return false;
    }
    
    // Get all messages
    final messagesRef = _database.ref('chatRooms/$chatRoomId/messages');
    final messagesSnapshot = await messagesRef.get();
    
    if (messagesSnapshot.exists) {
      final messagesData = messagesSnapshot.value as Map<dynamic, dynamic>?;
      
      if (messagesData != null) {
        for (final entry in messagesData.entries) {
          final message = Map<String, dynamic>.from(entry.value as Map);
          final senderId = message['senderId'];
          final readStatus = message['read'] ?? false;
          
          // If any message is from patient and not read, return true
          if (senderId == patientId && readStatus == false) {
            debugPrint('✅ Found unread message from patient in $chatRoomId');
            return true;
          }
        }
      }
    }
    
    return false;
  } catch (e) {
    debugPrint('❌ Error checking unread messages: $e');
    return false;
  }
}
Stream<bool> getUnreadStatusStream(String chatRoomId, String userId) {
  return _database.ref('chatRooms/$chatRoomId/messages')
      .onValue
      .asyncMap((event) async {
    try {
      // Get the chat room to identify the other user
      final chatRoomRef = _database.ref('chatRooms/$chatRoomId');
      final chatRoomSnapshot = await chatRoomRef.get();
      
      if (!chatRoomSnapshot.exists) {
        return false;
      }
      
      final chatRoomData = Map<String, dynamic>.from(
        chatRoomSnapshot.value as Map<dynamic, dynamic>
      );
      
      String otherUserId = '';
      
      // Determine who the other user is based on current user's role
      if (userId == chatRoomData['doctorId']) {
        otherUserId = chatRoomData['patientId'] ?? '';
      } else if (userId == chatRoomData['patientId']) {
        otherUserId = chatRoomData['doctorId'] ?? '';
      } else {
        return false; // User not in this chat
      }
      
      if (otherUserId.isEmpty) {
        return false;
      }
      
      // Check for unread messages from the other user
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          for (final entry in data.entries) {
            final message = Map<String, dynamic>.from(entry.value as Map);
            final senderId = message['senderId'];
            final readStatus = message['read'] ?? false;
            
            if (senderId == otherUserId && readStatus == false) {
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error in unread status stream: $e');
      return false;
    }
  });
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