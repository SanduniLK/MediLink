import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../model/appointment.dart';

class MyAppointmentsPage extends StatefulWidget {
  final String patientId;
  
  const MyAppointmentsPage({Key? key, required this.patientId}) : super(key: key);

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage>
    with SingleTickerProviderStateMixin {
  final String baseUrl = 'http://localhost:8080/api'; // Update with your backend URL
  
  late TabController _tabController;
  List<Appointment> appointments = [];
  bool isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Changed to 2 tabs
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/patient?patientId=${widget.patientId}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            appointments = (data['data'] as List)
                .map((apt) => Appointment.fromMap(apt['id'], apt))
                .toList();
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load appointments: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  List<Appointment> _getUpcomingAppointments() {
    final now = DateTime.now();
    return appointments.where((apt) {
      if (apt.status == 'cancelled') return false;
      final appointmentDate = DateTime.parse(apt.date);
      return appointmentDate.isAfter(now) || 
             (appointmentDate.year == now.year && 
              appointmentDate.month == now.month && 
              appointmentDate.day == now.day);
    }).toList();
  }

  List<Appointment> _getHistoryAppointments() {
    final now = DateTime.now();
    return appointments.where((apt) {
      final appointmentDate = DateTime.parse(apt.date);
      return appointmentDate.isBefore(DateTime(now.year, now.month, now.day)) ||
             apt.status == 'cancelled' ||
             apt.status == 'completed';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _getUpcomingAppointments();
    final history = _getHistoryAppointments();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: _buildTabWithBadge('Upcoming', upcoming.length),
            ),
            Tab(
              child: _buildTabWithBadge('History', history.length),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentsList(upcoming, 'upcoming'),
          _buildAppointmentsList(history, 'history'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to book appointment page
          // Navigator.push(context, MaterialPageRoute(
          //   builder: (context) => BookAppointmentPage(patientId: widget.patientId),
          // ));
        },
        icon: const Icon(Icons.add),
        label: const Text('Book New'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTabWithBadge(String title, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppointmentsList(List<Appointment> appointmentList, String type) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (appointmentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(type),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(type),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptySubMessage(type),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointmentList.length,
        itemBuilder: (context, index) {
          final appointment = appointmentList[index];
          return _buildAppointmentCard(appointment, type);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment, String type) {
    final statusColor = _getStatusColor(appointment.status);
    final appointmentDate = DateTime.parse(appointment.date);
    final isToday = _isToday(appointmentDate);
    final isHistory = type == 'history';
    final isCancelled = appointment.status == 'cancelled';
    final isCompleted = appointment.status == 'completed';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isCancelled ? Colors.grey[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${appointment.doctorName ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCancelled ? Colors.grey : null,
                        ),
                      ),
                      Text(
                        appointment.doctorSpecialty ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCancelled ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    _formatStatus(appointment.status).toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appointment.medicalCenterName ?? 'Unknown Center',
                    style: TextStyle(
                      fontSize: 14,
                      color: isCancelled ? Colors.grey : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today, 
                  size: 16, 
                  color: isToday ? Colors.orange[600] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, MMM dd, yyyy').format(appointmentDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: isToday ? Colors.orange[600] : 
                           isCancelled ? Colors.grey : Colors.grey[700],
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isToday && !isHistory) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'TODAY',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isCancelled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'CANCELLED',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isCompleted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${appointment.startTime} - ${appointment.endTime}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCancelled ? Colors.grey : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  _getConsultationIcon(appointment.consultationType), 
                  size: 16, 
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  _formatConsultationType(appointment.consultationType),
                  style: TextStyle(
                    fontSize: 14,
                    color: isCancelled ? Colors.grey : Colors.grey[700],
                  ),
                ),
              ],
            ),
            if (appointment.patientNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Notes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.patientNotes,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (appointment.adminNotes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Center Notes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.adminNotes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Booked: ${DateFormat('MMM dd, yyyy HH:mm').format(appointment.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const Spacer(),
                if (appointment.status == 'confirmed' && !isHistory) ...[
                  TextButton.icon(
                    onPressed: () {
                      // Handle join consultation (for online appointments)
                      if (appointment.consultationType != 'physical') {
                        _showJoinConsultationDialog(appointment);
                      } else {
                        _showGetDirectionsDialog(appointment);
                      }
                    },
                    icon: Icon(
                      appointment.consultationType == 'physical' 
                          ? Icons.directions 
                          : Icons.video_call,
                      size: 16,
                    ),
                    label: Text(
                      appointment.consultationType == 'physical' 
                          ? 'Get Directions' 
                          : 'Join Call',
                    ),
                  ),
                ],
                if (isHistory && !isCancelled) ...[
                  TextButton.icon(
                    onPressed: () {
                      _showAppointmentDetails(appointment);
                    },
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('Details'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinConsultationDialog(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${_formatConsultationType(appointment.consultationType)} Consultation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dr. ${appointment.doctorName}'),
              Text('${appointment.date} at ${appointment.startTime}'),
              const SizedBox(height: 16),
              Text(
                appointment.consultationType == 'video'
                    ? 'You will be connected to a video call with your doctor.'
                    : appointment.consultationType == 'audio'
                    ? 'You will be connected to an audio call with your doctor.'
                    : 'Get directions to the medical center.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Implement actual join functionality here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Join consultation feature coming soon!'),
                  ),
                );
              },
              child: const Text('Join Now'),
            ),
          ],
        );
      },
    );
  }

  void _showGetDirectionsDialog(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Get Directions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dr. ${appointment.doctorName}'),
              Text(appointment.medicalCenterName ?? 'Medical Center'),
              Text('${appointment.date} at ${appointment.startTime}'),
              const SizedBox(height: 16),
              const Text('Get directions to the medical center for your appointment.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Implement directions functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Directions feature coming soon!'),
                  ),
                );
              },
              child: const Text('Get Directions'),
            ),
          ],
        );
      },
    );
  }

  void _showAppointmentDetails(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Appointment Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Doctor', 'Dr. ${appointment.doctorName}'),
                _buildDetailRow('Specialty', appointment.doctorSpecialty ?? 'Not specified'),
                _buildDetailRow('Medical Center', appointment.medicalCenterName ?? 'Not specified'),
                _buildDetailRow('Date', DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(appointment.date))),
                _buildDetailRow('Time', '${appointment.startTime} - ${appointment.endTime}'),
                _buildDetailRow('Type', _formatConsultationType(appointment.consultationType)),
                _buildDetailRow('Status', _formatStatus(appointment.status)),
                _buildDetailRow('Booked On', DateFormat('MMM dd, yyyy HH:mm').format(appointment.createdAt)),
                if (appointment.patientNotes.isNotEmpty)
                  _buildDetailRow('Your Notes', appointment.patientNotes),
                if (appointment.adminNotes?.isNotEmpty == true)
                  _buildDetailRow('Center Notes', appointment.adminNotes!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  IconData _getEmptyIcon(String type) {
    switch (type) {
      case 'upcoming':
        return Icons.event_available;
      case 'history':
        return Icons.history;
      default:
        return Icons.event;
    }
  }

  String _getEmptyMessage(String type) {
    switch (type) {
      case 'upcoming':
        return 'No upcoming appointments';
      case 'history':
        return 'No appointment history';
      default:
        return 'No appointments';
    }
  }

  String _getEmptySubMessage(String type) {
    switch (type) {
      case 'upcoming':
        return 'Book a new appointment to get started';
      case 'history':
        return 'Your past appointments will appear here';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'requested':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'requested':
        return 'Requested';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  IconData _getConsultationIcon(String type) {
    switch (type) {
      case 'physical':
        return Icons.local_hospital;
      case 'audio':
        return Icons.phone;
      case 'video':
        return Icons.video_call;
      default:
        return Icons.help;
    }
  }

  String _formatConsultationType(String type) {
    switch (type) {
      case 'physical':
        return 'Physical Visit';
      case 'audio':
        return 'Audio Call';
      case 'video':
        return 'Video Call';
      default:
        return type;
    }
  }
}