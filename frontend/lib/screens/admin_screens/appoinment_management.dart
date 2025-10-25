import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MedicalCenterAppointmentManagementPage extends StatefulWidget {
  const MedicalCenterAppointmentManagementPage({Key? key}) : super(key: key);

  @override
  State<MedicalCenterAppointmentManagementPage> createState() => _MedicalCenterAppointmentManagementPageState();
}

class _MedicalCenterAppointmentManagementPageState extends State<MedicalCenterAppointmentManagementPage>
    with SingleTickerProviderStateMixin {
  final CollectionReference _appointmentsRef =
      FirebaseFirestore.instance.collection('appointments');
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  String? _medicalCenterId;
  String? _medicalCenterName;
  
  late TabController _tabController;
  List<QueryDocumentSnapshot> _allAppointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchMedicalCenterData();
  }

  Future<void> _fetchMedicalCenterData() async {
    try {
      if (_currentUser == null) {
        setState(() => _loading = false);
        return;
      }

      final email = _currentUser!.email;
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('medical_centers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _medicalCenterId = doc.id;
          _medicalCenterName = doc['name'];
        });
      } else {
        final adminDoc = await FirebaseFirestore.instance
            .collection('admin')
            .doc(_currentUser!.uid)
            .get();
            
        if (adminDoc.exists) {
          setState(() {
            _medicalCenterId = adminDoc.data()?['medicalCenterId'];
            _medicalCenterName = adminDoc.data()?['medicalCenterName'] ?? 'Medical Center';
          });
        } else {
          setState(() {
            _medicalCenterId = _currentUser!.uid;
            _medicalCenterName = 'Medical Center';
          });
        }
      }
      
      _loadAppointments();
      
    } catch (e) {
      print('Error fetching medical center data: $e');
      setState(() {
        _medicalCenterId = _currentUser?.uid;
        _medicalCenterName = 'Medical Center';
        _loading = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    if (_currentUser == null || _medicalCenterId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snapshot = await _appointmentsRef.get();
      setState(() {
        _allAppointments = snapshot.docs;
        _loading = false;
      });
      
      _debugAllAppointments();
      
    } catch (e) {
      print("Error loading appointments: $e");
      setState(() => _loading = false);
    }
  }

  List<QueryDocumentSnapshot> _getFilteredAppointments(String statusFilter) {
    return _allAppointments.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['medicalCenterId'] == _medicalCenterId &&
             data['status'] == statusFilter &&
             data['appointmentType'] == 'physical';
    }).toList();
  }

  void _debugAllAppointments() {
    if (_currentUser == null || _medicalCenterId == null) return;
    
    print("=== ALL APPOINTMENTS DEBUG ===");
    print("Medical Center Admin UID: ${_currentUser!.uid}");
    print("Medical Center ID: $_medicalCenterId");
    print("Medical Center Name: $_medicalCenterName");
    print("Total appointments in database: ${_allAppointments.length}");
    
    int matchingMedicalCenter = 0;
    
    for (var doc in _allAppointments) {
      final data = doc.data() as Map<String, dynamic>;
      final medicalCenterId = data['medicalCenterId'];
      
      if (medicalCenterId == _medicalCenterId) {
        matchingMedicalCenter++;
      }
    }
    
    print("Appointments for this medical center: $matchingMedicalCenter");
  }

  // ADD THIS MISSING METHOD
  String _formatScheduleDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
    }
    return date.toString();
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      await _appointmentsRef.doc(docId).update({"status": newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Appointment ${newStatus} successfully")),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _createAppointmentsFromSchedules() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _medicalCenterId == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Creating appointments from schedules...")),
      );

      final schedules = await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .where('medicalCenterId', isEqualTo: _medicalCenterId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      int createdCount = 0;
      int existingCount = 0;

      for (var schedule in schedules.docs) {
        final scheduleData = schedule.data() as Map<String, dynamic>;
        
        final existingAppointments = await _appointmentsRef
            .where('doctorScheduleId', isEqualTo: schedule.id)
            .get();

        if (existingAppointments.docs.isEmpty) {
          await _appointmentsRef.add({
            'doctorScheduleId': schedule.id,
            'medicalCenterId': _medicalCenterId,
            'medicalCenterName': _medicalCenterName,
            'doctorId': scheduleData['doctorId'],
            'doctorName': scheduleData['doctorName'],
            'appointmentType': scheduleData['appointmentType'],
            'date': _formatScheduleDate(scheduleData['date']),
            'time': '${scheduleData['startTime']} - ${scheduleData['endTime']}',
            'status': 'pending',
            'maxAppointments': scheduleData['maxAppointments'],
            'createdAt': FieldValue.serverTimestamp(),
            'patientId': null,
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

      _loadAppointments();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating appointments: $e")),
      );
    }
  }

  // ADD THIS MISSING METHOD
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
                
                _buildDetailRow(Icons.calendar_today, "Date", data['date'] ?? 'N/A'),
                _buildDetailRow(Icons.access_time, "Time", data['time'] ?? 'N/A'),
                if (data['maxAppointments'] != null)
                  _buildDetailRow(Icons.people, "Max Appointments", "${data['maxAppointments']}"),
                _buildDetailRow(Icons.schedule, "Created", createdAtString),
                
                if (data['patientId'] != null)
                  _buildDetailRow(Icons.person, "Status", "Booked by Patient"),
                if (data['patientId'] == null)
                  _buildDetailRow(Icons.event_available, "Status", "Available for Booking"),
                
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

  // ADD THIS MISSING METHOD
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

  // ADD THIS MISSING METHOD
  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return "Just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
    if (difference.inHours < 24) return "${difference.inHours}h ago";
    if (difference.inDays < 7) return "${difference.inDays}d ago";
    
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // ADD THIS MISSING METHOD
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
        title: Text("Appointment Requests - ${_medicalCenterName ?? 'Medical Center'}"),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
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