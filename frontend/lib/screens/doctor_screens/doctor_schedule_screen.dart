import 'package:flutter/material.dart';

import 'package:frontend/model/doctor_schedule_model.dart';
import 'package:frontend/model/medical_center_model.dart';
import 'package:frontend/services/doctor_schedule_service.dart';
import 'package:frontend/services/medical_center_service.dart';


class DoctorScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  
  const DoctorScheduleScreen({super.key, required this.doctor});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  List<DailySchedule> weeklySchedule = [];
  List<MedicalCenter> medicalCenters = [];
  MedicalCenter? selectedMedicalCenter;
  bool isLoading = false;
  bool isSaved = false;
  bool loadingCenters = true;

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
    _loadMedicalCenters();
    _loadExistingSchedule();
  }

  Future<void> _loadMedicalCenters() async {
    try {
      setState(() => loadingCenters = true);
      
      final doctorId = widget.doctor['uid'] ?? widget.doctor['id'];
      if (doctorId != null) {
        print('🔄 Loading medical centers for doctor: $doctorId');
        
        final centersStream = MedicalCenterService.getDoctorMedicalCenters(doctorId.toString());
        
        centersStream.first.then((centers) {
          print('✅ Found ${centers.length} medical centers');
          setState(() {
            medicalCenters = centers;
            if (centers.isNotEmpty) {
              selectedMedicalCenter = centers.first;
              print('🏥 Selected medical center: ${selectedMedicalCenter!.name}');
            } else {
              print('⚠️ No medical centers found for this doctor');
            }
          });
        }).catchError((e) {
          print('❌ Error loading medical centers: $e');
          _showMockMedicalCenters(); // Fallback to mock data
        });
      } else {
        print('❌ No doctor ID found');
        _showMockMedicalCenters(); // Fallback to mock data
      }
    } catch (e) {
      print('❌ Error in _loadMedicalCenters: $e');
      _showMockMedicalCenters(); // Fallback to mock data
    } finally {
      setState(() => loadingCenters = false);
    }
  }

  // Fallback method with mock data
  void _showMockMedicalCenters() {
    setState(() {
      medicalCenters = [
        MedicalCenter(
          id: '1',
          name: 'City General Hospital',
          address: '123 Main Street, City Center',
          phone: '+1 234-567-8900',
          email: 'info@citygeneral.com',
          adminId: 'admin_city',
          adminName: 'Dr. Sarah Johnson',
        ),
        MedicalCenter(
          id: '2',
          name: 'Community Health Clinic',
          address: '456 Oak Avenue, Suburbia',
          phone: '+1 234-567-8901',
          email: 'contact@communityclinic.com',
          adminId: 'admin_community',
          adminName: 'Dr. Michael Brown',
        ),
      ];
      if (medicalCenters.isNotEmpty) {
        selectedMedicalCenter = medicalCenters.first;
      }
    });
  }

  void _initializeSchedule() {
  weeklySchedule = [
    DailySchedule(day: 'monday', available: false, timeSlots: [], maxAppointments: 10),
    DailySchedule(day: 'tuesday', available: false, timeSlots: [], maxAppointments: 10),
    DailySchedule(day: 'wednesday', available: false, timeSlots: [], maxAppointments: 10),
    DailySchedule(day: 'thursday', available: false, timeSlots: [], maxAppointments: 10),
    DailySchedule(day: 'friday', available: false, timeSlots: [], maxAppointments: 10),
    DailySchedule(day: 'saturday', available: false, timeSlots: [], maxAppointments: 10),
    DailySchedule(day: 'sunday', available: false, timeSlots: [], maxAppointments: 10),
  ];
}

  Future<void> _loadExistingSchedule() async {
    try {
      setState(() => isLoading = true);
      final doctorId = widget.doctor['uid'] ?? widget.doctor['id'];
      if (doctorId != null) {
        final schedule = await DoctorScheduleService.getMySchedule(doctorId.toString());
        if (schedule != null) {
          setState(() {
            weeklySchedule = schedule.weeklySchedule;
            isSaved = true;
          });
        }
      }
    } catch (e) {
      print('No existing schedule: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _toggleDayAvailability(int dayIndex) {
  setState(() {
    weeklySchedule[dayIndex] = DailySchedule(
      day: weeklySchedule[dayIndex].day,
      available: !weeklySchedule[dayIndex].available,
      timeSlots: weeklySchedule[dayIndex].timeSlots,
      maxAppointments: weeklySchedule[dayIndex].maxAppointments, // ✅ ADD THIS
    );
  });
}

  void _addTimeSlot(int dayIndex) {
    setState(() {
      final newSlots = List<TimeSlot>.from(weeklySchedule[dayIndex].timeSlots);
      newSlots.add(TimeSlot(
        startTime: '09:00',
        endTime: '17:00',
        slotDuration: 30,
        maxAppointments: weeklySchedule[dayIndex].maxAppointments,
      ));
      weeklySchedule[dayIndex] = DailySchedule(
        day: weeklySchedule[dayIndex].day,
        available: true,
        timeSlots: newSlots,
        maxAppointments: weeklySchedule[dayIndex].maxAppointments,
      );
    });
  }

  void _updateTimeSlot(int dayIndex, int slotIndex, TimeSlot updatedSlot) {
    setState(() {
      final newSlots = List<TimeSlot>.from(weeklySchedule[dayIndex].timeSlots);
      newSlots[slotIndex] = updatedSlot;
      weeklySchedule[dayIndex] = DailySchedule(
        day: weeklySchedule[dayIndex].day,
        available: weeklySchedule[dayIndex].available,
        timeSlots: newSlots,
        maxAppointments: weeklySchedule[dayIndex].maxAppointments,
      );
    });
  }

  void _removeTimeSlot(int dayIndex, int slotIndex) {
    setState(() {
      final newSlots = List<TimeSlot>.from(weeklySchedule[dayIndex].timeSlots);
      newSlots.removeAt(slotIndex);
      weeklySchedule[dayIndex] = DailySchedule(
        day: weeklySchedule[dayIndex].day,
        available: newSlots.isNotEmpty,
        timeSlots: newSlots,
        maxAppointments: weeklySchedule[dayIndex].maxAppointments,
      );
    });
  }

  Future<void> _saveSchedule() async {
    if (selectedMedicalCenter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please select a medical center first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if at least one day is available
    final hasAvailableDays = weeklySchedule.any((day) => day.available && day.timeSlots.isNotEmpty);
    if (!hasAvailableDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please set availability for at least one day'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => isLoading = true);
      
      final doctorId = widget.doctor['uid'] ?? widget.doctor['id'];
      final doctorName = widget.doctor['fullname'] ?? 'Doctor';
      
      if (doctorId == null) {
        throw Exception('Doctor ID not found');
      }

      print('💾 Saving schedule for:');
      print('   Doctor: $doctorName');
      print('   Medical Center: ${selectedMedicalCenter!.name}');
      print('   Admin ID: ${selectedMedicalCenter!.adminId}');

      // ONLY CHANGE: Added scheduleDate parameter with current date
      await DoctorScheduleService.saveSchedule(
        doctorId: doctorId.toString(),
        doctorName: doctorName,
        medicalCenterId: selectedMedicalCenter!.id,
        medicalCenterName: selectedMedicalCenter!.name,
        medicalCenterAdminId: selectedMedicalCenter!.adminId,
        weeklySchedule: weeklySchedule,
        appointmentType: 'physical',
        telemedicineTypes: [],
        scheduleDate: DateTime.now(), 
        maxAppointments: 10,
      );
      
      setState(() => isSaved = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Schedule submitted for ${selectedMedicalCenter!.name}! Waiting for admin approval.'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      print('❌ Error saving schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving schedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Your Schedule'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          if (isSaved)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
        ],
      ),
      body: isLoading || loadingCenters
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Medical Center Selection - ADDED THIS SECTION
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.medical_services, color: Color(0xFF18A3B6)),
                              SizedBox(width: 8),
                              Text(
                                'Select Medical Center',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF18A3B6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Choose where you want to set your schedule:',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          
                          if (medicalCenters.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange, size: 40),
                                  SizedBox(height: 8),
                                  Text(
                                    'No medical centers registered',
                                    style: TextStyle(color: Colors.orange),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Please contact admin to register you with medical centers',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            DropdownButtonFormField<MedicalCenter>(
                              value: selectedMedicalCenter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Medical Center',
                                prefixIcon: Icon(Icons.business),
                              ),
                              items: medicalCenters.map((center) {
                                return DropdownMenuItem(
                                  value: center,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        center.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        center.address,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (MedicalCenter? newValue) {
                                setState(() {
                                  selectedMedicalCenter = newValue;
                                });
                              },
                            ),
                          
                          if (selectedMedicalCenter != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF18A3B6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF18A3B6)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info, color: Color(0xFF18A3B6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selected: ${selectedMedicalCenter!.name}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF18A3B6),
                                          ),
                                        ),
                                        Text(
                                          'Admin: ${selectedMedicalCenter!.adminName}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Schedule Setup Section
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.schedule, color: Color(0xFF18A3B6)),
                              SizedBox(width: 8),
                              Text(
                                'Set Your Weekly Availability',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF18A3B6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Admin approval required before patients can book',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          // Show warning if no medical center selected
                          if (selectedMedicalCenter == null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Please select a medical center above to set your schedule',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                itemCount: weeklySchedule.length,
                                itemBuilder: (context, index) {
                                  return _buildDayScheduleCard(index);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedMedicalCenter != null ? _saveSchedule : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF18A3B6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : const Text(
                              'Save Schedule',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDayScheduleCard(int dayIndex) {
    final day = weeklySchedule[dayIndex];
    final dayName = _capitalize(day.day);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: day.available,
                  onChanged: (value) => _toggleDayAvailability(dayIndex),
                  activeColor: const Color(0xFF18A3B6),
                ),
              ],
            ),
            if (day.available) ...[
              const SizedBox(height: 12),
              const Text(
                'Time Slots:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...day.timeSlots.asMap().entries.map((entry) {
                final slotIndex = entry.key;
                final slot = entry.value;
                return _buildTimeSlotRow(dayIndex, slotIndex, slot);
              }).toList(),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _addTimeSlot(dayIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('Add Time Slot'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotRow(int dayIndex, int slotIndex, TimeSlot slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: slot.startTime,
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    hintText: 'HH:MM (24-hour format)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _updateTimeSlot(
                      dayIndex,
                      slotIndex,
                      TimeSlot(
                        startTime: value,
                        endTime: slot.endTime,
                        slotDuration: slot.slotDuration,
                        maxAppointments: slot.maxAppointments,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: slot.endTime,
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    hintText: 'HH:MM (24-hour format)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _updateTimeSlot(
                      dayIndex,
                      slotIndex,
                      TimeSlot(
                        startTime: slot.startTime,
                        endTime: value,
                        slotDuration: slot.slotDuration,
                        maxAppointments: slot.maxAppointments
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: slot.slotDuration,
                  decoration: const InputDecoration(
                    labelText: 'Slot Duration',
                    border: OutlineInputBorder(),
                  ),
                  items: [15, 20, 30, 45, 60]
                      .map((duration) => DropdownMenuItem(
                            value: duration,
                            child: Text('$duration minutes'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    _updateTimeSlot(
                      dayIndex,
                      slotIndex,
                      TimeSlot(
                        startTime: slot.startTime,
                        endTime: slot.endTime,
                        slotDuration: value!,
                        maxAppointments: slot.maxAppointments,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeTimeSlot(dayIndex, slotIndex),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    return text[0].toUpperCase() + text.substring(1);
  }
}