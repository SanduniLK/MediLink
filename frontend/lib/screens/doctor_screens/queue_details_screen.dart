import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/queue_provider.dart';

class QueueDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> schedule;

  const QueueDetailsScreen({super.key, required this.schedule});

  @override
  State<QueueDetailsScreen> createState() => _QueueDetailsScreenState();
}

class _QueueDetailsScreenState extends State<QueueDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Start real-time queue listener when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scheduleId = widget.schedule['_id'] ?? widget.schedule['id'] ?? '';
      Provider.of<QueueProvider>(context, listen: false)
          .getQueueBySchedule(scheduleId);
    });
  }

  @override
  void dispose() {
    // Clean up listeners when screen is disposed
    Provider.of<QueueProvider>(context, listen: false).disposeListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('Queue Management'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          // Real-time indicator
          Consumer<QueueProvider>(
            builder: (context, queueProvider, child) {
              if (queueProvider.currentQueue != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: Consumer<QueueProvider>(
        builder: (context, queueProvider, child) {
          if (queueProvider.isLoading && queueProvider.currentQueue == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (queueProvider.currentQueue == null) {
            return _buildNoQueueView();
          }

          final queue = queueProvider.currentQueue!;
          final currentPatient = _getCurrentPatient(queue);
          final waitingPatients = _getWaitingPatients(queue);
          final completedPatients = _getCompletedPatients(queue);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Queue Header
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF18A3B6),
                          const Color(0xFF32BACD),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            queue['medicalCenterName'] ?? 'Medical Center',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Dr. ${queue['doctorName'] ?? 'Doctor'}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Current Token with auto-update
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'NOW SERVING',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  child: Text(
                                    'Token #${queue['currentToken']}',
                                    key: ValueKey(queue['currentToken']),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (currentPatient != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    currentPatient['patientName'] ?? 'Patient',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Queue Progress
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${queue['currentToken'] - 1}/${queue['maxPatients']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (queue['currentToken'] - 1) / queue['maxPatients'],
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Next Patient Button
                if (queue['currentToken'] <= queue['maxPatients'] && queue['isActive'] == true)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Current Consultation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18A3B6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (currentPatient != null)
                            _buildPatientCard(currentPatient, true),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final success = await queueProvider.nextPatient(queue['queueId']);
                              if (!mounted) return;
                              
                              if (success) {
                                // Real-time listener will automatically update the UI
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Moved to next patient'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${queueProvider.error}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF18A3B6),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text(
                              'Complete & Next Patient',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Waiting Patients (Auto-updates)
                if (waitingPatients.isNotEmpty)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Waiting Patients',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF18A3B6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF32BACD),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${waitingPatients.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${waitingPatients.length} patients waiting',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...waitingPatients.map((patient) => 
                            _buildPatientCard(patient, false)
                          ).toList(),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Completed Patients (Auto-updates)
                if (completedPatients.isNotEmpty)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${completedPatients.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${completedPatients.length} patients completed',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...completedPatients.map((patient) => 
                            _buildPatientCard(patient, false)
                          ).toList(),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                
                // Real-time Updates Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF18A3B6)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.update,
                        color: const Color(0xFF18A3B6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Live updates enabled. The queue updates automatically in real-time.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF18A3B6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper methods
  Map<String, dynamic>? _getCurrentPatient(Map<String, dynamic> queue) {
    final patients = (queue['patients'] as List?) ?? [];
    for (var patient in patients) {
      final patientMap = patient as Map<String, dynamic>;
      if (patientMap['tokenNumber'] == queue['currentToken']) {
        return patientMap;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _getWaitingPatients(Map<String, dynamic> queue) {
    final patients = (queue['patients'] as List?) ?? [];
    final waitingPatients = <Map<String, dynamic>>[];
    
    for (var patient in patients) {
      final patientMap = patient as Map<String, dynamic>;
      if (patientMap['tokenNumber'] > queue['currentToken'] && 
          patientMap['status'] != 'completed') {
        waitingPatients.add(patientMap);
      }
    }
    
    // Sort by token number
    waitingPatients.sort((a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int));
    return waitingPatients;
  }

  List<Map<String, dynamic>> _getCompletedPatients(Map<String, dynamic> queue) {
    final patients = (queue['patients'] as List?) ?? [];
    final completedPatients = <Map<String, dynamic>>[];
    
    for (var patient in patients) {
      final patientMap = patient as Map<String, dynamic>;
      if (patientMap['status'] == 'completed') {
        completedPatients.add(patientMap);
      }
    }
    
    // Sort by token number
    completedPatients.sort((a, b) => (a['tokenNumber'] as int).compareTo(b['tokenNumber'] as int));
    return completedPatients;
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFE8F4FD) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? const Color(0xFF18A3B6) : const Color(0xFFB2DEE6),
        ),
      ),
      child: Row(
        children: [
          // Token Number
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF18A3B6) : const Color(0xFF32BACD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '#${patient['tokenNumber']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Patient Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient['patientName'] ?? 'Unknown Patient',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isCurrent ? const Color(0xFF18A3B6) : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${_getStatusText(patient['status'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(patient['status']),
                  ),
                ),
                if (patient['checkInTime'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Checked in: ${_formatTime(patient['checkInTime'])}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Status Icon
          Icon(
            _getStatusIcon(patient['status']),
            color: _getStatusColor(patient['status']),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting': return 'Waiting';
      case 'checked-in': return 'Checked In';
      case 'in-consultation': return 'In Consultation';
      case 'completed': return 'Completed';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting': return Colors.orange;
      case 'checked-in': return const Color(0xFF32BACD);
      case 'in-consultation': return const Color(0xFF18A3B6);
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waiting': return Icons.access_time;
      case 'checked-in': return Icons.check_circle_outline;
      case 'in-consultation': return Icons.person;
      case 'completed': return Icons.verified;
      default: return Icons.help;
    }
  }

  String _formatTime(dynamic time) {
    if (time is String) {
      final dateTime = DateTime.tryParse(time);
      if (dateTime != null) {
        return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    }
    return '--:--';
  }

  Widget _buildNoQueueView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Active Queue',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const Text(
            'Queue not found or has ended',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final scheduleId = widget.schedule['_id'] ?? widget.schedule['id'] ?? '';
              Provider.of<QueueProvider>(context, listen: false)
                  .getQueueBySchedule(scheduleId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18A3B6),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}