// frontend/lib/telemedicine/doctor_telemedicine_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/model/telemedicine_session.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';
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

  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _veryLightColor = const Color(0xFFDDF0F5);

  @override
  void initState() {
    super.initState();
    _loadDoctorSessions();
    _setupPatientLeftListener();
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    super.dispose();
  }

  void _applyFilter() {
    switch (_selectedFilter) {
      case 'scheduled':
        _filteredSessions = _sessions
            .where((session) => session.status == 'Scheduled')
            .toList();
        break;
      case 'in-progress':
        _filteredSessions = _sessions
            .where((session) => session.status == 'In-Progress')
            .toList();
        break;
      case 'completed':
        _filteredSessions = _sessions
            .where((session) => session.status == 'Completed')
            .toList();
        break;
      default:
        _filteredSessions = List.from(_sessions);
    }
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

      debugPrint(
        '🔄 Loading REAL sessions from Firestore for doctor: ${widget.doctorId}, schedule: ${widget.scheduleId}',
      );

      _sessionsSubscription?.cancel();

      _sessionsSubscription =
          FirestoreService.getDoctorSessionsStream(
            widget.doctorId,
            scheduleId: widget.scheduleId,
          ).listen(
            (sessionsData) {
              _handleSessionsData(sessionsData);
            },
            onError: (error) {
              _handleSessionsError(error);
            },
          );
    } catch (e) {
      debugPrint('❌ Error setting up Firestore listener: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Failed to connect to database: ${e.toString()}';
        });
      }
    }
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

  void _handleSessionsData(List<Map<String, dynamic>> sessionsData) {
    if (!mounted) return;

    debugPrint(
      '📋 _handleSessionsData → rawCount=${sessionsData.length} '
      '(doctorId=${widget.doctorId}, scheduleId=${widget.scheduleId ?? 'NONE'})',
    );

    final sessions = sessionsData
        .map((data) {
          try {
            debugPrint(
              '🧾 Mapping session data: appointmentId=${data['appointmentId']}, '
              'scheduleId=${data['scheduleId']}',
            );
            return TelemedicineSession.fromMap(data);
          } catch (e) {
            debugPrint('❌ Error parsing session data: $e');
            return null;
          }
        })
        .where((session) => session != null)
        .cast<TelemedicineSession>()
        .toList();

    sessions.sort((a, b) {
      if (a.canStart && !b.canStart) return -1;
      if (!a.canStart && b.canStart) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
        _applyFilter();
        _usingRealData = true;
        _hasError = false;
      });
    }

    debugPrint(
      '✅ _handleSessionsData → mappedSessions=${sessions.length}, '
      'filteredSessionsAfterApply=${_filteredSessions.length}',
    );
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

  // In DoctorTelemedicinePage - update _buildSessionCard method
  Widget _buildSessionCard(TelemedicineSession session) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _lightColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.patientName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Token #${session.tokenNumber ?? session.appointmentId.substring(session.appointmentId.length - 4)}',
                        style: TextStyle(color: _secondaryColor, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // REAL-TIME STATUS BADGE
                StreamBuilder<Map<String, dynamic>>(
                  stream: FirestoreService.getSessionJoinStatusStream(
                    session.appointmentId,
                  ),
                  builder: (context, snapshot) {
                    final joinStatus =
                        snapshot.data ??
                        {'patientJoined': false, 'doctorJoined': false};
                    final patientJoined = joinStatus['patientJoined'] ?? false;
                    final doctorJoined = joinStatus['doctorJoined'] ?? false;

                    String statusText = session.status;
                    Color statusColor = _getStatusColor(session.status);

                    // Override status based on real-time join status
                    if (session.status == 'Completed') {
                      statusText = 'Completed';
                      statusColor = Colors.grey;
                    } else if (patientJoined && doctorJoined) {
                      statusText = 'Connected';
                      statusColor = Colors.green;
                    } else if (patientJoined && !doctorJoined) {
                      statusText = 'Patient Joined';
                      statusColor = Colors.green;
                    } else if (session.status == 'In-Progress' &&
                        !patientJoined) {
                      statusText = 'Waiting Patient';
                      statusColor = Colors.orange;
                    } else if (session.status == 'Scheduled') {
                      statusText = 'Scheduled';
                      statusColor = _secondaryColor;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Session details
            _buildDetailRow(
              icon: Icons.videocam,
              text: session.isVideoCall
                  ? 'Video Consultation'
                  : 'Audio Consultation',
            ),

            const SizedBox(height: 8),

            _buildDetailRow(
              icon: Icons.calendar_today,
              text: _formatDate(session.createdAt),
            ),

            // REAL-TIME JOIN STATUS WITH PROPER FLOW
            StreamBuilder<Map<String, dynamic>>(
              stream: FirestoreService.getSessionJoinStatusStream(
                session.appointmentId,
              ),
              builder: (context, snapshot) {
                final joinStatus =
                    snapshot.data ??
                    {'patientJoined': false, 'doctorJoined': false};
                final patientJoined = joinStatus['patientJoined'] ?? false;
                final doctorJoined = joinStatus['doctorJoined'] ?? false;

                // Also check session status from Firestore
                return StreamBuilder<Map<String, dynamic>?>(
                  stream: _getSessionStatusStream(session.appointmentId),
                  builder: (context, sessionSnapshot) {
                    final sessionData = sessionSnapshot.data;
                    final consultationStarted =
                        sessionData?['status'] == 'In-Progress' ||
                        session.status == 'In-Progress';
                    final sessionCompleted =
                        sessionData?['status'] == 'Completed' ||
                        session.status == 'Completed';
                    return Column(
                      children: [
                        const SizedBox(height: 8),

                        // DYNAMIC STATUS BASED ON REAL-TIME DATA
                        if (!consultationStarted && !sessionCompleted) ...[
                          _buildStatusDetailRow(
                            icon: Icons.schedule,
                            text: 'Ready to start consultation',
                            statusColor: _primaryColor,
                          ),
                        ] else if (consultationStarted &&
                            !patientJoined &&
                            !sessionCompleted) ...[
                          _buildStatusDetailRow(
                            icon: Icons.notifications_active,
                            text:
                                'Consultation started - Waiting for patient...',
                            statusColor: Colors.orange,
                          ),
                        ] else if (patientJoined &&
                            !doctorJoined &&
                            !sessionCompleted) ...[
                          _buildStatusDetailRow(
                            icon: Icons.check_circle,
                            text: 'Patient Joined 👤 - Ready for you!',
                            statusColor: Colors.green,
                          ),

                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Patient notified - join when they arrive',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (sessionCompleted) ...[
                          _buildStatusDetailRow(
                            icon: Icons.done_all,
                            text: 'Consultation Completed',
                            statusColor: Colors.green,
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // ACTION BUTTONS BASED ON REAL-TIME STATUS
            if (session.canStart && session.status != 'Completed')
              StreamBuilder<Map<String, dynamic>>(
                stream: FirestoreService.getSessionJoinStatusStream(
                  session.appointmentId,
                ),
                builder: (context, snapshot) {
                  final joinStatus =
                      snapshot.data ??
                      {'patientJoined': false, 'doctorJoined': false};
                  final patientJoined = joinStatus['patientJoined'] ?? false;

                  return StreamBuilder<Map<String, dynamic>?>(
                    stream: _getSessionStatusStream(session.appointmentId),
                    builder: (context, sessionSnapshot) {
                      final sessionData = sessionSnapshot.data;
                      final consultationStarted =
                          sessionData?['status'] == 'In-Progress' ||
                          session.status == 'In-Progress';
                      final sessionCompleted =
                          sessionData?['status'] == 'Completed' ||
                          session.status == 'Completed';

                      debugPrint('🔍 Session: ${session.appointmentId}');
                      debugPrint(
                        '   Consultation Started: $consultationStarted',
                      );
                      debugPrint('   Patient Joined: $patientJoined');
                      debugPrint(
                        '   Doctor Joined: ${joinStatus['doctorJoined']}',
                      );
                      debugPrint('   Session Completed: $sessionCompleted');

                      // Show START button only if consultation hasn't started AND patient hasn't joined
                      if (!consultationStarted && !sessionCompleted) {
                        return _buildStartButton(session);
                      }

                      // Show connected state if both in call
                      if (consultationStarted &&
                          !joinStatus['doctorJoined'] &&
                          !sessionCompleted) {
                        return _buildJoinButton(session);
                      }

                      if (consultationStarted &&
                          joinStatus['doctorJoined'] &&
                          !sessionCompleted) {
                        return _buildConnectedState();
                      }

                      return const SizedBox.shrink();
                    },
                  );
                },
              )
            else if (session.status == 'Completed')
              _buildViewDetailsButton(session),
          ],
        ),
      ),
    );
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
                  _buildClickableStatCard(
                    'All',
                    _sessions.length,
                    const Color.fromARGB(255, 173, 158, 17),
                    'all',
                    _selectedFilter == 'all',
                  ),
                  _buildClickableStatCard(
                    'Scheduled',
                    _sessions.where((s) => s.status == 'Scheduled').length,
                    _primaryColor,
                    'scheduled',
                    _selectedFilter == 'scheduled',
                  ),
                  _buildClickableStatCard(
                    'In Progress',
                    _sessions.where((s) => s.status == 'In-Progress').length,
                    Colors.orange,
                    'in-progress',
                    _selectedFilter == 'in-progress',
                  ),
                  _buildClickableStatCard(
                    'Completed',
                    _sessions.where((s) => s.status == 'Completed').length,
                    Colors.green,
                    'completed',
                    _selectedFilter == 'completed',
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDoctorSessions,
            backgroundColor: _veryLightColor,
            color: _primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _filteredSessions.length, // CHANGE THIS
              itemBuilder: (context, index) {
                return _buildSessionCard(
                  _filteredSessions[index],
                ); // CHANGE THIS
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
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : _primaryColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
