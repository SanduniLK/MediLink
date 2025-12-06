// screens/assistant/assistant_queue_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AssistantQueueScreen extends StatefulWidget {
  final String? scheduleId;
  final String? doctorId;
  final String? doctorName;

  const AssistantQueueScreen({
    super.key,
    this.scheduleId,
    this.doctorId,
    this.doctorName,
  });

  @override
  State<AssistantQueueScreen> createState() => _AssistantQueueScreenState();
}

class _AssistantQueueScreenState extends State<AssistantQueueScreen> {
  List<Map<String, dynamic>> _queueAppointments = [];
  List<Map<String, dynamic>> _completedAppointments = [];
  List<Map<String, dynamic>> _skippedAppointments = [];
  List<Map<String, dynamic>> _waitingAppointments = [];

  bool _isLoading = false;
  bool _showDetails = true;
  StreamSubscription? _queueSubscription;
  Map<String, dynamic>? _currentSchedule;
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Method 1: Check if assistant is assigned to schedules
      final scheduleQuery = await FirebaseFirestore.instance
          .collection('schedules')
          .where('assistantId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.now())
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
            _currentSchedule = schedules.first;
            _setupQueueStream(_currentSchedule!['id']);
          }
        });
      } else {
        // Method 2: If not assigned, show all active schedules
        final allSchedulesQuery = await FirebaseFirestore.instance
            .collection('schedules')
            .where('status', isEqualTo: 'active')
            .where('date', isGreaterThanOrEqualTo: Timestamp.now())
            .orderBy('date')
            .get();

        final schedules = allSchedulesQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        setState(() {
          _availableSchedules = schedules;
          if (schedules.isNotEmpty) {
            _currentSchedule = schedules.first;
            _setupQueueStream(_currentSchedule!['id']);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    } finally {
      setState(() => _isLoading = false);
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
    final appointments = <Map<String, dynamic>>[];
    final completed = <Map<String, dynamic>>[];
    final skipped = <Map<String, dynamic>>[];
    final waiting = <Map<String, dynamic>>[];
    final inConsultation = <Map<String, dynamic>>[];

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
          'arrivedAt': data['arrivedAt'],
          'mobile': data['patientMobile'] ?? data['mobile'] ?? '',
        };

        final status = data['status'];
        final queueStatus = data['queueStatus'];

        if (status == 'completed') {
          completed.add(appointment);
        } else if (status == 'skipped' ||
            status == 'absent' ||
            status == 'cancelled' ||
            queueStatus == 'skipped') {
          skipped.add(appointment);
        } else if (status == 'confirmed' ||
            status == 'pending' ||
            status == 'waiting') {
          if (queueStatus == 'in_consultation') {
            inConsultation.add(appointment);
          } else {
            waiting.add(appointment);
          }
        }
      }
    }

    // Sort by token number
    waiting.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );
    completed.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );
    skipped.sort(
      (a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int),
    );

    final queue = [...inConsultation, ...waiting];

    if (mounted) {
      setState(() {
        _queueAppointments = queue;
        _completedAppointments = completed;
        _skippedAppointments = skipped;
        _waitingAppointments = waiting;
        _isLoading = false;
      });
    }
  }

  Future<void> _startQueueSession() async {
    if (_currentSchedule == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Queue Session?'),
        content: const Text(
          'This will mark all confirmed appointments as "Waiting" in the queue.',
        ),
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
            child: const Text('Start Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('scheduleId', isEqualTo: _currentSchedule!['id'])
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'];
        final currentQueueStatus = data['queueStatus'];

        if (status != 'completed' &&
            status != 'cancelled' &&
            status != 'skipped' &&
            currentQueueStatus != 'in_consultation') {
          batch.update(doc.reference, {
            'queueStatus': 'waiting',
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Queue initialized. $updateCount patients set to Waiting.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _callNextPatient() async {
    if (_waitingAppointments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patients waiting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nextPatient = _waitingAppointments.first;
    final patientName = nextPatient['patientName'];
    final tokenNumber = nextPatient['tokenNumber'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Next Patient?'),
        content: Text('Call $patientName (Token #$tokenNumber) for consultation?'),
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

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(nextPatient['id'])
          .update({
        'queueStatus': 'in_consultation',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$patientName (Token #$tokenNumber) called for consultation'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calling patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAsSkipped(Map<String, dynamic> appointment) async {
    final patientName = appointment['patientName'];
    final tokenNumber = appointment['tokenNumber'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Skipped?'),
        content: Text('Mark $patientName (Token #$tokenNumber) as skipped/absent?'),
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

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointment['id'])
          .update({
        'queueStatus': 'skipped',
        'status': 'skipped',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$patientName marked as skipped'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAsArrived(Map<String, dynamic> appointment) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointment['id'])
          .update({
        'arrivedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${appointment['patientName']} marked as arrived'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendPatientNotification(
    String patientId,
    String patientName,
    String message,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('patientNotifications')
          .add({
        'patientId': patientId,
        'patientName': patientName,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
        'type': 'queue_update',
        'scheduleId': _currentSchedule?['id'],
        'doctorName': _currentSchedule?['doctorName'] ?? 'Doctor',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification sent to patient'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  void _toggleDetails() {
    setState(() {
      _showDetails = !_showDetails;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCount =
        _queueAppointments.length +
        _completedAppointments.length +
        _skippedAppointments.length;

    final currentAppointment = _queueAppointments.firstWhere(
      (appt) => appt['queueStatus'] == 'in_consultation',
      orElse: () => {},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Assistant'),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        actions: [
          if (_currentSchedule != null)
            IconButton(
              icon: const Icon(Icons.play_circle_filled),
              tooltip: 'Start Session',
              onPressed: _startQueueSession,
            ),
          IconButton(
            icon: Icon(_showDetails ? Icons.visibility_off : Icons.visibility),
            onPressed: _toggleDetails,
            tooltip: _showDetails ? 'Hide Details' : 'Show Details',
          ),
        ],
      ),
      body: _isLoading && _queueAppointments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Schedule Selector
                _buildScheduleSelector(),
                
                // Queue Overview Card
                _buildQueueOverviewCard(
                  totalCount,
                  currentAppointment,
                ),
                
                if (_showDetails)
                  Expanded(
                    child: _buildDetailedQueueView(),
                  )
                else
                  const SizedBox(height: 16),
                
                // Quick Actions
                if (!_showDetails && _currentSchedule != null)
                  _buildQuickActions(),
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
              ),
            ),
            const SizedBox(height: 8),
            if (_availableSchedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No schedules available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              DropdownButton<Map<String, dynamic>>(
                value: _currentSchedule,
                isExpanded: true,
                items: _availableSchedules.map((schedule) {
                  final doctorName = schedule['doctorName'] ?? 'Unknown Doctor';
                  final medicalCenter = schedule['medicalCenterName'] ?? 'Unknown Center';
                  final date = schedule['date'] != null
                      ? DateFormat('MMM dd, yyyy HH:mm').format(
                          (schedule['date'] as Timestamp).toDate(),
                        )
                      : 'No date';
                  
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
                          '$medicalCenter • $date',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (schedule) {
                  if (schedule != null) {
                    setState(() {
                      _currentSchedule = schedule;
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

  Widget _buildQueueOverviewCard(
    int totalCount,
    Map<String, dynamic> currentAppointment,
  ) {
    return GestureDetector(
      onTap: _toggleDetails,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF18A3B6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Queue Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      Text(
                        '${_completedAppointments.length} done • ${_skippedAppointments.length} absent • ${_waitingAppointments.length} waiting',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showDetails ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: const Color(0xFF18A3B6),
                ),
              ],
            ),
            if (currentAppointment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Currently Consulting',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            '${currentAppointment['patientName']} (#${currentAppointment['tokenNumber']})',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedQueueView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _waitingAppointments.isNotEmpty ? _callNextPatient : null,
                    icon: const Icon(Icons.volume_up, size: 20),
                    label: const Text('Call Next Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadAvailableSchedules,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Refresh'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Statistics
            _buildQueueStatistics(),
            
            const SizedBox(height: 20),
            
            // Waiting Patients List
            if (_waitingAppointments.isNotEmpty) ...[
              _buildPatientListSection(
                'Waiting Patients (${_waitingAppointments.length})',
                _waitingAppointments,
                'waiting',
              ),
              const SizedBox(height: 20),
            ],
            
            // Currently Consulting
            final currentPatient = _queueAppointments.firstWhere(
              (appt) => appt['queueStatus'] == 'in_consultation',
              orElse: () => {},
            );
            if (currentPatient.isNotEmpty) ...[
              _buildPatientListSection(
                'Currently Consulting',
                [currentPatient],
                'consulting',
              ),
              const SizedBox(height: 20),
            ],
            
            // Completed Patients
            if (_completedAppointments.isNotEmpty) ...[
              _buildPatientListSection(
                'Completed (${_completedAppointments.length})',
                _completedAppointments,
                'completed',
              ),
              const SizedBox(height: 20),
            ],
            
            // Skipped/Absent Patients
            if (_skippedAppointments.isNotEmpty) ...[
              _buildPatientListSection(
                'Skipped/Absent (${_skippedAppointments.length})',
                _skippedAppointments,
                'skipped',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatistics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Total',
              '${_queueAppointments.length + _completedAppointments.length + _skippedAppointments.length}',
              Colors.blue,
            ),
            _buildStatItem(
              'Waiting',
              '${_waitingAppointments.length}',
              Colors.orange,
            ),
            _buildStatItem(
              'Completed',
              '${_completedAppointments.length}',
              Colors.green,
            ),
            _buildStatItem(
              'Skipped',
              '${_skippedAppointments.length}',
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
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

  Widget _buildPatientListSection(
    String title,
    List<Map<String, dynamic>> patients,
    String status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18A3B6),
          ),
        ),
        const SizedBox(height: 8),
        ...patients.map((patient) => _buildPatientCard(patient, status)),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, String status) {
    final tokenNumber = patient['tokenNumber'] ?? 0;
    final patientName = patient['patientName'] ?? 'Unknown';
    final appointmentTime = patient['appointmentTime'] ?? '--:--';
    final mobile = patient['mobile'] ?? '';
    final arrivedAt = patient['arrivedAt'];

    Color statusColor = Colors.grey;
    String statusText = 'Unknown';

    switch (status) {
      case 'waiting':
        statusColor = Colors.orange;
        statusText = 'WAITING';
        break;
      case 'consulting':
        statusColor = Colors.green;
        statusText = 'IN CONSULTATION';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'COMPLETED';
        break;
      case 'skipped':
        statusColor = Colors.red;
        statusText = 'SKIPPED';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (mobile.isNotEmpty)
                        Text(
                          mobile,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Appointment: $appointmentTime'),
                const Spacer(),
                if (arrivedAt != null)
                  Text(
                    'Arrived: ${DateFormat('HH:mm').format((arrivedAt as Timestamp).toDate())}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
              ],
            ),
            if (status == 'waiting') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markAsArrived(patient),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Mark Arrived'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markAsSkipped(patient),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Skip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendPatientNotification(
                        patient['patientId'],
                        patientName,
                        'Please proceed to consultation room. Token #$tokenNumber',
                      ),
                      icon: const Icon(Icons.notification_important, size: 16),
                      label: const Text('Notify'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _waitingAppointments.isNotEmpty ? _callNextPatient : null,
              icon: const Icon(Icons.volume_up),
              label: const Text('Call Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleDetails,
              icon: const Icon(Icons.list),
              label: const Text('View All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}