// screens/assistant_screens/attendance_marking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AttendanceMarkingScreen extends StatefulWidget {
  const AttendanceMarkingScreen({super.key});

  @override
  State<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  List<Map<String, dynamic>> _todaysSchedules = [];
  Map<String, dynamic>? _selectedSchedule;
  List<Map<String, dynamic>> _scheduleAppointments = [];
  bool _isLoading = false;
  StreamSubscription? _scheduleSubscription;
  StreamSubscription? _appointmentsSubscription;

  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _backgroundColor = const Color(0xFFDDF0F5);

  @override
  void initState() {
    super.initState();
    _loadTodaysSchedules();
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTodaysSchedules() async {
    setState(() => _isLoading = true);
    
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      
      // Query based on your actual schedule structure
      final scheduleQuery = await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .where('availableDate', isEqualTo: today)
          .where('status', whereIn: ['confirmed', 'active'])
          .where('adminApproved', isEqualTo: true)
          .where('doctorConfirmed', isEqualTo: true)
          .orderBy('createdAt')
          .get();
      
      if (scheduleQuery.docs.isNotEmpty) {
        final schedules = scheduleQuery.docs.map((doc) {
          final data = doc.data();
          
          // Parse schedule date/time from your data structure
          String scheduleTime = 'All day';
          if (data['weeklySchedule'] != null && data['weeklySchedule'] is List) {
            final weeklySchedule = data['weeklySchedule'] as List;
            for (var daySchedule in weeklySchedule) {
              if (daySchedule['available'] == true && 
                  daySchedule['timeSlots'] != null && 
                  (daySchedule['timeSlots'] as List).isNotEmpty) {
                final timeSlots = daySchedule['timeSlots'] as List;
                if (timeSlots.isNotEmpty) {
                  scheduleTime = '${timeSlots[0]['startTime']} - ${timeSlots[0]['endTime']}';
                  break;
                }
              }
            }
          }
          
          return {
            'id': doc.id,
            ...data,
            'scheduleTime': scheduleTime,
          };
        }).toList();
        
        setState(() {
          _todaysSchedules = schedules;
          if (schedules.isNotEmpty) {
            _selectedSchedule = schedules.first;
            _loadScheduleAppointments(_selectedSchedule!['id']);
          }
        });
      } else {
        setState(() {
          _todaysSchedules = [];
          _selectedSchedule = null;
          _scheduleAppointments = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadScheduleAppointments(String scheduleId) {
    _appointmentsSubscription?.cancel();
    
    setState(() {
      _isLoading = true;
      _scheduleAppointments = [];
    });
    
    _appointmentsSubscription = FirebaseFirestore.instance
        .collection('appointments')
        .where('scheduleId', isEqualTo: scheduleId)
        .orderBy('tokenNumber')
        .snapshots()
        .listen((snapshot) {
      _processAppointmentsData(snapshot.docs);
    });
  }

  void _processAppointmentsData(List<DocumentSnapshot> docs) {
    final List<Map<String, dynamic>> appointments = [];
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        // Determine if patient is attended based on your queue system logic
        final status = data['status'] ?? 'confirmed';
        final queueStatus = data['queueStatus'] ?? '';
        final arrivedAt = data['arrivedAt'];
        final bookedAt = data['bookedAt'];
        
        bool isAttended = false;
        String attendanceStatus = 'pending';
        
        if (arrivedAt != null) {
          isAttended = true;
          attendanceStatus = 'attended';
        } else if (queueStatus == 'waiting' || queueStatus == 'in_consultation') {
          isAttended = true;
          attendanceStatus = 'in_queue';
        } else if (queueStatus == 'completed') {
          isAttended = true;
          attendanceStatus = 'consulted';
        } else if (status == 'skipped' || queueStatus == 'skipped') {
          attendanceStatus = 'absent';
        }
        
        final appointment = {
          'id': doc.id,
          'patientId': data['patientId'] ?? '',
          'patientName': data['patientName'] ?? 'Unknown',
          'tokenNumber': data['tokenNumber'] ?? 0,
          'status': status,
          'queueStatus': queueStatus,
          'appointmentTime': data['appointmentTime'] ?? data['timeSlot'] ?? '--:--',
          'mobile': data['patientMobile'] ?? data['mobile'] ?? data['phone'] ?? '',
          'isAttended': isAttended,
          'attendanceStatus': attendanceStatus,
          'arrivedAt': arrivedAt,
          'bookedAt': bookedAt,
          'markedBy': data['attendanceMarkedBy'] ?? '',
          'markedAt': data['attendanceMarkedAt'],
          'bookedAppointments': data['bookedAppointments'] ?? 0,
        };
        appointments.add(appointment);
      }
    }
    
    // Sort by token number
    appointments.sort((a, b) => (a['tokenNumber'] ?? 0).compareTo(b['tokenNumber'] ?? 0));
    
    if (mounted) {
      setState(() {
        _scheduleAppointments = appointments;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAttendance(Map<String, dynamic> appointment, bool attended) async {
    if (!mounted) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final patientName = appointment['patientName'];
    final tokenNumber = appointment['tokenNumber'];
    final appointmentId = appointment['id'];
    
    try {
      final updateData = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
        'attendanceMarkedBy': user.uid,
        'attendanceMarkedAt': FieldValue.serverTimestamp(),
      };
      
      if (attended) {
        // Mark as attended - ready for queue
        updateData.addAll({
          'arrivedAt': FieldValue.serverTimestamp(),
          'queueStatus': 'waiting',
          'status': 'confirmed',
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$patientName (Token #$tokenNumber) marked as attended'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Mark as absent - skip from queue
        updateData.addAll({
          'queueStatus': 'skipped',
          'status': 'skipped',
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$patientName (Token #$tokenNumber) marked as absent'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);
      
      // Also update schedule booked appointments count
      if (_selectedSchedule != null) {
        final currentCount = _selectedSchedule!['bookedAppointments'] ?? 0;
        await FirebaseFirestore.instance
            .collection('schedules')
            .doc(_selectedSchedule!['id'])
            .update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllAttended() async {
    if (!mounted || _scheduleAppointments.isEmpty) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Attended?'),
        content: const Text('Mark all patients in this schedule as attended?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark All'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      final timestamp = FieldValue.serverTimestamp();
      int markedCount = 0;
      
      for (var appointment in _scheduleAppointments) {
        final status = appointment['status'];
        final queueStatus = appointment['queueStatus'];
        final attendanceStatus = appointment['attendanceStatus'];
        
        // Only mark pending patients (not attended, not completed, not skipped)
        if (attendanceStatus == 'pending' || 
            (status != 'completed' && 
             status != 'skipped' && 
             queueStatus != 'completed' && 
             queueStatus != 'skipped')) {
          
          final docRef = FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointment['id']);
          
          batch.update(docRef, {
            'arrivedAt': timestamp,
            'queueStatus': 'waiting',
            'status': 'confirmed',
            'attendanceMarkedBy': user.uid,
            'attendanceMarkedAt': timestamp,
            'lastUpdated': timestamp,
          });
          markedCount++;
        }
      }
      
      if (markedCount > 0) {
        await batch.commit();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$markedCount patients marked as attended'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No patients need to be marked'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status, String queueStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': status,
        'queueStatus': queueStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating appointment: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadTodaysSchedules();
  }

  String _getScheduleTimeText(Map<String, dynamic> schedule) {
    if (schedule['weeklySchedule'] != null && schedule['weeklySchedule'] is List) {
      final weeklySchedule = schedule['weeklySchedule'] as List;
      
      // Find available days
      final availableDays = weeklySchedule.where((day) => day['available'] == true).toList();
      
      if (availableDays.isNotEmpty) {
        final firstAvailableDay = availableDays.first;
        if (firstAvailableDay['timeSlots'] != null && (firstAvailableDay['timeSlots'] as List).isNotEmpty) {
          final timeSlots = firstAvailableDay['timeSlots'] as List;
          if (timeSlots.isNotEmpty) {
            return '${firstAvailableDay['day']}: ${timeSlots[0]['startTime']} - ${timeSlots[0]['endTime']}';
          }
        }
      }
    }
    
    return 'Check schedule';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Attendance'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _todaysSchedules.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_todaysSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Active Schedules Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'There are no confirmed and approved schedules for today.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Schedule Selection
        _buildScheduleSelector(),
        
        const SizedBox(height: 16),
        
        // Schedule Info Card
        if (_selectedSchedule != null)
          _buildScheduleInfoCard(),
        
        const SizedBox(height: 16),
        
        // Attendance Statistics
        _buildAttendanceStats(),
        
        const SizedBox(height: 16),
        
        // Quick Actions
        if (_scheduleAppointments.isNotEmpty)
          _buildQuickActions(),
        
        const SizedBox(height: 16),
        
        // Appointments List
        Expanded(
          child: _buildAppointmentsList(),
        ),
      ],
    );
  }

  Widget _buildScheduleSelector() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Today\'s Schedule',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<Map<String, dynamic>>(
              value: _selectedSchedule,
              isExpanded: true,
              items: _todaysSchedules.map((schedule) {
                final doctorName = schedule['doctorName'] ?? 'Unknown Doctor';
                final medicalCenter = schedule['medicalCenterName'] ?? 'Unknown Center';
                final scheduleTime = _getScheduleTimeText(schedule);
                
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: schedule,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$medicalCenter',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        scheduleTime,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (schedule) {
                if (schedule != null) {
                  setState(() {
                    _selectedSchedule = schedule;
                  });
                  _loadScheduleAppointments(schedule['id']);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleInfoCard() {
    final doctorName = _selectedSchedule!['doctorName'] ?? 'Unknown Doctor';
    final medicalCenter = _selectedSchedule!['medicalCenterName'] ?? 'Unknown Center';
    final bookedAppointments = _selectedSchedule!['bookedAppointments'] ?? 0;
  
    final scheduleTime = _getScheduleTimeText(_selectedSchedule!);
    
    final adminApproved = _selectedSchedule!['adminApproved'] ?? false;
    final doctorConfirmed = _selectedSchedule!['doctorConfirmed'] ?? false;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.medical_services,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        medicalCenter,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        scheduleTime,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: adminApproved && doctorConfirmed 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: adminApproved && doctorConfirmed 
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      child: Text(
                        adminApproved && doctorConfirmed ? 'Confirmed' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          color: adminApproved && doctorConfirmed 
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem('Booked', '$bookedAppointments', Colors.blue),
                
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStats() {
    final total = _scheduleAppointments.length;
    final attended = _scheduleAppointments.where((a) => a['attendanceStatus'] == 'attended' || 
                                                       a['attendanceStatus'] == 'in_queue' || 
                                                       a['attendanceStatus'] == 'consulted').length;
    final pending = _scheduleAppointments.where((a) => a['attendanceStatus'] == 'pending').length;
    final absent = _scheduleAppointments.where((a) => a['attendanceStatus'] == 'absent').length;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Attendance Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCircle('Total', total, Colors.blue),
                _buildStatCircle('Attended', attended, Colors.green),
                _buildStatCircle('Pending', pending, Colors.orange),
                _buildStatCircle('Absent', absent, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final pendingCount = _scheduleAppointments.where((a) => a['attendanceStatus'] == 'pending').length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: pendingCount > 0 ? _markAllAttended : null,
              icon: const Icon(Icons.check_circle, size: 20),
              label: Text('Mark All Attended ($pendingCount)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // You can add filtering functionality here
            },
            tooltip: 'Filter',
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_scheduleAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Appointments',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            Text(
              'No appointments booked for this schedule',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _scheduleAppointments.length,
      itemBuilder: (context, index) {
        return _buildAppointmentCard(_scheduleAppointments[index]);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final tokenNumber = appointment['tokenNumber'] ?? 0;
    final patientName = appointment['patientName'] ?? 'Unknown';
    final appointmentTime = appointment['appointmentTime'] ?? '--:--';
    final mobile = appointment['mobile'] ?? '';
    final attendanceStatus = appointment['attendanceStatus'] ?? 'pending';
    final status = appointment['status'] ?? 'confirmed';
    final queueStatus = appointment['queueStatus'] ?? '';
    final arrivedAt = appointment['arrivedAt'];
    final bookedAt = appointment['bookedAt'];
    
    // Determine status color, icon and text
    Color statusColor = Colors.grey;
    String statusText = 'Pending';
    IconData statusIcon = Icons.access_time;
    Color bgColor = Colors.white;
    
    switch (attendanceStatus) {
      case 'attended':
        statusColor = Colors.green;
        statusText = 'Attended';
        statusIcon = Icons.check_circle;
        bgColor = Colors.green.withOpacity(0.05);
        break;
      case 'in_queue':
        statusColor = Colors.blue;
        statusText = 'In Queue';
        statusIcon = Icons.people;
        bgColor = Colors.blue.withOpacity(0.05);
        break;
      case 'consulted':
        statusColor = Colors.purple;
        statusText = 'Consulted';
        statusIcon = Icons.medical_services;
        bgColor = Colors.purple.withOpacity(0.05);
        break;
      case 'absent':
        statusColor = Colors.red;
        statusText = 'Absent';
        statusIcon = Icons.close;
        bgColor = Colors.red.withOpacity(0.05);
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.access_time;
        bgColor = Colors.orange.withOpacity(0.05);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Center(
                    child: Text(
                      '#$tokenNumber',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (mobile.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              mobile,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Appointment Details
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Slot: $appointmentTime',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            
            // Arrival Time
            if (arrivedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Arrived: ${DateFormat('hh:mm a').format((arrivedAt as Timestamp).toDate())}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            
            // Queue Status
            if (queueStatus.isNotEmpty && attendanceStatus != 'absent')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Queue: ${queueStatus.replaceAll('_', ' ').toUpperCase()}',
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            if (attendanceStatus == 'pending' || attendanceStatus == 'absent')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAttendance(appointment, true),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mark Attended'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (attendanceStatus == 'pending')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markAttendance(appointment, false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Mark Absent'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            
            // Change Status button for already attended/consulted patients
            if (attendanceStatus != 'pending' && attendanceStatus != 'absent')
              ElevatedButton.icon(
                onPressed: () => _markAttendance(appointment, false),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Mark as Absent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 36),
                ),
              ),
          ],
        ),
      ),
    );
  }
}