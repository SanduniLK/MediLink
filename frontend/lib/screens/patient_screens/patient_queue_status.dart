import 'dart:async';
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
  String? _patientId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic>? _selectedAppointment;
  Map<String, dynamic>? _queueStatus;

  // Timer for auto-refreshing queue data
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentPatientAppointments();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadCurrentPatientAppointments() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _patientId = currentUser.uid;
      });
      _loadTodayAppointments();
    } else {
      _showError('Unable to detect your account. Please sign in again.');
    }
  }

  void _loadTodayAppointments() async {
    final patientId = _patientId;
    if (patientId == null || patientId.isEmpty) {
      _showError('Unable to detect patient information. Please try again.');
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
        final appointments = List<Map<String, dynamic>>.from(
          result['data'] ?? [],
        );
        final todayAppointments = appointments.where((appointment) {
          final dateValue = appointment['date'];

          // If the string contains "Today", automatically include it
          if (dateValue is String &&
              dateValue.toLowerCase().contains('today')) {
            return true;
          }

          final parsedDate = _parseAppointmentDate(dateValue);
          if (parsedDate == null) return false;

          final now = DateTime.now();
          return _isSameDay(parsedDate, now);
        }).toList();

        setState(() {
          _appointments = todayAppointments;
          _isLoading = false;
        });

        if (todayAppointments.isEmpty) {
          _showInfo('No appointments Booked for today');
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Failed to load appointments: ${result['error']}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  // --- UPDATED QUEUE CHECK LOGIC ---
  void _checkQueueStatus(Map<String, dynamic> appointment) async {
    // 1. Get Schedule ID
    final scheduleId =
        appointment['scheduleId'] ?? appointment['_id'] ?? appointment['id'];

    if (scheduleId == null) {
      _showError('Cannot find Schedule ID for this appointment.');
      return;
    }

    setState(() {
      _selectedAppointment = appointment;
      _isLoading = true;
      _queueStatus = null;
    });

    _refreshTimer?.cancel(); // Cancel any existing timer

    await _fetchQueueData(scheduleId);

    // 2. Start Auto-Refresh (every 15 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _selectedAppointment != null) {
        _fetchQueueData(scheduleId, isBackground: true);
      }
    });
  }

  Future<void> _fetchQueueData(
    String scheduleId, {
    bool isBackground = false,
  }) async {
    final queueProvider = Provider.of<QueueProvider>(context, listen: false);

    try {
      // NOTE: Ensure your QueueProvider has `getQueueByScheduleId` method
      // If not, use your existing method but ensure backend returns full queue list
      final queueData = await queueProvider.getQueueByScheduleId(scheduleId);

      if (mounted) {
        setState(() {
          _queueStatus = queueData;
          if (!isBackground) _isLoading = false;
        });

        if (queueData == null && !isBackground) {
          _showInfo('Queue has not started for this schedule yet.');
        }
      }
    } catch (e) {
      if (mounted && !isBackground) {
        setState(() => _isLoading = false);
        _showError('Error checking queue: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2FBFC), Color(0xFFE0F5F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildUserInfoCard(),
              const SizedBox(height: 20),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_appointments.isNotEmpty && _queueStatus == null)
                Expanded(child: _buildAppointmentsList())
              else if (_queueStatus != null)
                Expanded(child: _buildQueueStatus())
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF18A3B6).withOpacity(0.1),
                  radius: 24,
                  child: const Icon(Icons.person, color: Color(0xFF18A3B6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Patient ID',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _patientId ?? 'Not available',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_patientId != null)
                  const Icon(Icons.verified, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadTodayAppointments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Today\'s Appointments'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Appointments Today',
              style: TextStyle(fontSize: 18, color: Colors.grey),
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
          'Today\'s Appointments (${_appointments.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _appointments.length,
            itemBuilder: (context, index) {
              return _buildAppointmentCard(_appointments[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final doctorName = appointment['doctorName'] ?? 'Unknown Doctor';
    final medicalCenter = appointment['medicalCenterName'] ?? 'Unknown Center';
    final time = appointment['time'] ?? 'No time';
    final status = appointment['status'] ?? 'scheduled';
    final currentQueueNumber =
        appointment['tokenNumber'] ?? appointment['queueNumber'] ?? 'N/A';

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
                      Text(
                        medicalCenter,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(time),
                const SizedBox(width: 16),
                Icon(
                  Icons.confirmation_number,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text('Token: $currentQueueNumber'),
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
                child: const Text('Check Live Queue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UPDATED BUILD LOGIC FOR IN-CONSULTATION ---
  Widget _buildQueueStatus() {
    if (_selectedAppointment == null || _queueStatus == null) {
      return const Center(child: Text('No queue data available'));
    }

    final patients =
        (_queueStatus!['patients'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    // 1. FIND "ME" (My Token)
    final myEntry = patients.firstWhere(
      (p) => (p['patientId'] ?? '') == _patientId,
      orElse: () => {},
    );
    final myToken = myEntry['tokenNumber'] ?? 0;

    // 2. FIND "CURRENTLY CONSULTING" (Specific logic requested)
    // We look for the patient strictly marked as 'in_consultation'
    final consultingEntry = patients.firstWhere(
      (p) => p['queueStatus'] == 'in_consultation',
      orElse: () => {},
    );

    // Display Logic: If someone is inside, show their token.
    // If room is empty, show the last completed token or 0.
    final currentTokenDisplay = consultingEntry.isNotEmpty
        ? consultingEntry['tokenNumber']
        : (patients.where((p) => p['status'] == 'completed').length);

    // 3. WAITING LIST (Filter out completed and the person inside)
    final waitingPatients =
        patients
            .where(
              (p) =>
                  (p['status'] == 'confirmed' ||
                      p['status'] == 'pending' ||
                      p['status'] == 'waiting') &&
                  p['queueStatus'] != 'in_consultation' &&
                  p['status'] != 'completed',
            )
            .toList()
          ..sort(
            (a, b) => (a['tokenNumber'] ?? 0).compareTo(b['tokenNumber'] ?? 0),
          );

    // Calculate People Ahead
    int peopleAhead = 0;
    if (myToken > 0) {
      peopleAhead = waitingPatients
          .where((p) => (p['tokenNumber'] ?? 0) < myToken)
          .length;
      if (consultingEntry.isNotEmpty &&
          consultingEntry['tokenNumber'] != myToken) {
        peopleAhead++; // Add the person inside the room
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appointment Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Doctor',
                    _selectedAppointment!['doctorName'] ?? 'Unknown',
                  ),
                  _buildDetailRow(
                    'Center',
                    _selectedAppointment!['medicalCenterName'] ?? 'Unknown',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // LIVE QUEUE STATUS
          Card(
            elevation: 4,
            color: const Color(0xFF18A3B6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'Live Queue Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBigStatusItem(
                        'My Token',
                        myToken == 0 ? '--' : '#$myToken',
                        Icons.confirmation_number,
                      ),
                      Container(width: 1, height: 50, color: Colors.white30),
                      _buildBigStatusItem(
                        'Now Serving', // This is what you requested
                        consultingEntry.isEmpty
                            ? '--'
                            : '#$currentTokenDisplay',
                        Icons.play_circle_fill,
                        isHighlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      peopleAhead == 0
                          ? (consultingEntry['tokenNumber'] == myToken
                                ? "It's your turn!"
                                : "You are next!")
                          : "$peopleAhead people ahead of you",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Now Consulting List
          if (consultingEntry.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Currently in Room",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildPatientCard(
              consultingEntry,
              isCurrent: true,
              isYou: consultingEntry['tokenNumber'] == myToken,
            ),
            const SizedBox(height: 16),
          ],

          // Waiting List
          if (waitingPatients.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Up Next",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...waitingPatients
                .take(4)
                .map(
                  (p) =>
                      _buildPatientCard(p, isYou: p['tokenNumber'] == myToken),
                ),
            if (waitingPatients.length > 4)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "+ ${waitingPatients.length - 4} more waiting",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],

          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              _refreshTimer?.cancel();
              setState(() {
                _selectedAppointment = null;
                _queueStatus = null;
              });
            },
            child: const Text('Back to Appointments'),
          ),
        ],
      ),
    );
  }

  Widget _buildBigStatusItem(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? Colors.yellowAccent : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard(
    Map<String, dynamic> patient, {
    bool isCurrent = false,
    bool isYou = false,
    bool isCompleted = false,
  }) {
    final tokenNumber = patient['tokenNumber'] ?? 0;
    final patientName = patient['patientName'] ?? 'Unknown Patient';

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
      statusText = 'CONSULTING';
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
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
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

  // --- Date Parsing Utilities (Kept from original) ---
  DateTime? _parseAppointmentDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
    if (dateValue is String && dateValue.isNotEmpty) {
      final sanitizedValue = _sanitizeDateString(dateValue);
      try {
        return DateTime.parse(sanitizedValue);
      } catch (_) {}
      // Add custom parsing logic here if needed for MM/DD/YYYY etc.
    }
    return null;
  }

  String _sanitizeDateString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('(') && trimmed.contains(')')) {
      final start = trimmed.indexOf('(');
      final end = trimmed.indexOf(')', start + 1);
      if (start != -1 && end != -1) return trimmed.substring(start + 1, end);
    }
    const labels = ['Today', 'Tomorrow', 'Yesterday'];
    for (final label in labels) {
      if (trimmed.startsWith(label))
        return trimmed.replaceFirst(label, '').trim();
    }
    return trimmed;
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
