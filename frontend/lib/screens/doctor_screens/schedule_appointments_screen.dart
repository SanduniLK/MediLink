import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'allschedule.dart';
import 'doctor_unified_search_screen.dart'; // Add this import

// Color Scheme (same as main file)
const Color primaryColor = Color(0xFF18A3B6);
const Color secondaryColor = Color(0xFF32BACD);
const Color accentColor1 = Color(0xFF85CEDA);
const Color accentColor2 = Color(0xFFB2DEE6);
const Color backgroundColor = Color(0xFFDDF0F5);
const Color textColorDark = Color(0xFF1A3A3F);
const Color textColorLight = Color(0xFF5A6D70);

// Appointment Model
class ScheduleAppointment {
  final String id;
  final String appointmentType;
  final String consultationType;
  final String? chatRoomId;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final int currentQueueNumber;
  final String date;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String fees;
  final String medicalCenterId;
  final String medicalCenterName;
  final DateTime? paidAt;
  final String patientId;
  final String patientName;
  final String patientNotes;
  final String paymentStatus;
  final String qrCodeData;
  final String queueStatus;
  final String scheduleId;
  final String selectedDate;
  final String selectedTime;
  final String status;
  final String? telemedicineId;
  final String time;
  final int tokenNumber;
  final String? videoLink;
  final DateTime updatedAt;

  ScheduleAppointment({
    required this.id,
    required this.appointmentType,
    required this.consultationType,
    this.chatRoomId,
    this.cancelledAt,
    required this.createdAt,
    required this.currentQueueNumber,
    required this.date,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.fees,
    required this.medicalCenterId,
    required this.medicalCenterName,
    this.paidAt,
    required this.patientId,
    required this.patientName,
    required this.patientNotes,
    required this.paymentStatus,
    required this.qrCodeData,
    required this.queueStatus,
    required this.scheduleId,
    required this.selectedDate,
    required this.selectedTime,
    required this.status,
    this.telemedicineId,
    required this.time,
    required this.tokenNumber,
    this.videoLink,
    required this.updatedAt,
  });

  factory ScheduleAppointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ScheduleAppointment(
      id: doc.id,
      appointmentType: data['appointmentType'] ?? '',
      consultationType: data['consultationType'] ?? '',
      chatRoomId: data['chatRoomId'],
      cancelledAt: data['cancelledAt']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      currentQueueNumber: data['currentQueueNumber'] ?? 0,
      date: data['date'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      doctorSpecialty: data['doctorSpecialty'] ?? '',
      fees: data['fees'] ?? '',
      medicalCenterId: data['medicalCenterId'] ?? '',
      medicalCenterName: data['medicalCenterName'] ?? '',
      paidAt: data['paidAt']?.toDate(),
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      patientNotes: data['patientNotes'] ?? '',
      paymentStatus: data['paymentStatus'] ?? '',
      qrCodeData: data['qrCodeData'] ?? '',
      queueStatus: data['queueStatus'] ?? '',
      scheduleId: data['scheduleId'] ?? '',
      selectedDate: data['selectedDate'] ?? '',
      selectedTime: data['selectedTime'] ?? '',
      status: data['status'] ?? '',
      telemedicineId: data['telemedicineId'],
      time: data['time'] ?? '',
      tokenNumber: data['tokenNumber'] ?? 0,
      videoLink: data['videoLink'],
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  bool get isActive => status.toLowerCase() != 'cancelled';
  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class ScheduleAppointmentsScreen extends StatefulWidget {
  final DoctorSchedule schedule;
  

  const ScheduleAppointmentsScreen({
    super.key,
    required this.schedule,
  });

  @override
  State<ScheduleAppointmentsScreen> createState() => _ScheduleAppointmentsScreenState();
}

class _ScheduleAppointmentsScreenState extends State<ScheduleAppointmentsScreen> {
  late Stream<QuerySnapshot> _appointmentsStream;
  List<ScheduleAppointment> _appointments = [];
  bool _isLoading = true;
  int _totalAppointments = 0;
  int _activeAppointments = 0;
  int _cancelledAppointments = 0;
  double _totalRevenue = 0;
  int _currentQueueNumber = 0;
  String? _currentappointmentId;
 StreamSubscription<QuerySnapshot>? _appointmentsSubscription;
 
 bool _hasConsultationStarted = false;
  bool _isSessionEndedByDoctor = false;
  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

void _loadAppointments() {
  _appointmentsStream = FirebaseFirestore.instance
      .collection('appointments')
      .where('scheduleId', isEqualTo: widget.schedule.id)
      .snapshots();

  _appointmentsSubscription = _appointmentsStream.listen((snapshot) async {
    if (!mounted) return;

    final appointments = snapshot.docs
        .map((doc) => ScheduleAppointment.fromFirestore(doc))
        .toList()
      ..sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));

    await _initializeQueueStatus(appointments);

    if (!mounted) return;

    final currentAppointment = _getCurrentAppointment(appointments);

    final total = appointments.length;
    final active = appointments.where((a) => a.isActive).length;
    final cancelled = appointments.where((a) => !a.isActive).length;
    final revenue = appointments
        .where((a) => a.isPaid)
        .fold(0.0, (sum, a) => sum + (double.tryParse(a.fees) ?? 0));
    
    // Check if any consultation is already active
    final isConsultationActive = appointments
        .any((a) => a.queueStatus.toLowerCase() == 'in_consultation');
    
    // Check if session was ended by doctor
    final scheduleDoc = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(widget.schedule.id)
        .get();
    
    final isSessionEnded = scheduleDoc.data()?['sessionEnded'] ?? false;
    final endedByDoctor = scheduleDoc.data()?['endedByDoctor'] ?? false;
    
    debugPrint('📋 Appointments loaded: ${appointments.length} total, $active active');
    debugPrint('🔍 Current appointment: ${currentAppointment?.patientName} (#${currentAppointment?.tokenNumber})');
    debugPrint('🏥 Consultation active: $isConsultationActive');
    debugPrint('🔚 Session ended: $isSessionEnded (by doctor: $endedByDoctor)');

    if (mounted) {
      setState(() {
        _appointments = appointments;
        _totalAppointments = total;
        _activeAppointments = active;
        _cancelledAppointments = cancelled;
        _totalRevenue = revenue;
        _currentQueueNumber = currentAppointment?.tokenNumber ?? 0;
        _currentappointmentId = currentAppointment?.id;
        _hasConsultationStarted = isConsultationActive;
        _isSessionEndedByDoctor = isSessionEnded && endedByDoctor;
        _isLoading = false;
      });
    }
  }, onError: (error) {
    debugPrint('❌ Error loading appointments: $error');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  });
}
Future<void> _initializeQueueStatus(List<ScheduleAppointment> appointments) async {
  final activeConfirmedAppointments = appointments
      .where((a) => a.isActive && a.status.toLowerCase() == 'confirmed')
      .toList();

  if (activeConfirmedAppointments.isEmpty) {
    debugPrint('⏭️ No active confirmed appointments found');
    return;
  }

  // Check if there's already an appointment in consultation
  final inConsultationList = activeConfirmedAppointments
      .where((a) => a.queueStatus.toLowerCase() == 'in_consultation')
      .toList();

  final ScheduleAppointment? inConsultation = inConsultationList.isNotEmpty ? inConsultationList.first : null;

  if (inConsultation != null) {
    debugPrint('🎯 Already have appointment in consultation: #${inConsultation.tokenNumber}');
    
    // Update local state
    if (mounted) {
      setState(() {
        _hasConsultationStarted = true;
      });
    }
    return;
  }

  // If no one is in consultation, don't automatically set anyone
  // Wait for doctor to explicitly click "Start Consultation"
  debugPrint('⏸️ No appointment in consultation - waiting for doctor to start');
}
ScheduleAppointment? _getCurrentAppointment(List<ScheduleAppointment> appointments) {
  // Get the appointment currently in consultation
  final inConsultation = appointments
      .where((a) => a.isActive && 
                   a.status.toLowerCase() == 'confirmed' &&
                   a.queueStatus.toLowerCase() == 'in_consultation')
      .firstOrNull;

  if (inConsultation != null) {
    return inConsultation;
  }

  // Fallback to first waiting appointment if none in consultation
  final waitingAppointments = appointments
      .where((a) => a.isActive && 
                   a.status.toLowerCase() == 'confirmed' &&
                   a.queueStatus.toLowerCase() == 'waiting')
      .toList()
    ..sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));

  return waitingAppointments.isNotEmpty ? waitingAppointments.first : null;
}
void _updateQueueStatus(String appointmentId, String newStatus) async {
  try {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({
      'queueStatus': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    if (newStatus == 'completed') {
      // Move to next patient in queue
      await _moveToNextPatient();
    }
  } catch (e) {
    debugPrint('Error updating queue: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
Future<void> _startConsultationProcess() async {
  try {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    // 1. Find the first waiting patient
    final waitingAppointments = _appointments
        .where((a) => a.isActive && 
                     a.status.toLowerCase() == 'confirmed' &&
                     a.queueStatus.toLowerCase() == 'waiting')
        .toList()
      ..sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));
    
    if (waitingAppointments.isEmpty) {
      _showError('No waiting patients found to start consultation');
      setState(() { _isLoading = false; });
      return;
    }
    
    final firstPatient = waitingAppointments.first;
    
    // 2. Update Firestore to mark patient as in consultation
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(firstPatient.id)
        .update({
      'queueStatus': 'in_consultation',
      'consultationStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // 3. Send notification to patient
    await _sendPatientNotification(firstPatient);
    
    // 4. Update local state
    setState(() {
      _currentQueueNumber = firstPatient.tokenNumber;
      _currentappointmentId = firstPatient.id;
      _hasConsultationStarted = true;
      _isLoading = false;
    });
    
    // 5. Show success message to doctor
    _showConsultationStartedSuccess(firstPatient);
    
    // 6. Navigate to consultation screen after a brief delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _navigateToConsultationScreen();
      }
    });
    
  } catch (e) {
    debugPrint('❌ Error starting consultation: $e');
    setState(() { _isLoading = false; });
    _showError('Failed to start consultation: $e');
  }
}
void _showConsultationStartedSuccess(ScheduleAppointment patient) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Consultation Started!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Now consulting with ${patient.patientName} (Token #${patient.tokenNumber})',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
  
  // Also show a dialog for more visibility
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.medical_services, color: Colors.green),
          SizedBox(width: 12),
          Text('Consultation Started'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 60),
          SizedBox(height: 20),
          Text(
            'You are now consulting with:',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  patient.patientName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Token #${patient.tokenNumber}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  patient.selectedTime,
                  style: TextStyle(color: Colors.green[600]),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Please proceed with the consultation.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
Future<void> _sendPatientNotification(ScheduleAppointment patient) async {
  try {
    // Create notification in Firestore
    await FirebaseFirestore.instance
        .collection('patientNotifications')
        .add({
      'patientId': patient.patientId,
      'type': 'consultation_started',
      'title': '🎯 Your Consultation Has Started!',
      'message': 'Dr. ${widget.schedule.doctorName} is ready to see you. Token #${patient.tokenNumber}',
      'appointmentId': patient.id,
      'tokenNumber': patient.tokenNumber,
      'doctorName': widget.schedule.doctorName,
      'medicalCenter': widget.schedule.medicalCenterName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'urgent': true,
    });
    
    debugPrint('📢 Notification sent to patient ${patient.patientName}');
    
  } catch (e) {
    debugPrint('❌ Error sending notification: $e');
    // Don't fail the whole process if notification fails
  }
}
void _navigateToConsultationScreen() {
  debugPrint('📌 Navigating to Doctor Unified Search Screen');
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DoctorUnifiedSearchScreen(
        doctorId: widget.schedule.doctorId,
        doctorName: widget.schedule.doctorName,
        scheduleId: widget.schedule.id,
        appointmentType: widget.schedule.appointmentType,
        currentAppointmentId: _currentappointmentId,
      ),
    ),
  );
}
void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}

Future<void> _moveToNextPatient() async {
  final confirmedAppointments = _appointments
      .where((a) => a.isActive && 
                    a.status.toLowerCase() == 'confirmed' &&
                    a.queueStatus.toLowerCase() == 'waiting')
      .toList()
    ..sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));
  
  if (confirmedAppointments.isNotEmpty) {
    final nextAppointment = confirmedAppointments.first;
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(nextAppointment.id)
          .update({
        'queueStatus': 'in_consultation',
        'consultationStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to next patient
      await _sendPatientNotification(nextAppointment);
      
      setState(() {
        _currentQueueNumber = nextAppointment.tokenNumber;
        _currentappointmentId = nextAppointment.id;
        _hasConsultationStarted = true;
      });
      
      // Show notification to doctor
      _showNextPatientNotification(nextAppointment);
      
      debugPrint('⏭️ Moved to next patient: #${nextAppointment.tokenNumber} (${nextAppointment.patientName})');
      
    } catch (e) {
      debugPrint('❌ Error moving to next patient: $e');
      _showError('Failed to move to next patient: $e');
    }
  } else {
    setState(() {
      _currentQueueNumber = 0;
      _currentappointmentId = null;
      _hasConsultationStarted = false;
    });
    debugPrint('🏁 No more patients in queue');
    _showSessionEndedNotification();
  }
}
void _showNextPatientNotification(ScheduleAppointment nextPatient) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_forward, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Next Patient Ready',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Now consulting with ${nextPatient.patientName} (Token #${nextPatient.tokenNumber})',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      backgroundColor: Colors.blue,
      duration: Duration(seconds: 3),
    ),
  );
}
void _showSessionEndedNotification() {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All consultations completed for this schedule!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 5),
    ),
  );
}
// NEW: Show end session confirmation
void _showEndSessionConfirmation() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 12),
          Text('End Consultation Session?' ,style: TextStyle(fontSize: 16),),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to end the current consultation session?',
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
                  '⚠️ This will:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                SizedBox(height: 8),
                _buildWarningPoint('after end consulation cannot be restart'),
                
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Patients who are still waiting will be notified that the session has ended.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await _endSessionByDoctor();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
          ),
          child: Text('Yes, End Session'),
        ),
      ],
    ),
  );
}
Future<void> _endSessionByDoctor() async {
  try {
    setState(() {
      _isLoading = true;
    });
    
    // 1. Mark all waiting appointments as "session_ended"
    final waitingAppointments = _appointments
        .where((a) => a.isActive && 
                     a.status.toLowerCase() == 'confirmed' &&
                     a.queueStatus.toLowerCase() == 'waiting')
        .toList();
    
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    for (final appointment in waitingAppointments) {
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointment.id);
      
      batch.update(appointmentRef, {
        'queueStatus': 'session_ended',
        'status': 'cancelled',
        'cancelledReason': 'Session ended by doctor',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to each waiting patient
      await _sendSessionEndedNotification(appointment);
    }
    
    // 2. Mark schedule as session ended
    final scheduleRef = FirebaseFirestore.instance
        .collection('doctorSchedules')
        .doc(widget.schedule.id);
    
    batch.update(scheduleRef, {
      'sessionEnded': true,
      'endedByDoctor': true,
      'endedAt': FieldValue.serverTimestamp(),
      'endedBy': 'Doctor',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // 3. Commit batch
    await batch.commit();
    
    // 4. Update local state
    setState(() {
      _isSessionEndedByDoctor = true;
      _hasConsultationStarted = false;
      _currentQueueNumber = 0;
      _currentappointmentId = null;
      _isLoading = false;
    });
    
    // 5. Show success message
    _showSessionEndedSuccess(waitingAppointments.length);
    
  } catch (e) {
    debugPrint('❌ Error ending session: $e');
    setState(() {
      _isLoading = false;
    });
    _showError('Failed to end session: $e');
  }
}
Future<void> _sendSessionEndedNotification(ScheduleAppointment appointment) async {
  try {
    await FirebaseFirestore.instance
        .collection('patientNotifications')
        .add({
      'patientId': appointment.patientId,
      'type': 'session_ended_by_doctor',
      'title': '⚠️ Session Ended',
      'message': 'Consultation session has been ended by Dr. ${widget.schedule.doctorName}. Your appointment has been cancelled.',
      'appointmentId': appointment.id,
      'tokenNumber': appointment.tokenNumber,
      'doctorName': widget.schedule.doctorName,
      'medicalCenter': widget.schedule.medicalCenterName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'urgent': true,
    });
    
    debugPrint('📢 Session ended notification sent to ${appointment.patientName}');
    
  } catch (e) {
    debugPrint('❌ Error sending session ended notification: $e');
  }
}
void _showSessionEndedSuccess(int waitingPatientsCount) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Session Ended Successfully',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '$waitingPatientsCount waiting patients have been notified.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      backgroundColor: Colors.red[700],
      duration: Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
  
  // Also show success dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.done_all, color: Colors.red),
          SizedBox(width: 12),
          Text('Session Ended'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stop_circle, color: Colors.red, size: 60),
          SizedBox(height: 20),
          Text(
            'Consultation session has been ended.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Waiting patients have been notified.',
                  style: TextStyle(color: Colors.red[700]),
                ),
                SizedBox(height: 8),
                Text(
                  '$waitingPatientsCount patient(s) affected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'The "Start Consultation" button is now disabled.',
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
Widget _buildWarningPoint(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, size: 8, color: Colors.red[700]),
        SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(primaryColor.value).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Back button and title
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.schedule.doctorName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColorDark,
                              ),
                            ),
                            Text(
                              widget.schedule.medicalCenterName,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColorLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Statistics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.people,
                          label: 'Total',
                          value: _totalAppointments.toString(),
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.check_circle,
                          label: 'Active',
                          value: _activeAppointments.toString(),
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.monetization_on,
                          label: 'Revenue',
                          value: 'Rs.${_totalRevenue.toStringAsFixed(0)}',
                          color: Colors.orange,
                          
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  
                ],
              ),
            ),

   // SINGLE Start Consultation/Continue Consultation Button
if (_activeAppointments > 0 && _currentQueueNumber > 0)
  Container(
    padding: const EdgeInsets.all(16),
    color: _isSessionEndedByDoctor ? Colors.grey[200] : accentColor2,
    child: Column(
      children: [
        // Row with two buttons
        Row(
          children: [
            // Start/Continue Consultation Button
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSessionEndedByDoctor ? null : () async {
                    debugPrint('🚀 ${_hasConsultationStarted ? 'Continue' : 'Start'} Consultation clicked');
                    
                    if (!_hasConsultationStarted) {
                      await _startConsultationProcess();
                    } else {
                      _navigateToConsultationScreen();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSessionEndedByDoctor 
                      ? Colors.grey 
                      : (_hasConsultationStarted ? Colors.green : primaryColor),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: Icon(
                    widget.schedule.appointmentType == 'telemedicine' ? 
                    Icons.video_call : Icons.local_hospital,
                    size: 24,
                  ),
                  label: Text(
                    _hasConsultationStarted ? 'Continue Consultation' : 'Start Consultation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: 12),
            
            // End Session Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSessionEndedByDoctor ? null : () {
                  _showEndSessionConfirmation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: Icon(Icons.stop_circle, size: 24),
                label: Text(
                  'End Session',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Session Status Indicator
        if (_isSessionEndedByDoctor)
          Container(
            margin: EdgeInsets.only(top: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info, color: Colors.red[700]),
                SizedBox(width: 8),
                Text(
                  'Session ended by doctor',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  ),

            // Appointments List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    )
                  : _appointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: accentColor2,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  size: 48,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Appointments',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: textColorDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No appointments booked for this schedule yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColorLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            return _buildAppointmentCard(_appointments[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(color.value).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(color.value).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColorLight,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColorDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(ScheduleAppointment appointment) {
    final isCurrent = appointment.tokenNumber == _currentQueueNumber;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(primaryColor.value).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: isCurrent ? Border.all(
          color: primaryColor,
          width: 2,
        ) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCurrent ? primaryColor : accentColor2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${appointment.tokenNumber}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColorDark,
                          ),
                        ),
                        Text(
                          appointment.selectedTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColorLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(appointment.statusColor.value).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        appointment.isActive ? Icons.check_circle : Icons.cancel,
                        size: 14,
                        color: appointment.statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        appointment.status.capitalize(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: appointment.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Details Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3,
              children: [
                _buildAppointmentDetailItem(
                  icon: Icons.medical_services,
                  label: 'Specialty',
                  value: appointment.doctorSpecialty,
                ),
                _buildAppointmentDetailItem(
                  icon: Icons.payment,
                  label: 'Fees',
                  value: 'Rs.${appointment.fees}',
                ),
                _buildAppointmentDetailItem(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: appointment.selectedDate,
                ),
                _buildAppointmentDetailItem(
                  icon: Icons.payment,
                  label: 'Payment',
                  value: appointment.paymentStatus.capitalize(),
                  color: appointment.isPaid ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentDetailItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: textColorLight,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColorDark,
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // NEW: Send notification to patient that consultation has started
Future<void> _sendConsultationStartedNotification(String appointmentId) async {
  try {
    // Get appointment details
    final appointmentDoc = await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get();
    
    if (appointmentDoc.exists) {
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      final patientId = appointmentData['patientId'];
      final tokenNumber = appointmentData['tokenNumber'];
      final patientName = appointmentData['patientName'];
      
      if (patientId != null) {
        // Create a notification document
        await FirebaseFirestore.instance
            .collection('patientNotifications')
            .add({
          'patientId': patientId,
          'type': 'consultation_started',
          'title': '🎯 Your Turn Has Come!',
          'message': 'Doctor is ready to consult with you. Token #$tokenNumber',
          'appointmentId': appointmentId,
          'tokenNumber': tokenNumber,
          'doctorName': widget.schedule.doctorName,
          'medicalCenter': widget.schedule.medicalCenterName,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'data': {
            'action': 'go_to_consultation',
            'scheduleId': widget.schedule.id,
            'appointmentId': appointmentId,
          }
        });
        
        debugPrint('📢 Notification sent to patient $patientId (Token #$tokenNumber)');
        
        // Also update a flag in patient's appointment for real-time detection
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({
          'consultationStartedNotification': true,
          'lastNotificationSent': FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (e) {
    debugPrint('❌ Error sending notification: $e');
  }
}
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}