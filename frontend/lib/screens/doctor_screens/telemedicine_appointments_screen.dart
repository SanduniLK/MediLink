import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';
import 'package:frontend/services/video_call_service.dart';
import 'package:frontend/telemedicine/audio_call_screen.dart';
import 'package:frontend/telemedicine/video_call_screen.dart';

class TelemedicineAppointmentsScreen extends StatefulWidget {
  const TelemedicineAppointmentsScreen({super.key});

  @override
  State<TelemedicineAppointmentsScreen> createState() =>
      _TelemedicineAppointmentsScreenState();
}

class _TelemedicineAppointmentsScreenState
    extends State<TelemedicineAppointmentsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VideoCallService _videoCallService = VideoCallService(); 
  String? _doctorId;
  String? _doctorName;

  @override
  void initState() {
    super.initState();
    _getDoctorInfo();
  }

  Future<void> _getDoctorInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doctorDoc = await _firestore.collection('doctors').doc(user.uid).get();
      if (doctorDoc.exists) {
        final data = doctorDoc.data()!;
        setState(() {
          _doctorId = user.uid;
          _doctorName = data['fullName'] ?? data['name'] ?? 'Doctor';
        });
      } else {
        setState(() {
          _doctorId = user.uid;
          _doctorName = user.displayName ?? 'Doctor';
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching doctor info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_doctorId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF18A3B6),
  foregroundColor: Colors.white,
  title: Text(
    _doctorName == null
        ? 'Loading...'
        : 'Dr. $_doctorName - Telemedicine Sessions',
    style: const TextStyle(fontWeight: FontWeight.bold),
  ),
  centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('telemedicine_sessions')
            .where('doctorId', isEqualTo: _doctorId) // ✅ filter by doctorId
            .where('status', whereIn: ['Scheduled', 'confirmed', 'In-Progress'])
            
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data?.docs ?? [];
          if (sessions.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final sessionDoc = sessions[index];
              final data = sessionDoc.data() as Map<String, dynamic>;
              return _buildSessionCard(sessionDoc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(String sessionId, Map<String, dynamic> data) {
    final patientName = data['patientName'] ?? 'Patient';
    final date = data['date'] ?? '';
    final timeSlot = data['timeSlot'] ?? '';
    final status = data['status'] ?? 'Scheduled';
    final tokenNumber = data['tokenNumber'] ?? '';
    final videoLink = data['videoLink'] ?? '';
    final consultationType = data['consultationType'] ?? 'video'; // ✅ FIXED: Get from data
    final isVideoCall = consultationType == 'video'; // ✅ FIXED: Define locally

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Date: $date'),
            Text('Time: $timeSlot'),
            Text('Token: #$tokenNumber'),
            Text('Type: ${consultationType == 'video' ? 'Video Call' : 'Audio Call'}'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call),
              label: Text(
                status == 'In-Progress'
                   ? 'Join ${consultationType == 'video' ? 'Video' : 'Audio'} Call'
                   : 'Start ${consultationType == 'video' ? 'Video' : 'Audio'} Consultation',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getButtonColor(status),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _startConsultation(sessionId, data, videoLink),
            ),
            SizedBox(height:10,),
             if (status == 'In-Progress')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.medical_services),
                    label: const Text('write Prescription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _writePrescription(sessionId, data),
                  ),
          ],
        ),
      ),
    );
  }

 // In your doctor's screen - UPDATE the _startConsultation method
void _startConsultation(String sessionId, Map<String, dynamic> data, String videoLink) async {
  try {
    final patientId = data['patientId'] ?? '';
    final patientName = data['patientName'] ?? 'Patient';
    final doctorName = _doctorName ?? 'Doctor';
   final consultationType = data['consultationType'] ?? 'video';
    final isVideoCall = consultationType == 'video';

     debugPrint('🎯 Starting $consultationType consultation with $patientName');

    // Update session to In-Progress
    if (data['status'] == 'Scheduled' || data['status'] == 'confirmed') {
      await _firestore.collection('telemedicine_sessions').doc(sessionId).update({
        'status': 'In-Progress',
        'startedAt': FieldValue.serverTimestamp(),
      });
    }

    // ✅ FIXED: Use the new method to start call as doctor
   await _videoCallService.notifyPatientCallStarted(
      patientId, 
      sessionId, 
      doctorName,
      consultationType: consultationType // ✅ ADD THIS
    );
     debugPrint('✅ Doctor started $consultationType call and notified patient $patientName');

    if (!mounted) return;

    // Navigate to video call screen as DOCTOR
   if (isVideoCall) {
      // Navigate to Video Call Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            callId: sessionId,
            otherUserName: patientName,
            otherUserId: patientId,
            currentUserId: _doctorId!,
            currentUserName: _doctorName!,
            isDoctor: true,
            isIncomingCall: false,
            isVideoCall: true, 
          ),
        ),
      );
    } else {
      // Navigate to Audio Call Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioCallScreen(
            callId: sessionId,
            otherUserName: patientName,
            otherUserId: patientId,
            currentUserId: _doctorId!,
            currentUserName: _doctorName!,
            isDoctor: true,
            isIncomingCall: false,
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('❌ Error starting consultation: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error starting call: $e'), backgroundColor: Colors.red),
    );
  }
}
void _writePrescription(String sessionId, Map<String, dynamic> data) {
  final patientId = data['patientId'] ?? '';
  final patientName = data['patientName'] ?? 'Patient';
  
  try {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionScreen(
          
        ),
      ),
    );
  } catch (e) {
    debugPrint('❌ Error navigating to prescription screen: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error opening prescription: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No Telemedicine Sessions Found',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'in-progress':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getButtonColor(String status) {
    if (status.toLowerCase() == 'in-progress') return Colors.green;
    return const Color(0xFF18A3B6);
  }
}
