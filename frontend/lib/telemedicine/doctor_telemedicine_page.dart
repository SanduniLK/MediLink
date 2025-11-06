import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/telemedicine_session.dart';
import 'package:frontend/telemedicine/consultation_screen.dart';
import '../../services/firestore_service.dart';
import 'dart:async'; 

class DoctorTelemedicinePage extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorTelemedicinePage({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorTelemedicinePage> createState() => _DoctorTelemedicinePageState();
}

class _DoctorTelemedicinePageState extends State<DoctorTelemedicinePage> {
  List<TelemedicineSession> _sessions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _usingRealData = false;
  StreamSubscription? _sessionsSubscription;

  // Color scheme
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _veryLightColor = const Color(0xFFDDF0F5);

  @override
  void initState() {
    super.initState();
    _loadDoctorSessions();
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    super.dispose();
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

      debugPrint('🔄 Loading REAL sessions from Firestore for doctor: ${widget.doctorId}');
      
      // Cancel any existing subscription
      _sessionsSubscription?.cancel();
      
      // Subscribe to real-time updates from Firestore
      _sessionsSubscription = FirestoreService.getDoctorSessionsStream(widget.doctorId)
          .listen((sessionsData) {
        _handleSessionsData(sessionsData);
      }, onError: (error) {
        _handleSessionsError(error);
      });

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

  void _handleSessionsData(List<Map<String, dynamic>> sessionsData) {
    if (!mounted) return;
    
    debugPrint('📋 Received ${sessionsData.length} real sessions from Firestore');
    
    final sessions = sessionsData.map((data) {
      try {
        debugPrint('📝 Parsing real session: ${data['patientName']} - ${data['status']}');
        return TelemedicineSession.fromMap(data);
      } catch (e) {
        debugPrint('❌ Error parsing session data: $e');
        debugPrint('❌ Problematic data: $data');
        return null;
      }
    }).where((session) => session != null).cast<TelemedicineSession>().toList();

    // Sort sessions: scheduled first, then in-progress, then completed
    sessions.sort((a, b) {
      if (a.canStart && !b.canStart) return -1;
      if (!a.canStart && b.canStart) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    debugPrint('✅ Successfully parsed ${sessions.length} real sessions');

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
        _usingRealData = true;
        _hasError = false;
      });
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

 void _startConsultation(TelemedicineSession session) async {
  // Store context in local variable before any async operations
  final currentContext = context;
  
  try {
    debugPrint('🎬 Starting consultation for session:');
    debugPrint('   Appointment ID: ${session.appointmentId}');
    debugPrint('   Patient: ${session.patientName}');
    debugPrint('   Current Status: ${session.status}');
    debugPrint('   Consultation Type: ${session.consultationType}');

    // Show loading dialog using the stored context
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _veryLightColor,
        content: Row(
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
            const SizedBox(width: 16),
            Text(
              'Starting consultation...',
              style: TextStyle(color: _primaryColor),
            ),
          ],
        ),
      ),
    );

    // Update session status to In-Progress in Firestore if not already
    if (session.status != 'In-Progress') {
      debugPrint('🔄 Updating session status to In-Progress...');
      try {
        await FirestoreService.updateSessionStatus(
          appointmentId: session.appointmentId,
          status: 'In-Progress',
          startedAt: DateTime.now(),
        );
        await FirestoreService.createDoctorStartedNotification(
          patientId: session.patientId,
          doctorName: widget.doctorName,
          appointmentId: session.appointmentId,
          consultationType: session.consultationType, 
        );
        debugPrint('✅ Session status updated successfully');
      } catch (e) {
        debugPrint('❌ Failed to update session status: $e');
        // Close loading dialog using stored context
        if (mounted) {
          Navigator.of(currentContext, rootNavigator: true).pop();
        }
        _showError('Failed to update session: $e');
        return;
      }
    } else {
      debugPrint('ℹ️ Session is already In-Progress');
    }

    // Close loading dialog using stored context
    if (mounted) {
      Navigator.of(currentContext, rootNavigator: true).pop();
      debugPrint('✅ Loading dialog closed');
    }

    // Navigate to consultation screen using stored context
    if (mounted) {
      debugPrint('🚀 Navigating to ConsultationScreen...');
      
      // Get the session to pass patient ID
      final sessionData = await FirestoreService.getSessionByAppointmentId(session.appointmentId);
      
      if (sessionData != null) {
        Navigator.of(currentContext).push(
          MaterialPageRoute(
            builder: (context) => ConsultationScreen(
              appointmentId: session.appointmentId,
              userId: widget.doctorId,
              userName: widget.doctorName,
              userType: 'doctor',
              consultationType: session.consultationType,
              patientId: sessionData['patientId'],
              doctorId: widget.doctorId, // Add this for consistency
              patientName: session.patientName,
              doctorName: widget.doctorName,
            ),
          ),
        );
      } else {
        _showError('Could not load session details');
      }
    }

  } catch (e, stackTrace) {
    debugPrint('❌ Error in _startConsultation: $e');
    debugPrint('❌ Stack trace: $stackTrace');
    
    // Safely close loading dialog using stored context
    if (mounted) {
      try {
        Navigator.of(currentContext, rootNavigator: true).pop();
      } catch (_) {
        // Ignore error if dialog is already closed
      }
    }
    _showError('Failed to start consultation: $e');
  }
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      color: _veryLightColor,
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
                        style: TextStyle(
                          color: _secondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(session.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Session details
            _buildDetailRow(
              icon: Icons.videocam,
              text: session.isVideoCall ? 'Video Consultation' : 'Audio Consultation',
            ),
            
            const SizedBox(height: 8),
            
            _buildDetailRow(
              icon: Icons.calendar_today,
              text: _formatDate(session.createdAt),
            ),
            
            if (session.medicalCenterName != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.medical_services,
                text: session.medicalCenterName!,
              ),
            ],
            
            const SizedBox(height: 8),
            
            _buildDetailRow(
              icon: Icons.attach_money,
              text: 'Fees: ₹${session.fees}',
              isPrice: true,
            ),

            if (session.date != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.schedule,
                text: 'Date: ${session.date}',
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                if (session.canStart && session.status != 'Completed')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startConsultation(session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_call, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'START CONSULTATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (session.status == 'Completed')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showSessionDetails(session);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('VIEW DETAILS'),
                    ),
                  ),
                
                if (session.status == 'Scheduled') ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _lightColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.info_outline, color: _primaryColor),
                      onPressed: () => _showSessionDetails(session),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text, bool isPrice = false}) {
    return Row(
      children: [
        Icon(
          icon,
          color: isPrice ? Colors.green[700] : _accentColor,
          size: 20,
        ),
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
              _buildDialogDetailRow('Type', '${session.consultationType} Consultation'),
              _buildDialogDetailRow('Status', session.status),
              _buildDialogDetailRow('Appointment ID', session.appointmentId),
              if (session.startedAt != null)
                _buildDialogDetailRow('Started', _formatDateTime(session.startedAt!)),
              if (session.endedAt != null)
                _buildDialogDetailRow('Ended', _formatDateTime(session.endedAt!)),
              _buildDialogDetailRow('Fees', '₹${session.fees}'),
              if (session.medicalCenterName != null)
                _buildDialogDetailRow('Medical Center', session.medicalCenterName!),
              if (session.doctorSpecialty != null)
                _buildDialogDetailRow('Specialty', session.doctorSpecialty!),
              if (session.tokenNumber != null)
                _buildDialogDetailRow('Token Number', session.tokenNumber.toString()),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Live Data - Connected to Firestore',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
            ),
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
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('My Telemedicine Sessions'),
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
          if (_usingRealData)
            const Tooltip(
              message: 'Connected to live data',
              child: Icon(Icons.cloud_done, color: Colors.green),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDoctorSessions,
          ),
        ],
      ),
      backgroundColor: _veryLightColor,
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
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
          const SizedBox(height: 16),
          Text(
            'Loading live sessions...',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 16,
            ),
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
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDoctorSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_call, size: 64, color: _accentColor),
          const SizedBox(height: 16),
          Text(
            'No Telemedicine Sessions',
            style: TextStyle(
              fontSize: 16,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No demo sessions available',
            style: TextStyle(color: _secondaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDoctorSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: const Text('REFRESH'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    return Column(
      children: [
        // Live data banner
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
        // Statistics card
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
                  _buildStatCard('Scheduled', _sessions.where((s) => s.status == 'Scheduled').length, _primaryColor),
                  _buildStatCard('In Progress', _sessions.where((s) => s.status == 'In-Progress').length, Colors.orange),
                  _buildStatCard('Completed', _sessions.where((s) => s.status == 'Completed').length, Colors.green),
                ],
              ),
            ),
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
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                return _buildSessionCard(_sessions[index]);
              },
            ),
          ),
        ),
      ],
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