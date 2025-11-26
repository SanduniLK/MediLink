// lib/screens/patient_screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/chat_service.dart';

import 'package:frontend/telemedicine/telemedicine_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  void _loadChatRooms() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'User not logged in';
      });
      return;
    }

    try {
      final chatRooms = await _chatService.getUserChatRooms(user.uid);
      
      // Enhance chat rooms with real names
      final enhancedChatRooms = await _enhanceChatRoomsWithRealNames(chatRooms);
      
      if (mounted) {
        setState(() {
          _chatRooms = enhancedChatRooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load conversations: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _enhanceChatRoomsWithRealNames(
      List<Map<String, dynamic>> chatRooms) async {
    final enhancedChatRooms = <Map<String, dynamic>>[];

    for (final chatRoom in chatRooms) {
      try {
        final doctorId = chatRoom['doctorId'];
        final patientId = chatRoom['patientId'];
        
        // Get real names from Firestore
        final doctorName = await _chatService.getDoctorName(doctorId);
        final patientName = await _chatService.getPatientName(patientId);
        
        enhancedChatRooms.add({
          ...chatRoom,
          'doctorName': doctorName,
          'patientName': patientName,
          'realDoctorName': doctorName, // Store the real name separately
          'realPatientName': patientName,
        });
      } catch (e) {
        debugPrint('❌ Error enhancing chat room: $e');
        // Keep original data if enhancement fails
        enhancedChatRooms.add(chatRoom);
      }
    }

    return enhancedChatRooms;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Conversations'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChatRooms,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _chatRooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No conversations yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start a conversation from Telemedicine',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadChatRooms(),
                      child: ListView.builder(
                        itemCount: _chatRooms.length,
                        itemBuilder: (context, index) {
                          final chatRoom = _chatRooms[index];
                          return _buildChatItem(chatRoom);
                        },
                      ),
                    ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chatRoom) {
    final user = _auth.currentUser;
    final bool isDoctor = user?.uid == chatRoom['doctorId'];
    
    // Use enhanced names with fallback
    final otherPersonName = isDoctor 
        ? chatRoom['realPatientName'] ?? chatRoom['patientName'] ?? 'Patient'
        : chatRoom['realDoctorName'] ?? chatRoom['doctorName'] ?? 'Doctor';
        
    final lastMessage = chatRoom['lastMessage'] ?? 'Start conversation...';
    final lastMessageTime = chatRoom['lastMessageTime'];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF18A3B6),
          child: Icon(
            isDoctor ? Icons.person : Icons.medical_services,
            color: Colors.white,
          ),
        ),
        title: Text(
          otherPersonName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: lastMessageTime != null
            ? Text(
                _formatTime(lastMessageTime),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TelemedicineChatScreen(
                sessionId: chatRoom['appointmentId'] ?? '',
                patientId: chatRoom['patientId'] ?? '',
                patientName: chatRoom['realPatientName'] ?? chatRoom['patientName'] ?? 'Patient',
                doctorId: chatRoom['doctorId'] ?? '',
                doctorName: chatRoom['realDoctorName'] ?? chatRoom['doctorName'] ?? 'Doctor',
                chatRoomId: chatRoom['id'] ?? '',
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(date).inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    } else {
      return '${date.month}/${date.day}';
    }
  }
}