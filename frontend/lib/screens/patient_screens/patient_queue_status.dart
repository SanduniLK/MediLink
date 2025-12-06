import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/queue_provider.dart';
import 'package:frontend/services/patient_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientQueueStatus extends StatefulWidget {
  const PatientQueueStatus({super.key});

  @override
  State<PatientQueueStatus> createState() => _PatientQueueStatusState();
}

class _PatientQueueStatusState extends State<PatientQueueStatus> {
  String? _patientId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic>? _selectedAppointment;
  Map<String, dynamic>? _queueStatus;

  // Timer for auto-refreshing queue data
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentPatientAppointments();
    _resetNotificationFlag();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadCurrentPatientAppointments() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _patientId = currentUser.uid;
      });
      _loadTodayAppointments();
    } else {
      _showError('Unable to detect your account. Please sign in again.');
    }
  }

  void _loadTodayAppointments() async {
    final patientId = _patientId;
    if (patientId == null || patientId.isEmpty) {
      _showError('Unable to detect patient information. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _appointments = [];
      _selectedAppointment = null;
      _queueStatus = null;
    });

    try {
      final result = await PatientService.getPatientAppointments(patientId);

      if (result['success'] == true) {
        final appointments = List<Map<String, dynamic>>.from(
          result['data'] ?? [],
        );
        final todayAppointments = appointments.where((appointment) {
          final dateValue = appointment['date'];

          // If the string contains "Today", automatically include it
          if (dateValue is String &&
              dateValue.toLowerCase().contains('today')) {
            return true;
          }

          final parsedDate = _parseAppointmentDate(dateValue);
          if (parsedDate == null) return false;

          final now = DateTime.now();
          return _isSameDay(parsedDate, now);
        }).toList();

        setState(() {
          _appointments = todayAppointments;
          _isLoading = false;
        });

        if (todayAppointments.isEmpty) {
          _showInfo('No appointments Booked for today');
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Failed to load appointments: ${result['error']}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  // --- UPDATED QUEUE CHECK LOGIC ---
void _checkQueueStatus(Map<String, dynamic> appointment) async {
  // 1. Get Schedule ID
  final scheduleId =
      appointment['scheduleId'] ?? appointment['_id'] ?? appointment['id'];

  if (scheduleId == null) {
    _showError('Cannot find Schedule ID for this appointment.');
    return;
  }

  setState(() {
    _selectedAppointment = appointment;
    _isLoading = true;
    _queueStatus = null;
    // Reset notification flag when checking new queue
    _hasShownConsultationNotification = false;
  });

  _refreshTimer?.cancel(); // Cancel any existing timer

  await _fetchQueueData(scheduleId);

  // 2. Start Auto-Refresh (every 15 seconds)
  _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
    if (mounted && _selectedAppointment != null) {
      _fetchQueueData(scheduleId, isBackground: true);
    }
  });
}
void _setupNotificationListener(String patientId) {
  FirebaseFirestore.instance
      .collection('patientNotifications')
      .where('patientId', isEqualTo: patientId)
      .where('read', isEqualTo: false)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.docs.isNotEmpty && mounted) {
      final notification = snapshot.docs.first.data();
      
      if (notification['type'] == 'session_ended_by_doctor') {
        _showSessionEndedByDoctorNotification(notification);
        
        // Mark as read
        snapshot.docs.first.reference.update({'read': true});
      }
    }
  });
}
void _showSessionEndedByDoctorNotification(Map<String, dynamic> notification) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 12),
              Text('Session Ended'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The consultation session has been ended by the doctor.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor: ${notification['doctorName']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Medical Center: ${notification['medicalCenter']}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your appointment has been cancelled. Please check your appointments for rescheduling options.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  });
}
Future<void> _fetchQueueData(
  String scheduleId, {
  bool isBackground = false,
}) async {
  final queueProvider = Provider.of<QueueProvider>(context, listen: false);

  try {
    final queueData = await queueProvider.getQueueByScheduleId(scheduleId);

    if (mounted) {
      setState(() {
        _queueStatus = queueData;
        if (!isBackground) _isLoading = false;
      });

      // Check if all appointments are completed
      if (queueData != null) {
        final patients = (queueData['patients'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final allCompleted = _checkIfAllAppointmentsCompleted(patients);
        
        if (allCompleted) {
          _showSessionEndedDialog();
        } else {
          // Check if MY consultation has started
          _checkIfMyConsultationStarted(patients);
        }
      }
      
      if (queueData == null && !isBackground) {
        _showInfo('Queue has not started for this schedule yet.');
      }
    }
  } catch (e) {
    if (mounted && !isBackground) {
      setState(() => _isLoading = false);
      _showError('Error checking queue: $e');
    }
  }
}
void _checkIfMyConsultationStarted(List<Map<String, dynamic>> patients) {
  if (_patientId == null) return;
  
  // Find my appointment in the queue
  final myAppointment = patients.firstWhere(
    (p) => p['patientId'] == _patientId,
    orElse: () => {},
  );
  
  if (myAppointment.isNotEmpty) {
    final myToken = myAppointment['tokenNumber'] ?? 0;
    final myStatus = myAppointment['queueStatus']?.toString().toLowerCase() ?? '';
    
    // If I'm currently in consultation
    if (myStatus == 'in_consultation') {
      _showConsultationStartedNotification(myToken);
    }
  }
}
void _showConsultationStartedNotification(int tokenNumber) {
  // Only show once per consultation
  if (_hasShownConsultationNotification) return;
  
  // Show notification
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _hasShownConsultationNotification = true;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Consultation Started!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Token #$tokenNumber - Doctor is now consulting with you.',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  });
}
bool _hasShownConsultationNotification = false;

void _resetNotificationFlag() {
  _hasShownConsultationNotification = false;
}
// NEW: Check if all appointments are completed
bool _checkIfAllAppointmentsCompleted(List<Map<String, dynamic>> patients) {
  if (patients.isEmpty) return false;
  
  // Count total appointments and completed ones
  int totalAppointments = 0;
  int completedAppointments = 0;
  
  for (final patient in patients) {
    final status = patient['status']?.toString().toLowerCase() ?? '';
    final queueStatus = patient['queueStatus']?.toString().toLowerCase() ?? '';
    
    // Skip cancelled/absent appointments
    if (status == 'cancelled' || status == 'absent' || status == 'skipped') {
      continue;
    }
    
    totalAppointments++;
    
    if (status == 'completed' || queueStatus == 'completed') {
      completedAppointments++;
    }
  }
  
  // If all appointments are completed
  return totalAppointments > 0 && completedAppointments == totalAppointments;
}
// NEW: Show session ended dialog
Future<void> _showSessionEndedDialog() async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 12),
          Text('Session Completed'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✅ Today\'s consultation session has ended!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[100] ?? Colors.green),
            ),
            child: const Column(
              children: [
                Icon(Icons.medical_services, size: 40, color: Colors.green),
                SizedBox(height: 12),
                Text(
                  'All appointments for today\'s schedule are now complete.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Thank you for your visit!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Next Steps:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildBulletPoint('Follow your doctor\'s instructions'),
          _buildBulletPoint('Take prescribed medications on time'),
          _buildBulletPoint('Schedule follow-up if needed'),
          _buildBulletPoint('Contact clinic for any concerns'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Go back to appointments list
            _refreshTimer?.cancel();
            setState(() {
              _selectedAppointment = null;
              _queueStatus = null;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Back to Appointments'),
        ),
      ],
    ),
  );
}

Widget _buildBulletPoint(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 16)),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Queue Status'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2FBFC), Color(0xFFE0F5F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildUserInfoCard(),
              const SizedBox(height: 20),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_appointments.isNotEmpty && _queueStatus == null)
                Expanded(child: _buildAppointmentsList())
              else if (_queueStatus != null)
                Expanded(child: _buildQueueStatus())
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF18A3B6).withOpacity(0.1),
                  radius: 24,
                  child: const Icon(Icons.person, color: Color(0xFF18A3B6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Patient ID',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _patientId ?? 'Not available',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_patientId != null)
                  const Icon(Icons.verified, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadTodayAppointments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Today\'s Appointments'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Appointments Today',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Appointments (${_appointments.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _appointments.length,
            itemBuilder: (context, index) {
              return _buildAppointmentCard(_appointments[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final doctorName = appointment['doctorName'] ?? 'Unknown Doctor';
    final medicalCenter = appointment['medicalCenterName'] ?? 'Unknown Center';
    final time = appointment['time'] ?? 'No time';
    final status = appointment['status'] ?? 'scheduled';
    final currentQueueNumber =
        appointment['tokenNumber'] ?? appointment['queueNumber'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        medicalCenter,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(time),
                const SizedBox(width: 16),
                Icon(
                  Icons.confirmation_number,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text('Token: $currentQueueNumber'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _checkQueueStatus(appointment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Check Live Queue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Update _buildQueueStatus to show consultation started indicator
Widget _buildQueueStatus() {
  if (_selectedAppointment == null || _queueStatus == null) {
    return const Center(child: Text('No queue data available'));
  }

  final patients =
      (_queueStatus!['patients'] as List?)?.cast<Map<String, dynamic>>() ??
      [];

  // Check if session has ended
  final allCompleted = _checkIfAllAppointmentsCompleted(patients);
  
  if (allCompleted) {
    return _buildSessionEndedView();
  }

  // 1. FIND "ME" (My Token)
  final myEntry = patients.firstWhere(
    (p) => (p['patientId'] ?? '') == _patientId,
    orElse: () => {},
  );
  final myToken = myEntry['tokenNumber'] ?? 0;
  final myQueueStatus = myEntry['queueStatus']?.toString().toLowerCase() ?? '';
  final isMyConsultationStarted = myQueueStatus == 'in_consultation';

  // 2. FIND "CURRENTLY CONSULTING" (Specific logic requested)
  // We look for the patient strictly marked as 'in_consultation'
  final consultingEntry = patients.firstWhere(
    (p) => p['queueStatus'] == 'in_consultation',
    orElse: () => {},
  );

  // Display Logic: If someone is inside, show their token.
  // If room is empty, show the last completed token or 0.
  final currentTokenDisplay = consultingEntry.isNotEmpty
      ? consultingEntry['tokenNumber']
      : (patients.where((p) => p['status'] == 'completed').length);

  // 3. WAITING LIST (Filter out completed and the person inside)
  final waitingPatients =
      patients
          .where(
            (p) =>
                (p['status'] == 'confirmed' ||
                    p['status'] == 'pending' ||
                    p['status'] == 'waiting') &&
                p['queueStatus'] != 'in_consultation' &&
                p['status'] != 'completed',
          )
          .toList()
        ..sort(
          (a, b) => (a['tokenNumber'] ?? 0).compareTo(b['tokenNumber'] ?? 0),
        );

  // Calculate People Ahead
  int peopleAhead = 0;
  if (myToken > 0) {
    peopleAhead = waitingPatients
        .where((p) => (p['tokenNumber'] ?? 0) < myToken)
        .length;
    if (consultingEntry.isNotEmpty &&
        consultingEntry['tokenNumber'] != myToken) {
      peopleAhead++; // Add the person inside the room
    }
  }

  return SingleChildScrollView(
    child: Column(
      children: [
        // Show Consultation Started Banner if it's my turn
        if (isMyConsultationStarted)
          _buildConsultationStartedBanner(myToken),
        
        // Header Card
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appointment Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Doctor',
                  _selectedAppointment!['doctorName'] ?? 'Unknown',
                ),
                _buildDetailRow(
                  'Center',
                  _selectedAppointment!['medicalCenterName'] ?? 'Unknown',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // LIVE QUEUE STATUS
        Card(
          elevation: 4,
          color: isMyConsultationStarted ? Colors.green : const Color(0xFF18A3B6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  isMyConsultationStarted 
                    ? '🎯 Your Consultation Started!' 
                    : 'Live Queue Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBigStatusItem(
                      'My Token',
                      myToken == 0 ? '--' : '#$myToken',
                      isMyConsultationStarted ? Icons.person : Icons.confirmation_number,
                    ),
                    Container(width: 1, height: 50, color: Colors.white30),
                    _buildBigStatusItem(
                      'Now Serving',
                      consultingEntry.isEmpty
                          ? '--'
                          : '#$currentTokenDisplay',
                      isMyConsultationStarted ? Icons.video_call : Icons.play_circle_fill,
                      isHighlight: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Different messages based on consultation status
                if (isMyConsultationStarted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Doctor is now consulting with you!\nPlease proceed to consultation room.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (peopleAhead == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      consultingEntry['tokenNumber'] == myToken
                          ? "🎯 It's your turn! Please proceed."
                          : "⏳ You are next in line!",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$peopleAhead people ahead of you",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Consultation Instructions if consultation started
        if (isMyConsultationStarted)
          _buildConsultationInstructions(),
        
        const SizedBox(height: 20),

        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () {
            _refreshTimer?.cancel();
            setState(() {
              _selectedAppointment = null;
              _queueStatus = null;
              _hasShownConsultationNotification = false;
            });
          },
          child: const Text('Back to Appointments'),
        ),
      ],
    ),
  );
}
// NEW: Build consultation started banner
Widget _buildConsultationStartedBanner(int tokenNumber) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green, Colors.green[700]!],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.green.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.notifications_active, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Consultation Has Started!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Token #$tokenNumber - Doctor is ready to see you.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward, color: Colors.white),
      ],
    ),
  );
}

// NEW: Build consultation instructions
Widget _buildConsultationInstructions() {
  return Card(
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 What to do now:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            icon: Icons.meeting_room,
            title: 'Go to Consultation Room',
            description: 'Proceed to the designated consultation area',
          ),
          _buildInstructionStep(
            icon: Icons.medical_services,
            title: 'Meet the Doctor',
            description: 'The doctor is waiting for your consultation',
          ),
          _buildInstructionStep(
            icon: Icons.list,
            title: 'Have Your Documents Ready',
            description: 'Keep your ID, medical reports, and insurance ready',
          ),
          _buildInstructionStep(
            icon: Icons.question_answer,
            title: 'Ask Questions',
            description: 'Feel free to discuss all your health concerns',
          ),
        ],
      ),
    ),
  );
}

Widget _buildInstructionStep({
  required IconData icon,
  required String title,
  required String description,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
// NEW: Build session ended view
Widget _buildSessionEndedView() {
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Celebration Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 60,
              color: Colors.green,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title
          const Text(
            '✅ Session Completed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green[100] ?? Colors.green),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.medical_services,
                  size: 48,
                  color: Colors.green,
                ),
                SizedBox(height: 16),
                Text(
                  'Today\'s consultation session has ended successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'All appointments for this doctor\'s schedule are now complete.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Doctor Info Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appointment Summary:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Doctor',
                    _selectedAppointment?['doctorName'] ?? 'Unknown',
                  ),
                  _buildDetailRow(
                    'Medical Center',
                    _selectedAppointment?['medicalCenterName'] ?? 'Unknown',
                  ),
                  _buildDetailRow(
                    'Your Token',
                    '#${_selectedAppointment?['tokenNumber'] ?? 'N/A'}',
                  ),
                  _buildDetailRow(
                    'Status',
                    'COMPLETED',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Next Steps
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Next Steps:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint('Follow your doctor\'s instructions carefully'),
                  _buildBulletPoint('Take prescribed medications on time'),
                  _buildBulletPoint('Schedule follow-up appointment if needed'),
                  _buildBulletPoint('Contact clinic for any concerns or questions'),
                  _buildBulletPoint('Keep your prescription and medical records safe'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _refreshTimer?.cancel();
                  setState(() {
                    _selectedAppointment = null;
                    _queueStatus = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to My Appointments'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // Optionally, navigate to home or dashboard
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.home),
                label: const Text('Return to Home'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Thank You Message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 24),
                SizedBox(height: 8),
                Text(
                  'Thank you for choosing our medical services!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Stay healthy and take care!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildBigStatusItem(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? Colors.yellowAccent : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard(
    Map<String, dynamic> patient, {
    bool isCurrent = false,
    bool isYou = false,
    bool isCompleted = false,
  }) {
    final tokenNumber = patient['tokenNumber'] ?? 0;
    final patientName = patient['patientName'] ?? 'Unknown Patient';

    Color backgroundColor = Colors.white;
    Color textColor = Colors.black;
    String statusText = 'Waiting';

    if (isYou) {
      backgroundColor = const Color(0xFF18A3B6).withOpacity(0.1);
      textColor = const Color(0xFF18A3B6);
      statusText = 'YOU';
    } else if (isCurrent) {
      backgroundColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
      statusText = 'CONSULTING';
    } else if (isCompleted) {
      backgroundColor = Colors.grey.withOpacity(0.1);
      textColor = Colors.grey;
      statusText = 'COMPLETED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '#$tokenNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (isYou)
                  Text(
                    'Your Appointment',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'waiting':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // --- Date Parsing Utilities (Kept from original) ---
  DateTime? _parseAppointmentDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
    if (dateValue is String && dateValue.isNotEmpty) {
      final sanitizedValue = _sanitizeDateString(dateValue);
      try {
        return DateTime.parse(sanitizedValue);
      } catch (_) {}
      // Add custom parsing logic here if needed for MM/DD/YYYY etc.
    }
    return null;
  }

  String _sanitizeDateString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('(') && trimmed.contains(')')) {
      final start = trimmed.indexOf('(');
      final end = trimmed.indexOf(')', start + 1);
      if (start != -1 && end != -1) return trimmed.substring(start + 1, end);
    }
    const labels = ['Today', 'Tomorrow', 'Yesterday'];
    for (final label in labels) {
      if (trimmed.startsWith(label))
        return trimmed.replaceFirst(label, '').trim();
    }
    return trimmed;
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
