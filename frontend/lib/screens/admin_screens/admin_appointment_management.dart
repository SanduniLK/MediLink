// lib/screens/admin_screens/admin_appointment_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                    builder: (context) => AdminScheduleApprovalScreen(
                      medicalCenterId: widget.medicalCenterId, 
                      medicalCenterName: widget.medicalCenterName,
                    ),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Changed to 2 tabs
  }

  // Stream for appointments
  Stream<QuerySnapshot> _getAppointmentsStream(String statusFilter) {
    return _appointmentsRef
        .where('medicalCenterId', isEqualTo: widget.medicalCenterId)
        .where('status', isEqualTo: statusFilter)
        .where('appointmentType', isEqualTo: 'physical')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildAppointmentsStream(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAppointmentsStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[300], size: 80),
                const SizedBox(height: 16),
                Text(
                  statusFilter == 'completed' ? "No completed appointments" : "No confirmed appointments",
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final doc = appointments[index];
            final data = doc.data() as Map<String, dynamic>;

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
                              const SizedBox(height: 4),
                              Text(
                                "Patient: ${data['patientName'] ?? 'N/A'}",
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                "Doctor: ${data['doctorName'] ?? 'N/A'}",
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

                    const SizedBox(height: 16),

                    // Appointment Details
                    _buildDetailSection(
                      "Appointment Details",
                      [
                        _buildDetailRow(Icons.calendar_today, "Date", data['date'] ?? 'N/A'),
                        _buildDetailRow(Icons.access_time, "Time", data['time'] ?? 'N/A'),
                        _buildDetailRow(Icons.medical_services, "Queue Status", data['queueStatus'] ?? 'N/A'),
                        if (data['tokenNumber'] != null)
                          _buildDetailRow(Icons.confirmation_number, "Token Number", data['tokenNumber'].toString()),
                        if (data['currentQueueNumber'] != null)
                          _buildDetailRow(Icons.format_list_numbered, "Current Queue", data['currentQueueNumber'].toString()),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Fees Details
                    _buildDetailSection(
                      "Fees Details",
                      [
                        if (data['doctorFees'] != null)
                          _buildDetailRow(Icons.attach_money, "Doctor Fees", "₹${data['doctorFees']}"),
                        if (data['medicalCenterFees'] != null)
                          _buildDetailRow(Icons.business, "Center Fees", "₹${data['medicalCenterFees']}"),
                        if (data['fees'] != null)
                          _buildDetailRow(Icons.payments, "Total Fees", "₹${data['fees']}"),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Payment & Completion Details
                    _buildDetailSection(
                      "Payment & Timeline",
                      [
                        if (data['paymentStatus'] != null)
                          _buildDetailRow(
                            Icons.payment,
                            "Payment Status",
                            data['paymentStatus'],
                            color: data['paymentStatus'] == 'paid' ? Colors.green : Colors.orange,
                          ),
                        if (data['createdAt'] != null)
                          _buildDetailRow(Icons.create, "Created", _formatTimestamp(data['createdAt'])),
                        if (statusFilter == 'completed' && data['completedAt'] != null)
                          _buildDetailRow(Icons.check_circle, "Completed", _formatTimestamp(data['completedAt'])),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Patient Notes (if any)
                    if (data['patientNotes'] != null && data['patientNotes'].toString().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            "Patient Notes:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['patientNotes'].toString(),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF18A3B6),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (timestamp is String) {
        return timestamp;
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
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
        title: Text('Appointments - ${widget.medicalCenterName}'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Confirmed"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentsStream('confirmed'),
          _buildAppointmentsStream('completed'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.close),
        backgroundColor: const Color(0xFF18A3B6),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}