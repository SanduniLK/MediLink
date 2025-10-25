import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/queue_provider.dart';
import 'package:frontend/services/patient_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientQueueStatus extends StatefulWidget {
  const PatientQueueStatus({super.key});

  @override
  State<PatientQueueStatus> createState() => _PatientQueueStatusState();
}

class _PatientQueueStatusState extends State<PatientQueueStatus> {
  final TextEditingController _patientIdController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic>? _selectedAppointment;
  Map<String, dynamic>? _queueStatus;

  @override
  void initState() {
    super.initState();
    // Auto-load current patient's appointments if available
    _loadCurrentPatientAppointments();
  }

  void _loadCurrentPatientAppointments() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _patientIdController.text = currentUser.uid;
      _loadAppointments();
    }
  }

  void _loadAppointments() async {
    final patientId = _patientIdController.text.trim();
    if (patientId.isEmpty) {
      _showError('Please enter Patient ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _appointments = [];
      _selectedAppointment = null;
      _queueStatus = null;
    });

    try {
      final result = await PatientService.getPatientAppointments(patientId);
      
      if (result['success'] == true) {
        final appointments = List<Map<String, dynamic>>.from(result['data'] ?? []);
        
        setState(() {
          _appointments = appointments;
          _isLoading = false;
        });

        if (appointments.isEmpty) {
          _showError('No appointments found for this patient');
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError('Failed to load appointments: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error: $e');
    }
  }

  void _checkQueueStatus(Map<String, dynamic> appointment) async {
    setState(() {
      _selectedAppointment = appointment;
      _isLoading = true;
      _queueStatus = null;
    });

    final queueProvider = Provider.of<QueueProvider>(context, listen: false);
    final patientId = _patientIdController.text.trim();
    
    try {
      final queueData = await queueProvider.getQueueForPatient(patientId);
      
      setState(() {
        _queueStatus = queueData;
        _isLoading = false;
      });

      if (queueData == null) {
        _showInfo('No active queue found for this appointment');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error checking queue: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Queue Status'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Patient ID Input
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Check Your Appointments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _patientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Patient ID',
                        hintText: 'Enter your Patient ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loadAppointments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18A3B6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Load Appointments'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Loading State
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading...'),
                    ],
                  ),
                ),
              )

            // Appointments List
            else if (_appointments.isNotEmpty && _queueStatus == null)
              Expanded(
                child: _buildAppointmentsList(),
              )

            // Queue Status Display
            else if (_queueStatus != null)
              Expanded(
                child: _buildQueueStatus(),
              )

            // Empty State
            else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Appointments',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Enter your Patient ID to check your appointments',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Appointments (${_appointments.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
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
    final doctorName = appointment['doctorName'] ?? 'Unknown Doctor';
    final medicalCenter = appointment['medicalCenterName'] ?? 'Unknown Center';
    final date = appointment['date'] ?? 'No date';
    final time = appointment['time'] ?? 'No time';
    final status = appointment['status'] ?? 'scheduled';

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
                        doctorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicalCenter,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(date),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(time),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _checkQueueStatus(appointment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Check Queue Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatus() {
    if (_selectedAppointment == null || _queueStatus == null) {
      return const Center(child: Text('No queue data available'));
    }

    final patientInfo = _queueStatus!['patientInfo'] ?? {};
    final currentToken = _queueStatus!['currentToken'] ?? 1;
    final patientToken = patientInfo['tokenNumber'] ?? 0;
    final patients = (_queueStatus!['patients'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Separate patients into current, waiting, and completed
    final currentPatient = patients.firstWhere(
      (p) => (p['tokenNumber'] ?? 0) == currentToken,
      orElse: () => {},
    );
    
    final waitingPatients = patients
        .where((p) => (p['tokenNumber'] ?? 0) > currentToken && (p['status'] ?? 'waiting') != 'completed')
        .toList()
      ..sort((a, b) => (a['tokenNumber'] ?? 0).compareTo(b['tokenNumber'] ?? 0));
    
    final completedPatients = patients
        .where((p) => (p['status'] ?? 'waiting') == 'completed')
        .toList()
      ..sort((a, b) => (a['tokenNumber'] ?? 0).compareTo(b['tokenNumber'] ?? 0));

    return SingleChildScrollView(
      child: Column(
        children: [
          // Appointment Info
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appointment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Doctor', _selectedAppointment!['doctorName'] ?? 'Unknown'),
                  _buildDetailRow('Medical Center', _selectedAppointment!['medicalCenterName'] ?? 'Unknown'),
                  _buildDetailRow('Date', _selectedAppointment!['date'] ?? 'Unknown'),
                  _buildDetailRow('Time', _selectedAppointment!['time'] ?? 'Unknown'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Queue Status Overview
          Card(
            elevation: 4,
            color: const Color(0xFF18A3B6),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'Queue Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusItem('Your Token', '#$patientToken', Icons.confirmation_number),
                      _buildStatusItem('Current Token', '#$currentToken', Icons.flag),
                      _buildStatusItem('Ahead of You', '${waitingPatients.length}', Icons.people),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Now Consulting
          if (currentPatient.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Now Consulting',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPatientCard(currentPatient, isCurrent: true),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Waiting Patients
          if (waitingPatients.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waiting Patients (${waitingPatients.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...waitingPatients.map((patient) => 
                      _buildPatientCard(patient, isYou: patient['tokenNumber'] == patientToken)
                    ).toList(),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Completed Patients
          if (completedPatients.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completed (${completedPatients.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...completedPatients.map((patient) => 
                      _buildPatientCard(patient, isCompleted: true)
                    ).toList(),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedAppointment = null;
                      _queueStatus = null;
                    });
                  },
                  child: const Text('Back to Appointments'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _checkQueueStatus(_selectedAppointment!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18A3B6),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Refresh Status'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, {
    bool isCurrent = false,
    bool isYou = false,
    bool isCompleted = false,
  }) {
    final tokenNumber = patient['tokenNumber'] ?? 0;
    final patientName = patient['patientName'] ?? 'Unknown Patient';
    final status = patient['status'] ?? 'waiting';

    Color backgroundColor = Colors.white;
    Color textColor = Colors.black;
    String statusText = 'Waiting';

    if (isYou) {
      backgroundColor = const Color(0xFF18A3B6).withOpacity(0.1);
      textColor = const Color(0xFF18A3B6);
      statusText = 'YOU';
    } else if (isCurrent) {
      backgroundColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
      statusText = 'NOW CONSULTING';
    } else if (isCompleted) {
      backgroundColor = Colors.grey.withOpacity(0.1);
      textColor = Colors.grey;
      statusText = 'COMPLETED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$tokenNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (isYou) 
                  Text(
                    'Your Appointment',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'waiting':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}