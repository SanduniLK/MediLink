import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDoctorAppointments();
  }

  Future<void> _loadDoctorAppointments() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          errorMessage = 'Please log in to view appointments';
          isLoading = false;
        });
        return;
      }

      print('🔍 Loading appointments for doctor: ${currentUser.uid}');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      print('✅ Found ${querySnapshot.docs.length} appointments');

      List<Map<String, dynamic>> appointmentsList = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // If patientName is "Patient Name", try to fetch actual patient data
        String patientName = data['patientName'] ?? 'Patient';
        String patientId = data['patientId'] ?? '';
        
        // If patient name is generic, try to fetch real name
        if (patientName == 'Patient Name' || patientName == 'Patient' || patientName.isEmpty) {
          patientName = await _fetchPatientName(patientId);
        }

        appointmentsList.add({
          'id': doc.id,
          'patientId': patientId,
          'patientName': patientName,
          'doctorId': data['doctorId'],
          'doctorName': data['doctorName'],
          'doctorSpecialty': data['doctorSpecialty'],
          'medicalCenterName': data['medicalCenterName'],
          'date': data['date'],
          'time': data['time'],
          'appointmentType': data['appointmentType'],
          'patientNotes': data['patientNotes'],
          'fees': data['fees'],
          'status': data['status'],
          'paymentStatus': data['paymentStatus'],
          'paymentMethod': data['paymentMethod'],
          'createdAt': data['createdAt'],
        });
      }

      setState(() {
        appointments = appointmentsList;
      });

    } catch (e) {
      print('❌ Error loading appointments: $e');
      setState(() {
        errorMessage = 'Failed to load appointments: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<String> _fetchPatientName(String patientId) async {
    if (patientId.isEmpty) return 'Patient';
    
    try {
      // Try patients collection first
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        return patientDoc.data()!['fullname'] ?? 'Patient';
      }

      // Try users collection as fallback
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      if (userDoc.exists) {
        return userDoc.data()!['fullname'] ?? 'Patient';
      }

      return 'Patient';
    } catch (e) {
      print('❌ Error fetching patient name: $e');
      return 'Patient';
    }
  }

  // FIXED: Return Color instead of String
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // FIXED: Return Color instead of String
  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDoctorAppointments,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDoctorAppointments,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : appointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No Appointments',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You don\'t have any appointments yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${appointments.length} Appointment(s)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18A3B6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: appointments.length,
                              itemBuilder: (context, index) {
                                final appointment = appointments[index];
                                return _buildAppointmentCard(appointment);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final statusColor = _getStatusColor(appointment['status'] ?? 'pending');
    final paymentStatusColor = _getPaymentStatusColor(appointment['paymentStatus'] ?? 'pending');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF18A3B6),
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['patientName'] ?? 'Patient',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_capitalize(appointment['appointmentType'] ?? '')} Appointment',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Appointment Details
            _buildAppointmentDetail('Date', appointment['date'] ?? 'Not specified'),
            _buildAppointmentDetail('Time', appointment['time'] ?? 'Not specified'),
            _buildAppointmentDetail('Medical Center', appointment['medicalCenterName'] ?? 'Not specified'),
            
            if (appointment['patientNotes'] != null && appointment['patientNotes'].isNotEmpty)
              _buildAppointmentDetail('Patient Notes', appointment['patientNotes']),
            
            const SizedBox(height: 12),
            
            // Status and Payment
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    (appointment['status'] ?? 'pending').toString().toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: paymentStatusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: paymentStatusColor),
                  ),
                  child: Text(
                    '${appointment['paymentStatus'] ?? 'pending'} - ${appointment['paymentMethod'] ?? 'Not specified'}',
                    style: TextStyle(
                      color: paymentStatusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs. ${appointment['fees'] ?? '0'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}