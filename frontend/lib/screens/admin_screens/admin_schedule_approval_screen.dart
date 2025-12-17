// frontend/lib/screens/admin_screens/admin_schedule_approval_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_schedule_service.dart';

class AdminScheduleApprovalScreen extends StatefulWidget {
  final String medicalCenterId;
  final String medicalCenterName;
  
  const AdminScheduleApprovalScreen({
    super.key,
    required this.medicalCenterId,
    required this.medicalCenterName,
  });

  @override
  State<AdminScheduleApprovalScreen> createState() => _AdminScheduleApprovalScreenState();
}

class _AdminScheduleApprovalScreenState extends State<AdminScheduleApprovalScreen> {
  bool isLoading = false;
  String? errorMessage;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _checkFirebaseConnection();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      await AdminScheduleService.getSchedulesCount(widget.medicalCenterId);
      if (_isMounted) {
        setState(() {
          errorMessage = null;
        });
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          errorMessage = 'Firebase connection error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Approval'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkFirebaseConnection,
          ),
        ],
      ),
      body: errorMessage != null
          ? _buildErrorState()
          : Column(
              children: [
                // Statistics Card
                StreamBuilder<Map<String, int>>(
                  stream: Stream.fromFuture(AdminScheduleService.getSchedulesCount(widget.medicalCenterId)),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorCard(snapshot.error.toString());
                    }
                    
                    final counts = snapshot.data ?? {'pending': 0, 'approved': 0, 'rejected': 0, 'total': 0};
                    
                    return Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard('Pending', counts['pending']!, Colors.orange),
                            _buildStatCard('Approved', counts['approved']!, Colors.green),
                            _buildStatCard('Rejected', counts['rejected']!, Colors.red),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                Expanded(
                  child: DefaultTabController(
                    
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Color.fromARGB(255, 16, 131, 146),
                          tabs: [
                            Tab(
                              icon: Icon(Icons.pending_actions),
                              text: 'Pending',
                              
                            ),
                            Tab(
                              icon: Icon(Icons.check_circle),
                              text: 'Approved',
                            ),
                            Tab(
                              icon: Icon(Icons.cancel),
                              text: 'Rejected',
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // PENDING TAB
                              _buildSchedulesList(AdminScheduleService.getPendingSchedules(widget.medicalCenterId), 'pending'),
                              
                              // APPROVED TAB
                              _buildSchedulesList(AdminScheduleService.getApprovedSchedules(widget.medicalCenterId), 'approved'),
                              
                              // REJECTED TAB
                              _buildSchedulesList(AdminScheduleService.getRejectedSchedules(widget.medicalCenterId), 'rejected'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Firebase Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _checkFirebaseConnection,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'Error Loading Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatIcon(title),
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  IconData _getStatIcon(String title) {
    switch (title.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  Widget _buildSchedulesList(Stream<List<Map<String, dynamic>>> stream, String status) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }

        final schedules = snapshot.data ?? [];

        if (schedules.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyStateIcon(status),
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyStateMessage(status),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            return _buildScheduleCard(schedules[index], status);
          },
        );
      },
    );
  }

  IconData _getEmptyStateIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  String _getEmptyStateMessage(String status) {
    switch (status) {
      case 'pending':
        return 'No pending schedules to review';
      case 'approved':
        return 'No approved schedules yet';
      case 'rejected':
        return 'No rejected schedules';
      default:
        return 'No schedules found';
    }
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule, String status) {
    final doctorName = schedule['doctorName']?.toString() ?? 
                     schedule['fullname']?.toString() ?? 
                     'Unknown Doctor';
    
    final scheduleId = schedule['scheduleId']?.toString() ?? 
                      schedule['id']?.toString() ?? 
                      '';
    
    final appointmentType = schedule['appointmentType']?.toString() ?? 'physical';
    final slotDuration = schedule['slotDuration']?.toString() ?? '30';
    final maxAppointments = schedule['maxAppointments']?.toString() ?? '10';
    final availableSlots = schedule['availableSlots']?.toString() ?? maxAppointments;
    
    final date = _parseDate(schedule['date']);
    
    final startTime = schedule['startTime']?.toString() ?? '09:00';
    final endTime = schedule['endTime']?.toString() ?? '17:00';
    
    final createdAt = _parseDate(schedule['createdAt']) ?? DateTime.now();
    
    final specialization = schedule['specialization']?.toString() ?? 
                          schedule['specialty']?.toString() ?? 
                          'General';

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
                        'Dr. $doctorName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Specialty: $specialization',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                        ),
                      ),
                      if (scheduleId.isNotEmpty)
                        Text(
                          'ID: ${scheduleId.length > 10 ? '${scheduleId.substring(0, 10)}...' : scheduleId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            _buildDetailRow('Appointment Type', _capitalize(appointmentType)),
            
            if (date != null)
              _buildDetailRow('Date', _formatDate(date)),
            
            _buildDetailRow('Time Slot', '$startTime - $endTime'),
            _buildDetailRow('Slot Duration', '$slotDuration minutes'),
            _buildDetailRow('Max Appointments', maxAppointments),
            _buildDetailRow('Available Slots', availableSlots),
            _buildDetailRow('Submitted', _formatDateTime(createdAt)),

            if (schedule['medicalCenterName'] != null)
              _buildDetailRow('Medical Center', schedule['medicalCenterName'].toString()),

            const SizedBox(height: 12),

            _buildWeeklyScheduleSection(schedule),

            const SizedBox(height: 12),

            if (status == 'pending') ...[
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : () => _approveSchedule(scheduleId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : () => _rejectSchedule(scheduleId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],

            if (status != 'pending') ...[
              const Divider(),
              const SizedBox(height: 8),
              if (schedule['approvedAt'] != null)
                _buildDetailRow(
                  '${status == 'approved' ? 'Approved' : 'Rejected'} On', 
                  _formatDateTime(_parseDate(schedule['approvedAt']) ?? DateTime.now())
                ),
              
              if (schedule['approvedBy'] != null)
                _buildDetailRow('${status == 'approved' ? 'Approved' : 'Rejected'} By', 
                    schedule['approvedBy'].toString()),
            ],
          ],
        ),
      ),
    );
  }

  DateTime? _parseDate(dynamic dateField) {
    if (dateField == null) return null;
    
    if (dateField is Timestamp) {
      return dateField.toDate();
    } else if (dateField is DateTime) {
      return dateField;
    } else if (dateField is String) {
      try {
        return DateTime.parse(dateField);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Widget _buildWeeklyScheduleSection(Map<String, dynamic> schedule) {
    final weeklySchedule = schedule['weeklySchedule'] ?? 
                          schedule['weeklySchedules'] ?? 
                          schedule['recurringSchedule'];
    
    if (weeklySchedule == null || weeklySchedule is! List || weeklySchedule.isEmpty) {
      return const SizedBox();
    }

    final availableDays = weeklySchedule.where((day) => 
      day is Map && (day['available'] == true || day['isAvailable'] == true)
    ).toList();

    if (availableDays.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Schedule:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: availableDays.map((day) {
            final dayName = day['day']?.toString() ?? day['dayName']?.toString() ?? '';
            final startTime = day['startTime']?.toString() ?? '09:00';
            final endTime = day['endTime']?.toString() ?? '17:00';
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Text(
                '${_capitalize(dayName)}\n$startTime - $endTime',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduleDay = DateTime(date.year, date.month, date.day);
    
    if (scheduleDay == today) {
      return 'Today (${date.day}/${date.month}/${date.year})';
    } else if (scheduleDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow (${date.day}/${date.month}/${date.year})';
    } else {
      return '${_getDayName(date.weekday)}, ${date.day}/${date.month}/${date.year}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _approveSchedule(String scheduleId) async {
    if (!_isMounted) return;
    
    setState(() => isLoading = true);

    try {
      await AdminScheduleService.approveSchedule(scheduleId);
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule approved! Now available for patients.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (_isMounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _rejectSchedule(String scheduleId) async {
    if (!_isMounted) return;
    
    setState(() => isLoading = true);

    try {
      await AdminScheduleService.rejectSchedule(scheduleId);
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (_isMounted) {
        setState(() => isLoading = false);
      }
    }
  }
}