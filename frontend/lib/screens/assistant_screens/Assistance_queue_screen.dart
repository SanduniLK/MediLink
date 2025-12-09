// screens/assistant_screens/assistant_queue_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AssistantQueueScreen extends StatefulWidget {
  const AssistantQueueScreen({super.key});

  @override
  State<AssistantQueueScreen> createState() => _AssistantQueueScreenState();
}

class _AssistantQueueScreenState extends State<AssistantQueueScreen> {
  List<Map<String, dynamic>> _waitingPatients = [];
  Map<String, dynamic>? _currentPatient;
  List<Map<String, dynamic>> _completedPatients = [];
  List<Map<String, dynamic>> _skippedPatients = [];
  
  bool _isLoading = false;
  StreamSubscription? _queueSubscription;
  Map<String, dynamic>? _selectedSchedule;
  List<Map<String, dynamic>> _availableSchedules = [];
  
  final Color _accentColor = const Color(0xFF18A3B6);
  final Color _backgroundColor = const Color(0xFFDDF0F5);

  @override
  void initState() {
    super.initState();
    _loadAvailableSchedules();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAvailableSchedules() async {
    setState(() => _isLoading = true);
    
    try {
      // Get today's active schedules
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final scheduleQuery = await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: 'active')
          .orderBy('date')
          .get();
      
      if (scheduleQuery.docs.isNotEmpty) {
        final schedules = scheduleQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        
        setState(() {
          _availableSchedules = schedules;
          if (schedules.isNotEmpty) {
            _selectedSchedule = schedules.first;
            _setupQueueStream(_selectedSchedule!['id']);
          }
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

  void _setupQueueStream(String scheduleId) {
    _queueSubscription?.cancel();
    
    setState(() => _isLoading = true);
    
    _queueSubscription = FirebaseFirestore.instance
        .collection('appointments')
        .where('scheduleId', isEqualTo: scheduleId)
        .snapshots()
        .listen((snapshot) {
      _processQueueData(snapshot.docs);
    });
  }

  void _processQueueData(List<DocumentSnapshot> docs) {
    final List<Map<String, dynamic>> waiting = [];
    Map<String, dynamic>? current;
    final List<Map<String, dynamic>> completed = [];
    final List<Map<String, dynamic>> skipped = [];
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        final appointment = {
          'id': doc.id,
          'patientName': data['patientName'] ?? 'Unknown',
          'patientId': data['patientId'] ?? '',
          'tokenNumber': data['tokenNumber'] ?? 0,
          'queueStatus': data['queueStatus'] ?? 'waiting',
          'status': data['status'] ?? 'confirmed',
          'appointmentTime': data['appointmentTime'] ?? '--:--',
          'mobile': data['patientMobile'] ?? data['mobile'] ?? '',
        };

        final status = data['status'];
        final queueStatus = data['queueStatus'];

        if (queueStatus == 'in_consultation') {
          current = appointment;
        } else if (status == 'completed' || queueStatus == 'completed') {
          completed.add(appointment);
        } else if (status == 'skipped' || 
                   status == 'absent' || 
                   status == 'cancelled' ||
                   queueStatus == 'skipped') {
          skipped.add(appointment);
        } else if (status == 'confirmed' || 
                   status == 'pending' || 
                   status == 'waiting') {
          waiting.add(appointment);
        }
      }
    }
    
    // Sort waiting patients by token number
    waiting.sort((a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int));
    completed.sort((a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int));
    skipped.sort((a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int));
    
    if (mounted) {
      setState(() {
        _waitingPatients = waiting;
        _currentPatient = current;
        _completedPatients = completed;
        _skippedPatients = skipped;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsSkipped(Map<String, dynamic> patient) async {
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Skipped?'),
        content: Text('Mark ${patient['patientName']} as skipped/absent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Skipped'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(patient['id'])
            .update({
          'queueStatus': 'skipped',
          'status': 'skipped',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${patient['patientName']} marked as skipped'),
              backgroundColor: Colors.orange,
            ),
          );
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
  }

  Future<void> _callNextPatient() async {
    if (_waitingPatients.isEmpty || !mounted) return;
    
    final nextPatient = _waitingPatients.first;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Next Patient?'),
        content: Text('Call ${nextPatient['patientName']} (Token #${nextPatient['tokenNumber']})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Call Patient'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(nextPatient['id'])
            .update({
          'queueStatus': 'in_consultation',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${nextPatient['patientName']} called for consultation'),
              backgroundColor: Colors.green,
            ),
          );
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
  }

  @override
  Widget build(BuildContext context) {
    final totalPatients = _waitingPatients.length + 
                         (_currentPatient != null ? 1 : 0) + 
                         _completedPatients.length + 
                         _skippedPatients.length;
    
    final completedCount = _completedPatients.length;
    final progress = totalPatients > 0 ? completedCount / totalPatients : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Assistant'),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Schedule Selector
                _buildScheduleSelector(),
                
                // Progress Bar Section
                _buildProgressBar(progress, completedCount, totalPatients),
                
                // Current Patient Section
                if (_currentPatient != null) 
                  _buildCurrentPatientCard(),
                
                // Next Patient Section
                if (_waitingPatients.isNotEmpty)
                  _buildNextPatientCard(),
                
                // Statistics Section
                _buildStatisticsCard(),
                
                // Action Buttons
                _buildActionButtons(),
                
                // Queue List
                Expanded(
                  child: _buildQueueListView(),
                ),
              ],
            ),
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
              'Select Schedule',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 8),
            if (_availableSchedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No active schedules today',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              DropdownButton<Map<String, dynamic>>(
                value: _selectedSchedule,
                isExpanded: true,
                items: _availableSchedules.map((schedule) {
                  final doctorName = schedule['doctorName'] ?? 'Unknown Doctor';
                  final date = schedule['date'] != null
                      ? DateFormat('hh:mm a').format(
                          (schedule['date'] as Timestamp).toDate(),
                        )
                      : 'Today';
                  
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
                          'Time: $date',
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
                    _setupQueueStream(schedule['id']);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, int completed, int total) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Queue Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$completed/$total completed',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProgressItem('Waiting', _waitingPatients.length, Colors.orange),
                _buildProgressItem('Consulting', _currentPatient != null ? 1 : 0, Colors.blue),
                _buildProgressItem('Completed', completed, Colors.green),
                _buildProgressItem('Skipped', _skippedPatients.length, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
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

  Widget _buildCurrentPatientCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Currently Consulting',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentPatient!['patientName'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Token #${_currentPatient!['tokenNumber']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentPatient!['mobile'] != null && _currentPatient!['mobile'].toString().isNotEmpty)
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    _currentPatient!['mobile'].toString(),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextPatientCard() {
    final nextPatient = _waitingPatients.first;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next Patient',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        nextPatient['patientName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Token #${nextPatient['tokenNumber']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCircle('Waiting', _waitingPatients.length, Colors.orange),
            _buildStatCircle('In Room', _currentPatient != null ? 1 : 0, Colors.blue),
            _buildStatCircle('Completed', _completedPatients.length, Colors.green),
            _buildStatCircle('Skipped', _skippedPatients.length, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _waitingPatients.isNotEmpty ? _callNextPatient : null,
              icon: const Icon(Icons.volume_up, size: 20),
              label: const Text('Call Next Patient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loadAvailableSchedules,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueListView() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 4),
                    Text('Waiting (${_waitingPatients.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16),
                    const SizedBox(width: 4),
                    Text('Completed (${_completedPatients.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, size: 16),
                    const SizedBox(width: 4),
                    Text('Skipped (${_skippedPatients.length})'),
                  ],
                ),
              ),
            ],
            labelColor: _accentColor,
            indicatorColor: _accentColor,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPatientList(_waitingPatients, 'waiting'),
                _buildPatientList(_completedPatients, 'completed'),
                _buildPatientList(_skippedPatients, 'skipped'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList(List<Map<String, dynamic>> patients, String status) {
    if (patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(status),
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(status),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        return _buildPatientListItem(patients[index], status);
      },
    );
  }

  Widget _buildPatientListItem(Map<String, dynamic> patient, String status) {
    final tokenNumber = patient['tokenNumber'] ?? 0;
    final patientName = patient['patientName'] ?? 'Unknown';
    final appointmentTime = patient['appointmentTime'] ?? '--:--';
    final mobile = patient['mobile'] ?? '';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.person;

    switch (status) {
      case 'waiting':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'skipped':
        statusColor = Colors.red;
        statusIcon = Icons.close;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
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
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mobile.isNotEmpty)
              Text(
                mobile,
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              'Appointment: $appointmentTime',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            if (status == 'waiting')
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                onPressed: () => _markAsSkipped(patient),
                tooltip: 'Mark as Skipped',
              ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waiting':
        return Icons.access_time;
      case 'completed':
        return Icons.check_circle;
      case 'skipped':
        return Icons.close;
      default:
        return Icons.person;
    }
  }

  String _getEmptyMessage(String status) {
    switch (status) {
      case 'waiting':
        return 'No patients waiting';
      case 'completed':
        return 'No consultations completed yet';
      case 'skipped':
        return 'No skipped patients';
      default:
        return 'No patients';
    }
  }
}