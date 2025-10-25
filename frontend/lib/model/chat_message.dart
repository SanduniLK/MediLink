class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String receiverId;
  final String receiverName;
  final DateTime timestamp;
  final bool read;
  final String chatRoomId;
  final bool isFileMessage;
  final String? filePath;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.receiverName,
    required this.timestamp,
    required this.read,
    required this.chatRoomId,
    this.isFileMessage = false,
    this.filePath,
  });

  // From Realtime Database
  factory ChatMessage.fromRealtimeDB(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['id'] ?? '',
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      read: data['read'] ?? false,
      chatRoomId: data['chatRoomId'] ?? '',
      isFileMessage: data['isFileMessage'] ?? false,
      filePath: data['filePath'],
    );
  }

  // From Map (for backward compatibility)
  factory ChatMessage.fromMap(Map<String, dynamic> data, String id) {
    DateTime timestamp;
    if (data['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
    } else {
      timestamp = DateTime.now();
    }
        
    return ChatMessage(
      id: id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      timestamp: timestamp,
      read: data['read'] ?? false,
      chatRoomId: data['chatRoomId'] ?? '',
      isFileMessage: data['isFileMessage'] ?? false,
      filePath: data['filePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'read': read,
      'chatRoomId': chatRoomId,
      'isFileMessage': isFileMessage,
      'filePath': filePath,
    };
  }
}