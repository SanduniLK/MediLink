import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/model/telemedicine_session.dart';
import 'package:frontend/telemedicine/consultation_screen.dart';
import '../../services/firestore_service.dart';
import 'dart:async'; 

class PatientTelemedicinePage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientTelemedicinePage({
    Key? key,
    required this.patientId,
    required this.patientName,
    
  }) : super(key: key);

  @override
  _PatientTelemedicinePageState createState() => _PatientTelemedicinePageState();
}

class _PatientTelemedicinePageState extends State<PatientTelemedicinePage> {
  List<TelemedicineSession> _sessions = [];
   List<TelemedicineSession> _filteredSessions = []; 
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _usingRealData = false;
  StreamSubscription? _sessionsSubscription;
  String _selectedFilter = 'all';



  

  // Color scheme
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _veryLightColor = const Color(0xFFDDF0F5);


 
  @override
  void initState() {
    super.initState();
    _loadPatientSessions();
    
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    super.dispose();
  }

void _applyFilter() {
  switch (_selectedFilter) {
    case 'scheduled':
      _filteredSessions = _sessions.where((session) => session.status == 'Scheduled').toList();
      break;
    case 'in-progress':
      _filteredSessions = _sessions.where((session) => session.status == 'In-Progress').toList();
      break;
    case 'completed':
      _filteredSessions = _sessions.where((session) => session.status == 'Completed').toList();
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
  Future<void> _loadPatientSessions() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = '';
        });
      }

      print('🔄 Loading REAL sessions from Firestore for patient: ${widget.patientId}');
      
      // Cancel any existing subscription
      _sessionsSubscription?.cancel();
      
      // Subscribe to real-time updates from Firestore
      _sessionsSubscription = FirestoreService.getPatientSessionsStream(widget.patientId)
          .listen((sessionsData) {
        _handleSessionsData(sessionsData);
      }, onError: (error) {
        _handleSessionsError(error);
      });

    } catch (e) {
      print('❌ Error setting up Firestore listener: $e');
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
    
    print('📋 Received ${sessionsData.length} real sessions from Firestore');
    
    final sessions = sessionsData.map((data) {
      try {
        print('📝 Parsing real session: ${data['patientName']} - ${data['status']}');
        return TelemedicineSession.fromMap(data);
      } catch (e) {
        print('❌ Error parsing session data: $e');
        print('❌ Problematic data: $data');
        return null;
      }
    }).where((session) => session != null).cast<TelemedicineSession>().toList();

    print('✅ Successfully parsed ${sessions.length} real sessions');

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _applyFilter();
        _isLoading = false;
        _usingRealData = true;
        _hasError = false;
      });
    }
  }

  void _handleSessionsError(error) {
    print('❌ Firestore stream error: $error');
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to load sessions: $error';
      });
    }
  }

void _joinConsultation(TelemedicineSession session) async {
  // Store context in local variable before any async operations
  final currentContext = context;
  
  try {
    // Show loading dialog using stored context
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _veryLightColor,
        content: Row(
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
            SizedBox(width: 16),
            Text(
              'Joining consultation...',
              style: TextStyle(color: _primaryColor),
            ),
          ],
        ),
      ),
    );

    
    
    debugPrint('🔄 Updating patient join status...');
    await FirestoreService.updateSessionJoinStatus(
      appointmentId: session.appointmentId,
      userType: 'patient',
      hasJoined: true,
    );
    
    // 🔔 SEND NOTIFICATION TO DOCTOR THAT PATIENT JOINED
    debugPrint('🔔 Sending patient joined notification to doctor...');
    await FirestoreService.createPatientJoinedNotification(
      doctorId: session.doctorId,
      patientName: widget.patientName,
      appointmentId: session.appointmentId,
      consultationType: session.consultationType, // FIXED: Now this parameter exists
    );

    // Close loading dialog using stored context
    if (mounted) {
      Navigator.of(currentContext, rootNavigator: true).pop();
    }

    // Navigate to consultation screen using stored context
    if (mounted) {
      Navigator.of(currentContext).push(
        MaterialPageRoute(
          builder: (context) => ConsultationScreen(
            appointmentId: session.appointmentId,
            userId: widget.patientId,
            userName: widget.patientName,
            userType: 'patient',
            consultationType: session.consultationType,
            patientId: widget.patientId,
            doctorId: session.doctorId,
            patientName: widget.patientName,
            doctorName: session.doctorName,
          ),
        ),
      );
    }

  } catch (e) {
    // Safely close loading dialog using stored context
    if (mounted) {
      try {
        Navigator.of(currentContext, rootNavigator: true).pop();
      } catch (_) {
        // Ignore error if dialog is already closed
      }
    }
    _showError('Failed to join consultation: $e');
  }
}
// NEW METHOD: Check if patient can join the consultation
bool _canPatientJoin(TelemedicineSession session) {
  // Patient can only join if:
  // 1. Session is in progress
  // 2. Session is not completed
  // 3. Doctor has started the consultation (doctorHasJoined is true)
  return session.status == 'In-Progress' ;
         
         
}

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }


  Widget _buildSessionCard(TelemedicineSession session) {
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
                Expanded(
                  child: Text(
                    'Dr. ${session.doctorName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(session.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Session details
            _buildDetailRow(
              icon: Icons.videocam,
              text: session.isVideoCall ? 'Video Consultation' : 'Audio Consultation',
            ),
            
            SizedBox(height: 8),
            
            _buildDetailRow(
              icon: Icons.calendar_today,
              text: '${_formatDate(session.createdAt)}',
            ),
            
            if (session.medicalCenterName != null) ...[
              SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.medical_services,
                text: session.medicalCenterName!,
              ),
            ],
            
            SizedBox(height: 8),
            
            

            if (session.date != null) ...[
              SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.schedule,
                text: 'Date: ${session.date}',
              ),
            ],
            
            SizedBox(height: 16),
            
            // Action button
            if (_canPatientJoin(session))
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () => _joinConsultation(session),
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
                      Icon(Icons.video_call, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'JOIN CONSULTATION',
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _showSessionDetails(session);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('VIEW DETAILS'),
                ),
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
        SizedBox(width: 8),
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
              _buildDialogDetailRow('Doctor', 'Dr. ${session.doctorName}'),
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
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Live Data - Connected to Firestore',
                  style: TextStyle(
                    color: Colors.green[800],
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
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
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
            Text('My Tele Consultations'),
            SizedBox(width: 8),
            if (_usingRealData)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                
              ),
          ],
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          
          
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPatientSessions,
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
                  : setupCallListener(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
          SizedBox(height: 16),
          Text(
            'Loading live consultations...',
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
          SizedBox(height: 16),
          Text(
            'Unable to Load',
            style: TextStyle(
              fontSize: 18,
              color: _primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPatientSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: Text('TRY AGAIN'),
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
          SizedBox(height: 16),
          Text(
            'No Consultations',
            style: TextStyle(
              fontSize: 16,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No telemedicine consultations scheduled',
            style: TextStyle(color: _secondaryColor),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPatientSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
            child: Text('REFRESH'),
          ),
        ],
      ),
    );
  }

  Widget setupCallListener() {
    return Column(
      children: [
        // Live data banner
        if (_usingRealData)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            color: Colors.green[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_done, color: Colors.green, size: 16),
                SizedBox(width: 8),
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
        // Statistics card - NOW CLICKABLE
Padding(
  padding: EdgeInsets.all(16),
  child: Card(
    color: _lightColor,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildClickableStatCard(
            'All', 
            _sessions.length, 
            _primaryColor, 
            'all',
            _selectedFilter == 'all'
          ),
          _buildClickableStatCard(
            'Scheduled', 
            _sessions.where((s) => s.status == 'Scheduled').length, 
            _primaryColor, 
            'scheduled',
            _selectedFilter == 'scheduled'
          ),
          _buildClickableStatCard(
            'In Progress', 
            _sessions.where((s) => s.status == 'In-Progress').length, 
            Colors.orange, 
            'in-progress',
            _selectedFilter == 'in-progress'
          ),
          _buildClickableStatCard(
            'Completed', 
            _sessions.where((s) => s.status == 'Completed').length, 
            Colors.green, 
            'completed',
            _selectedFilter == 'completed'
          ),
        ],
      ),
    ),
  ),
),

        // Sessions list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPatientSessions,
            backgroundColor: _veryLightColor,
            color: _primaryColor,
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 16),
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
Widget _buildClickableStatCard(String title, int count, Color color, String filter, bool isSelected) {
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
            border: Border.all(
              color: color, 
              width: isSelected ? 3 : 2,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              )
            ] : [],
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
        SizedBox(height: 8),
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
Widget _buildStatusDetailRow({required IconData icon, required String text, required Color statusColor}) {
  return Row(
    children: [
      Icon(
        icon,
        color: statusColor,
        size: 20,
      ),
      SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
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
        SizedBox(height: 8),
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