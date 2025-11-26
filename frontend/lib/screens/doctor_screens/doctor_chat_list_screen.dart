import 'package:firebase_storage/firebase_storage.dart';
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
  final Map<String, int> _unreadCounts = {};

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
    final uniquePatients = _removeDuplicatePatients(patients);
    setState(() {
      _realPatients = uniquePatients;
      _isLoading = false;
    });
    
    // Load profile images for all patients
    _loadProfileImages(uniquePatients);
    // Load unread counts
    _loadUnreadCounts(user.uid);
  } else {
    setState(() {
      _isLoading = false;
    });
  }
}

  // Remove duplicate patients based on patientId
  List<Map<String, dynamic>> _removeDuplicatePatients(List<Map<String, dynamic>> patients) {
    final Map<String, Map<String, dynamic>> uniquePatients = {};
    
    for (final patient in patients) {
      final patientId = patient['patientId'];
      if (patientId != null && !uniquePatients.containsKey(patientId)) {
        uniquePatients[patientId] = patient;
      }
    }
    
    return uniquePatients.values.toList();
  }
Future<void> _loadUnreadCounts(String doctorId) async {
  for (final patient in _realPatients) {
    final patientId = patient['patientId'];
    if (patientId != null) {
      final chatRoomId = _chatService.generateChatRoomId(patientId, doctorId);
      final unreadCount = await _chatService.getUnreadCountForDoctor(chatRoomId, doctorId);
      setState(() {
        _unreadCounts[patientId] = unreadCount;
      });
    }
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
  final profileImageUrl = patientId != null ? _profileImageUrls[patientId] : null;
  final unreadCount = patientId != null ? _unreadCounts[patientId] ?? 0 : 0;

  return Card(
    margin: EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: _buildProfileAvatar(patientName, profileImageUrl),
      title: Text(patientName, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Tap to start chat', style: TextStyle(color: Colors.green)),
      trailing: _buildMessageCounter(unreadCount), 
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
        final uniqueChatRooms = _removeDuplicateChatRooms(chatRooms);

        if (uniqueChatRooms.isEmpty) {
          return _buildEmptyState(doctorId);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: uniqueChatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = uniqueChatRooms[index];
            return _buildChatItem(chatRoom);
          },
        );
      },
    );
  }
Widget _buildMessageCounter(int unreadCount) {
  if (unreadCount > 0) {
    return Stack(
      children: [
        Icon(Icons.chat, color: Color(0xFF18A3B6)),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )
      ],
    );
  } else {
    return Icon(Icons.chat, color: Color(0xFF18A3B6));
  }
}
  // Remove duplicate chat rooms based on patientId
  List<Map<String, dynamic>> _removeDuplicateChatRooms(List<Map<String, dynamic>> chatRooms) {
    final Map<String, Map<String, dynamic>> uniqueChatRooms = {};
    
    for (final chatRoom in chatRooms) {
      final patientId = chatRoom['patientId'];
      if (patientId != null && !uniqueChatRooms.containsKey(patientId)) {
        uniqueChatRooms[patientId] = chatRoom;
      }
    }
    
    return uniqueChatRooms.values.toList();
  }

 Widget _buildChatItem(Map<String, dynamic> chatRoom) {
  final patientName = chatRoom['patientName'] ?? 'Patient';
  final patientId = chatRoom['patientId'];
  final lastMessage = chatRoom['lastMessage'] ?? 'No messages yet';
  final lastMessageTime = chatRoom['lastMessageTime'] != null 
      ? DateFormat('MMM dd, HH:mm').format(
          DateTime.fromMillisecondsSinceEpoch(chatRoom['lastMessageTime']))
      : '';
  final profileImageUrl = patientId != null ? _profileImageUrls[patientId] : null;
  final unreadCount = patientId != null ? _unreadCounts[patientId] ?? 0 : 0;

  return Card(
    margin: EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: _buildProfileAvatar(patientName, profileImageUrl),
      title: Text(patientName, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lastMessage,
            style: TextStyle(
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (lastMessageTime.isNotEmpty) 
            Text(lastMessageTime, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: _buildMessageCounter(unreadCount), // Updated this line
      onTap: () => _openChat(chatRoom),
    ),
  );
}

  void _openOrCreateChat(String patientId, String patientName, String doctorId, String sessionId) async {
    try {
      // Use the same chat room ID generation
      final chatRoomId = _chatService.generateChatRoomId(patientId, doctorId);
      
      debugPrint('🔑 Generated Chat Room ID: $chatRoomId');
      debugPrint('   Patient ID: $patientId');
      debugPrint('   Doctor ID: $doctorId');
      
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
  final FirebaseStorage _storage = FirebaseStorage.instance;
final Map<String, String> _profileImageUrls = {};
// Load profile images for patients
Future<void> _loadProfileImages(List<Map<String, dynamic>> patients) async {
  for (final patient in patients) {
    final patientId = patient['patientId'];
    if (patientId != null) {
      try {
        final imageUrl = await _getProfileImageUrl(patientId);
        if (imageUrl != null) {
          setState(() {
            _profileImageUrls[patientId] = imageUrl;
          });
        }
      } catch (e) {
        print('Error loading profile image for patient $patientId: $e');
      }
    }
  }
}

// Get profile image URL from Firebase Storage
Future<String?> _getProfileImageUrl(String patientId) async {
  try {
    // List all files in the patient's profile images directory
    final ref = _storage.ref().child('patient_profile_images/$patientId');
    final result = await ref.listAll();
    
    // Get the first image file (assuming there's only one profile image per patient)
    if (result.items.isNotEmpty) {
      final imageRef = result.items.first;
      return await imageRef.getDownloadURL();
    }
    return null;
  } catch (e) {
    print('No profile image found for patient $patientId: $e');
    return null;
  }
}

// Profile avatar widget
Widget _buildProfileAvatar(String patientName, String? profileImageUrl) {
  if (profileImageUrl != null) {
    return CircleAvatar(
      backgroundColor: Color(0xFF18A3B6),
      backgroundImage: NetworkImage(profileImageUrl),
      child: profileImageUrl.isEmpty 
          ? Text(
              patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
              style: TextStyle(color: Colors.white)
            )
          : null,
    );
  } else {
    return CircleAvatar(
      backgroundColor: Color(0xFF18A3B6),
      child: Text(
        patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
        style: TextStyle(color: Colors.white)
      ),
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