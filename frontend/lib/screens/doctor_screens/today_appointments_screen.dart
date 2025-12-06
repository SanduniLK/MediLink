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
    _appointments = [];
  });

  try {
    final user = _auth.currentUser;
    if (user == null) return;

    print('🔍 Loading appointments for doctor: ${user.uid}');
    
    // Get ALL appointments for this doctor first
    final appointmentsSnapshot = await _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .get();

    print('📊 Found ${appointmentsSnapshot.docs.length} total appointments');

    final appointments = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    for (final doc in appointmentsSnapshot.docs) {
      final appointment = doc.data();
      appointment['id'] = doc.id;
      
      // Extract date from appointment
      final appointmentDate = appointment['date']?.toString() ?? '';
      final appointmentStatus = appointment['status']?.toString() ?? '';
      
      print('📅 Checking appointment: ${appointment['patientName']} | Date: $appointmentDate | Status: $appointmentStatus');
      
      // Check if appointment is for today
      bool isToday = false;
      
      // Method 1: Check with helper function
      isToday = _isDateToday(appointmentDate, now);
      
      // Method 2: Check for "Today" keyword
      if (!isToday && appointmentDate.toLowerCase().contains('today')) {
        isToday = true;
        print('✅ Matched via "Today" keyword');
      }
      
      // Method 3: Check date formats directly
      if (!isToday) {
        // Try to match date directly
        final todayFormatted = DateFormat('dd/MM/yyyy').format(now);
        if (appointmentDate.contains(todayFormatted)) {
          isToday = true;
          print('✅ Matched via date format');
        }
      }
      
      // Skip if not today
      if (!isToday) {
        print('❌ Not today: $appointmentDate');
        continue;
      }
      
      print('✅✅✅ TODAY\'S APPOINTMENT FOUND!');
      
      // Get patient details
      final patientId = appointment['patientId'];
      if (patientId != null) {
        try {
          final patientDoc = await _firestore.collection('patients').doc(patientId).get();
          if (patientDoc.exists) {
            appointment['patientName'] = patientDoc.data()?['fullname'] ?? appointment['patientName'] ?? 'Unknown Patient';
            appointment['patientPhone'] = patientDoc.data()?['phone'] ?? '';
            appointment['patientEmail'] = patientDoc.data()?['email'] ?? '';
          } else {
            appointment['patientName'] = appointment['patientName'] ?? 'Unknown Patient';
          }
        } catch (e) {
          print('❌ Error loading patient data: $e');
          appointment['patientName'] = appointment['patientName'] ?? 'Unknown Patient';
        }
      } else {
        appointment['patientName'] = appointment['patientName'] ?? 'Unknown Patient';
      }
      
      appointments.add(appointment);
    }

    // Sort appointments by time
    appointments.sort((a, b) {
      final timeA = a['time']?.toString() ?? '';
      final timeB = b['time']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });

    print('🎯 Total today appointments: ${appointments.length}');
    for (var apt in appointments) {
      print('   - ${apt['patientName']} at ${apt['time']} (${apt['date']})');
    }

    setState(() {
      _appointments = appointments;
      _isLoading = false;
    });
  } catch (e) {
    print('❌ Error loading appointments: $e');
    setState(() {
      _isLoading = false;
    });
  }
}

bool _isDateToday(String dateString, DateTime today) {
  if (dateString.isEmpty) return false;
  
  print('🔍 Checking if date is today: $dateString');
  
  try {
    // Try to extract date from formats like "Tomorrow (10/10/2025)"
    final regex = RegExp(r'(\d{1,2}/\d{1,2}/\d{4})');
    final match = regex.firstMatch(dateString);
    if (match != null) {
      final datePart = match.group(1);
      print('📆 Extracted date part: $datePart');
      try {
        final date = DateFormat('dd/MM/yyyy').parse(datePart!);
        final isToday = date.year == today.year && 
                       date.month == today.month && 
                       date.day == today.day;
        print('📅 Parsed date: $date | Today: $today | IsToday: $isToday');
        return isToday;
      } catch (e) {
        print('❌ Error parsing date part: $e');
      }
    }
    
    // Try to match "Today" explicitly
    if (dateString.toLowerCase().contains('today')) {
      print('✅ Matched "Today" keyword');
      return true;
    }
    
    // Try common date formats
    List<String> formats = [
      'dd/MM/yyyy', 
      'dd-MM-yyyy',
      'dd.MM.yyyy',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'MMMM dd, yyyy',
      'EEEE, MMMM dd, yyyy'
    ];
    
    for (final format in formats) {
      try {
        final date = DateFormat(format).parse(dateString);
        final isToday = date.year == today.year && 
                       date.month == today.month && 
                       date.day == today.day;
        if (isToday) {
          print('✅ Matched format $format');
        }
        return isToday;
      } catch (e) {
        // Continue to next format
      }
    }
    
    // Check if date string contains today's date in different formats
    final todayFormats = [
      DateFormat('dd/MM/yyyy').format(today),
      DateFormat('dd-MM-yyyy').format(today),
      DateFormat('yyyy-MM-dd').format(today),
      DateFormat('MM/dd/yyyy').format(today),
    ];
    
    for (final todayFormatted in todayFormats) {
      if (dateString.contains(todayFormatted)) {
        print('✅ Matched via today formatted string: $todayFormatted');
        return true;
      }
    }
    
    print('❌ No match found for: $dateString');
    return false;
  } catch (e) {
    print('💥 Error in _isDateToday: $e');
    return false;
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
  // Handle different time formats
  if (timeSlot.contains(' - ')) {
    try {
      final times = timeSlot.split(' - ');
      if (times.length == 2) {
        final startTime = _parseTime(times[0]);
        final endTime = _parseTime(times[1]);
        
        final startFormatted = DateFormat('h:mm a').format(startTime);
        final endFormatted = DateFormat('h:mm a').format(endTime);
        return '$startFormatted - $endFormatted';
      }
    } catch (e) {
      print('Error formatting time: $e');
    }
  }
  
  // Try to parse as a single time
  try {
    final time = _parseTime(timeSlot);
    return DateFormat('h:mm a').format(time);
  } catch (e) {
    return timeSlot;
  }
}

DateTime _parseTime(String timeString) {
  // Handle different time formats
  timeString = timeString.trim();
  
  // Try 24-hour format
  try {
    return DateFormat('HH:mm').parse(timeString);
  } catch (e) {
    // Try 12-hour format
    try {
      return DateFormat('h:mm a').parse(timeString);
    } catch (e) {
      return DateTime.now(); // Fallback
    }
  }
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
  final timeSlot = appointment['time'] ?? appointment['timeSlot'] ?? ''; // Check both fields
  final status = appointment['status'] ?? 'pending';
  final symptoms = appointment['symptoms'] ?? appointment['patientNotes'] ?? '';
  final notes = appointment['notes'] ?? appointment['patientNotes'] ?? '';

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
          // Date
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                appointment['date']?.toString() ?? 'No date',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          // Symptoms/Notes (if available)
          if (symptoms.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Notes: $symptoms',
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