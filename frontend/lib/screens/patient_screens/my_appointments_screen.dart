import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../model/appointment.dart';

// Add this import for prescription service
import '../../services/prescription_storage_service.dart';

class MyAppointmentsPage extends StatefulWidget {
  final String patientId;
  
  const MyAppointmentsPage({Key? key, required this.patientId}) : super(key: key);

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage>
    with SingleTickerProviderStateMixin {
  final String baseUrl = 'http://localhost:8080/api'; 
  
  late TabController _tabController;
  List<Appointment> appointments = [];
  bool isLoading = false;
  
  // Add these for prescription management
  final Map<String, Map<String, dynamic>> _prescriptions = {};
  final Map<String, bool> _loadingPrescriptions = {};
  final Map<String, bool> _hasPrescription = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          
          // Check for prescriptions for completed appointments
          _checkPrescriptionsForCompletedAppointments();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load appointments: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  // New method to check prescriptions for completed appointments
  Future<void> _checkPrescriptionsForCompletedAppointments() async {
    final completedAppointments = appointments.where((apt) => apt.status == 'completed').toList();
    
    for (final appointment in completedAppointments) {
      // Use appointment.id as the prescription identifier
      await _checkIfPrescriptionExists(appointment.id);
    }
  }
  
  // New method to check if prescription exists for an appointment
  Future<void> _checkIfPrescriptionExists(String appointmentId) async {
    if (_loadingPrescriptions[appointmentId] == true) return;
    
    setState(() {
      _loadingPrescriptions[appointmentId] = true;
    });
    
    try {
      debugPrint('💊 Checking for prescription for appointment: $appointmentId');
      
      final prescription = await PrescriptionFirestoreService.getPrescriptionByAppointmentId(appointmentId);
      
      if (mounted) {
        setState(() {
          _hasPrescription[appointmentId] = prescription != null;
          if (prescription != null) {
            _prescriptions[appointmentId] = prescription;
          }
          _loadingPrescriptions[appointmentId] = false;
        });
      }
      
    } catch (e) {
      debugPrint('❌ Error checking prescription: $e');
      if (mounted) {
        setState(() {
          _loadingPrescriptions[appointmentId] = false;
          _hasPrescription[appointmentId] = false;
        });
      }
    }
  }
  
  // New method to show prescription
  Future<void> _showPrescription(Appointment appointment) async {
    final appointmentId = appointment.id;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[50],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!)),
            SizedBox(height: 16),
            Text('Loading prescription...', style: TextStyle(color: Colors.blue[600])),
          ],
        ),
      ),
    );
    
    try {
      // Fetch prescription
      final prescription = await PrescriptionFirestoreService.getPrescriptionByAppointmentId(appointmentId);
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (prescription == null) {
        _showErrorSnackBar('No prescription found for this appointment');
        return;
      }
      
      // Show prescription dialog
      _showPrescriptionDialog(appointment, prescription);
      
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showErrorSnackBar('Failed to load prescription: $e');
    }
  }
  
  // New method to show prescription dialog
  void _showPrescriptionDialog(Appointment appointment, Map<String, dynamic> prescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.medication, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Prescription', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic info
              _buildPrescriptionDetailRow('Doctor', 'Dr. ${prescription['doctorName'] ?? appointment.doctorName}'),
              _buildPrescriptionDetailRow('Patient', prescription['patientName'] ?? 'Patient'),
              _buildPrescriptionDetailRow('Appointment ID', appointment.id),
              _buildPrescriptionDetailRow('Date', _formatPrescriptionDate(prescription['createdAt'])),
              
              SizedBox(height: 16),
              
              // Medicines section
              Text('Medicines:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              SizedBox(height: 8),
              
              if (prescription['medicines'] != null && (prescription['medicines'] as List).isNotEmpty)
                ...(prescription['medicines'] as List).map<Widget>((medicine) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💊 ${medicine['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Dosage: ${medicine['dosage']}'),
                          Text('Frequency: ${medicine['frequency']}'),
                          Text('Duration: ${medicine['duration']}'),
                          if (medicine['instructions'] != null && medicine['instructions'].toString().isNotEmpty)
                            Text('Instructions: ${medicine['instructions']}'),
                        ],
                      ),
                    ),
                  );
                }).toList()
              else
                Text('No medicines prescribed', style: TextStyle(color: Colors.grey)),
              
              SizedBox(height: 16),
              
              // Additional info
              if (prescription['diagnosis'] != null && prescription['diagnosis'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diagnosis:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    SizedBox(height: 4),
                    Text(prescription['diagnosis']),
                    SizedBox(height: 12),
                  ],
                ),
              
              if (prescription['description'] != null && prescription['description'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    SizedBox(height: 4),
                    Text(prescription['description']),
                    SizedBox(height: 12),
                  ],
                ),
              
              // Pharmacy info
              if (prescription['dispensingPharmacy'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dispensing Pharmacy:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    SizedBox(height: 4),
                    Text(prescription['dispensingPharmacy']),
                    SizedBox(height: 8),
                    Text('Last Dispensed: ${_formatDateTime(prescription['lastDispensedAt']?.toDate() ?? DateTime.now())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              
              // Prescription image
              if (prescription['prescriptionImageUrl'] != null && prescription['prescriptionImageUrl'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    Text('Prescription Image:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        prescription['prescriptionImageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrescriptionDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _formatPrescriptionDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('MMM dd, yyyy HH:mm').format(date.toDate());
      } else if (date is String) {
        return DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(date));
      } else if (date is DateTime) {
        return DateFormat('MMM dd, yyyy HH:mm').format(date);
      }
      return 'Unknown date';
    } catch (e) {
      return 'Invalid date';
    }
  }
  
  String _formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
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
    final hasPrescription = isCompleted && _hasPrescription[appointment.id] == true;
    final isLoadingPrescription = _loadingPrescriptions[appointment.id] == true;
    
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
                if (isHistory) ...[
                  // Always show details button for history
                  TextButton.icon(
                    onPressed: () {
                      _showAppointmentDetails(appointment);
                    },
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('Details'),
                  ),
                  
                  // Show prescription button only for completed appointments with prescription
                  if (isCompleted) ...[
                    const SizedBox(width: 8),
                    if (isLoadingPrescription)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (hasPrescription)
                      TextButton.icon(
                        onPressed: () => _showPrescription(appointment),
                        icon: const Icon(Icons.medication, size: 16),
                        label: const Text('Prescription'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                      ),
                  ],
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