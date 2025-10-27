// screens/patient_screens/doctor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/patient_screens/book_appointment_page.dart';
import 'package:intl/intl.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;
  
  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Map<String, dynamic>? doctorData;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    doctorData = widget.doctorData;
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    setState(() => isLoading = true);
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .get();

      if (snap.exists) {
        setState(() {
          doctorData = snap.data()!;
        });
      }
    } catch (e) {
      // Error handled
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not specified' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Professional Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Specialization', doctorData?['specialization'] ?? '', icon: Icons.medical_services),
            _buildInfoRow('Qualification', doctorData?['qualification'] ?? '', icon: Icons.school),
            _buildInfoRow('Experience', '${doctorData?['experience'] ?? 0} years', icon: Icons.work),
            _buildInfoRow('Hospital', doctorData?['hospital'] ?? '', icon: Icons.local_hospital),
            _buildInfoRow('License Number', doctorData?['license'] ?? '', icon: Icons.badge),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Email', doctorData?['email'] ?? '', icon: Icons.email),
            _buildInfoRow('Phone', doctorData?['phone'] ?? '', icon: Icons.phone),
            _buildInfoRow('Address', doctorData?['address'] ?? '', icon: Icons.location_on),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    final String? profileImageUrl = doctorData?['profileImage'];
    
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(profileImageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // Error handled silently
        },
      );
    } else {
      return const CircleAvatar(
        radius: 50,
        backgroundColor: Color(0xFF18A3B6),
        child: Icon(Icons.person, size: 50, color: Colors.white),
      );
    }
  }

  // Book Appointment Method
  Future<void> _fetchAndShowDoctorSchedules() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch confirmed schedules for this doctor
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .where('doctorId', isEqualTo: widget.doctorId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (schedulesSnapshot.docs.isEmpty) {
        _showNoSchedulesDialog();
        return;
      }

      // Get current date and time for comparison
      final now = DateTime.now();
      final currentDate = DateTime(now.year, now.month, now.day);
      
      List<Map<String, dynamic>> availableSchedules = [];

      for (var doc in schedulesSnapshot.docs) {
        final data = doc.data();
        
        // Process as single date if availableDate or scheduleDate exists
        if (data['availableDate'] != null || data['scheduleDate'] != null) {
          final singleSchedule = _processSingleDateSchedule(doc.id, data, doctorData?['fullname'] ?? 'Doctor', currentDate);
          if (singleSchedule != null) {
            availableSchedules.add(singleSchedule);
          }
        }
        // Process as weekly schedule if no date fields exist
        else if (data['weeklySchedule'] != null && data['weeklySchedule'] is List) {
          final weeklySchedules = _processWeeklySchedule(doc.id, data, doctorData?['fullname'] ?? 'Doctor');
          availableSchedules.addAll(weeklySchedules);
        }
      }

      // Sort schedules by date (earliest first)
      availableSchedules.sort((a, b) {
        final dateA = a['date'] as DateTime;
        final dateB = b['date'] as DateTime;
        return dateA.compareTo(dateB);
      });

      if (availableSchedules.isEmpty) {
        _showNoFutureSchedulesDialog();
      } else {
        _showScheduleSelectionDialog(availableSchedules);
      }

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      _showErrorDialog('Failed to load available schedules: $e');
    }
  }

  Map<String, dynamic>? _processSingleDateSchedule(String scheduleId, Map<String, dynamic> data, String doctorName, DateTime currentDate) {
    DateTime? scheduleDate;
    
    // PRIORITY 1: Use availableDate (string format "2025-10-25")
    if (data['availableDate'] != null && data['availableDate'] is String) {
      final availableDateStr = data['availableDate'] as String;
      try {
        scheduleDate = DateFormat('yyyy-MM-dd').parse(availableDateStr);
      } catch (e) {
        print('Error parsing availableDate: $e');
      }
    }
    
    // PRIORITY 2: Fallback to scheduleDate (timestamp)
    if (scheduleDate == null && data['scheduleDate'] != null) {
      if (data['scheduleDate'] is Timestamp) {
        scheduleDate = (data['scheduleDate'] as Timestamp).toDate();
      } else if (data['scheduleDate'] is DateTime) {
        scheduleDate = data['scheduleDate'] as DateTime;
      }
    }

    if (scheduleDate == null) return null;

    final scheduleDay = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
    final isFuture = scheduleDay.isAfter(currentDate.subtract(const Duration(days: 1)));
    
    if (!isFuture) return null;

    // Get time slots
    String startTime = '09:00';
    String endTime = '17:00';
    int slotDuration = 30;
    int maxAppointments = 10;

    // Get time slots from weekly schedule for the specific day
    if (data['weeklySchedule'] != null && data['weeklySchedule'] is List) {
      final weeklySchedule = data['weeklySchedule'] as List<dynamic>;
      final dayName = _getDayName(scheduleDate.weekday).toLowerCase();
      
      for (var daySchedule in weeklySchedule) {
        if (daySchedule is Map<String, dynamic>) {
          final scheduleDayName = (daySchedule['day'] as String? ?? '').toLowerCase();
          final isAvailable = daySchedule['available'] as bool? ?? false;
          
          if (scheduleDayName == dayName && isAvailable) {
            final timeSlots = daySchedule['timeSlots'] as List<dynamic>? ?? [];
            if (timeSlots.isNotEmpty) {
              final firstSlot = timeSlots[0];
              if (firstSlot is Map<String, dynamic>) {
                startTime = firstSlot['startTime'] ?? startTime;
                endTime = firstSlot['endTime'] ?? endTime;
                slotDuration = firstSlot['slotDuration'] ?? slotDuration;
              }
            }
            break;
          }
        }
      }
    } else {
      // Use direct time fields as fallback
      startTime = data['startTime'] ?? startTime;
      endTime = data['endTime'] ?? endTime;
      slotDuration = data['slotDuration'] ?? slotDuration;
    }

    maxAppointments = data['maxAppointments'] ?? maxAppointments;

    return {
      'scheduleId': scheduleId,
      'date': scheduleDate,
      'startTime': startTime,
      'endTime': endTime,
      'appointmentType': data['appointmentType'] ?? 'physical',
      'slotDuration': slotDuration,
      'maxAppointments': maxAppointments,
      'availableSlots': data['availableSlots'] ?? maxAppointments,
      'doctorName': data['doctorName'] ?? doctorName,
      'isWeekly': false,
    };
  }

  List<Map<String, dynamic>> _processWeeklySchedule(String scheduleId, Map<String, dynamic> data, String doctorName) {
    final weeklySchedule = data['weeklySchedule'] as List<dynamic>;
    final List<Map<String, dynamic>> schedules = [];
    
    // Get next 7 days
    final now = DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final dayName = _getDayName(date.weekday).toLowerCase();
      
      // Find if this day is available in the weekly schedule
      for (var daySchedule in weeklySchedule) {
        if (daySchedule is Map<String, dynamic>) {
          final scheduleDay = (daySchedule['day'] as String? ?? '').toLowerCase();
          final isAvailable = daySchedule['available'] as bool? ?? false;
          
          if (scheduleDay == dayName && isAvailable) {
            final timeSlots = daySchedule['timeSlots'] as List<dynamic>? ?? [];
            
            for (var slot in timeSlots) {
              if (slot is Map<String, dynamic>) {
                schedules.add({
                  'scheduleId': scheduleId,
                  'date': date,
                  'startTime': slot['startTime'] ?? '09:00',
                  'endTime': slot['endTime'] ?? '17:00',
                  'appointmentType': data['appointmentType'] ?? 'physical',
                  'slotDuration': slot['slotDuration'] ?? data['slotDuration'] ?? 30,
                  'maxAppointments': data['maxAppointments'] ?? 10,
                  'availableSlots': data['availableSlots'] ?? data['maxAppointments'] ?? 10,
                  'doctorName': data['doctorName'] ?? doctorName,
                  'isWeekly': true,
                  'dayOfWeek': _getDayName(date.weekday),
                });
              }
            }
          }
        }
      }
    }
    
    return schedules;
  }

  void _showScheduleSelectionDialog(List<Map<String, dynamic>> schedules) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Available Slots - Dr. ${doctorData?['fullname']}',
          style: TextStyle(
            color: Colors.blueGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              final date = schedule['date'] is DateTime 
                  ? _getFormattedDate(schedule['date'] as DateTime)
                  : 'Date not specified';
              
              // Check if slots are available
              final availableSlots = schedule['availableSlots'] ?? 0;
              final isAvailable = availableSlots > 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isAvailable ? null : Colors.grey[100],
                child: ListTile(
                  leading: Icon(
                    _getAppointmentTypeIcon(schedule['appointmentType']),
                    color: isAvailable ? const Color(0xFF18A3B6) : Colors.grey,
                  ),
                  title: Text(
                    date,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${schedule['startTime']} - ${schedule['endTime']}',
                        style: TextStyle(
                          color: isAvailable ? Colors.black : Colors.grey,
                        ),
                      ),
                      Text(
                        'Type: ${_capitalize(schedule['appointmentType'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAvailable ? Colors.grey[600] : Colors.grey,
                        ),
                      ),
                      if (schedule['isWeekly'] == true)
                        Text(
                          'Weekly Schedule',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        )
                      else
                        Text(
                          "One-time Schedule",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        'Available Slots: $availableSlots',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAvailable ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  onTap: isAvailable ? () {
                    Navigator.pop(context);
                    _navigateToBookingPage(schedule);
                  } : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToBookingPage(Map<String, dynamic> schedule) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorDialog('Please log in to book an appointment');
        return;
      }

      // Fetch actual patient data
      final patientId = currentUser.uid;
      String patientName = 'Patient';

      // Try to get patient name from patients collection
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        patientName = patientDoc.data()!['fullname'] ?? 'Patient';
      } else {
        // Try users collection as fallback
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .get();
        
        if (userDoc.exists) {
          patientName = userDoc.data()!['fullname'] ?? 'Patient';
        }
      }

      final scheduleId = schedule['scheduleId']?.toString() ?? '';
      final selectedDate = _getFormattedDate(schedule['date'] as DateTime);
      final selectedTime = '${schedule['startTime']} - ${schedule['endTime']}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookAppointmentPage(
            patientId: patientId,
            patientName: patientName,
            doctorId: widget.doctorId,
            doctorName: doctorData?['fullname'] ?? 'Dr. Unknown',
            doctorSpecialty: doctorData?['specialization'] ?? 'General Practitioner',
            selectedDate: selectedDate,
            selectedTime: selectedTime,
            medicalCenterId: _getMedicalCenterId(),
            medicalCenterName: doctorData?['hospital'] ?? 'Medical Center',
            doctorFees: (doctorData?['fees'] ?? 0.0).toDouble(),
            scheduleId: scheduleId,
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Error loading your profile. Please try again.');
    }
  }

  String _getMedicalCenterId() {
    // Extract medical center ID from doctor data
    final medicalCenters = doctorData?['medicalCenters'];
    if (medicalCenters is List && medicalCenters.isNotEmpty) {
      final firstCenter = medicalCenters[0];
      if (firstCenter is Map<String, dynamic>) {
        return firstCenter['id'] ?? '';
      }
    }
    return '';
  }

  // Helper Methods
  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduleDay = DateTime(date.year, date.month, date.day);
    
    if (scheduleDay == today) {
      return 'Today (${date.day}/${date.month}/${date.year})';
    } else if (scheduleDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow (${date.day}/${date.month}/${date.year})';
    } else {
      return '${_getDayName(date.weekday)}, ${date.day}/${date.month}/${date.year}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  IconData _getAppointmentTypeIcon(String type) {
    switch (type) {
      case 'physical': return Icons.medical_services;
      case 'video': return Icons.video_call;
      case 'audio': return Icons.audiotrack;
      default: return Icons.calendar_today;
    }
  }

  void _showNoSchedulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Available Schedules'),
        content: const Text('This doctor does not have any confirmed schedules available at the moment. Please check back later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNoFutureSchedulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Upcoming Schedules'),
        content: const Text('This doctor does not have any upcoming schedules. All available slots are for past dates. Please check back later for new schedule updates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: const Color(0xFF18A3B6),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDoctorData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: doctorData == null
          ? const Center(child: Text('Doctor data not available'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF18A3B6).withOpacity(0.1),
                          Colors.grey[50]!,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildProfileImage(),
                        const SizedBox(height: 16),
                        Text(
                          'Dr. ${doctorData?['fullname'] ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctorData?['specialization'] ?? 'General Practitioner',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (doctorData?['fees'] != null && doctorData!['fees'] > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              'Consultation Fee: Rs. ${doctorData!['fees']}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  _buildProfessionalCard(),
                  _buildContactCard(),
                  
                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _fetchAndShowDoctorSchedules,
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Book Appointment'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF18A3B6),
                              side: const BorderSide(color: Color(0xFF18A3B6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}