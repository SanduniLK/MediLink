import 'package:cloud_firestore/cloud_firestore.dart';

class FileMessage {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType; // 'image', 'pdf', 'document'
  final int fileSize;
  final String senderId;
  final String senderName;
  final String senderRole;
  final DateTime timestamp;
  final String chatRoomId;

  FileMessage({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.timestamp,
    required this.chatRoomId,
  });

  factory FileMessage.fromMap(Map<String, dynamic> data, String id) {
    Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    
    return FileMessage(
      id: id,
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileType: data['fileType'] ?? 'document',
      fileSize: data['fileSize'] ?? 0,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? 'doctor',
      timestamp: timestamp.toDate(),
      chatRoomId: data['chatRoomId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'timestamp': Timestamp.fromDate(timestamp),
      'chatRoomId': chatRoomId,
    };
  }

  bool get isImage => fileType == 'image';
  bool get isPdf => fileType == 'pdf';
  bool get isDocument => fileType == 'document';
}