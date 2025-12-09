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

      // Get TODAY's date in the format stored in appointments
      // Based on your payment_screen, dates are stored as "5/12/2025" (d/M/yyyy)
      final now = DateTime.now();
      final todayFormatted = '${now.day}/${now.month}/${now.year}';
      
      print('📅 TODAY IS: $todayFormatted');
      print('🔍 Looking for appointments with date: $todayFormatted');

      // Get appointments for this doctor WITH today's date
      // We need to check both possible date field names and formats
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .get();

      print('📊 Found ${appointmentsSnapshot.docs.length} total appointments');

      final appointments = <Map<String, dynamic>>[];
      
      for (final doc in appointmentsSnapshot.docs) {
        final appointment = doc.data();
        appointment['id'] = doc.id;
        
        // Check multiple possible date fields
        final dateString = appointment['appointmentDate']?.toString() ??
                          appointment['date']?.toString() ??
                          appointment['selectedDate']?.toString() ??
                          '';
        
        print('🔍 Checking appointment for: ${appointment['patientName']}');
        print('   Date string from DB: "$dateString"');
        
        if (dateString.isEmpty) {
          print('❌ No date found, skipping');
          continue;
        }
        
        // Extract date from various formats
        final extractedDate = _extractDateOnly(dateString);
        print('   Extracted date: "$extractedDate"');
        print('   Today date: "$todayFormatted"');
        
        if (extractedDate == todayFormatted) {
          print('✅✅✅ MATCH! This appointment is for TODAY');
          
          // Get patient details
          final patientId = appointment['patientId'];
          if (patientId != null) {
            try {
              final patientDoc = await _firestore.collection('patients').doc(patientId).get();
              if (patientDoc.exists) {
                appointment['patientName'] = patientDoc.data()?['fullname'] ?? appointment['patientName'] ?? 'Unknown Patient';
                appointment['patientPhone'] = patientDoc.data()?['phone'] ?? '';
                appointment['patientEmail'] = patientDoc.data()?['email'] ?? '';
              }
            } catch (e) {
              print('⚠️ Error loading patient: $e');
            }
          }
          
          appointments.add(appointment);
        } else {
          print('❌ Not for today');
        }
      }

      // Sort by token number or time
      appointments.sort((a, b) {
        // Try token number first
        final tokenA = a['tokenNumber'] ?? 999;
        final tokenB = b['tokenNumber'] ?? 999;
        if (tokenA != 999 || tokenB != 999) {
          return tokenA.compareTo(tokenB);
        }
        
        // Fallback to time
        final timeA = a['time'] ?? a['selectedTime'] ?? '';
        final timeB = b['time'] ?? b['selectedTime'] ?? '';
        return timeA.compareTo(timeB);
      });

      print('🎯 TODAY\'S APPOINTMENTS: ${appointments.length} found');
      for (var apt in appointments) {
        print('   👤 ${apt['patientName']} | 🕐 ${apt['time'] ?? apt['selectedTime']} | 🔢 Token: ${apt['tokenNumber']}');
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

  // Helper method to extract date only from various formats
  String _extractDateOnly(String dateString) {
    if (dateString.isEmpty) return '';
    
    // Remove any whitespace
    dateString = dateString.trim();
    
    // Case 1: Already in format "5/12/2025"
    if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(dateString)) {
      return dateString;
    }
    
    // Case 2: Has parentheses like "Today (5/12/2025)" or "Tomorrow (8/12/2025)"
    if (dateString.contains('(') && dateString.contains(')')) {
      final start = dateString.indexOf('(') + 1;
      final end = dateString.indexOf(')');
      if (start < end) {
        final extracted = dateString.substring(start, end).trim();
        // Validate it's a date
        if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(extracted)) {
          return extracted;
        }
      }
    }
    
    // Case 3: Try to parse other formats
    try {
      // Try parsing as ISO string
      final parsed = DateTime.parse(dateString);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      // Try other date formats
      try {
        final parsed = DateFormat('yyyy-MM-dd').parse(dateString);
        return '${parsed.day}/${parsed.month}/${parsed.year}';
      } catch (e) {
        // Return empty if can't parse
        return '';
      }
    }
  }

  // Alternative: Query directly by date (if you know the exact format)
  Future<void> _loadTodayAppointmentsDirectQuery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get today's date in multiple possible formats
      final now = DateTime.now();
      final todayFormatted1 = '${now.day}/${now.month}/${now.year}'; // 5/12/2025
      final todayFormatted2 = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}'; // 05/12/2025
      final todayFormatted3 = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'; // 2025-12-05
      
      print('🔍 Querying for appointments with date: $todayFormatted1');

      // Query using 'appointmentDate' field (from payment_screen)
      final snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .where('appointmentDate', isEqualTo: todayFormatted1)
          .get();

      print('📊 Found ${snapshot.docs.length} appointments for today');

      final appointments = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final appointment = doc.data();
        appointment['id'] = doc.id;
        
        // Get patient details
        final patientId = appointment['patientId'];
        if (patientId != null) {
          try {
            final patientDoc = await _firestore.collection('patients').doc(patientId).get();
            if (patientDoc.exists) {
              appointment['patientName'] = patientDoc.data()?['fullname'] ?? appointment['patientName'] ?? 'Unknown Patient';
              appointment['patientPhone'] = patientDoc.data()?['phone'] ?? '';
              appointment['patientEmail'] = patientDoc.data()?['email'] ?? '';
            }
          } catch (e) {
            print('⚠️ Error loading patient: $e');
          }
        }
        
        appointments.add(appointment);
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
    
    try {
      final time = _parseTime(timeSlot);
      return DateFormat('h:mm a').format(time);
    } catch (e) {
      return timeSlot;
    }
  }

  DateTime _parseTime(String timeString) {
    timeString = timeString.trim();
    
    try {
      return DateFormat('HH:mm').parse(timeString);
    } catch (e) {
      try {
        return DateFormat('h:mm a').parse(timeString);
      } catch (e) {
        return DateTime.now();
      }
    }
  }

  void _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': newStatus});

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
              _buildDetailRow('Date', appointment['appointmentDate'] ?? 'No date'),
              _buildDetailRow('Time', _formatTimeSlot(appointment['timeSlot'] ?? '')),
              _buildDetailRow('Status', appointment['status'] ?? 'Unknown'),
              _buildDetailRow('Token', appointment['tokenNumber']?.toString() ?? 'N/A'),
              _buildDetailRow('Phone', appointment['patientPhone'] ?? 'Not provided'),
              _buildDetailRow('Email', appointment['patientEmail'] ?? 'Not provided'),
              if (appointment['patientNotes'] != null && appointment['patientNotes'].toString().isNotEmpty)
                _buildDetailRow('Patient Notes', appointment['patientNotes'].toString()),
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
            icon: Icon(Icons.bug_report),
            onPressed: () {
              _debugCurrentDate();
            },
          ),
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

  void _debugCurrentDate() {
    final now = DateTime.now();
    final todayFormatted = '${now.day}/${now.month}/${now.year}';
    print('🔍 DEBUG CURRENT DATE:');
    print('   Today: $todayFormatted');
    print('   Full DateTime: ${now.toString()}');
    print('   Appointments count: ${_appointments.length}');
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
    final now = DateTime.now();
    final todayFormatted = '${now.day}/${now.month}/${now.year}';
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Appointments for Today',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            formattedDate,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            'Looking for date: $todayFormatted',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTodayAppointments,
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final now = DateTime.now();
    final todayFormatted = '${now.day}/${now.month}/${now.year}';
    
    return Column(
      children: [
        // Header with date and count
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Date: $todayFormatted',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
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
    final timeSlot = appointment['selectedTime'] ?? appointment['time'] ?? '';
    final status = appointment['status'] ?? 'pending';
    final tokenNumber = appointment['tokenNumber'];
    final date = appointment['appointmentDate'] ?? 'No date';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with token
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (tokenNumber != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF18A3B6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Token #$tokenNumber',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          patientName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
                  date,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            // Appointment type
            if (appointment['consultationType'] != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.video_call, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Type: ${appointment['consultationType']}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
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
                      if (status == 'waiting')
                        PopupMenuItem(
                          value: 'checked-in',
                          child: Text('Mark as Checked-in'),
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