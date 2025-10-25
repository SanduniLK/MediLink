import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/patient_screens/book_appointment_page.dart';
import 'package:intl/intl.dart';

class DoctorsListScreen extends StatefulWidget {
  const DoctorsListScreen({super.key});

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  List<Map<String, dynamic>> doctors = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDoctorsFromFirebase();
  }

  Future<void> _loadDoctorsFromFirebase() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      print('🔍 Loading doctors from Firebase...');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .where('role', isEqualTo: 'doctor')
          .get();

      print('✅ Found ${querySnapshot.docs.length} doctors in Firebase');

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          errorMessage = 'No doctors registered in the system yet';
        });
        return;
      }

      List<Map<String, dynamic>> doctorsList = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        String medicalCenterName = 'No Medical Center';
        String medicalCenterId = '';
        final medicalCenters = data['medicalCenters'];
        
        if (medicalCenters is List && medicalCenters.isNotEmpty) {
          final firstCenter = medicalCenters[0];
          if (firstCenter is Map<String, dynamic>) {
            medicalCenterName = firstCenter['name'] ?? 'Medical Center';
            medicalCenterId = firstCenter['id'] ?? '';
          }
        }

        doctorsList.add({
          'id': doc.id,
          'uid': data['uid'] ?? doc.id,
          'fullname': data['fullname'] ?? 'Dr. Unknown',
          'specialization': data['specialization'] ?? 'General Practitioner',
          'hospital': medicalCenterName,
          'medicalCenterId': medicalCenterId,
          'experience': data['experience'] ?? 'Not specified',
          'fees': (data['fees'] ?? 0.0).toDouble(),
          'medicalCenters': medicalCenters,
        });
      }

      setState(() {
        doctors = doctorsList;
      });

    } catch (e) {
      print('❌ Error loading doctors from Firebase: $e');
      setState(() {
        errorMessage = 'Failed to load doctors: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Doctors'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDoctorsFromFirebase,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty && doctors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.medical_services, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Doctors Available',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDoctorsFromFirebase,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${doctors.length} Doctor(s) Available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: ListView.builder(
                          itemCount: doctors.length,
                          itemBuilder: (context, index) {
                            final doctor = doctors[index];
                            return _buildDoctorCard(doctor);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF18A3B6),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          doctor['fullname'] ?? 'Dr. Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctor['specialization'] ?? 'General Practitioner',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(doctor['hospital']),
            if (doctor['experience'] != null && doctor['experience'] != 'Not specified')
              Text('Experience: ${doctor['experience']}'),
            if (doctor['fees'] != null && doctor['fees'] > 0)
              Text(
                'Fees: Rs. ${doctor['fees']}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _fetchAndShowAvailableSchedules(doctor);
        },
      ),
    );
  }

Future<void> _fetchAndShowAvailableSchedules(Map<String, dynamic> doctor) async {
  try {
    setState(() {
      isLoading = true;
    });

    print('🔍 Fetching schedules for doctor: ${doctor['fullname']}');
    print('👨‍⚕️ Doctor UID: ${doctor['uid']}');

    // Fetch confirmed schedules for this doctor
    final schedulesSnapshot = await FirebaseFirestore.instance
        .collection('doctorSchedules')
        .where('doctorId', isEqualTo: doctor['uid'])
        .where('status', isEqualTo: 'confirmed')
        .get();

    print('✅ Found ${schedulesSnapshot.docs.length} confirmed schedules');

    if (schedulesSnapshot.docs.isEmpty) {
      print('❌ No confirmed schedules found for this doctor');
      setState(() {
        isLoading = false;
      });
      _showNoSchedulesDialog();
      return;
    }

    // Get current date and time for comparison
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    print('📅 Current date: $currentDate');

    List<Map<String, dynamic>> availableSchedules = [];

    for (var doc in schedulesSnapshot.docs) {
      final data = doc.data();
      print('\n📋 Processing schedule: ${doc.id}');
      print('   📅 All fields: ${data.keys.join(', ')}');
      print('   📅 availableDate: ${data['availableDate']}');
      print('   📅 scheduleDate: ${data['scheduleDate']}');
      print('   📅 Has weeklySchedule: ${data['weeklySchedule'] != null}');
      
      // ALWAYS process as single date if availableDate or scheduleDate exists
      if (data['availableDate'] != null || data['scheduleDate'] != null) {
        print('   📅 This has DATE fields - processing as SINGLE DATE schedule');
        final singleSchedule = _processSingleDateSchedule(doc.id, data, doctor['fullname'], currentDate);
        if (singleSchedule != null) {
          availableSchedules.add(singleSchedule);
          print('   ✅ Added single date schedule: ${singleSchedule['date']}');
        }
      }
      // Only process as pure weekly schedule if NO date fields exist
      else if (data['weeklySchedule'] != null && data['weeklySchedule'] is List) {
        print('   📅 This is PURE WEEKLY schedule (no date fields)');
        final weeklySchedules = _processWeeklySchedule(doc.id, data, doctor['fullname']);
        availableSchedules.addAll(weeklySchedules);
      } else {
        print('   ❓ Unknown schedule type - skipping');
      }
    }

    // Sort schedules by date (earliest first)
    availableSchedules.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateA.compareTo(dateB);
    });

    print('\n📆 FINAL RESULT: ${availableSchedules.length} available schedules');
    for (var schedule in availableSchedules) {
      final date = schedule['date'] as DateTime;
      print('   📅 ${_getFormattedDate(date)} - ${schedule['startTime']} to ${schedule['endTime']}');
      print('   📅 Is Weekly: ${schedule['isWeekly']}');
      print('   📅 Original availableDate: ${schedule['originalAvailableDate']}');
    }

    setState(() {
      isLoading = false;
    });

    if (availableSchedules.isEmpty) {
      _showNoFutureSchedulesDialog();
    } else {
      _showScheduleSelectionDialog(doctor, availableSchedules);
    }

  } catch (e) {
    print('❌ Error fetching schedules: $e');
    print('Stack trace: ${e.toString()}');
    setState(() {
      isLoading = false;
    });
    _showErrorDialog('Failed to load available schedules: $e');
  }
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

Map<String, dynamic>? _processSingleDateSchedule(String scheduleId, Map<String, dynamic> data, String doctorName, DateTime currentDate) {
  // Handle date field - Check for availableDate FIRST, then scheduleDate as fallback
  DateTime? scheduleDate;
  
  // PRIORITY 1: Use availableDate (string format "2025-10-25")
  if (data['availableDate'] != null && data['availableDate'] is String) {
    final availableDateStr = data['availableDate'] as String;
    try {
      scheduleDate = DateFormat('yyyy-MM-dd').parse(availableDateStr);
      print('   ✅ Found availableDate: $availableDateStr -> $scheduleDate');
    } catch (e) {
      print('   ❌ Error parsing availableDate: $e');
    }
  }
  
  // PRIORITY 2: Fallback to scheduleDate (timestamp)
  if (scheduleDate == null && data['scheduleDate'] != null) {
    if (data['scheduleDate'] is Timestamp) {
      scheduleDate = (data['scheduleDate'] as Timestamp).toDate();
    } else if (data['scheduleDate'] is DateTime) {
      scheduleDate = data['scheduleDate'] as DateTime;
    }
    print('   ✅ Found scheduleDate: $scheduleDate');
  }

  if (scheduleDate == null) {
    print('   ❌ No date found, skipping');
    return null;
  }

  final scheduleDay = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
  final isFuture = scheduleDay.isAfter(currentDate.subtract(const Duration(days: 1)));
  
  print('   📆 Final schedule date: $scheduleDay, Is future: $isFuture');

  if (!isFuture) {
    print('   ❌ Schedule date is in the past, skipping');
    return null;
  }

  // Get time slots from weekly schedule for Saturday
  String startTime = '09:00';
  String endTime = '17:00';
  int slotDuration = 30;
  int maxAppointments = 10;

  // Get time slots from weekly schedule for the specific day
  if (data['weeklySchedule'] != null && data['weeklySchedule'] is List) {
    final weeklySchedule = data['weeklySchedule'] as List<dynamic>;
    final dayName = _getDayName(scheduleDate.weekday).toLowerCase();
    
    print('   🔍 Looking for time slots for day: $dayName');
    
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
              print('   ⏰ Found time slots for $dayName: $startTime - $endTime');
            }
          } else {
            print('   ⚠️ Day $dayName is available but has no time slots');
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
    print('   ⏰ Using default time slots: $startTime - $endTime');
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
    'hasWeeklyData': data['weeklySchedule'] != null,
    'originalAvailableDate': data['availableDate'], 
    'originalScheduleDate': data['scheduleDate'], 
  };
}

  void _showScheduleSelectionDialog(
  Map<String, dynamic> doctor, 
  List<Map<String, dynamic>> schedules
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Available Slots - Dr. ${doctor['fullname']}',style: TextStyle(color: Colors.blueGrey,fontWeight: FontWeight.bold),),
      content: SizedBox(
        width: double.maxFinite,
        child: schedules.isEmpty
            ? const Center(
                child: Text('No available schedules found'),
              )
            : ListView.builder(
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
                            Text("you can book only if have slots",style: TextStyle(color: Colors.blueAccent),)
                         
                        ],
                      ),
                      onTap: isAvailable ? () {
                        Navigator.pop(context);
                        _navigateToBookingPage(
                          doctor: doctor,
                          selectedDate: date,
                          selectedTime: '${schedule['startTime']} - ${schedule['endTime']}',
                          scheduleData: schedule,
                        );
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

  void _navigateToBookingPage({
  required Map<String, dynamic> doctor,
  required String selectedDate,
  required String selectedTime,
  required Map<String, dynamic> scheduleData,
}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorDialog('Please log in to book an appointment');
      return;
    }

    // Fetch actual patient data
    final patientId = currentUser.uid;
    String patientName = 'Patient'; // Default fallback

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

    final scheduleId = scheduleData['scheduleId']?.toString() ?? '';
    
    print('👤 Patient booking: $patientName ($patientId)');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentPage(
          patientId: patientId, // Actual patient ID
          patientName: patientName, // Actual patient name
          doctorId: doctor['uid'] ?? doctor['id'] ?? '',
          doctorName: doctor['fullname'] ?? 'Dr. Unknown',
          doctorSpecialty: doctor['specialization'] ?? 'General Practitioner',
          selectedDate: selectedDate,
          selectedTime: selectedTime,
          medicalCenterId: doctor['medicalCenterId'] ?? '',
          medicalCenterName: doctor['hospital'] ?? 'Medical Center',
          doctorFees: (doctor['fees'] ?? 0.0).toDouble(),
          scheduleId: scheduleId,
        ),
      ),
    );
  } catch (e) {
    print('❌ Error fetching patient data: $e');
    _showErrorDialog('Error loading your profile. Please try again.');
  }
}
}