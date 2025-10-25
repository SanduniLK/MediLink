// lib/screens/admin_screens/admin_appointment_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/admin_screens/admin_schedule_approval_screen.dart';

class AdminAppointmentManagement extends StatefulWidget {
  final String medicalCenterId;
  final String medicalCenterName;

  const AdminAppointmentManagement({
    super.key,
    required this.medicalCenterId,
    required this.medicalCenterName,
  });

  @override
  State<AdminAppointmentManagement> createState() => _AdminAppointmentManagementState();
}

class _AdminAppointmentManagementState extends State<AdminAppointmentManagement> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appointments - ${widget.medicalCenterName}'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medical Center Info Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital, size: 40, color: Color(0xFF18A3B6)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medicalCenterName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18A3B6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${widget.medicalCenterId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Management Options
            const Text(
              'Management Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // View Appointments Tile
            _buildManagementTile(
              icon: Icons.calendar_today,
              title: 'View Appointments',
              subtitle: 'Manage and view all patient appointments',
              onTap: () {
                _showAppointmentsScreen(context);
              },
            ),
            
            const SizedBox(height: 16),
            
            // Schedule Approval Tile
            _buildManagementTile(
              icon: Icons.schedule,
              title: 'Schedule Approval',
              subtitle: 'Approve or reject doctor schedule requests',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminScheduleApprovalScreen(medicalCenterId: widget.medicalCenterId, medicalCenterName: widget.medicalCenterName,),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF18A3B6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF18A3B6), size: 30),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF18A3B6)),
        onTap: onTap,
      ),
    );
  }

  void _showAppointmentsScreen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: _AppointmentsView(
          medicalCenterId: widget.medicalCenterId,
          medicalCenterName: widget.medicalCenterName,
        ),
      ),
    );
  }
}

// Separate widget for appointments view
class _AppointmentsView extends StatefulWidget {
  final String medicalCenterId;
  final String medicalCenterName;

  const _AppointmentsView({
    required this.medicalCenterId,
    required this.medicalCenterName,
  });

  @override
  State<_AppointmentsView> createState() => __AppointmentsViewState();
}

class __AppointmentsViewState extends State<_AppointmentsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CollectionReference _appointmentsRef = FirebaseFirestore.instance.collection('appointments');
  List<QueryDocumentSnapshot> _allAppointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    try {
      final snapshot = await _appointmentsRef.get();
      setState(() {
        _allAppointments = snapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print("Error loading appointments: $e");
      setState(() => _loading = false);
    }
  }

  List<QueryDocumentSnapshot> _getFilteredAppointments(String statusFilter) {
    return _allAppointments.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['medicalCenterId'] == widget.medicalCenterId &&
             data['status'] == statusFilter;
    }).toList();
  }

  Widget _buildAppointmentsList(String statusFilter) {
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
              "No $statusFilter appointments",
              style: const TextStyle(fontSize: 18, color: Colors.grey),
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
                            data['appointmentType'] == 'physical' ? "Physical Appointment" : "Telemedicine",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _getStatusColor(statusFilter),
                            ),
                          ),
                          if (data['patientName'] != null)
                            Text("Patient: ${data['patientName']}"),
                          if (data['doctorName'] != null)
                            Text("Doctor: ${data['doctorName']}"),
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
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
          Text(value),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appointments - ${widget.medicalCenterName}'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Confirmed"),
            Tab(text: "Cancelled"),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.close),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}