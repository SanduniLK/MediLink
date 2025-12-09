// Replace the entire DoctorChatListScreen with this simplified version:

import 'dart:async';
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
  final Map<String, bool> _hasUnreadMessages = {};
  final Map<String, StreamSubscription> _unreadSubscriptions = {};
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, String> _profileImageUrls = {};

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
      
      // Load profile images
      _loadProfileImages(uniquePatients);
      // Setup unread listeners
      _setupUnreadListeners(user.uid, uniquePatients);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    _unreadSubscriptions.values.forEach((sub) => sub.cancel());
    super.dispose();
  }

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

  void _setupUnreadListeners(String doctorId, List<Map<String, dynamic>> patients) {
    // Cancel existing subscriptions
    _unreadSubscriptions.values.forEach((sub) => sub.cancel());
    _unreadSubscriptions.clear();
    
    // Set up new subscriptions
    for (final patient in patients) {
      final patientId = patient['patientId'];
      if (patientId != null) {
        final chatRoomId = _chatService.generateChatRoomId(patientId, doctorId);
        
        // Listen for unread status changes
        final subscription = _chatService.getUnreadStatusStream(chatRoomId, doctorId)
            .listen((hasUnread) {
          if (mounted) {
            setState(() {
              _hasUnreadMessages[patientId] = hasUnread;
            });
            debugPrint('👤 Patient $patientId has unread: $hasUnread');
          }
        }, onError: (error) {
          debugPrint('❌ Error in unread stream: $error');
        });
        
        _unreadSubscriptions[patientId] = subscription;
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
          // Chat button with red dot if any unread
          StreamBuilder<bool>(
            stream: _getAnyUnreadStream(user.uid),
            builder: (context, snapshot) {
              final hasAnyUnread = snapshot.data ?? false;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.chat),
                    onPressed: () {
                      // Already on chat screen
                    },
                  ),
                  if (hasAnyUnread)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
              : _buildEmptyState(user.uid),
    );
  }

 Stream<bool> _getAnyUnreadStream(String doctorId) {
  return Stream.periodic(Duration(seconds: 10)).asyncMap((_) async {
    try {
      // Check each patient's chat room for unread messages
      for (final patient in _realPatients) {
        final patientId = patient['patientId'];
        if (patientId != null) {
          final chatRoomId = _chatService.generateChatRoomId(patientId, doctorId);
          final hasUnread = await _chatService.hasUnreadMessagesForDoctor(chatRoomId, doctorId);
          if (hasUnread) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking for any unread: $e');
      return false;
    }
  });
}

  Widget _buildRealPatientsList(String doctorId) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _realPatients.length,
      itemBuilder: (context, index) {
        final patient = _realPatients[index];
        return _buildRealPatientItem(patient, doctorId);
      },
    );
  }

  Widget _buildRealPatientItem(Map<String, dynamic> patient, String doctorId) {
    final patientName = patient['patientName'] ?? 'Patient';
    final patientId = patient['patientId'];
    final sessionId = patient['sessionId'];
    final profileImageUrl = patientId != null ? _profileImageUrls[patientId] : null;
    final hasUnread = patientId != null ? (_hasUnreadMessages[patientId] ?? false) : false;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            _buildProfileAvatar(patientName, profileImageUrl),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                patientName,
                style: TextStyle(
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (hasUnread)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'New',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          hasUnread ? 'You have unread messages' : 'Tap to chat',
          style: TextStyle(
            color: hasUnread ? Colors.red : Colors.grey[600],
          ),
        ),
        
        onTap: () => _openOrCreateChat(patientId, patientName, doctorId, sessionId),
      ),
    );
  }

 void _openOrCreateChat(String? patientId, String patientName, String doctorId, String? sessionId) async {
  if (patientId == null) return;
  
  try {
    final chatRoomId = _chatService.generateChatRoomId(patientId, doctorId);
    
    // Get doctor name BEFORE building the widget
    final String doctorName = await _chatService.getDoctorName(doctorId);
    
    await _chatService.ensureChatRoomExists(
      chatRoomId: chatRoomId,
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      doctorName: doctorName,
      appointmentId: sessionId,
    );

    await _chatService.markMessagesAsRead(chatRoomId, doctorId);
    
    if (mounted) {
      setState(() {
        _hasUnreadMessages[patientId] = false;
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorChatScreen(
          chatRoomId: chatRoomId,
          patientName: patientName,
          patientId: patientId,
          doctorId: doctorId,
          doctorName: doctorName,  // Use the already fetched name
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error starting chat: $e')),
    );
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
          SizedBox(height: 20),
        ],
      ),
    );
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
          print('Error loading profile image: $e');
        }
      }
    }
  }

  Future<String?> _getProfileImageUrl(String patientId) async {
    try {
      final ref = _storage.ref().child('patient_profile_images/$patientId');
      final result = await ref.listAll();
      
      if (result.items.isNotEmpty) {
        final imageRef = result.items.first;
        return await imageRef.getDownloadURL();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}