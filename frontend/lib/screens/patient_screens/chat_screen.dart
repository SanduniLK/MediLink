// patient_chat_list_screen.dart - Updated for real doctors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/chat_service.dart';
import 'package:frontend/telemedicine/telemedicine_chat_screen.dart';

class PatientChatListScreen extends StatefulWidget {
  const PatientChatListScreen({super.key});

  @override
  State<PatientChatListScreen> createState() => _PatientChatListScreenState();
}

class _PatientChatListScreenState extends State<PatientChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _realDoctors = [];

  @override
  void initState() {
    super.initState();
    _loadRealDoctors();
  }

  Future<void> _loadRealDoctors() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doctors = await _chatService.getRealDoctorsForPatient(user.uid);
      setState(() {
        _realDoctors = doctors;
      });
    }
  }

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
        title: Text('My Doctors'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: _realDoctors.isNotEmpty 
          ? _buildRealDoctorsList()
          : _buildChatRoomsFallback(user.uid),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRealDoctors,
        child: Icon(Icons.refresh),
        backgroundColor: Color(0xFF18A3B6),
      ),
    );
  }

  Widget _buildRealDoctorsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _realDoctors.length,
      itemBuilder: (context, index) {
        final doctor = _realDoctors[index];
        return _buildRealDoctorItem(doctor);
      },
    );
  }

  Widget _buildRealDoctorItem(Map<String, dynamic> doctor) {
    final doctorName = doctor['doctorName'] ?? 'Doctor';
    final doctorId = doctor['doctorId'];
    final sessionId = doctor['sessionId'];
    final appointmentData = doctor['appointmentData'] ?? {};
    final date = appointmentData['date'] ?? '';
    final status = appointmentData['status'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF18A3B6),
          child: Icon(Icons.medical_services, color: Colors.white),
        ),
        title: Text('Dr. $doctorName', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date.isNotEmpty) Text('Next appointment: $date'),
            if (status.isNotEmpty) 
              Text('Status: $status', style: TextStyle(color: _getStatusColor(status))),
            Text('Tap to chat', style: TextStyle(color: Colors.green)),
          ],
        ),
        trailing: Icon(Icons.chat, color: Color(0xFF18A3B6)),
        onTap: () => _openOrCreateChat(doctorId, doctorName, sessionId),
      ),
    );
  }

  Widget _buildChatRoomsFallback(String patientId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getPatientChatRooms(patientId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final chatRooms = snapshot.data ?? [];

        if (chatRooms.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = chatRooms[index];
            return _buildChatItem(chatRoom);
          },
        );
      },
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chatRoom) {
    final doctorName = chatRoom['doctorName'] ?? 'Doctor';
    final lastMessage = chatRoom['lastMessage'] ?? 'No messages yet';
    final lastMessageTime = chatRoom['lastMessageTime'] != null 
        ? DateFormat('MMM dd, HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(chatRoom['lastMessageTime']))
        : '';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF18A3B6),
          child: Icon(Icons.medical_services, color: Colors.white),
        ),
        title: Text('Dr. $doctorName', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lastMessage),
            if (lastMessageTime.isNotEmpty) 
              Text(lastMessageTime, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Icon(Icons.chat, color: Color(0xFF18A3B6)),
        onTap: () => _openChat(chatRoom),
      ),
    );
  }

  void _openOrCreateChat(String doctorId, String doctorName, String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final chatRoomId = _chatService.generateChatRoomId(user.uid, doctorId);
      
      await _chatService.ensureChatRoomExists(
        chatRoomId: chatRoomId,
        patientId: user.uid,
        patientName: user.displayName ?? 'Patient',
        doctorId: doctorId,
        doctorName: doctorName,
        appointmentId: sessionId,
      );

      _openChat({
        'id': chatRoomId,
        'patientId': user.uid,
        'patientName': user.displayName ?? 'Patient',
        'doctorId': doctorId,
        'doctorName': doctorName,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  void _openChat(Map<String, dynamic> chatRoom) {
    final user = _auth.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelemedicineChatScreen(
          sessionId: chatRoom['appointmentId'] ?? '',
          patientId: user.uid,
          patientName: chatRoom['patientName'] ?? 'Patient',
          doctorId: chatRoom['doctorId'] ?? '',
          doctorName: chatRoom['doctorName'] ?? 'Doctor',
          chatRoomId: chatRoom['id'],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled': return Colors.blue;
      case 'confirmed': return Colors.orange;
      case 'in-progress': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text('No doctors yet', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Book an appointment to start chatting with doctors'),
        ],
      ),
    );
  }
}