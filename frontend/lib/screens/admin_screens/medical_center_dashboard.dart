import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../model/appointment.dart';

class MedicalCenterDashboard extends StatefulWidget {
  final String medicalCenterId;
  final String centerName;
  
  const MedicalCenterDashboard({
    Key? key,
    required this.medicalCenterId,
    required this.centerName,
  }) : super(key: key);

  @override
  State<MedicalCenterDashboard> createState() => _MedicalCenterDashboardState();
}

class _MedicalCenterDashboardState extends State<MedicalCenterDashboard>
    with SingleTickerProviderStateMixin {
  final String baseUrl = 'http://localhost:8080/api'; // Update with your backend URL
  
  late TabController _tabController;
  List<Appointment> appointments = [];
  bool isLoading = false;
  String selectedStatus = 'all';
  DateTime? selectedDate;
  
  final List<String> statuses = ['all', 'requested', 'confirmed', 'cancelled', 'completed'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final params = <String, String>{
        'medicalCenterId': widget.medicalCenterId,
      };
      
      if (selectedStatus != 'all') {
        params['status'] = selectedStatus;
      }
      
      if (selectedDate != null) {
        params['date'] = DateFormat('yyyy-MM-dd').format(selectedDate!);
      }
      
      final uri = Uri.parse('$baseUrl/appointments/medical-center')
          .replace(queryParameters: params);
      
      final response = await http.get(uri);
      
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

  Future<void> _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/appointments/$appointmentId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': newStatus,
          'adminNotes': 'Status updated by medical center admin',
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Appointment status updated successfully');
        _loadAppointments();
      } else {
        final data = json.decode(response.body);
        _showErrorSnackBar(data['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update appointment: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  List<Appointment> _getAppointmentsByStatus(String status) {
    if (status == 'all') return appointments;
    return appointments.where((apt) => apt.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.centerName} - Dashboard'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: _buildTabWithBadge('Requested', _getAppointmentsByStatus('requested').length),
            ),
            Tab(
              child: _buildTabWithBadge('Confirmed', _getAppointmentsByStatus('confirmed').length),
            ),
            Tab(
              child: _buildTabWithBadge('Cancelled', _getAppointmentsByStatus('cancelled').length),
            ),
            Tab(
              child: _buildTabWithBadge('All', appointments.length),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsList('requested'),
                _buildAppointmentsList('confirmed'),
                _buildAppointmentsList('cancelled'),
                _buildAppointmentsList('all'),
              ],
            ),
          ),
        ],
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
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                  });
                  _loadAppointments();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      selectedDate != null
                          ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                          : 'Filter by date',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (selectedDate != null)
            IconButton(
              onPressed: () {
                setState(() {
                  selectedDate = null;
                });
                _loadAppointments();
              },
              icon: const Icon(Icons.clear),
              tooltip: 'Clear date filter',
            ),
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(String status) {
    final filteredAppointments = _getAppointmentsByStatus(status);
    
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (filteredAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No ${status == 'all' ? '' : status} appointments found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New appointments will appear here',
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
        itemCount: filteredAppointments.length,
        itemBuilder: (context, index) {
          final appointment = filteredAppointments[index];
          return _buildAppointmentCard(appointment);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final statusColor = _getStatusColor(appointment.status);
    final isActionable = appointment.status == 'requested';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
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
                        appointment.patientName ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Phone: ${appointment.patientPhone ?? 'Not provided'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
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
                    appointment.status.toUpperCase(),
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
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Dr. ${appointment.doctorName ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  appointment.doctorSpecialty ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(appointment.date)),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${appointment.startTime} - ${appointment.endTime}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_getConsultationIcon(appointment.consultationType), 
                     size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  _formatConsultationType(appointment.consultationType),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
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
                      'Patient Notes:',
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
            if (isActionable) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(appointment),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAppointmentStatus(appointment.id, 'confirmed'),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Requested: ${DateFormat('MMM dd, yyyy HH:mm').format(appointment.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Appointment'),
          content: Text(
            'Are you sure you want to cancel the appointment with ${appointment.patientName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateAppointmentStatus(appointment.id, 'cancelled');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
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


