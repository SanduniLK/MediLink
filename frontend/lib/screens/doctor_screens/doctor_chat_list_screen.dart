// doctor_chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/chat_service.dart';
import 'doctor_chat_screen.dart';

class DoctorChatListScreen extends StatefulWidget {
  const DoctorChatListScreen({super.key});

  @override
  State<DoctorChatListScreen> createState() => _DoctorChatListScreenState();
}

class _DoctorChatListScreenState extends State<DoctorChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _realPatients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealPatients();
  }

  Future<void> _loadRealPatients() async {
    setState(() {
      _isLoading = true;
    });
    
    final user = _auth.currentUser;
    if (user != null) {
      final patients = await _chatService.getRealPatientsForDoctor(user.uid);
      setState(() {
        _realPatients = patients;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
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
        title: Text('Patient Chats'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRealPatients,
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _realPatients.isNotEmpty 
              ? _buildRealPatientsList(user.uid)
              : _buildChatRoomsFallback(user.uid),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createRealChatRooms(user.uid),
        child: Icon(Icons.sync),
        backgroundColor: Color(0xFF18A3B6),
        tooltip: 'Sync with real patients',
      ),
    );
  }

  Widget _buildRealPatientsList(String doctorId) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'My Patients (${_realPatients.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _realPatients.length,
            itemBuilder: (context, index) {
              final patient = _realPatients[index];
              return _buildRealPatientItem(patient, doctorId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRealPatientItem(Map<String, dynamic> patient, String doctorId) {
    final patientName = patient['patientName'] ?? 'Patient';
    final patientId = patient['patientId'];
    final sessionId = patient['sessionId'];
    final appointmentData = patient['appointmentData'] ?? {};
    final date = appointmentData['date'] ?? '';
    final timeSlot = appointmentData['timeSlot'] ?? '';
    final status = appointmentData['status'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF18A3B6),
          child: Text(patientName[0], style: TextStyle(color: Colors.white)),
        ),
        title: Text(patientName, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date.isNotEmpty) Text('Appointment: $date at $timeSlot'),
            if (status.isNotEmpty) 
              Text('Status: ${status.replaceAll('-', ' ')}', 
                   style: TextStyle(color: _getStatusColor(status))),
            Text('Tap to start chat', style: TextStyle(color: Colors.green)),
          ],
        ),
        trailing: Icon(Icons.chat, color: Color(0xFF18A3B6)),
        onTap: () => _openOrCreateChat(patientId, patientName, doctorId, sessionId),
      ),
    );
  }

  Widget _buildChatRoomsFallback(String doctorId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getDoctorChatRooms(doctorId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final chatRooms = snapshot.data ?? [];

        if (chatRooms.isEmpty) {
          return _buildEmptyState(doctorId);
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
    final patientName = chatRoom['patientName'] ?? 'Patient';
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
          child: Text(patientName[0], style: TextStyle(color: Colors.white)),
        ),
        title: Text(patientName, style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _openOrCreateChat(String patientId, String patientName, String doctorId, String sessionId) async {
    try {
      final chatRoomId = _chatService.generateChatRoomId(patientId, doctorId);
      
      await _chatService.ensureChatRoomExists(
        chatRoomId: chatRoomId,
        patientId: patientId,
        patientName: patientName,
        doctorId: doctorId,
        doctorName: await _chatService.getDoctorName(doctorId),
        appointmentId: sessionId,
      );

      _openChat({
        'id': chatRoomId,
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': await _chatService.getDoctorName(doctorId),
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
        builder: (context) => DoctorChatScreen(
          chatRoomId: chatRoom['id'],
          patientName: chatRoom['patientName'],
          patientId: chatRoom['patientId'],
          doctorId: user.uid,
          doctorName: chatRoom['doctorName'] ?? 'Dr. Reshika',
        ),
      ),
    );
  }

  Future<void> _createRealChatRooms(String doctorId) async {
    try {
      await _chatService.createChatRoomsFromRealAppointments(doctorId);
      await _loadRealPatients(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat rooms synced with real patients!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled': return Colors.blue;
      case 'confirmed': return Colors.orange;
      case 'in-progress': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildEmptyState(String doctorId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text('No patient chats', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('You will see patients here when you have appointments'),
          Text('or tap the sync button to check for appointments'),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _createRealChatRooms(doctorId),
            child: Text('Sync with Appointments'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF18A3B6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}