import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TodayAppointmentsScreen extends StatefulWidget {
  const TodayAppointmentsScreen({super.key});

  @override
  State<TodayAppointmentsScreen> createState() => _TodayAppointmentsScreenState();
}

class _TodayAppointmentsScreenState extends State<TodayAppointmentsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  String _todayDate = '';

  @override
  void initState() {
    super.initState();
    _loadTodayAppointments();
  }

  Future<void> _loadTodayAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get today's date in YYYY-MM-DD format
      final now = DateTime.now();
      _todayDate = DateFormat('yyyy-MM-dd').format(now);

      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .where('date', isEqualTo: _todayDate)
          .orderBy('timeSlot')
          .get();

      final appointments = <Map<String, dynamic>>[];

      for (final doc in appointmentsSnapshot.docs) {
        final appointment = doc.data();
        appointment['id'] = doc.id;
        
        // Get patient details
        final patientId = appointment['patientId'];
        if (patientId != null) {
          final patientDoc = await _firestore.collection('patients').doc(patientId).get();
          if (patientDoc.exists) {
            appointment['patientName'] = patientDoc.data()?['fullname'] ?? 'Unknown Patient';
            appointment['patientPhone'] = patientDoc.data()?['phone'] ?? '';
            appointment['patientEmail'] = patientDoc.data()?['email'] ?? '';
          } else {
            appointment['patientName'] = 'Unknown Patient';
          }
        }
        
        appointments.add(appointment);
      }

      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading appointments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'waiting':
        return Colors.purple;
      case 'checked-in':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeSlot(String timeSlot) {
    // Convert "09:00-10:00" to "9:00 AM - 10:00 AM"
    try {
      final times = timeSlot.split('-');
      if (times.length == 2) {
        final startTime = DateFormat('HH:mm').parse(times[0]);
        final endTime = DateFormat('HH:mm').parse(times[1]);
        return '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}';
      }
    } catch (e) {
      print('Error formatting time: $e');
    }
    return timeSlot;
  }

  void _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': newStatus});

      // Reload the appointments
      _loadTodayAppointments();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient', appointment['patientName'] ?? 'Unknown'),
              _buildDetailRow('Time', _formatTimeSlot(appointment['timeSlot'] ?? '')),
              _buildDetailRow('Status', appointment['status'] ?? 'Unknown'),
              _buildDetailRow('Phone', appointment['patientPhone'] ?? 'Not provided'),
              _buildDetailRow('Email', appointment['patientEmail'] ?? 'Not provided'),
              if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
                _buildDetailRow('Notes', appointment['notes']),
              if (appointment['symptoms'] != null && appointment['symptoms'].isNotEmpty)
                _buildDetailRow('Symptoms', appointment['symptoms']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Today's Appointments"),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTodayAppointments,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _appointments.isEmpty
              ? _buildEmptyState()
              : _buildAppointmentsList(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading appointments...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Appointments Today',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'You have no appointments scheduled for today.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Column(
      children: [
        // Header with date and count
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text('${_appointments.length} appointments'),
                backgroundColor: Color(0xFF18A3B6),
                labelStyle: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        // Appointments list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _appointments.length,
            itemBuilder: (context, index) {
              final appointment = _appointments[index];
              return _buildAppointmentCard(appointment);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final patientName = appointment['patientName'] ?? 'Unknown Patient';
    final timeSlot = appointment['timeSlot'] ?? '';
    final status = appointment['status'] ?? 'pending';
    final symptoms = appointment['symptoms'] ?? '';
    final notes = appointment['notes'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
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
                    patientName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Time slot
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  _formatTimeSlot(timeSlot),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            // Symptoms (if available)
            if (symptoms.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Symptoms: $symptoms',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Notes (if available)
            if (notes.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                'Notes: $notes',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showAppointmentDetails(appointment),
                    child: Text('View Details'),
                  ),
                ),
                SizedBox(width: 8),
                if (status != 'completed' && status != 'cancelled')
                  PopupMenuButton<String>(
                    onSelected: (newStatus) => 
                        _updateAppointmentStatus(appointment['id'], newStatus),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'confirmed',
                        child: Text('Mark as Confirmed'),
                      ),
                      PopupMenuItem(
                        value: 'completed',
                        child: Text('Mark as Completed'),
                      ),
                      PopupMenuItem(
                        value: 'cancelled',
                        child: Text('Cancel Appointment'),
                      ),
                    ],
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF18A3B6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}