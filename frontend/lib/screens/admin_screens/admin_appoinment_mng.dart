import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalCenterAppointmentManagementPage extends StatefulWidget {
  const MedicalCenterAppointmentManagementPage({Key? key, required String medicalCenterName}) : super(key: key);

  @override
  State<MedicalCenterAppointmentManagementPage> createState() => _MedicalCenterAppointmentManagementPageState();
}

class _MedicalCenterAppointmentManagementPageState extends State<MedicalCenterAppointmentManagementPage>
    with SingleTickerProviderStateMixin {
  final CollectionReference _appointmentsRef =
      FirebaseFirestore.instance.collection('appointments');
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  late TabController _tabController;
  List<QueryDocumentSnapshot> _allAppointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAppointments();
  }

  // Load all appointments and filter locally
  Future<void> _loadAppointments() async {
    if (_currentUser == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snapshot = await _appointmentsRef.get();
      setState(() {
        _allAppointments = snapshot.docs;
        _loading = false;
      });
      
      // Debug: Check what appointments are found
      _debugAllAppointments();
      
    } catch (e) {
      print("Error loading appointments: $e");
      setState(() => _loading = false);
    }
  }

  // Filter appointments locally
  List<QueryDocumentSnapshot> _getFilteredAppointments(String statusFilter) {
    return _allAppointments.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['medicalCenterId'] == _currentUser?.uid &&
             data['status'] == statusFilter &&
             data['appointmentType'] == 'physical';
    }).toList();
  }

  // DEBUG FUNCTION: Check ALL appointments in database
  void _debugAllAppointments() {
    if (_currentUser == null) return;
    
    print("=== ALL APPOINTMENTS DEBUG ===");
    print("Medical Center Admin UID: ${_currentUser!.uid}");
    print("Total appointments in database: ${_allAppointments.length}");
    
    int matchingMedicalCenter = 0;
    int pendingCount = 0;
    int physicalCount = 0;
    
    for (var doc in _allAppointments) {
      final data = doc.data() as Map<String, dynamic>;
      final medicalCenterId = data['medicalCenterId'];
      final status = data['status'];
      final appointmentType = data['appointmentType'];
      
      print("Appointment: ${doc.id}");
      print("  - medicalCenterId: $medicalCenterId");
      print("  - status: $status");
      print("  - appointmentType: $appointmentType");
      print("  - patientId: ${data['patientId']}");
      print("  - doctorId: ${data['doctorId']}");
      print("  - date: ${data['date']}");
      print("  - time: ${data['time']}");
      
      if (medicalCenterId == _currentUser!.uid) {
        matchingMedicalCenter++;
        print("  ✅ MATCHES current medical center");
      } else {
        print("  ❌ DIFFERENT medical center");
      }
      
      if (status == 'pending') pendingCount++;
      if (appointmentType == 'physical') physicalCount++;
      
      print(""); // Empty line for readability
    }
    
    print("=== SUMMARY ===");
    print("Appointments for this medical center: $matchingMedicalCenter");
    print("Total pending appointments: $pendingCount");
    print("Total physical appointments: $physicalCount");
    
    // Check filtered results
    final pendingForThisCenter = _getFilteredAppointments('pending');
    print("Pending PHYSICAL appointments for this center: ${pendingForThisCenter.length}");
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      await _appointmentsRef.doc(docId).update({"status": newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Appointment ${newStatus} successfully")),
      );
      // Reload data
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // FUNCTION: Create appointments from confirmed doctor schedules
  Future<void> _createAppointmentsFromSchedules() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Creating appointments from schedules...")),
      );

      // Get confirmed doctor schedules for this medical center
      final schedules = await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .where('medicalCenterId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .get();

      int createdCount = 0;
      int existingCount = 0;

      for (var schedule in schedules.docs) {
        final scheduleData = schedule.data() as Map<String, dynamic>;
        
        // Check if appointment already exists for this schedule
        final existingAppointments = await _appointmentsRef
            .where('doctorScheduleId', isEqualTo: schedule.id)
            .get();

        if (existingAppointments.docs.isEmpty) {
          // Create appointment from schedule
          await _appointmentsRef.add({
            'doctorScheduleId': schedule.id,
            'medicalCenterId': scheduleData['medicalCenterId'],
            'doctorId': scheduleData['doctorId'],
            'appointmentType': scheduleData['appointmentType'],
            'date': _formatScheduleDate(scheduleData['date']),
            'time': '${scheduleData['startTime']} - ${scheduleData['endTime']}',
            'status': 'pending', // New appointments start as pending
            'maxAppointments': scheduleData['maxAppointments'],
            'createdAt': FieldValue.serverTimestamp(),
            'patientId': null, // Will be filled when patient books
            'patientName': null,
          });
          createdCount++;
        } else {
          existingCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Created $createdCount new appointments. $existingCount already existed.")),
      );

      // Reload appointments
      _loadAppointments();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating appointments: $e")),
      );
    }
  }

  String _formatScheduleDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
    }
    return date.toString();
  }

  Widget _buildAppointmentsList(String statusFilter) {
    if (_currentUser == null) {
      return const Center(child: Text("Please sign in to view appointments"));
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredAppointments = _getFilteredAppointments(statusFilter);

    if (filteredAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, color: Colors.grey[300], size: 80),
            const SizedBox(height: 16),
            Text(
              "No $statusFilter physical appointments",
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create appointments from confirmed schedules",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAppointments,
              child: const Text("Refresh"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createAppointmentsFromSchedules,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text("Create from Schedules"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredAppointments.length,
      itemBuilder: (context, index) {
        final doc = filteredAppointments[index];
        final data = doc.data() as Map<String, dynamic>;

        final createdAtTimestamp = data['createdAt'] as Timestamp?;
        final createdAtString = createdAtTimestamp != null
            ? _formatDateTime(createdAtTimestamp.toDate())
            : 'Recently';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Physical Appointment",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _getStatusColor(statusFilter),
                            ),
                          ),
                          if (data['patientName'] != null)
                            Text(
                              "Patient: ${data['patientName']}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          if (data['doctorId'] != null)
                            Text(
                              "Doctor ID: ${data['doctorId']}",
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(statusFilter).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        statusFilter.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(statusFilter),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Appointment details
                _buildDetailRow(Icons.calendar_today, "Date", data['date'] ?? 'N/A'),
                _buildDetailRow(Icons.access_time, "Time", data['time'] ?? 'N/A'),
                if (data['maxAppointments'] != null)
                  _buildDetailRow(Icons.people, "Max Appointments", "${data['maxAppointments']}"),
                _buildDetailRow(Icons.schedule, "Created", createdAtString),
                
                // Show if appointment is booked or available
                if (data['patientId'] != null)
                  _buildDetailRow(Icons.person, "Status", "Booked by Patient"),
                if (data['patientId'] == null)
                  _buildDetailRow(Icons.event_available, "Status", "Available for Booking"),
                
                // Action buttons for pending appointments
                if (statusFilter == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text("Confirm"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _updateStatus(doc.id, 'confirmed'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text("Cancel"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _updateStatus(doc.id, 'cancelled'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return "Just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
    if (difference.inHours < 24) return "${difference.inHours}h ago";
    if (difference.inDays < 7) return "${difference.inDays}d ago";
    
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Requests"),
        backgroundColor: const Color(0xFF18A3B6),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pending), text: "Pending"),
            Tab(icon: Icon(Icons.check_circle), text: "Confirmed"),
            Tab(icon: Icon(Icons.cancel), text: "Cancelled"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentsList('pending'),
          _buildAppointmentsList('confirmed'),
          _buildAppointmentsList('cancelled'),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _loadAppointments,
            child: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _createAppointmentsFromSchedules,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add),
            tooltip: 'Create from Schedules',
            mini: true,
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _debugAllAppointments,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.bug_report),
            tooltip: 'Debug Info',
            mini: true,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}