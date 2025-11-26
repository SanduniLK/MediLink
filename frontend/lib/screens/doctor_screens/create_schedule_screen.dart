import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/doctor_schedule_model.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/doctor_schedule_service.dart';

class CreateScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  
  const CreateScheduleScreen({super.key, required this.doctor});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String _appointmentType = 'physical';
  List<String> _selectedTelemedicineTypes = [];
  int _slotDuration = 30;
  int _maxAppointments = 10;
  String? _selectedMedicalCenter;
  List<Map<String, dynamic>> _medicalCenters = [];
  bool isLoading = false;
  bool _loadingCenters = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMedicalCenters();
  }

Future<void> _loadMedicalCenters() async {
  try {
    setState(() {
      _loadingCenters = true;
      _errorMessage = '';
      _medicalCenters = [];
    });

    print('🚀 Loading medical centers directly from doctor document...');

    final doctorUid = widget.doctor['uid'] ?? widget.doctor['id'] ?? '';
    if (doctorUid.isEmpty) {
      setState(() {
        _errorMessage = 'Doctor profile not properly loaded.';
      });
      return;
    }

    // Fetch doctor document
    final doctorDoc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(doctorUid)
        .get();

    if (!doctorDoc.exists) {
      setState(() {
        _errorMessage = 'Doctor record not found.';
      });
      return;
    }

    final data = doctorDoc.data()!;
    final medicalCentersArray = data['medicalCenters'] as List<dynamic>? ?? [];

    if (medicalCentersArray.isEmpty) {
      setState(() {
        _errorMessage =
            'You are not registered with any medical centers. Please contact the administrator.';
      });
      return;
    }

    print('✅ Found ${medicalCentersArray.length} medical centers in array: $medicalCentersArray');

    final List<Map<String, dynamic>> centers = [];

    for (var i = 0; i < medicalCentersArray.length; i++) {
      final item = medicalCentersArray[i];
      print('   Processing item $i: $item (${item.runtimeType})');
      
      if (item is Map<String, dynamic>) {
        // Item is a map with medical center details
        centers.add({
          'id': item['id'] ?? '',
          'name': item['name'] ?? 'Unknown Medical Center',
          'specialization': item['specialization'] ?? '',
          'regNumber': item['regNumber'] ?? '',
          'melicenseNumber': item['melicenseNumber'] ?? '',
          'address': item['address'] ?? '',
          'phone': item['mobile'] ?? '',
        });
      } else if (item is String) {
        // Item is just a string (medical center name or ID)
        // We need to search for this medical center in the medical_centers collection
        print('   🔍 Searching for medical center with name/ID: "$item"');
        
        try {
          // Search by name first
          final querySnapshot = await FirebaseFirestore.instance
              .collection('medical_centers')
              .where('name', isEqualTo: item)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            // Found by name
            final doc = querySnapshot.docs.first;
            final centerData = doc.data();
            centers.add({
              'id': doc.id,
              'name': centerData['name'] ?? item,
              'specialization': centerData['specialization'] ?? '',
              'regNumber': centerData['regNumber'] ?? '',
              'melicenseNumber': centerData['melicenseNumber'] ?? '',
              'address': centerData['address'] ?? '',
              'phone': centerData['mobile'] ?? centerData['phone'] ?? '',
            });
            print('   ✅ Found medical center by name: ${centerData['name']}');
          } else {
            // Try searching by ID (using the string as document ID)
            final doc = await FirebaseFirestore.instance
                .collection('medical_centers')
                .doc(item)
                .get();

            if (doc.exists) {
              final centerData = doc.data()!;
              centers.add({
                'id': doc.id,
                'name': centerData['name'] ?? item,
                'specialization': centerData['specialization'] ?? '',
                'regNumber': centerData['regNumber'] ?? '',
                'melicenseNumber': centerData['melicenseNumber'] ?? '',
                'address': centerData['address'] ?? '',
                'phone': centerData['mobile'] ?? centerData['phone'] ?? '',
              });
              print('   ✅ Found medical center by ID: ${centerData['name']}');
            } else {
              // If not found in database, use the string as name and generate an ID
              centers.add({
                'id': 'temp_${item.hashCode}',
                'name': item,
                'specialization': '',
                'regNumber': '',
                'melicenseNumber': '',
                'address': '',
                'phone': '',
              });
              print('   ⚠️ Using temporary medical center: $item');
            }
          }
        } catch (e) {
          print('   💥 Error processing medical center "$item": $e');
          // Add as temporary center anyway
          centers.add({
            'id': 'temp_${item.hashCode}',
            'name': item,
            'specialization': '',
            'regNumber': '',
            'melicenseNumber': '',
            'address': '',
            'phone': '',
          });
        }
      }
    }

    // Remove duplicates based on ID
    final uniqueCenters = centers.fold<Map<String, Map<String, dynamic>>>(
      {}, 
      (map, center) {
        map[center['id']] = center;
        return map;
      },
    ).values.toList();

    setState(() {
      _medicalCenters = uniqueCenters;
      if (uniqueCenters.isNotEmpty) {
        _selectedMedicalCenter = uniqueCenters.first['id'];
      }
    });

    print('🎯 Successfully loaded ${uniqueCenters.length} centers:');
    for (var center in uniqueCenters) {
      print('   - ${center['name']} (${center['id']})');
    }

  } catch (e) {
    print('💥 Error loading medical centers: $e');
    setState(() {
      _errorMessage = 'Error loading medical centers: $e';
    });
  } finally {
    setState(() {
      _loadingCenters = false;
    });
  }
}

  Future<void> _processDoctorRequests(List<QueryDocumentSnapshot> requests) async {
    final List<Map<String, dynamic>> centers = [];
    
    for (var request in requests) {
      final requestData = request.data() as Map<String, dynamic>;
      final medicalCenterId = requestData['medicalCenterId'];
      final status = requestData['status'] ?? 'pending';
      
      if (medicalCenterId != null && medicalCenterId is String) {
        print('🔍 Fetching medical center for request: $medicalCenterId (Status: $status)');
        
        try {
          final medicalCenterDoc = await FirebaseFirestore.instance
              .collection('medical_centers')
              .doc(medicalCenterId)
              .get();

          if (medicalCenterDoc.exists) {
            final data = medicalCenterDoc.data()!;
            centers.add({
              'id': medicalCenterId,
              'name': data['name'] ?? 'Unknown Medical Center',
              'email': data['email'] ?? '',
              'specialization': data['specialization'] ?? '',
              'address': data['address'] ?? '',
              'adminId': data['adminId'] ?? data['uid'] ?? '',
              'phone': data['phone'] ?? data['mobile'] ?? '',
              'regNumber': data['regNumber'] ?? '',
              'uid': data['uid'] ?? '',
              'requestStatus': status,
            });
            print('✅ Added medical center: ${data['name']} (Status: $status)');
          }
        } catch (e) {
          print('💥 Error fetching medical center $medicalCenterId: $e');
        }
      }
    }

    if (centers.isNotEmpty) {
      print('🎯 SUCCESS: Loaded ${centers.length} medical centers from requests');
      setState(() {
        _medicalCenters = centers;
        if (centers.isNotEmpty) {
          _selectedMedicalCenter = centers.first['id'] as String?;
        }
      });
    } else {
      setState(() {
        _errorMessage = 'No approved medical centers found. You may have pending requests.';
      });
    }
  }

  Future<void> _processMedicalCentersFromArray(List<dynamic> medicalCentersArray) async {
    final List<Map<String, dynamic>> centers = [];
    
    print('🔍 Processing ${medicalCentersArray.length} medical centers from array...');
    
    for (var i = 0; i < medicalCentersArray.length; i++) {
      final item = medicalCentersArray[i];
      print('   Processing item $i: $item (${item.runtimeType})');
      
      String? centerId;
      String? centerName;
      
      if (item is Map<String, dynamic>) {
        // Extract medical center ID and name
        centerId = item['id'] as String? ?? item['medicalCenterId'] as String?;
        centerName = item['name'] as String? ?? item['medicalCenterName'] as String?;
        
        if (centerId != null) {
          print('   🔍 Fetching details for medical center ID: $centerId');
          try {
            final medicalCenterDoc = await FirebaseFirestore.instance
                .collection('medical_centers')
                .doc(centerId)
                .get();

            if (medicalCenterDoc.exists) {
              final data = medicalCenterDoc.data()!;
              centers.add({
                'id': centerId,
                'name': data['name'] ?? centerName ?? 'Unknown Medical Center',
                'email': data['email'] ?? '',
                'specialization': data['specialization'] ?? '',
                'address': data['address'] ?? '',
                'adminId': data['adminId'] ?? data['uid'] ?? '',
                'phone': data['phone'] ?? data['mobile'] ?? '',
                'regNumber': data['regNumber'] ?? '',
                'uid': data['uid'] ?? '',
              });
              print('   ✅ Loaded: ${data['name']}');
            } else {
              print('   ❌ Medical center not found: $centerId');
            }
          } catch (e) {
            print('   💥 Error fetching medical center $centerId: $e');
          }
        }
      } else if (item is String) {
        // Item is just medical center ID as string
        centerId = item;
        print('   🔍 Fetching details for medical center ID: $centerId');
        await _addMedicalCenterById(centerId, centers);
      }
    }
    
    if (centers.isEmpty) {
      print('❌ No valid medical centers found in array');
      setState(() {
        _errorMessage = 'No valid medical center data found in your profile.';
      });
      return;
    }
    
    print('🎯 SUCCESS: Loaded ${centers.length} medical centers from profile');
    setState(() {
      _medicalCenters = centers;
      if (centers.isNotEmpty) {
        _selectedMedicalCenter = centers.first['id'] as String?;
      }
    });
  }

  Future<void> _processMedicalCenterDocs(List<QueryDocumentSnapshot> docs) async {
    final centers = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      print('🏥 Processing medical center: ${data['name']}');
      
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unknown Medical Center',
        'email': data['email'] ?? '',
        'specialization': data['specialization'] ?? '',
        'address': data['address'] ?? '',
        'adminId': data['adminId'] ?? data['uid'] ?? '',
        'phone': data['phone'] ?? data['mobile'] ?? '',
        'regNumber': data['regNumber'] ?? '',
        'uid': data['uid'] ?? '',
      };
    }).toList();

    print('🎯 SUCCESS: Loaded ${centers.length} medical centers');
    for (var center in centers) {
      print('   - ${center['name']} (${center['id']})');
    }

    setState(() {
      _medicalCenters = centers;
      if (centers.isNotEmpty) {
        _selectedMedicalCenter = centers.first['id'] as String?;
        print('✅ Auto-selected: ${centers.first['name']}');
      }
    });
  }

  Future<void> _addMedicalCenterById(String centerId, List<Map<String, dynamic>> centers) async {
    try {
      final medicalCenterDoc = await FirebaseFirestore.instance
          .collection('medical_centers')
          .doc(centerId)
          .get();
      
      if (medicalCenterDoc.exists) {
        final data = medicalCenterDoc.data()!;
        centers.add({
          'id': centerId,
          'name': data['name'] ?? 'Unknown Medical Center',
          'email': data['email'] ?? '',
          'specialization': data['specialization'] ?? '',
          'address': data['address'] ?? '',
          'adminId': data['adminId'] ?? data['uid'] ?? '',
          'phone': data['phone'] ?? data['mobile'] ?? '',
          'regNumber': data['regNumber'] ?? '',
          'uid': data['uid'] ?? '',
        });
        print('   ✅ Loaded: ${data['name']}');
      } else {
        print('   ❌ Medical center not found: $centerId');
      }
    } catch (e) {
      print('   💥 Error fetching medical center $centerId: $e');
    }
  }

  Future<void> _createScheduleSlot() async {
    if (_selectedMedicalCenter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medical center')),
      );
      return;
    }

    // MARK: Validate telemedicine types
    if (_appointmentType == 'telemedicine' && _selectedTelemedicineTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one telemedicine type')),
      );
      return;
    }

    try {
      setState(() { isLoading = true; });

      // Get selected medical center data
      final selectedCenter = _medicalCenters.firstWhere(
        (center) => center['id'] == _selectedMedicalCenter,
      );

      // Get doctor info
      final doctorId = widget.doctor['uid'] ?? widget.doctor['id'] ?? '';
      final doctorName = widget.doctor['fullname'] ?? widget.doctor['name'] ?? 'Unknown Doctor';
      final medicalCenterAdminId = selectedCenter['adminId'] ?? '';

      // Create a single day schedule for the selected date
      final dayName = DateFormat('EEEE').format(_selectedDate).toLowerCase();
      
      final dailySchedule = DailySchedule(
        day: dayName,
        available: true,
        timeSlots: [
          TimeSlot(
            startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
            endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
            slotDuration: _slotDuration,
          ),
        ],
      );

      // Create weekly schedule with only the selected day available
      final weeklySchedule = [
        DailySchedule(day: 'monday', available: dayName == 'monday', timeSlots: dayName == 'monday' ? dailySchedule.timeSlots : []),
        DailySchedule(day: 'tuesday', available: dayName == 'tuesday', timeSlots: dayName == 'tuesday' ? dailySchedule.timeSlots : []),
        DailySchedule(day: 'wednesday', available: dayName == 'wednesday', timeSlots: dayName == 'wednesday' ? dailySchedule.timeSlots : []),
        DailySchedule(day: 'thursday', available: dayName == 'thursday', timeSlots: dayName == 'thursday' ? dailySchedule.timeSlots : []),
        DailySchedule(day: 'friday', available: dayName == 'friday', timeSlots: dayName == 'friday' ? dailySchedule.timeSlots : []),
        DailySchedule(day: 'saturday', available: dayName == 'saturday', timeSlots: dayName == 'saturday' ? dailySchedule.timeSlots : []),
        DailySchedule(day: 'sunday', available: dayName == 'sunday', timeSlots: dayName == 'sunday' ? dailySchedule.timeSlots : []),
      ];

      print('💾 Saving schedule for:');
      print('   Doctor: $doctorName ($doctorId)');
      print('   Medical Center: ${selectedCenter['name']} ($_selectedMedicalCenter)');
      print('   Date: ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}');
      print('   Time: ${_startTime.format(context)} - ${_endTime.format(context)}');
      print('   Appointment Type: $_appointmentType');
      // MARK: Added telemedicine types logging
      if (_appointmentType == 'telemedicine') {
        print('   Telemedicine Types: $_selectedTelemedicineTypes');
      }

      // Save using your DoctorScheduleService
      await DoctorScheduleService.saveSchedule(
        doctorId: doctorId,
        doctorName: doctorName,
        medicalCenterId: _selectedMedicalCenter!,
        medicalCenterName: selectedCenter['name'],
        medicalCenterAdminId: medicalCenterAdminId,
        weeklySchedule: weeklySchedule,
        appointmentType: _appointmentType,
        telemedicineTypes: _appointmentType == 'telemedicine' ? _selectedTelemedicineTypes : [],
        scheduleDate: _selectedDate,
       
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule created successfully! Waiting for admin approval.'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);

    } catch (e) {
      print('💥 Error creating schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating schedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() { isLoading = false; });
    }
  }

  // Date and Time Selection Methods
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() { _startTime = picked; });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() { _endTime = picked; });
    }
  }

  // MARK: Added telemedicine type section methods
  Widget _buildAppointmentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Appointment Type Dropdown
        _buildDropdown(
          'Appointment Type',
          _appointmentType,
          ['physical', 'telemedicine'],
          (value) => setState(() { 
            _appointmentType = value!;
            // Clear telemedicine types when switching to physical
            if (_appointmentType == 'physical') {
              _selectedTelemedicineTypes.clear();
            }
          }),
        ),
        
        // Telemedicine Subtypes (only show when telemedicine is selected)
        if (_appointmentType == 'telemedicine') ...[
          const SizedBox(height: 16),
          _buildTelemedicineTypeSection(),
        ],
      ],
    );
  }

  // MARK: Added telemedicine type selection section
  Widget _buildTelemedicineTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Telemedicine Type',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Audio Option
              _buildTelemedicineTypeOption(
                'Audio Call',
                'audio',
                'Voice-only consultation',
                Icons.audiotrack,
              ),
              const SizedBox(height: 12),
              // Video Option
              _buildTelemedicineTypeOption(
                'Video Call',
                'video',
                'Video consultation',
                Icons.videocam,
              ),
            ],
          ),
        ),
        // Validation message
        if (_appointmentType == 'telemedicine' && _selectedTelemedicineTypes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              'Please select at least one telemedicine type',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // MARK: Added individual telemedicine type option
  Widget _buildTelemedicineTypeOption(String title, String value, String subtitle, IconData icon) {
    final isSelected = _selectedTelemedicineTypes.contains(value);
    
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTelemedicineTypes.remove(value);
          } else {
            _selectedTelemedicineTypes.add(value);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18A3B6).withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF18A3B6) : Colors.grey,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Custom Radio Button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF18A3B6) : Colors.grey,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF18A3B6) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            // Icon
            Icon(icon, color: const Color(0xFF18A3B6)),
            const SizedBox(width: 12),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF18A3B6) : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? const Color(0xFF18A3B6).withOpacity(0.8) : Colors.grey,
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

  @override
  Widget build(BuildContext context) {
    final doctorName = widget.doctor['fullname'] ?? widget.doctor['name'] ?? 'Unknown Doctor';
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Schedule Slot'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMedicalCenters,
            tooltip: 'Reload Medical Centers',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF18A3B6),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Dr."+doctorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                           
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Medical Center Selection
              _buildMedicalCenterSection(),
              
              const SizedBox(height: 16),
              
              // Date Selection
              _buildFormField(
                'Date',
                '${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}',
                _selectDate,
                Icons.calendar_today,
              ),
              
              const SizedBox(height: 16),
              
              // Time Selection
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      'Start Time',
                      _startTime.format(context),
                      _selectStartTime,
                      Icons.access_time,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      'End Time',
                      _endTime.format(context),
                      _selectEndTime,
                      Icons.access_time,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // MARK: Updated Appointment Type section
              _buildAppointmentTypeSection(),
              
              const SizedBox(height: 16),
              
              
              
              const SizedBox(height: 16),
              
              // Max Appointments
              _buildSlider(
                'Max Appointments',
                _maxAppointments,
                1,
                50,
                49,
                (value) => setState(() { _maxAppointments = value.round(); }),
              ),
              
              const SizedBox(height: 30),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isLoading || _loadingCenters || _selectedMedicalCenter == null) 
                      ? null 
                      : _createScheduleSlot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18A3B6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'CREATE SCHEDULE SLOT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalCenterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Medical Center',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            if (_loadingCenters)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (_errorMessage.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        
        if (_loadingCenters)
          const Center(child: CircularProgressIndicator()),
        
        if (!_loadingCenters && _medicalCenters.isEmpty && _errorMessage.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_hospital, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  'No medical centers available',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please contact administrator to register with a medical center',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        
        if (!_loadingCenters && _medicalCenters.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _medicalCenters.map((center) {
                return _buildMedicalCenterItem(center);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMedicalCenterItem(Map<String, dynamic> center) {
    final isSelected = _selectedMedicalCenter == center['id'];
    final requestStatus = center['requestStatus'] as String?;
    final isPending = requestStatus == 'pending';
    
    return InkWell(
      onTap: isPending ? null : () {
        setState(() {
          _selectedMedicalCenter = center['id'] as String?;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18A3B6).withOpacity(0.1) : 
                 isPending ? Colors.grey.withOpacity(0.1) : Colors.transparent,
          border: Border(
            bottom: _medicalCenters.indexOf(center) < _medicalCenters.length - 1
                ? const BorderSide(color: Colors.grey)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPending ? Colors.grey : 
                         isSelected ? const Color(0xFF18A3B6) : Colors.grey,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF18A3B6) : Colors.transparent,
              ),
              child: isSelected && !isPending
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : isPending
                      ? const Icon(Icons.schedule, size: 12, color: Colors.grey)
                      : null,
            ),
            
            const SizedBox(width: 16),
            
            // Medical center icon
            Icon(
              Icons.local_hospital,
              color: isPending ? Colors.grey :
                     isSelected ? const Color(0xFF18A3B6) : Colors.grey,
              size: 32,
            ),
            
            const SizedBox(width: 12),
            
            // Medical center details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    center['name']?.toString() ?? 'Unknown Center',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isPending ? Colors.grey :
                             isSelected ? const Color(0xFF18A3B6) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (center['specialization']?.toString().isNotEmpty ?? false)
                    Text(
                      center['specialization']?.toString() ?? '',
                      style: TextStyle(
                        color: isPending ? Colors.grey : 
                               isSelected ? const Color(0xFF18A3B6).withOpacity(0.8) : Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  if (isPending)
                    Text(
                      'Pending Approval',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFormField(String label, String value, VoidCallback onTap, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF18A3B6)),
                const SizedBox(width: 12),
                Expanded(child: Text(value)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item[0].toUpperCase() + item.substring(1)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

 Widget _buildSlider(String label, int value, double min, double max, int divisions, ValueChanged<double> onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      const SizedBox(height: 8),
      Slider(
        value: value.toDouble(),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        activeColor: const Color(0xFF18A3B6),
      ),
    ],
  );
}
}