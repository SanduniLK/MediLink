import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';



import 'feedback_form_screen.dart'; 

class TokenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
}

class MyAppointmentsPage extends StatefulWidget {
  final String patientId;
  
  const MyAppointmentsPage({Key? key, required this.patientId}) : super(key: key);

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;
  String errorMessage = '';
  final TokenService _tokenService = TokenService();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 tabs only
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
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

      print('🔍 Loading appointments for patient: ${widget.patientId}');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('createdAt', descending: true)
          .get();

      print('✅ Found ${querySnapshot.docs.length} appointments');

      List<Map<String, dynamic>> appointmentsList = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        appointmentsList.add({
          'id': doc.id,
          'patientId': data['patientId'],
          'patientName': data['patientName'] ?? 'Patient',
          'doctorId': data['doctorId'],
          'doctorName': data['doctorName'] ?? 'Doctor',
          'doctorSpecialty': data['doctorSpecialty'] ?? 'General Practitioner',
          'medicalCenterName': data['medicalCenterName'] ?? 'Medical Center',
          'medicalCenterId': data['medicalCenterId'] ?? '', // Added for feedback
          'date': data['date'] ?? 'Not specified',
          'time': data['time'] ?? 'Not specified',
          'appointmentType': data['appointmentType'] ?? 'physical',
          'patientNotes': data['patientNotes'] ?? '',
          'fees': data['fees'] ?? '0',
          'status': data['status'] ?? 'requested',
          'paymentStatus': data['paymentStatus'] ?? 'pending',
          'paymentMethod': data['paymentMethod'] ?? 'Not specified',
          'createdAt': data['createdAt'] ?? Timestamp.now(),
          'tokenNumber': data['tokenNumber'] ?? 0,
          'queueStatus': data['queueStatus'] ?? 'waiting',
          'qrCodeData': data['qrCodeData'] ?? '',
          'currentQueueNumber': data['currentQueueNumber'] ?? 0,
          'scheduleId': data['scheduleId'] ?? '',
          'feedbackSubmitted': data['feedbackSubmitted'] ?? false, // Added feedback status
        });
      }

      setState(() {
        appointments = appointmentsList;
      });

      print('📊 ALL APPOINTMENTS:');
      for (var apt in appointments) {
        print(' - ${apt['doctorName']} | Date: ${apt['date']} | Status: ${apt['status']} | Feedback: ${apt['feedbackSubmitted']}');
      }
      
      print('📈 UPCOMING: ${_getUpcomingAppointments().length}');
      print('📈 PAST: ${_getPastAppointments().length}');

    } catch (e) {
      print('❌ Error loading appointments: $e');
      setState(() {
        errorMessage = 'Failed to load appointments. Please check your internet connection.';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  List<Map<String, dynamic>> _getUpcomingAppointments() {
    return appointments.where((apt) {
      final status = apt['status']?.toString() ?? '';
      
      return (status == 'confirmed' || status == 'pending') && 
             status != 'completed' && 
             status != 'cancelled';
    }).toList();
  }

  List<Map<String, dynamic>> _getPastAppointments() {
    return appointments.where((apt) {
      final status = apt['status']?.toString() ?? '';
      return status == 'completed';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _getUpcomingAppointments();
    final past = _getPastAppointments();
    
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: _buildTabWithBadge('upcomming', upcoming.length),
            ),
            Tab(
              child: _buildTabWithBadge('Completed ', past.length),
            ),
          ],
        ),
      ),
      body: errorMessage.isNotEmpty
          ? _buildErrorState()
          : _buildTabContent(upcoming, past),
      
    );
  }

  Widget _buildTabContent(List<Map<String, dynamic>> upcoming, List<Map<String, dynamic>> past) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAppointmentsList(upcoming, 'upcoming'),
        _buildAppointmentsList(past, 'past'),
      ],
    );
  }

  Widget _buildTabWithBadge(String title, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFF18A3B6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: const Color(0xFF85CEDA).withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connection Issue',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadAppointments,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(List<Map<String, dynamic>> appointmentList, String type) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF18A3B6)),
        ),
      );
    }
    
    if (appointmentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(type),
              size: 64,
              color: const Color(0xFFB2DEE6),
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(type),
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF18A3B6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptySubMessage(type),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF85CEDA),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      backgroundColor: const Color(0xFFDDF0F5),
      color: const Color(0xFF18A3B6),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointmentList.length,
        itemBuilder: (context, index) {
          final appointment = appointmentList[index];
          return _buildAppointmentCard(appointment, type);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, String type) {
    final statusColor = _getStatusColor(appointment['status']);
    final dateStr = appointment['date']?.toString() ?? '';
    final isTomorrow = dateStr.toLowerCase().contains('tomorrow');
    final tokenNumber = appointment['tokenNumber'] ?? 0;
    final queueStatus = appointment['queueStatus'] ?? 'waiting';
    final feedbackSubmitted = appointment['feedbackSubmitted'] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFDDF0F5).withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Info and Status
              Row(
                children: [
                  // Token number badge for upcoming appointments
                  if (tokenNumber > 0 && type == 'upcoming')
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18A3B6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#$tokenNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Token',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    CircleAvatar(
                      backgroundColor: const Color(0xFF32BACD),
                      child: Text(
                        _getDoctorInitials(appointment['doctorName']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment['doctorName'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18A3B6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          appointment['doctorSpecialty'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF85CEDA),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      appointment['status'].toString().toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Queue status for upcoming appointments
              if (tokenNumber > 0 && type == 'upcoming')
                _buildQueueStatusRow(queueStatus, tokenNumber, appointment['currentQueueNumber'] ?? 0),
              
              // Medical Center
              _buildDetailRow(Icons.location_on, appointment['medicalCenterName']),
              const SizedBox(height: 8),
              
              // Date with Tomorrow indicator
              Row(
                children: [
                  Icon(
                    Icons.calendar_today, 
                    size: 16, 
                    color: isTomorrow ? const Color(0xFF32BACD) : const Color(0xFF85CEDA),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment['date'],
                      style: TextStyle(
                        fontSize: 14,
                        color: isTomorrow ? const Color(0xFF32BACD) : const Color(0xFF18A3B6),
                        fontWeight: isTomorrow ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isTomorrow) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF32BACD).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'TOMORROW',
                        style: TextStyle(
                          color: const Color(0xFF32BACD),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              // Time and Appointment Type
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 360;
                  
                  return Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: const Color(0xFF85CEDA)),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(appointment['time']),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        _getConsultationIcon(appointment['appointmentType']), 
                        size: 16, 
                        color: const Color(0xFF85CEDA),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatConsultationType(appointment['appointmentType']),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF18A3B6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              // Fees
              const SizedBox(height: 8),
              _buildDetailRow(Icons.attach_money, 'Fees: Rs. ${appointment['fees']}'),
              
              // Payment Status
              const SizedBox(height: 8),
              _buildDetailRow(Icons.payment, 'Payment: ${appointment['paymentStatus']}'),
              
              
              const SizedBox(height: 12),
              
              // Footer with booking date and action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booked: ${_formatDateTime(appointment['createdAt'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF85CEDA),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                 
                  
                  // Feedback button for past appointments
                  if (type == 'past') 
                    _buildPastAppointmentButtons(appointment, feedbackSubmitted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Queue status row
  Widget _buildQueueStatusRow(String queueStatus, int tokenNumber, int currentQueue) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (queueStatus) {
      case 'in-consultation':
        statusColor = Colors.orange;
        statusText = 'Currently Consulting';
        statusIcon = Icons.medical_services;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Consultation Completed';
        statusIcon = Icons.check_circle;
        break;
      default: // waiting
        statusColor = const Color(0xFF32BACD);
        if (currentQueue > 0 && tokenNumber > currentQueue) {
          final patientsAhead = tokenNumber - currentQueue - 1;
          statusText = '$patientsAhead patient${patientsAhead == 1 ? '' : 's'} ahead';
          statusIcon = Icons.timer;
        } else {
          statusText = 'Waiting for your turn';
          statusIcon = Icons.schedule;
        }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  

  

  Widget _buildPastAppointmentButtons(Map<String, dynamic> appointment, bool feedbackSubmitted) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // View Details Button
        Container(
          constraints: const BoxConstraints(minWidth: 100),
          decoration: BoxDecoration(
            color: const Color(0xFF85CEDA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF85CEDA)),
          ),
          child: TextButton.icon(
            onPressed: () {
              _showAppointmentDetails(appointment);
            },
            icon: const Icon(
              Icons.info,
              size: 16,
              color: Color(0xFF85CEDA),
            ),
            label: const Text(
              'Details',
              style: TextStyle(
                color: Color(0xFF85CEDA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        // Feedback Button - NAVIGATES TO FeedbackFormScreen
        Container(
          constraints: const BoxConstraints(minWidth: 100),
          decoration: BoxDecoration(
            color: feedbackSubmitted 
                ? Colors.green.withOpacity(0.1)
                : const Color(0xFF18A3B6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: feedbackSubmitted ? Colors.green : const Color(0xFF18A3B6)
            ),
          ),
          child: TextButton.icon(
            onPressed: feedbackSubmitted 
                ? null // Disable button if feedback already submitted
                : () {
                    _navigateToFeedbackScreen(appointment);
                  },
            icon: Icon(
              feedbackSubmitted ? Icons.check : Icons.rate_review,
              size: 16,
              color: feedbackSubmitted ? Colors.green : const Color(0xFF18A3B6),
            ),
            label: Text(
              feedbackSubmitted ? 'Feedback Submitted' : 'Write Feedback',
              style: TextStyle(
                color: feedbackSubmitted ? Colors.green : const Color(0xFF18A3B6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // New method to navigate to FeedbackFormScreen
  void _navigateToFeedbackScreen(Map<String, dynamic> appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackFormScreen(
          patientId: widget.patientId,
          
        doctorId: appointment['doctorId'] ?? '',
        doctorName: appointment['doctorName'] ?? 'Doctor',
        medicalCenterId: appointment['medicalCenterId'] ?? '',
        medicalCenterName: appointment['medicalCenterName'] ?? 'Medical Center',
        appointmentDate: appointment['date'] ?? '',
        ),
      ),
    ).then((value) {
      // Refresh appointments when returning from feedback screen
      if (value == true) {
        _loadAppointments();
      }
    });
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final tokenNumber = appointment['tokenNumber'] ?? 0;
    final queueStatus = appointment['queueStatus'] ?? 'waiting';
    final feedbackSubmitted = appointment['feedbackSubmitted'] ?? false;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Doctor', 'Dr. ${appointment['doctorName']}'),
              _buildDetailItem('Specialty', appointment['doctorSpecialty']),
              _buildDetailItem('Medical Center', appointment['medicalCenterName']),
              _buildDetailItem('Date', appointment['date']),
              _buildDetailItem('Time', _formatTime(appointment['time'])),
              _buildDetailItem('Type', _formatConsultationType(appointment['appointmentType'])),
              _buildDetailItem('Status', appointment['status']),
              // Token and queue info
              if (tokenNumber > 0) _buildDetailItem('Token Number', '#$tokenNumber'),
              if (tokenNumber > 0) _buildDetailItem('Queue Status', _formatQueueStatus(queueStatus)),
              _buildDetailItem('Fees', 'Rs. ${appointment['fees']}'),
              _buildDetailItem('Payment Status', appointment['paymentStatus']),
              _buildDetailItem('Booked On', _formatDateTime(appointment['createdAt'])),
              // Feedback info
              _buildDetailItem('Feedback Submitted', feedbackSubmitted ? 'Yes' : 'No'),
              if (appointment['patientNotes']?.isNotEmpty == true)
                _buildDetailItem('Your Notes', appointment['patientNotes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!feedbackSubmitted) 
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToFeedbackScreen(appointment);
              },
              child: const Text('Write Feedback'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF85CEDA)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF85CEDA)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF18A3B6),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

 

  // Helper methods
  String _formatTime(String time) {
    try {
      if (time.contains(' - ')) {
        final parts = time.split(' - ');
        if (parts.isNotEmpty) {
          return '${parts[0]}';
        }
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _getDoctorInitials(String doctorName) {
    if (doctorName.isEmpty) return 'DR';
    final names = doctorName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return doctorName.length >= 2 ? doctorName.substring(0, 2).toUpperCase() : 'DR';
  }

  IconData _getEmptyIcon(String type) {
    switch (type) {
      case 'upcoming':
        return Icons.event_available;
      case 'past':
        return Icons.history;
      default:
        return Icons.event;
    }
  }

  String _getEmptyMessage(String type) {
    switch (type) {
      case 'upcoming':
        return 'No upcoming appointments';
      case 'past':
        return 'No past appointments';
      default:
        return 'No appointments';
    }
  }

  String _getEmptySubMessage(String type) {
    switch (type) {
      case 'upcoming':
        return 'Book a new appointment to get started';
      case 'past':
        return 'Your completed appointments will appear here';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF32BACD);
      case 'requested':
        return const Color(0xFF85CEDA);
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getConsultationIcon(String type) {
    switch (type) {
      case 'physical':
        return Icons.local_hospital;
      case 'audio':
        return Icons.phone;
      case 'video':
        return Icons.video_call;
      default:
        return Icons.help;
    }
  }

  String _formatConsultationType(String type) {
    switch (type) {
      case 'physical':
        return 'Physical Visit';
      case 'audio':
        return 'Audio Call';
      case 'video':
        return 'Video Call';
      default:
        return type;
    }
  }

  

  

  String _formatQueueStatus(String queueStatus) {
    switch (queueStatus) {
      case 'waiting': return 'Waiting for your turn';
      case 'in-consultation': return 'Currently in consultation';
      case 'completed': return 'Consultation completed';
      default: return queueStatus;
    }
  }
}
