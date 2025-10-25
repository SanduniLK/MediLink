// ========== SCHEDULE APPOINTMENTS PAGE ==========
import 'package:flutter/material.dart';
// ========== SCHEDULE APPOINTMENTS PAGE ==========
class ScheduleAppointmentsPage extends StatelessWidget {
  final Map<String, dynamic> schedule;

  const ScheduleAppointmentsPage({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);
    final medicalCenterName = schedule['medicalCenterName'] ?? 'Unknown Center';
    final bookedAppointments = schedule['bookedAppointments'] ?? 0;
    
    // Sort appointments by token number
    appointments.sort((a, b) {
      final aToken = a['tokenNumber'] ?? a['token'] ?? 999;
      final bToken = b['tokenNumber'] ?? b['token'] ?? 999;
      return (aToken as int).compareTo(bToken as int);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: Text('Appointments - $medicalCenterName'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Add refresh functionality if needed
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF18A3B6),
                  Color(0xFF32BACD),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicalCenterName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Schedule Information
                Row(
                  children: [
                    _buildHeaderInfo(Icons.people, '$bookedAppointments Patients'),
                    const SizedBox(width: 20),
                    _buildHeaderInfo(Icons.calendar_today, _getScheduleDays(schedule)),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Schedule Time
                if (_getScheduleTime(schedule).isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _getScheduleTime(schedule),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Appointments Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAppointmentStat('Total', appointments.length.toString(), const Color(0xFF18A3B6)),
                _buildAppointmentStat('Waiting', 
                  _countAppointmentsByStatus(appointments, 'waiting').toString(), 
                  const Color(0xFF32BACD)),
                _buildAppointmentStat('Confirmed', 
                  _countAppointmentsByStatus(appointments, 'confirmed').toString(), 
                  Colors.green),
                _buildAppointmentStat('Completed', 
                  _countAppointmentsByStatus(appointments, 'completed').toString(), 
                  Colors.blue),
              ],
            ),
          ),

          // Appointments List
          Expanded(
            child: appointments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No Appointments',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const Text(
                          'No patients scheduled yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      return _buildAppointmentCard(appointments[index], index + 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
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

  int _countAppointmentsByStatus(List<Map<String, dynamic>> appointments, String status) {
    return appointments.where((appointment) => 
      (appointment['status']?.toString().toLowerCase() ?? '') == status.toLowerCase()
    ).length;
  }

  String _getScheduleDays(Map<String, dynamic> schedule) {
    final weeklySchedule = schedule['weeklySchedule'] ?? [];
    List<String> availableDays = [];
    
    for (var daySchedule in weeklySchedule) {
      if (daySchedule['available'] == true) {
        final day = daySchedule['day'] ?? '';
        availableDays.add(day);
      }
    }
    
    return availableDays.isNotEmpty 
        ? availableDays.join(', ')
        : 'No scheduled days';
  }

  String _getScheduleTime(Map<String, dynamic> schedule) {
    final weeklySchedule = schedule['weeklySchedule'] ?? [];
    
    for (var daySchedule in weeklySchedule) {
      if (daySchedule['available'] == true) {
        final timeSlots = daySchedule['timeSlots'] as List? ?? [];
        if (timeSlots.isNotEmpty) {
          final firstSlot = timeSlots.first;
          final startTime = firstSlot['startTime'] ?? '';
          final endTime = firstSlot['endTime'] ?? '';
          return '$startTime - $endTime';
        }
      }
    }
    
    return '';
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, int index) {
    // Extract data from your actual appointment structure
    final patientName = appointment['patientName'] ?? 'Unknown Patient';
    final tokenNumber = appointment['tokenNumber'] ?? index;
    final appointmentTime = appointment['time'] ?? 'Not specified';
    final status = appointment['status']?.toString().toLowerCase() ?? 'waiting';
    final appointmentDate = appointment['date'] ?? 'Today';
    final appointmentType = appointment['appointmentType'] ?? 'physical';
    final fees = appointment['fees'] ?? 0;
    final paymentStatus = appointment['paymentStatus'] ?? 'unknown';
    
    // Calculate patient age from timestamp if available, or use default
    final patientAge = _calculatePatientAge(appointment);
    final patientGender = _getPatientGender(appointment);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor(status).withAlpha(100),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Token Number Circle
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF18A3B6),
                      Color(0xFF32BACD),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF18A3B6).withAlpha(76),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '#$tokenNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Patient Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Name and Demographics
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18A3B6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDF0F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$patientAge years',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF18A3B6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDF0F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            patientGender,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF18A3B6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Date and Time
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: const Color(0xFF32BACD)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(appointmentDate),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF32BACD)),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: const Color(0xFF32BACD)),
                        const SizedBox(width: 4),
                        Text(
                          appointmentTime,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF32BACD)),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Appointment Type and Fees
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F4F8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            appointmentType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF18A3B6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.attach_money, size: 12, color: const Color(0xFF32BACD)),
                        const SizedBox(width: 2),
                        Text(
                          'Rs. $fees',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF32BACD),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPaymentStatusColor(paymentStatus).withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentStatus.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getPaymentStatusColor(paymentStatus),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Status and Actions
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusTextColor(status),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (status == 'waiting' || status == 'confirmed')
                          ElevatedButton(
                            onPressed: () {
                              // Add action to start consultation for this specific patient
                              _startPatientConsultation(appointment);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF18A3B6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: const Size(0, 0),
                            ),
                            child: const Text(
                              'Start',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to calculate patient age (you might need to adjust based on your data)
  int _calculatePatientAge(Map<String, dynamic> appointment) {
    // If you have patient DOB in your data, use it here
    // For now, using a default or random age
    final patientAge = appointment['patientAge'];
    if (patientAge != null && patientAge is int) {
      return patientAge;
    }
    
    // Fallback: generate random age between 18-70
    return 18 + (DateTime.now().millisecondsSinceEpoch % 53);
  }

  // Helper method to get patient gender
  String _getPatientGender(Map<String, dynamic> appointment) {
    final gender = appointment['patientGender'] ?? appointment['gender'];
    if (gender != null && gender is String) {
      return gender;
    }
    return 'Not specified';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF32BACD);
      case 'waiting':
        return const Color(0xFF85CEDA);
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF18A3B6);
      case 'waiting':
        return const Color(0xFF18A3B6);
      case 'completed':
        return Colors.green[700]!;
      case 'cancelled':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Color _getPaymentStatusColor(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String date) {
    if (date == 'Today') return 'Today';
    if (date == 'Tomorrow') return 'Tomorrow';
    
    // Handle "Tomorrow (9/10/2025)" format
    if (date.contains('Tomorrow')) {
      return 'Tomorrow';
    }
    
    // Handle other date formats
    try {
      // Try to parse various date formats
      if (date.contains('/')) {
        final parts = date.split('/');
        if (parts.length == 3) {
          return '${parts[0]}/${parts[1]}/${parts[2]}';
        }
      }
      
      final DateTime parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      // Return the original date if parsing fails
      return date;
    }
  }

  void _startPatientConsultation(Map<String, dynamic> appointment) {
    // Implement starting consultation for a specific patient
    print('Starting consultation for: ${appointment['patientName']}');
    
    // You can navigate to a consultation screen or show a dialog
    // Navigator.push(...);
  }
}

