import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/queue_provider.dart';

class DoctorLiveQueueScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final Map<String, dynamic> schedule;
  
  const DoctorLiveQueueScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.schedule,
  });

  @override
  State<DoctorLiveQueueScreen> createState() => _DoctorLiveQueueScreenState();
}

class _DoctorLiveQueueScreenState extends State<DoctorLiveQueueScreen> {
  @override
  void initState() {
    super.initState();
    // Load the queue when screen starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQueue();
    });
  }

  void _loadQueue() {
    final queueProvider = Provider.of<QueueProvider>(context, listen: false);
    final scheduleId = widget.schedule['_id'] ?? widget.schedule['id'];
    print('🔄 Loading queue for schedule: $scheduleId');
    queueProvider.getQueueBySchedule(scheduleId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Queue - ${widget.schedule['medicalCenterName']}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Consumer<QueueProvider>(
        builder: (context, queueProvider, child) {
          print('🔄 QueueProvider state - Loading: ${queueProvider.isLoading}, Error: ${queueProvider.error}');
          
          if (queueProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (queueProvider.error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${queueProvider.error}'),
                  ElevatedButton(
                    onPressed: _loadQueue,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final queue = queueProvider.currentQueue;
          print('📊 Current Queue: ${queue != null ? "EXISTS" : "NULL"}');
          
          if (queue == null) {
            return const Center(child: Text('No active queue found'));
          }

          // Debug the queue data
          print('🔍 Queue Details:');
          print('   Queue ID: ${queue['queueId']}');
          print('   Current Token: ${queue['currentToken']}');
          print('   Total Patients: ${queue['patients']?.length ?? 0}');
          
          final patients = (queue['patients'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          print('   Patients List Length: ${patients.length}');
          
          for (var i = 0; i < patients.length; i++) {
            print('   Patient $i: ${patients[i]}');
          }

          return _buildQueueContent(queue, patients);
        },
      ),
    );
  }

  Widget _buildQueueContent(Map<String, dynamic> queue, List<Map<String, dynamic>> patients) {
    final currentToken = queue['currentToken'] ?? 1;
    
    // Get current consulting patient
    final currentPatient = patients.firstWhere(
      (patient) => (patient['tokenNumber'] ?? 0) == currentToken,
      orElse: () => {},
    );

    // Get waiting patients (tokens > currentToken)
    final waitingPatients = patients
        .where((patient) => (patient['tokenNumber'] ?? 0) > currentToken)
        .toList()
      ..sort((a, b) => (a['tokenNumber'] ?? 0).compareTo(b['tokenNumber'] ?? 0));

    print('👥 Current Patient: ${currentPatient.isNotEmpty ? currentPatient['patientName'] : "None"}');
    print('⏳ Waiting Patients: ${waitingPatients.length}');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Patient Card
          if (currentPatient.isNotEmpty) 
            _buildCurrentPatientCard(currentPatient),
          
          // Queue Statistics
          _buildQueueStats(queue, waitingPatients.length),
          
          // Waiting Queue
          Expanded(
            child: _buildWaitingQueue(waitingPatients),
          ),
          
          // Control Buttons
          _buildControlButtons(queue['queueId']),
        ],
      ),
    );
  }

  Widget _buildCurrentPatientCard(Map<String, dynamic> patient) {
    final tokenNumber = patient['tokenNumber'] ?? 0;
    final patientName = patient['patientName'] ?? 'Unknown Patient';
    final status = patient['status'] ?? 'waiting';

    return Card(
      elevation: 4,
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Currently Consulting',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700]!,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Token #$tokenNumber',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[700]!,
              ),
            ),
            Text(
              patientName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.green[600]!,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800]!,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStats(Map<String, dynamic> queue, int waitingCount) {
    final patients = (queue['patients'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final completedCount = patients.where((p) => p['status'] == 'completed').length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', '${patients.length}'),
            _buildStatItem('Waiting', '$waitingCount'),
            _buildStatItem('Completed', '$completedCount'),
            _buildStatItem('Current', '${queue['currentToken'] ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
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

  Widget _buildWaitingQueue(List<Map<String, dynamic>> waitingPatients) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Waiting Queue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${waitingPatients.length} patients'),
                  backgroundColor: Colors.teal[50],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: waitingPatients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]!),
                          const SizedBox(height: 16),
                          const Text(
                            'No patients waiting',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: waitingPatients.length,
                      itemBuilder: (context, index) {
                        return _buildQueueItem(waitingPatients[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueItem(Map<String, dynamic> patient) {
    final tokenNumber = patient['tokenNumber'] ?? 0;
    final patientName = patient['patientName'] ?? 'Unknown Patient';
    final status = patient['status'] ?? 'waiting';
    final isCheckedIn = status == 'checked-in';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCheckedIn ? Colors.green : Colors.grey[300]!,
          width: isCheckedIn ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCheckedIn ? Colors.green[50]! : Colors.orange[50]!,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$tokenNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCheckedIn ? Colors.green[700]! : Colors.orange[700]!,
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
                const SizedBox(height: 4),
                Text(
                  'Token #$tokenNumber',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600]!,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCheckedIn ? Colors.green[50]! : Colors.orange[50]!,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isCheckedIn ? 'CHECKED IN' : 'WAITING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isCheckedIn ? Colors.green[700]! : Colors.orange[700]!,
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildControlButtons(Map<String, dynamic> queue) {
  // ✅ FIX: Handle null queueId
   if (queue == null || queue['queueId'] == null) {
    return Text('Queue not available', style: TextStyle(color: Colors.red));
  }
    final queueId = queue['queueId']!;
  
  

  return Padding(
    padding: const EdgeInsets.only(top: 16.0),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _callNextPatient(queueId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Call Next Patient'),
          ),
        ),
      ],
    ),
  );
}

 Future<void> _callNextPatient(String queueId) async {
  if (queueId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: Queue ID is missing'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final queueProvider = Provider.of<QueueProvider>(context, listen: false);
  final success = await queueProvider.nextPatient(queueId);
  
  if (!success && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${queueProvider.error}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}