import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/chat_service.dart';
import 'package:frontend/telemedicine/telemedicine_chat_screen.dart';
import 'package:frontend/model/telemedicine_session.dart';

class TelemedicineScreen extends StatefulWidget {
  const TelemedicineScreen({super.key});

  @override
  State<TelemedicineScreen> createState() => _TelemedicineScreenState();
}

class _TelemedicineScreenState extends State<TelemedicineScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Telemedicine Sessions'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('telemedicine_sessions')
            .where('patientId', isEqualTo: user.uid)
            .where('status', whereIn: ['Scheduled', 'confirmed', 'In-Progress'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Color(0xFF18A3B6)));
          }

          final sessions = snapshot.data?.docs ?? [];
          
          if (sessions.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final sessionDoc = sessions[index];
              final sessionData = sessionDoc.data() as Map<String, dynamic>;
              final sessionId = sessionDoc.id;
              
              return _buildSessionCard(sessionId, sessionData);
            },
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(String sessionId, Map<String, dynamic> sessionData) {
    final doctorName = sessionData['doctorName'] ?? 'Doctor';
    final date = sessionData['date'] ?? '';
    final timeSlot = sessionData['timeSlot'] ?? '';
    final status = sessionData['status'] ?? 'Scheduled';
    final videoLink = sessionData['videoLink'] ?? '';
    final chatRoomId = sessionData['chatRoomId'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dr. $doctorName',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Date: $date'),
            Text('Time: $timeSlot'),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openChatScreen(sessionId, sessionData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF18A3B6),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Open Chat'),
                  ),
                ),
                SizedBox(width: 8),
                if (videoLink.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _joinVideoCall(videoLink),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Join Call'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openChatScreen(String sessionId, Map<String, dynamic> sessionData) {
  try {
    final user = _auth.currentUser;
    if (user == null) return;

    final patientName = user.displayName ?? 'Patient';
    final patientId = user.uid;
    final doctorName = sessionData['doctorName'] ?? 'Doctor';
    final doctorId = sessionData['doctorId'] ?? '';
    
    // Generate chat room ID
    final chatRoomId = _chatService.generateChatRoomId(patientId, doctorId);

    // Initialize chat room
    _chatService.ensureChatRoomExists(
      chatRoomId: chatRoomId,
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      doctorName: doctorName,
      appointmentId: sessionId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelemedicineChatScreen(
          sessionId: sessionId,
          patientId: patientId,
          patientName: patientName,
          doctorId: doctorId,
          doctorName: doctorName,
          chatRoomId: chatRoomId,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error opening chat: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error opening chat: $e')),
    );
  }
}

  void _joinVideoCall(String videoLink) {
    // Implement video call joining logic
    print('Joining video call: $videoLink');
    // You can use url_launcher package here
    // launchUrlString(videoLink);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'in-progress':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No telemedicine sessions',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Your scheduled sessions will appear here',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}