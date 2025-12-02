import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/patient_screens/book_appointment_page.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/patient_screens/doctor_profile_screen.dart';

class DoctorsListScreen extends StatefulWidget {
  const DoctorsListScreen({super.key});

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  List<Map<String, dynamic>> doctors = [];
  List<Map<String, dynamic>> filteredDoctors = [];
  bool isLoading = true;
  String errorMessage = '';

  // Search and Filter variables
  final TextEditingController searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSpecialization = 'All';
  String _selectedHospital = 'All';
  bool _showFilters = false;

  // Available specializations and hospitals for filters
  List<String> specializations = ['All'];
  List<String> hospitals = ['All'];

  @override
  void initState() {
    super.initState();
    _loadDoctorsFromFirebase();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(doctors);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((doctor) {
        final name = doctor['fullname']?.toString().toLowerCase() ?? '';
        final specialization = doctor['specialization']?.toString().toLowerCase() ?? '';
        final hospital = doctor['hospital']?.toString().toLowerCase() ?? '';
        final experience = doctor['experience']?.toString().toLowerCase() ?? '';

        return name.contains(_searchQuery) ||
            specialization.contains(_searchQuery) ||
            hospital.contains(_searchQuery) ||
            experience.contains(_searchQuery);
      }).toList();
    }

    // Apply specialization filter
    if (_selectedSpecialization != 'All') {
      result = result.where((doctor) {
        return doctor['specialization'] == _selectedSpecialization;
      }).toList();
    }

    // Apply hospital filter
    if (_selectedHospital != 'All') {
      result = result.where((doctor) {
        return doctor['hospital'] == _selectedHospital;
      }).toList();
    }

    setState(() {
      filteredDoctors = result;
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedSpecialization = 'All';
      _selectedHospital = 'All';
      searchController.clear();
      _applyFilters();
    });
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
      Set<String> specializationSet = {'All'};
      Set<String> hospitalSet = {'All'};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Get all medical centers for this doctor
        List<Map<String, dynamic>> medicalCentersList = [];
        final medicalCenters = data['medicalCenters'];
        
        if (medicalCenters is List && medicalCenters.isNotEmpty) {
          for (var center in medicalCenters) {
            if (center is Map<String, dynamic>) {
              medicalCentersList.add({
                'id': center['id'] ?? '',
                'name': center['name'] ?? 'Medical Center',
              });
              hospitalSet.add(center['name'] ?? 'Medical Center');
            }
          }
        } else {
          // Fallback to single hospital field
          medicalCentersList.add({
            'id': '',
            'name': data['hospital'] ?? 'Medical Center',
          });
          hospitalSet.add(data['hospital'] ?? 'Medical Center');
        }

        final doctorData = {
          'id': doc.id,
          'uid': data['uid'] ?? doc.id,
          'fullname': data['fullname'] ?? 'Dr. Unknown',
          'specialization': data['specialization'] ?? 'General Practitioner',
          'hospital': medicalCentersList.isNotEmpty 
              ? medicalCentersList[0]['name'] 
              : 'Medical Center', // First medical center for display
          'medicalCenters': medicalCentersList, // All medical centers
          'experience': data['experience'] ?? 'Not specified',
          'fees': (data['fees'] ?? 0.0).toDouble(),
          'profileImage': data['profileImage'],
        };

        doctorsList.add(doctorData);

        // Add to filter options
        specializationSet.add(doctorData['specialization']);
      }

      setState(() {
        doctors = doctorsList;
        filteredDoctors = doctorsList;
        specializations = specializationSet.toList();
        hospitals = hospitalSet.toList();
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
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
            onPressed: _toggleFilters,
            tooltip: 'Filter doctors',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search doctors by name, specialty, hospital...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      searchController.clear();
                    },
                  ) : null,
                ),
              ),
            ),
          ),

          // Filter Options
          if (_showFilters) _buildFilterSection(),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredDoctors.length} Doctor(s) Found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_showFilters || _searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text(
                      'Reset Filters',
                      style: TextStyle(color: Color(0xFF18A3B6)),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Doctors List
          Expanded(
            child: isLoading
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
                    : filteredDoctors.isEmpty
                        ? _buildNoResultsWidget()
                        : ListView.builder(
                            itemCount: filteredDoctors.length,
                            itemBuilder: (context, index) {
                              final doctor = filteredDoctors[index];
                              return _buildDoctorCard(doctor);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Doctors',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFilterDropdown(
            label: 'Specialization',
            value: _selectedSpecialization,
            items: specializations,
            onChanged: (value) {
              setState(() {
                _selectedSpecialization = value!;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 12),
          _buildFilterDropdown(
            label: 'Hospital',
            value: _selectedHospital,
            items: hospitals,
            onChanged: (value) {
              setState(() {
                _selectedHospital = value!;
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Doctors Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18A3B6),
            ),
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
  // Get all medical centers for this doctor
  final medicalCenters = doctor['medicalCenters'] as List<dynamic>? ?? [];
  final hasMultipleCenters = medicalCenters.length > 1;
  
  // Extract medical center names
  List<String> centerNames = [];
  for (var center in medicalCenters) {
    if (center is Map<String, dynamic>) {
      centerNames.add(center['name'] ?? 'Medical Center');
    }
  }
  
  // If no medical centers found, use the hospital field as fallback
  if (centerNames.isEmpty && doctor['hospital'] != null) {
    centerNames.add(doctor['hospital']);
  }
  
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    elevation: 2,
    child: ListTile(
      leading: _buildClickableDoctorAvatar(doctor),
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
          
          // Show medical center names
          if (centerNames.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasMultipleCenters)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '${medicalCenters.length} Medical Centers:',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                
                // Show all medical center names
                ...centerNames.map((centerName) {
                  return Text(
                    '• $centerName',
                    style: TextStyle(
                      fontSize: hasMultipleCenters ? 12 : 14,
                      color: hasMultipleCenters ? Colors.grey[700] : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }).toList(),
              ],
            ),
          
          if (doctor['experience'] != null && doctor['experience'] != 'Not specified')
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'Experience: ${doctor['experience']} years',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          
          if (doctor['fees'] != null && doctor['fees'] > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'Fees: Rs. ${doctor['fees']}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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

  Widget _buildClickableDoctorAvatar(Map<String, dynamic> doctor) {
    final String? profileImageUrl = doctor['profileImage'];
    
    return GestureDetector(
      onTap: () {
        _viewDoctorProfile(doctor);
      },
      child: CircleAvatar(
        radius: 25,
        backgroundColor: profileImageUrl != null && profileImageUrl.isNotEmpty
            ? Colors.grey[200]
            : const Color(0xFF18A3B6),
        backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
            ? NetworkImage(profileImageUrl)
            : null,
        onBackgroundImageError: profileImageUrl != null && profileImageUrl.isNotEmpty
            ? (exception, stackTrace) {}
            : null,
        child: profileImageUrl != null && profileImageUrl.isNotEmpty
            ? null
            : const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  void _viewDoctorProfile(Map<String, dynamic> doctor) {
    final String doctorId = doctor['uid'] ?? '';
    
    if (doctorId.isEmpty) {
      print('❌ Doctor ID is empty');
      return;
    }

    print('👨‍⚕️ Navigating to doctor profile: ${doctor['fullname']}');
    print('   🆔 Doctor ID: $doctorId');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorProfileScreen(
          doctorId: doctorId,
          doctorData: doctor,
        ),
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

      // Get doctor's medical centers
      final medicalCenters = doctor['medicalCenters'] as List<dynamic>? ?? [];
      print('🏥 Doctor has ${medicalCenters.length} medical centers');

      if (medicalCenters.isEmpty) {
        print('❌ No medical centers found for doctor');
        setState(() { isLoading = false; });
        _showNoMedicalCentersDialog();
        return;
      }

      // Fetch schedules for each medical center
      List<Map<String, dynamic>> allSchedules = [];

      for (var center in medicalCenters) {
        if (center is Map<String, dynamic>) {
          final centerId = center['id'] ?? '';
          final centerName = center['name'] ?? 'Medical Center';
          
          print('📋 Processing medical center: $centerName (ID: $centerId)');

          final schedulesSnapshot = await FirebaseFirestore.instance
              .collection('doctorSchedules')
              .where('doctorId', isEqualTo: doctor['uid'])
              .where('medicalCenterId', isEqualTo: centerId)
              .where('status', isEqualTo: 'confirmed')
              .get();

          print('   ✅ Found ${schedulesSnapshot.docs.length} schedules for this center');

          // Get current date for comparison
          final now = DateTime.now();
          final currentDate = DateTime(now.year, now.month, now.day);

          for (var doc in schedulesSnapshot.docs) {
            final data = doc.data();
            print('   📅 Processing schedule: ${doc.id}');

            // Process single date schedule
            final singleSchedule = _processSingleDateSchedule(
              doc.id, 
              data, 
              doctor['fullname'], 
              currentDate,
              centerName,
              centerId
            );
            
            if (singleSchedule != null) {
              allSchedules.add(singleSchedule);
              print('   ✅ Added schedule for $centerName: ${singleSchedule['date']}');
            }

            // Process weekly schedule if available
            if (data['weeklySchedule'] != null && data['weeklySchedule'] is List) {
              final weeklySchedules = _processWeeklySchedule(
                doc.id, 
                data, 
                doctor['fullname'],
                centerName,
                centerId
              );
              allSchedules.addAll(weeklySchedules);
              print('   📅 Added ${weeklySchedules.length} weekly schedules for $centerName');
            }
          }
        }
      }

      // Sort schedules by date (earliest first)
      allSchedules.sort((a, b) {
        final dateA = a['date'] as DateTime;
        final dateB = b['date'] as DateTime;
        return dateA.compareTo(dateB);
      });

      print('\n📊 FINAL RESULT: ${allSchedules.length} available schedules across ${medicalCenters.length} medical centers');

      setState(() {
        isLoading = false;
      });

      if (allSchedules.isEmpty) {
        _showNoSchedulesDialog();
      } else {
        _showScheduleSelectionDialog(doctor, allSchedules);
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

  List<Map<String, dynamic>> _processWeeklySchedule(
    String scheduleId, 
    Map<String, dynamic> data, 
    String doctorName,
    String medicalCenterName,
    String medicalCenterId
  ) {
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
                  'medicalCenterName': medicalCenterName,
                  'medicalCenterId': medicalCenterId,
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

  Map<String, dynamic>? _processSingleDateSchedule(
    String scheduleId, 
    Map<String, dynamic> data, 
    String doctorName, 
    DateTime currentDate,
    String medicalCenterName,
    String medicalCenterId
  ) {
    DateTime? scheduleDate;
    
    // Check for availableDate
    if (data['availableDate'] != null && data['availableDate'] is String) {
      final availableDateStr = data['availableDate'] as String;
      try {
        scheduleDate = DateFormat('yyyy-MM-dd').parse(availableDateStr);
      } catch (e) {
        print('   ❌ Error parsing availableDate: $e');
      }
    }
    
    // Fallback to scheduleDate
    if (scheduleDate == null && data['scheduleDate'] != null) {
      if (data['scheduleDate'] is Timestamp) {
        scheduleDate = (data['scheduleDate'] as Timestamp).toDate();
      } else if (data['scheduleDate'] is DateTime) {
        scheduleDate = data['scheduleDate'] as DateTime;
      }
    }

    if (scheduleDate == null) {
      return null;
    }

    final scheduleDay = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
    final isFuture = scheduleDay.isAfter(currentDate.subtract(const Duration(days: 1)));
    
    if (!isFuture) {
      return null;
    }

    // Get time slots
    String startTime = '09:00';
    String endTime = '17:00';
    int slotDuration = 30;
    int maxAppointments = 10;

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
      'medicalCenterName': medicalCenterName,
      'medicalCenterId': medicalCenterId,
      'isWeekly': false,
      'hasWeeklyData': data['weeklySchedule'] != null,
    };
  }

  void _showScheduleSelectionDialog(
    Map<String, dynamic> doctor, 
    List<Map<String, dynamic>> schedules
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Available Sessions - Dr. ${doctor['fullname']}',
          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: schedules.isEmpty
              ? const Center(child: Text('No available schedules found'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    final date = schedule['date'] is DateTime 
                        ? _getFormattedDate(schedule['date'] as DateTime)
                        : 'Date not specified';
                    
                    final availableSlots = schedule['availableSlots'] ?? 0;
                    final isAvailable = availableSlots > 0;
                    final medicalCenter = schedule['medicalCenterName'] ?? 'Medical Center';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isAvailable ? null : Colors.grey[100],
                      child: ListTile(
                        leading: Icon(
                          _getAppointmentTypeIcon(schedule['appointmentType']),
                          color: isAvailable ? const Color(0xFF18A3B6) : Colors.grey,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? Colors.black : Colors.grey,
                              ),
                            ),
                            Text(
                              medicalCenter,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey[600],
                              ),
                            ),
                          ],
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
                              ),
                            Text(
                              'Available Slots: $availableSlots',
                              style: TextStyle(
                                fontSize: 12,
                                color: isAvailable ? Colors.green[700] : Colors.grey,
                              ),
                            ),
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

  void _showNoMedicalCentersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Medical Centers'),
        content: const Text('This doctor is not associated with any medical centers. Please contact the administrator.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

      final patientId = currentUser.uid;
      String patientName = 'Patient';

      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        patientName = patientDoc.data()!['fullname'] ?? 'Patient';
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .get();
        
        if (userDoc.exists) {
          patientName = userDoc.data()!['fullname'] ?? 'Patient';
        }
      }

      final scheduleId = scheduleData['scheduleId']?.toString() ?? '';
      final medicalCenterId = scheduleData['medicalCenterId'] ?? '';
      final medicalCenterName = scheduleData['medicalCenterName'] ?? 'Medical Center';

      print('👤 Patient booking: $patientName ($patientId)');
      print('🏥 Medical Center: $medicalCenterName ($medicalCenterId)');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookAppointmentPage(
            patientId: patientId,
            patientName: patientName,
            doctorId: doctor['uid'] ?? doctor['id'] ?? '',
            doctorName: doctor['fullname'] ?? 'Dr. Unknown',
            doctorSpecialty: doctor['specialization'] ?? 'General Practitioner',
            selectedDate: selectedDate,
            selectedTime: selectedTime,
            medicalCenterId: medicalCenterId,
            medicalCenterName: medicalCenterName,
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