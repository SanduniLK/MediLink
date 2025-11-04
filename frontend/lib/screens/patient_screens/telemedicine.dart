// screens/patient_screens/telemedicine.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/chat_service.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/telemedicine_chat_screen.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/incoming_call_screen.dart';

class TelemedicineScreen extends StatefulWidget {
  const TelemedicineScreen({super.key});

  @override
  State<TelemedicineScreen> createState() => _TelemedicineScreenState();
}

class _TelemedicineScreenState extends State<TelemedicineScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final VideoCallService _videoCallService = VideoCallService();
  
  String? _patientName;
  String? _patientId;
  bool _isWebRTCConnected = false;
  bool _isPatientRoomJoined = false;
  final bool _isPhysicalDevice = true; // ✅ FIXED: Made final

  @override
  void initState() {
    super.initState();
    _getPatientInfo();
    _setupCallListener();
  }

  void _getPatientInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _patientId = user.uid;
      });
      
      try {
        final patientDoc = await _firestore.collection('patients').doc(user.uid).get();
        if (patientDoc.exists) {
          final data = patientDoc.data();
          setState(() {
            _patientName = data?['fullName'] ?? data?['name'] ?? user.displayName ?? 'Patient';
          });
          debugPrint('🟢 PATIENT: Found in patients collection: $_patientName');
        } else {
          setState(() {
            _patientName = user.displayName ?? 'Patient';
          });
          debugPrint('🟡 PATIENT: Using user profile name: $_patientName');
        }
      } catch (e) {
        setState(() {
          _patientName = user.displayName ?? 'Patient';
        });
        debugPrint('🔴 PATIENT: Error fetching patient info: $e');
      }
    }
  }

  void _setupCallListener() async {
    debugPrint('🎧 Setting up WebRTC call listener...');
    
    try {
      await _videoCallService.initialize(isPhysicalDevice: _isPhysicalDevice);
      debugPrint('✅ VideoCallService initialized');
      
      // Set up event listeners
      _videoCallService.onConnected = () {
        debugPrint('🎉 WEBRTC FULLY CONNECTED!');
        debugPrint('   Ready for video/audio calls!');
        
        if (mounted) {
          setState(() {
            _isWebRTCConnected = true;
          });
          
          // Auto-join patient room when connected
          _autoJoinPatientRoom();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Video calls are ready!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      };

      _videoCallService.onIncomingCall = (callData) {
        debugPrint('📞 📞 📞 INCOMING CALL! 📞 📞 📞');
        debugPrint('   Room: ${callData['roomId']}');
        debugPrint('   Doctor: ${callData['doctorName']}');
        debugPrint('   Type: ${callData['consultationType']}');
        
        // ✅ FIXED: Use mounted check
        if (mounted) {
          _handleIncomingCall(callData);
        }
      };

      _videoCallService.onError = (error) {
        debugPrint('🔴 WebRTC Error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('WebRTC: $error'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      };

      // Setup debug socket events
      _debugSocketEvents();

    } catch (e) {
      debugPrint('🔴 WebRTC setup error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video calls unavailable: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _debugSocketEvents() {
    debugPrint('🔍 PATIENT: Monitoring socket events...');
    
    _videoCallService.socket.on('call-started', (data) {
      debugPrint('🎉 SOCKET: call-started event received: $data');
    });
    
    _videoCallService.socket.on('incoming-call', (data) {
      debugPrint('🎉 SOCKET: incoming-call event received: $data');
    });
    
    _videoCallService.socket.on('user-joined', (data) {
      debugPrint('👤 SOCKET: user-joined event received: $data');
    });
    
    _videoCallService.socket.onAny((event, data) {
      if (event != 'ice-candidate' && event != 'ping' && event != 'pong') {
        debugPrint('📡 SOCKET: Event "$event" with data: $data');
      }
    });
  }

  void _handleIncomingCall(Map<String, dynamic> callData) {
    final consultationType = callData['consultationType'] ?? 'video';
    final roomId = callData['roomId'] ?? '';
    final doctorName = callData['doctorName'] ?? 'Doctor';
    final doctorId = callData['doctorId'] ?? '';

    debugPrint('🎉 PATIENT: Handling incoming call navigation');
    debugPrint('   - Doctor: $doctorName');
    debugPrint('   - Room ID: $roomId');
    debugPrint('   - Type: $consultationType');

    // ✅ FIXED: Use mounted check
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            callId: roomId,
            doctorName: doctorName,
            doctorId: doctorId,
            patientId: _patientId!,
            patientName: _patientName!,
            consultationType: consultationType,
          ),
        ),
      );
    }
  }

  void _autoJoinPatientRoom() async {
    if (_patientId == null || _patientName == null) {
      debugPrint('🔴 PATIENT: Cannot auto-join room - missing patient info');
      return;
    }

    try {
      debugPrint('🟢 PATIENT: Auto-joining patient room: $_patientId');
      await _videoCallService.joinPatientRoom(_patientId!);
      
      if (mounted) {
        setState(() {
          _isPatientRoomJoined = true;
        });
      }
      
      debugPrint('✅ PATIENT: Auto-joined patient room successfully');
      
      // ✅ FIXED: Use mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ready to receive calls from doctors'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ PATIENT: Error auto-joining patient room: $e');
      if (mounted) {
        setState(() {
          _isPatientRoomJoined = false;
        });
      }
    }
  }

  void _forceJoinRoom() async {
    if (_patientId == null || _patientName == null) {
      debugPrint('🔴 PATIENT: Cannot join room - missing patient info');
      return;
    }

    try {
      debugPrint('🔄 PATIENT: Manually joining patient room...');
      await _videoCallService.joinPatientRoom(_patientId!);
      
      if (mounted) {
        setState(() {
          _isPatientRoomJoined = true;
        });
      }
      
      debugPrint('✅ PATIENT: Successfully joined patient room manually');
      
      // ✅ FIXED: Use mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined patient room - Ready for calls!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ PATIENT: Error manually joining patient room: $e');
      // ✅ FIXED: Use mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _testWebRTCConnection() async {
    await _videoCallService.testWebRTCConnection();
  }

  // 🔥 FIXED: Corrected _joinConsultation method
  void _joinConsultation(String sessionId, Map<String, dynamic> sessionData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doctorName = sessionData['doctorName'] ?? 'Doctor';
    final doctorId = sessionData['doctorId'] ?? '';
    final consultationType = sessionData['consultationType'] ?? 'video';

    debugPrint('🎬 PATIENT: Joining consultation as ANSWERER');
    debugPrint('   - Session ID: $sessionId');
    debugPrint('   - Doctor: $doctorName ($doctorId)');
    debugPrint('   - Patient: $_patientName ($_patientId)');
    debugPrint('   - Type: $consultationType');
    debugPrint('   - Role: ANSWERER - WILL NOT CREATE OFFER');

    try {
      if (!_videoCallService.isConnected) {
        debugPrint('🟡 PATIENT: Call service not connected, initializing...');
        await _videoCallService.initialize();
      }

      // ✅ FIXED: Use regular joinRoom instead of non-existent joinRoomAsAnswerer
      await _videoCallService.joinRoom(
        sessionId, 
        _patientId!,
        _patientName!,
        false // isDoctor = false
      );

      debugPrint('✅ PATIENT: Joined room $sessionId as answerer');
      debugPrint('   👤 Waiting for doctor to initiate call...');

      // ✅ FIXED: Use mounted check before navigation
      if (mounted) {
        // Navigate to call screen - patient will wait for doctor's offer
        if (consultationType == 'video') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                callId: sessionId,
                otherUserName: doctorName,
                otherUserId: doctorId,
                currentUserId: user.uid,
                currentUserName: _patientName!,
                isDoctor: false,
                isIncomingCall: false,
                isVideoCall: true,
                shouldInitiateCall: false, // 🔥 PATIENT DOES NOT INITIATE
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioCallScreen(
                callId: sessionId,
                otherUserName: doctorName,
                otherUserId: doctorId,
                currentUserId: user.uid,
                currentUserName: _patientName!,
                isDoctor: false,
                isIncomingCall: false,
                shouldInitiateCall: false, // 🔥 PATIENT DOES NOT INITIATE
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ PATIENT: Error joining consultation: $e');
      // ✅ FIXED: Use mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ... REST OF YOUR BUILD METHODS REMAIN THE SAME ...
  // _buildConnectionStatusPanel, _buildSessionsList, _buildSessionCard, etc.

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
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: _getConnectionStatusColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getConnectionStatusText(),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Panel
          _buildConnectionStatusPanel(),
          Expanded(
            child: _buildSessionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WebRTC Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _isWebRTCConnected ? Icons.check_circle : Icons.sync,
                color: _isWebRTCConnected ? Colors.green : Colors.orange,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                _isWebRTCConnected ? '🟢 Ready for video calls' : '🟡 Connecting to WebRTC...',
                style: TextStyle(
                  color: _isWebRTCConnected ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _isPatientRoomJoined ? Icons.check_circle : Icons.radio_button_unchecked,
                color: _isPatientRoomJoined ? Colors.green : Colors.grey,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                _isPatientRoomJoined ? '🟢 Listening for calls' : '🟡 Not listening for calls',
                style: TextStyle(
                  color: _isPatientRoomJoined ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text('Server: 192.168.1.126:5001', style: TextStyle(fontSize: 12)),
          Text('Device: Physical', style: TextStyle(fontSize: 12)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testWebRTCConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('Test Connection'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _forceJoinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('Join Room'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_patientId == null) {
      return Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('telemedicine_sessions')
          .where('patientId', isEqualTo: _patientId)
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
        debugPrint('📋 PATIENT: Found ${sessions.length} sessions');

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
    );
  }

  Widget _buildSessionCard(String sessionId, Map<String, dynamic> sessionData) {
    final doctorName = sessionData['doctorName'] ?? 'Doctor';
    final date = sessionData['date'] ?? '';
    final timeSlot = sessionData['timeSlot'] ?? '';
    final status = sessionData['status'] ?? 'Scheduled';
    final tokenNumber = sessionData['tokenNumber'] ?? '';
    final doctorSpecialty = sessionData['doctorSpecialty'] ?? '';
    final consultationType = sessionData['consultationType'] ?? 'video';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. $doctorName',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      doctorSpecialty.isNotEmpty ? doctorSpecialty : 'Doctor',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
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
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('Date: $date'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('Time: $timeSlot'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(consultationType == 'video' ? Icons.videocam : Icons.call, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(consultationType == 'video' ? 'Video Consultation' : 'Audio Consultation'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.confirmation_number, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('Token: #$tokenNumber'),
              ],
            ),
            SizedBox(height: 16),
            
            // DUAL BUTTONS: Chat + Call
            Row(
              children: [
                // Chat Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.chat, size: 20),
                    label: Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF18A3B6),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _openChatScreen(sessionId, sessionData),
                  ),
                ),
                SizedBox(width: 12),
                
                // Call Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      consultationType == 'video' ? Icons.video_call : Icons.call,
                      size: 20,
                    ),
                    label: Text(
                      status == 'In-Progress' 
                          ? 'Join Call' 
                          : 'Start Call'
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isWebRTCConnected ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isWebRTCConnected
                        ? () => _joinConsultation(sessionId, sessionData)
                        : null,
                  ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Telemedicine Sessions',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Your scheduled video consultations will appear here',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          if (!_isWebRTCConnected)
            ElevatedButton(
              onPressed: _setupCallListener,
              child: Text('Connect to Video Calls'),
            ),
        ],
      ),
    );
  }

  Color _getConnectionStatusColor() {
    if (_isPatientRoomJoined && _isWebRTCConnected) return Colors.green;
    if (_videoCallService.isConnected) return Colors.orange;
    return Colors.red;
  }

  String _getConnectionStatusText() {
    if (_isPatientRoomJoined && _isWebRTCConnected) return '🟢 Ready for calls';
    if (_videoCallService.isConnected) return '🟡 Connected, joining room...';
    return '🔴 Disconnected';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled': return Colors.blue;
      case 'confirmed': return Colors.orange;
      case 'in-progress': return Colors.green;
      case 'completed': return Colors.grey;
      default: return Colors.blue;
    }
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
}