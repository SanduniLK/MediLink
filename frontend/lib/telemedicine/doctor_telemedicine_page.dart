// frontend/lib/telemedicine/doctor_telemedicine_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:frontend/model/telemedicine_session.dart';
import 'package:frontend/screens/doctor_screens/doctor_chat_screen.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';
import 'package:frontend/services/chat_service.dart';
import 'package:frontend/telemedicine/consultation_screen.dart';
import '../../services/firestore_service.dart';

class DoctorTelemedicinePage extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String? scheduleId;

  const DoctorTelemedicinePage({
    super.key,
    required this.doctorId,
    required this.doctorName,
    this.scheduleId,
  });

  @override
  State<DoctorTelemedicinePage> createState() => _DoctorTelemedicinePageState();
}

class _DoctorTelemedicinePageState extends State<DoctorTelemedicinePage> {
  List<TelemedicineSession> _sessions = [];
  List<TelemedicineSession> _filteredSessions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _usingRealData = false;
  StreamSubscription? _sessionsSubscription;
  String _selectedFilter = 'all';

final ChatService _chatService = ChatService();
final Map<String, bool> _hasUnreadMessages = {};
final Map<String, StreamSubscription> _unreadSubscriptions = {};
StreamSubscription? sessionSubscription;
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _veryLightColor = const Color(0xFFDDF0F5);
StreamSubscription<DatabaseEvent>? _sessionSubscription;

  @override
void initState() {
  super.initState();
   
  
  debugPrint('🔄 DoctorTelemedicinePage init for doctor: ${widget.doctorId}');
  debugPrint('Doctor name: ${widget.doctorName}');
  debugPrint('Schedule ID: ${widget.scheduleId}');
  
  // Add a small delay to ensure widget is fully mounted
   WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _loadDoctorSessions();
    }
  });
  
  _setupPatientLeftListener();
  _listenTelemedicineSessions();
}
  @override
void dispose() {
  
  // Properly dispose ALL subscriptions
  for (final subscription in _unreadSubscriptions.values) {
    subscription.cancel();
  }
  _unreadSubscriptions.clear();
  
  _sessionsSubscription?.cancel();
  _sessionsSubscription = null;
  
  // Clear all data
  _sessions.clear();
  _filteredSessions.clear();
  _hasUnreadMessages.clear();
  
  sessionSubscription?.cancel(); 
   _sessionSubscription?.cancel();
  super.dispose();
}
void _listenTelemedicineSessions() {
  // Cancel old listener if exists
  _sessionSubscription?.cancel();

  _sessionSubscription = FirebaseDatabase.instance
      .ref('telemedicine_sessions')
      .onValue
      .listen((event) {
    final data = event.snapshot.value;
    print("Telemedicine data: $data");
    // Add your code to update UI here
  });
}
  void _applyFilter() {
  debugPrint('🎯 Applying filter: $_selectedFilter');
  debugPrint('📊 Total sessions: ${_sessions.length}');
  
  switch (_selectedFilter) {
    case 'scheduled':
      _filteredSessions = _sessions
          .where((session) => session.status.toLowerCase() == 'scheduled')
          .toList();
      break;
    case 'in-progress':
      _filteredSessions = _sessions
          .where((session) => session.status.toLowerCase() == 'in-progress')
          .toList();
      break;
    case 'completed':
      _filteredSessions = _sessions
          .where((session) => session.status.toLowerCase() == 'completed')
          .toList();
      break;
    default:
      _filteredSessions = List.from(_sessions);
  }
  
  debugPrint('✅ Filtered to: ${_filteredSessions.length} sessions');
  debugPrint('📋 Status counts:');
  debugPrint('  - Scheduled: ${_sessions.where((s) => s.status.toLowerCase() == 'scheduled').length}');
  debugPrint('  - In-Progress: ${_sessions.where((s) => s.status.toLowerCase() == 'in-progress').length}');
  debugPrint('  - Completed: ${_sessions.where((s) => s.status.toLowerCase() == 'completed').length}');
}

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  Future<void> _loadDoctorSessions() async {
  try {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    debugPrint('=== DEBUG: _loadDoctorSessions START ===');
    debugPrint('🔄 Loading REAL sessions from Firestore for doctor: ${widget.doctorId}, schedule: ${widget.scheduleId}');

    // First, check if doctor exists
    final doctorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.doctorId)
        .get();
    
    debugPrint('Doctor exists: ${doctorDoc.exists}');
    debugPrint('Doctor data: ${doctorDoc.data()}');
    
    if (!doctorDoc.exists) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Doctor profile not found';
        });
      }
      return;
    }

    // Cancel existing subscription
    _sessionsSubscription?.cancel();

    // Get sessions stream
    final sessionsStream = FirestoreService.getDoctorSessionsStream(
      widget.doctorId,
      scheduleId: widget.scheduleId,
    );
    
    debugPrint('Session stream created');

    _sessionsSubscription = sessionsStream.listen(
      (sessionsData) {
        debugPrint('📊 Stream event: Received ${sessionsData.length} sessions');
        _debugSessionsData(sessionsData);
        _handleSessionsData(sessionsData);
      },
      onError: (error) {
        debugPrint('❌ Stream error: $error');
        _handleSessionsError(error);
      },
      onDone: () {
        debugPrint('✅ Stream completed');
      },
    );

    debugPrint('=== DEBUG: _loadDoctorSessions END ===');
  } catch (e, stackTrace) {
    debugPrint('❌ Error setting up Firestore listener: $e');
    debugPrint('Stack trace: $stackTrace');
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to connect to database: ${e.toString()}';
      });
    }
  }
}

// Add this debug method
void _debugSessionsData(List<Map<String, dynamic>> sessionsData) {
  debugPrint('=== SESSIONS DATA DEBUG ===');
  debugPrint('Total sessions: ${sessionsData.length}');
  
  for (int i = 0; i < sessionsData.length; i++) {
    final session = sessionsData[i];
    debugPrint('Session $i:');
    debugPrint('  - ID: ${session['appointmentId']}');
    debugPrint('  - Patient: ${session['patientName']}');
    debugPrint('  - Doctor ID: ${session['doctorId']}');
    debugPrint('  - Status: ${session['status']}');
    debugPrint('  - Type: ${session['consultationType']}');
  }
  debugPrint('=== END DEBUG ===');
}

  // In DoctorTelemedicinePage - enhanced debug method
  void _debugSessionStatus(TelemedicineSession session) async {
    try {
      debugPrint('🔍 DEBUG SESSION: ${session.appointmentId}');

      // Get the actual document directly
      final doc = await FirebaseFirestore.instance
          .collection('telemedicine_sessions')
          .doc(session.appointmentId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('✅ DOCUMENT EXISTS');
        debugPrint('📊 Full data: $data');
        debugPrint(
          '🎯 patientJoined: ${data['patientJoined']} (type: ${data['patientJoined']?.runtimeType})',
        );
        debugPrint(
          '🎯 doctorJoined: ${data['doctorJoined']} (type: ${data['doctorJoined']?.runtimeType})',
        );
        debugPrint('🎯 status: ${data['status']}');
      } else {
        debugPrint('❌ DOCUMENT NOT FOUND');
      }

      // Also check via service method
      final joinStatus = await FirestoreService.getSessionJoinStatus(
        session.appointmentId,
      );
      debugPrint('🔄 Join status from service: $joinStatus');
    } catch (e) {
      debugPrint('❌ Debug error: $e');
    }
  }
bool _canDoctorJoin(TelemedicineSession session) {
  return session.status == 'In-Progress' || 
         session.status == 'Scheduled' ||
         session.status == 'confirmed';
}

void _handleSessionsData(List<Map<String, dynamic>> sessionsData) {
  if (!mounted) return;
  
  final sessions = sessionsData.map((data) {
    try {
      return TelemedicineSession.fromMap(data);
    } catch (e) {
      debugPrint('❌ Error parsing session: $e');
      return null;
    }
  }).where((session) => session != null).cast<TelemedicineSession>().toList();

  sessions.sort((a, b) {
    if (a.canStart && !b.canStart) return -1;
    if (!a.canStart && b.canStart) return 1;
    return b.createdAt.compareTo(a.createdAt);
  });

  if (mounted) {
    setState(() {
      _sessions = sessions;
      _applyFilter();
      _isLoading = false;
      _usingRealData = true;
      _hasError = false;
    });
    
    // UNCOMMENT THIS:
    if (_sessions.isNotEmpty) {
      _setupUnreadListeners();
    }
  }
}
  void _handleSessionsError(error) {
    debugPrint('❌ Firestore stream error: $error');
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to load sessions: $error';
      });
    }
  }

  // STEP 1: Doctor starts consultation
  Future<void> _startConsultation(TelemedicineSession session) async {
    final currentContext = context;

    try {
      debugPrint(
        '🎬 STEP 1: Doctor Starting Consultation (NOT joining call yet)',
      );

      // Show loading dialog
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _veryLightColor,
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
              const SizedBox(width: 16),
              Text(
                'Starting consultation...',
                style: TextStyle(color: _primaryColor),
              ),
            ],
          ),
        ),
      );

      // STEP 1: Only start consultation and notify patient - DO NOT join call
      await FirestoreService.completeDoctorStartFlow(
        appointmentId: session.appointmentId,
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        patientId: session.patientId,
        consultationType: session.consultationType,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(currentContext, rootNavigator: true).pop();
      }

      // Show success message - DO NOT navigate to call screen
      _showConsultationStartedSuccess(session);

      // Update UI to show waiting for patient
      if (mounted) {
        setState(() {
          // UI will automatically update via stream to show "Patient Joined 👤" and "JOIN MEETING" button
        });
      }

      debugPrint(
        '✅ Consultation started successfully - waiting for patient to join',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _startConsultation: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      if (mounted) {
        try {
          Navigator.of(currentContext, rootNavigator: true).pop();
        } catch (_) {}
      }
      _showError('Failed to start consultation: $e');
    }
  }

  void _showConsultationStartedSuccess(TelemedicineSession session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _veryLightColor,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text(
              'Consultation Started',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification sent to ${session.patientName}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for patient to join...',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Join the meeting when patient arrives',
                      style: TextStyle(color: Colors.blue[800], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _primaryColor),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  // In DoctorTelemedicinePage - update join method to go to correct screen
  Future<void> _joinConsultationAsDoctor(TelemedicineSession session) async {
    final currentContext = context;

    try {
      debugPrint(
        '🎬 STEP 3: Doctor Joining ${session.consultationType} Meeting',
      );

      // Show loading
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _veryLightColor,
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
              const SizedBox(width: 16),
              Text(
                'Joining ${session.consultationType} consultation...',
                style: TextStyle(color: _primaryColor),
              ),
            ],
          ),
        ),
      );

      // STEP 3: Update doctor join status
      await FirestoreService.completeDoctorJoinFlow(
        appointmentId: session.appointmentId,
        doctorId: widget.doctorId,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(currentContext, rootNavigator: true).pop();
      }

      // Navigate to CORRECT consultation screen (video/audio)
      if (mounted) {
        final sessionData = await FirestoreService.getSessionByAppointmentId(
          session.appointmentId,
        );

        if (sessionData != null) {
          Navigator.of(currentContext).push(
            MaterialPageRoute(
              builder: (context) => ConsultationScreen(
                appointmentId: session.appointmentId,
                userId: widget.doctorId,
                userName: widget.doctorName,
                userType: 'doctor',
                consultationType: session
                    .consultationType, // This determines video/audio screen
                patientId: sessionData['patientId'],
                doctorId: widget.doctorId,
                patientName: session.patientName,
                doctorName: widget.doctorName,
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in doctor join: $e');

      if (mounted) {
        try {
          Navigator.of(currentContext, rootNavigator: true).pop();
        } catch (_) {}
      }
      _showError('Failed to join consultation: $e');
    }
  }

  void _fixSessionDocument(TelemedicineSession session) async {
    try {
      debugPrint(
        '🚨 EMERGENCY FIX: Adding join status fields to ${session.appointmentId}',
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Fixing session document...'),
            ],
          ),
        ),
      );

      await FirestoreService.addJoinStatusFields(session.appointmentId);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      _showError('Session document fixed! Try again.');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError('Fix failed: $e');
    }
  }

  void _setupPatientLeftListener() {
    // Listen for patient left events from Firestore
    FirebaseFirestore.instance
        .collection('telemedicine_sessions')
        .where('doctorId', isEqualTo: widget.doctorId)
        .where('status', isEqualTo: 'In-Progress')
        .snapshots()
        .listen((snapshot) {
          for (var doc in snapshot.docChanges) {
            if (doc.type == DocumentChangeType.modified) {
              final data = doc.doc.data() as Map<String, dynamic>;
              final patientJoined = data['patientJoined'] ?? false;
              final appointmentId = data['appointmentId'];

              debugPrint(
                '🔄 Patient join status changed for $appointmentId: $patientJoined',
              );

              // If patient left the call, update UI to show "Waiting Patient"
              if (!patientJoined && mounted) {
                setState(() {
                  // This will trigger the UI to show waiting state again
                });
              }
            }
          }
        });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

Widget _buildSessionCard(TelemedicineSession session) {
  final hasUnread = _hasUnreadMessages.containsKey(session.appointmentId) && 
                    _hasUnreadMessages[session.appointmentId] == true;
  
  return Card(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    elevation: 3,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: _lightColor, width: 1),
    ),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Patient name with token number
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${session.tokenNumber ?? 0}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.patientName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Token #${session.tokenNumber ?? 0}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getStatusColor(session.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  session.status.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Medical Center
          if (session.medicalCenterName != null && session.medicalCenterName!.isNotEmpty)
            Row(
              children: [
                Icon(Icons.medical_services, color: _accentColor, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.medicalCenterName!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          
          if (session.medicalCenterName != null && session.medicalCenterName!.isNotEmpty)
            SizedBox(height: 8),
          
          // Consultation type and time slot
          Row(
            children: [
              // Consultation type
              Row(
                children: [
                  Icon(
                    session.isVideoCall ? Icons.videocam : Icons.phone,
                    color: _accentColor,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    session.isVideoCall ? 'Video' : 'Audio',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              
              SizedBox(width: 16),
              
              // Time slot
              if (session.timeSlot != null && session.timeSlot!.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.access_time, color: _accentColor, size: 16),
                    SizedBox(width: 4),
                    Text(
                      session.timeSlot!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Appointment date and time
          Row(
            children: [
              Icon(Icons.calendar_today, color: _accentColor, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_formatDate(session.createdAt)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Action buttons row
          Row(
            children: [
              // Primary action button
              Expanded(
                child: _buildPrimaryActionButton(session),
              ),
              
              SizedBox(width: 8),
              
              // SMALL Chat button
              Container(
                width: 50, // Fixed small width
                child: Stack(
                  children: [
                    ElevatedButton(
                      onPressed: () => _navigateToChatScreen(session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasUnread ? Colors.red : Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size(50, 48),
                      ),
                      child: Icon(
                        Icons.chat,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    // Red dot for unread messages
                    if (hasUnread)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red, width: 1.5),
                          ),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// Add this method if not exists
String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}


Widget _buildPrimaryActionButton(TelemedicineSession session) {
  if (session.status == 'Scheduled') {
    return ElevatedButton(
      onPressed: () => _startConsultation(session),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            session.isVideoCall ? Icons.videocam : Icons.phone,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              session.isVideoCall ? 'START' : 'START',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  } else if (session.status == 'In-Progress') {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _getSessionStatusStream(session.appointmentId),
      builder: (context, snapshot) {
        final patientJoined = snapshot.data?['patientJoined'] ?? false;
        
        if (patientJoined) {
          return ElevatedButton(
            onPressed: () => _joinConsultationAsDoctor(session),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_call, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'JOIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, color: Colors.orange, size: 14),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'WAITING',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  } else {
    // For Completed, Cancelled, etc.
    return OutlinedButton(
      onPressed: () => _showSessionDetails(session),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        side: BorderSide(color: _primaryColor),
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: _primaryColor, size: 16),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'DETAILS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildChatButton(TelemedicineSession session, bool hasUnread) {
  return Container(
    constraints: BoxConstraints(
      minWidth: 60,
      maxWidth: 80,
    ),
    child: Stack(
      children: [
        ElevatedButton(
          onPressed: () => _navigateToChatScreen(session),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: Size(60, 48), // Minimum button size
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat, color: Colors.white, size: 18),
              SizedBox(height: 2),
              Text(
                'Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // RED DOT for unread messages
        if (hasUnread)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    ),
  );
}
void _navigateToChatScreen(TelemedicineSession session) async {
  try {
    final chatRoomId = _chatService.generateChatRoomId(session.patientId, widget.doctorId);
    
    // Ensure chat room exists
    await _chatService.ensureChatRoomExists(
      chatRoomId: chatRoomId,
      patientId: session.patientId,
      patientName: session.patientName,
      doctorId: widget.doctorId,
      doctorName: widget.doctorName,
      appointmentId: session.appointmentId,
    );

    // Mark messages as read before opening
    await _chatService.markMessagesAsRead(chatRoomId, widget.doctorId);
    
    // Clear unread status immediately
    if (mounted) {
      setState(() {
        _hasUnreadMessages[session.appointmentId] = false;
      });
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorChatScreen(
          chatRoomId: chatRoomId,
          patientName: session.patientName,
          patientId: session.patientId,
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error opening chat: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
void _setupUnreadListeners() {
  try {
    // Cancel existing subscriptions
    for (final sub in _unreadSubscriptions.values) {
      sub.cancel();
    }
    _unreadSubscriptions.clear();
    
    // Only setup listeners if sessions exist
    if (_sessions.isEmpty) return;
    
    debugPrint('🔄 Setting up chat listeners for ${_sessions.length} sessions');
    
    for (final session in _sessions) {
      try {
        final chatRoomId = _chatService.generateChatRoomId(
          session.patientId, 
          widget.doctorId
        );
        
        // Skip if already listening
        if (_unreadSubscriptions.containsKey(session.appointmentId)) {
          continue;
        }
        
        // Create listener with timeout
        final subscription = _chatService.getUnreadStatusStream(
          chatRoomId, 
          widget.doctorId
        ).timeout(
          Duration(seconds: 5), // Shorter timeout
          onTimeout: (sink) {
            sink.add(false);
            debugPrint('⏰ Unread stream timeout for $chatRoomId');
          },
        ).listen(
          (hasUnread) {
            if (mounted) {
              setState(() {
                _hasUnreadMessages[session.appointmentId] = hasUnread;
              });
            }
          },
          onError: (error) {
            debugPrint('❌ Error in unread stream: $error');
            // Don't crash, just set to false
            if (mounted) {
              setState(() {
                _hasUnreadMessages[session.appointmentId] = false;
              });
            }
          },
        );
        
        _unreadSubscriptions[session.appointmentId] = subscription;
        
      } catch (e) {
        debugPrint('❌ Error setting up listener for ${session.appointmentId}: $e');
      }
    }
    
    debugPrint('✅ Chat listeners setup complete');
    
  } catch (e) {
    debugPrint('❌ Error in _setupUnreadListeners: $e');
  }
}

  // ADD THIS METHOD FOR REAL-TIME SESSION STATUS
  Stream<Map<String, dynamic>?> _getSessionStatusStream(String appointmentId) {
    return FirebaseFirestore.instance
        .collection('telemedicine_sessions')
        .where('appointmentId', isEqualTo: appointmentId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return snapshot.docs.first.data();
          }
          return null;
        });
  }

  // Add this waiting state widget
  Widget _buildWaitingForPatientState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, color: Colors.orange),
          SizedBox(width: 8),
          Text(
            'WAITING FOR PATIENT TO JOIN',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(TelemedicineSession session) {
    return ElevatedButton(
      onPressed: () => _startConsultation(session),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            session.isVideoCall ? Icons.videocam : Icons.phone,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            session.isVideoCall
                ? 'START VIDEO CONSULTATION'
                : 'START AUDIO CONSULTATION',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(TelemedicineSession session) {
    return ElevatedButton(
      onPressed: () => _joinConsultationAsDoctor(session),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_call, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'JOIN CONSULTATION',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ADD THIS METHOD FOR PRESCRIPTION BUTTON
  Widget _buildPrescriptionButton(TelemedicineSession session) {
    return FloatingActionButton(
      onPressed: () => _navigateToPrescriptionPage(session),
      backgroundColor: const Color.fromARGB(255, 39, 176, 66),
      foregroundColor: Colors.white,
      child: const Icon(Icons.edit), // Pen icon
      heroTag: 'prescription_${session.appointmentId}', // Unique hero tag
    );
  }

  // ADD THIS METHOD TO HANDLE PRESCRIPTION NAVIGATION
  void _navigateToPrescriptionPage(TelemedicineSession session) {
    debugPrint(
      '📝 Navigating to prescription page for patient: ${session.patientName}',
    );

    // Navigate to your prescription writing screen

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PrescriptionScreen()),
    );
  }

  Widget _buildConnectedState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'CONNECTED',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildViewDetailsButton(TelemedicineSession session) {
    return OutlinedButton(
      onPressed: () => _showSessionDetails(session),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        side: BorderSide(color: _primaryColor),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('VIEW DETAILS'),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String text,
    bool isPrice = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: isPrice ? Colors.green[700] : _accentColor, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isPrice ? Colors.green[700] : Colors.grey[700],
            fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDetailRow({
    required IconData icon,
    required String text,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showSessionDetails(TelemedicineSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _veryLightColor,
        title: Text(
          'Consultation Details',
          style: TextStyle(color: _primaryColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogDetailRow('Patient', session.patientName),
              _buildDialogDetailRow(
                'Type',
                '${session.consultationType} Consultation',
              ),
              _buildDialogDetailRow('Status', session.status),
              _buildDialogDetailRow('Appointment ID', session.appointmentId),
              if (session.startedAt != null)
                _buildDialogDetailRow(
                  'Started',
                  _formatDateTime(session.startedAt!),
                ),
              if (session.endedAt != null)
                _buildDialogDetailRow(
                  'Ended',
                  _formatDateTime(session.endedAt!),
                ),
              _buildDialogDetailRow('Fees', '₹${session.fees}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _primaryColor),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return _secondaryColor;
      case 'in-progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return _accentColor;
    }
  }

  

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Test method for complete flow
  void _testCompleteFlow() {
    if (_sessions.isNotEmpty) {
      final testSession = _sessions.first;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Test Complete Flow'),
          content: Text(
            'Test the complete consultation flow for ${testSession.patientName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _runCompleteFlowTest(testSession);
              },
              child: Text('Test Flow'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _runCompleteFlowTest(TelemedicineSession session) async {
    try {
      await FirestoreService.testCompleteFlow(
        appointmentId: session.appointmentId,
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        patientId: session.patientId,
        patientName: session.patientName,
        consultationType: session.consultationType,
      );

      _showError('Flow test completed successfully! Check notifications.');
    } catch (e) {
      _showError('Flow test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('My Sessions'),
            const SizedBox(width: 8),
            if (_usingRealData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDoctorSessions,
          ),
        ],
      ),
      backgroundColor: _veryLightColor,
      floatingActionButton:
          _selectedFilter == 'in-progress' && _filteredSessions.isNotEmpty
          ? _buildPrescriptionButton(_filteredSessions.first)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _isLoading
          ? _buildLoading()
          : _hasError
          ? _buildError()
          : _sessions.isEmpty
          ? _buildEmpty()
          : _buildSessionList(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading live sessions...',
            style: TextStyle(color: _primaryColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: _primaryColor),
          const SizedBox(height: 16),
          Text(
            'Unable to Load',
            style: TextStyle(
              fontSize: 18,
              color: _primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDoctorSessions,
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    String message = 'No telemedicine sessions available';
    if (_selectedFilter != 'all') {
      message = 'No ${_selectedFilter.replaceAll('-', ' ')} sessions';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_call, size: 64, color: _accentColor),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all'
                ? 'No Sessions'
                : 'No ${_selectedFilter.replaceAll('-', ' ').toUpperCase()}',
            style: TextStyle(fontSize: 16, color: _primaryColor),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: _secondaryColor)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDoctorSessions,
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('REFRESH'),
          ),
        ],
      ),
    );
  }

Color _getFilterColor(String filter) {
  switch (filter) {
    case 'all':
      return _primaryColor;
    case 'scheduled':
      return Colors.blue;
    case 'in-progress':
      return Colors.orange;
    case 'completed':
      return Colors.green;
    default:
      return _primaryColor;
  }
}
Widget _buildSessionList() {
  return Column(
    children: [
      if (_usingRealData)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.green[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_done, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Data - Connected to Firestore. Updates in real-time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      
      // Statistics card - NOW CLICKABLE
      Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: _lightColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ALL - Clickable
                _buildClickableStatCard(
                  'All',
                  _sessions.length,
                  _selectedFilter == 'all' ? _primaryColor : Colors.grey[600]!,
                  'all',
                  _selectedFilter == 'all',
                ),
                
                // SCHEDULED - Clickable
                _buildClickableStatCard(
                  'Scheduled',
                  _sessions.where((s) => s.status == 'Scheduled').length,
                  _selectedFilter == 'scheduled' ? Colors.blue : Colors.grey[600]!,
                  'scheduled',
                  _selectedFilter == 'scheduled',
                ),
                
                // IN PROGRESS - Clickable  
                _buildClickableStatCard(
                  'In Progress',
                  _sessions.where((s) => s.status == 'In-Progress').length,
                  _selectedFilter == 'in-progress' ? Colors.orange : Colors.grey[600]!,
                  'in-progress',
                  _selectedFilter == 'in-progress',
                ),
                
                // COMPLETED - Clickable
                _buildClickableStatCard(
                  'Completed',
                  _sessions.where((s) => s.status == 'Completed').length,
                  _selectedFilter == 'completed' ? Colors.green : Colors.grey[600]!,
                  'completed',
                  _selectedFilter == 'completed',
                ),
              ],
            ),
          ),
        ),
      ),
      
      // Active filter indicator
      if (_selectedFilter != 'all')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_alt,
                color: _getFilterColor(_selectedFilter),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Showing: ${_selectedFilter.replaceAll('-', ' ').toUpperCase()}',
                style: TextStyle(
                  color: _getFilterColor(_selectedFilter),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 16),
              GestureDetector(
                onTap: () => _setFilter('all'),
                child: Text(
                  'Clear filter',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      
      // Sessions list
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadDoctorSessions,
          backgroundColor: _veryLightColor,
          color: _primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _filteredSessions.length,
            itemBuilder: (context, index) {
              return _buildSessionCard(_filteredSessions[index]);
            },
          ),
        ),
      ),
    ],
  );
}


  Widget _buildClickableStatCard(
  String title,
  int count,
  Color color,
  String filter,
  bool isSelected,
) {
  return GestureDetector(
    onTap: () => _setFilter(filter),
    child: Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : _veryLightColor,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isSelected ? 3 : 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(maxWidth: 80),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : _primaryColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStatCard(String title, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _veryLightColor,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: _primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
