import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../model/medical_center.dart';
import '../../model/doctor.dart';
import '../../model/appointment.dart';

class DoctorConsultationPage extends StatefulWidget {
  const DoctorConsultationPage({Key? key}) : super(key: key);

  @override
  State<DoctorConsultationPage> createState() => _DoctorConsultationPageState();
}

class _DoctorConsultationPageState extends State<DoctorConsultationPage> {
  // Use 10.0.2.2 for Android emulator to reach host machine; include API version prefix
  final String baseUrl = 'http://10.0.2.2:8080/api/v1';
  
  // Form state
  String? selectedMedicalCenterId;
  String? selectedDoctorId;
  DateTime? selectedDate;
  String? selectedStartTime;
  String? selectedEndTime;
  String selectedConsultationType = 'physical';
  
  // Data
  List<MedicalCenter> medicalCenters = [];
  List<Doctor> doctors = [];
  List<DoctorAvailability> availableSlots = [];
  
  // Loading states
  bool isLoadingCenters = false;
  bool isLoadingDoctors = false;
  bool isLoadingSlots = false;
  bool isCreatingAvailability = false;
  
  final List<String> consultationTypes = ['physical', 'audio', 'video'];
  final List<String> timeSlots = [
    '09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '12:00', '12:30',
    '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
    '17:00', '17:30', '18:00', '18:30', '19:00', '19:30', '20:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadMedicalCenters();
  }

  Future<void> _loadMedicalCenters() async {
    setState(() => isLoadingCenters = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/medical-centers'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            medicalCenters = (data['data'] as List)
                .map((center) => MedicalCenter.fromMap(center['id'], center))
                .toList();
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load medical centers: $e');
    } finally {
      setState(() => isLoadingCenters = false);
    }
  }

  Future<void> _loadDoctorsByCenter(String centerId) async {
    setState(() => isLoadingDoctors = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/doctors/by-medical-center?medicalCenterId=$centerId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            doctors = (data['data'] as List)
                .map((doctor) => Doctor.fromMap(doctor['id'], doctor))
                .toList();
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load doctors: $e');
    } finally {
      setState(() => isLoadingDoctors = false);
    }
  }

  Future<void> _loadDoctorAvailability() async {
    if (selectedDoctorId == null || selectedDate == null) return;
    
    setState(() => isLoadingSlots = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final response = await http.get(
        Uri.parse('$baseUrl/doctor-availability?doctorId=$selectedDoctorId&date=$dateStr'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            availableSlots = (data['data']['availableSlots'] as List)
                .map((slot) => DoctorAvailability.fromMap(slot['id'] ?? '', slot))
                .toList();
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load availability: $e');
    } finally {
      setState(() => isLoadingSlots = false);
    }
  }

  Future<void> _createAvailability() async {
    if (!_isFormValid()) return;
    
    setState(() => isCreatingAvailability = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final requestData = {
        'doctorId': selectedDoctorId,
        'date': dateStr,
        'startTime': selectedStartTime,
        'endTime': selectedEndTime,
        'medicalCenterId': selectedMedicalCenterId,
        'consultationType': [selectedConsultationType],
      };

      final response = await http.post(
        Uri.parse('$baseUrl/doctor-availability'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 201) {
        _showSuccessSnackBar('Availability created successfully!');
        _resetForm();
        _loadDoctorAvailability();
      } else {
        final data = json.decode(response.body);
        _showErrorSnackBar(data['message'] ?? 'Failed to create availability');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create availability: $e');
    } finally {
      setState(() => isCreatingAvailability = false);
    }
  }

  bool _isFormValid() {
    return selectedMedicalCenterId != null &&
           selectedDoctorId != null &&
           selectedDate != null &&
           selectedStartTime != null &&
           selectedEndTime != null;
  }

  void _resetForm() {
    setState(() {
      selectedStartTime = null;
      selectedEndTime = null;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Consultation Schedule'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Set Your Availability'),
            const SizedBox(height: 16),
            _buildMedicalCenterDropdown(),
            const SizedBox(height: 16),
            _buildDoctorDropdown(),
            const SizedBox(height: 16),
            _buildDatePicker(),
            const SizedBox(height: 16),
            _buildTimeSelectors(),
            const SizedBox(height: 16),
            _buildConsultationTypeSelector(),
            const SizedBox(height: 24),
            _buildCreateButton(),
            const SizedBox(height: 32),
            _buildCurrentAvailability(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildMedicalCenterDropdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medical Center',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            isLoadingCenters
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: selectedMedicalCenterId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select medical center',
                    ),
                    items: medicalCenters.map((center) {
                      return DropdownMenuItem(
                        value: center.id,
                        child: Text(center.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMedicalCenterId = value;
                        selectedDoctorId = null;
                        doctors.clear();
                        availableSlots.clear();
                      });
                      if (value != null) {
                        _loadDoctorsByCenter(value);
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorDropdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Doctor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            isLoadingDoctors
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: selectedDoctorId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select doctor',
                    ),
                    items: doctors.map((doctor) {
                      return DropdownMenuItem(
                        value: doctor.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor.name),
                            Text(
                              doctor.specialty,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDoctorId = value;
                        availableSlots.clear();
                      });
                      if (value != null && selectedDate != null) {
                        _loadDoctorAvailability();
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                    availableSlots.clear();
                  });
                  if (selectedDoctorId != null) {
                    _loadDoctorAvailability();
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  selectedDate != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(selectedDate!)
                      : 'Select date',
                  style: TextStyle(
                    color: selectedDate != null ? Colors.black87 : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelectors() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStartTime,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Start Time',
                    ),
                    items: timeSlots.map((time) {
                      return DropdownMenuItem(
                        value: time,
                        child: Text(time),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStartTime = value;
                        if (selectedEndTime != null) {
                          final startIndex = timeSlots.indexOf(value!);
                          final endIndex = timeSlots.indexOf(selectedEndTime!);
                          if (endIndex <= startIndex) {
                            selectedEndTime = null;
                          }
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedEndTime,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'End Time',
                    ),
                    items: selectedStartTime != null
                        ? timeSlots
                            .where((time) => timeSlots.indexOf(time) > timeSlots.indexOf(selectedStartTime!))
                            .map((time) {
                            return DropdownMenuItem(
                              value: time,
                              child: Text(time),
                            );
                          }).toList()
                        : [],
                    onChanged: (value) {
                      setState(() {
                        selectedEndTime = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consultation Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: consultationTypes.map((type) {
                return FilterChip(
                  label: Text(_formatConsultationType(type)),
                  selected: selectedConsultationType == type,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedConsultationType = type;
                      });
                    }
                  },
                  selectedColor: Colors.blue[100],
                  checkmarkColor: Colors.blue[800],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isFormValid() && !isCreatingAvailability
            ? _createAvailability
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isCreatingAvailability
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Create Availability',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildCurrentAvailability() {
    if (selectedDoctorId == null || selectedDate == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Current Availability'),
        const SizedBox(height: 16),
        isLoadingSlots
            ? const Center(child: CircularProgressIndicator())
            : availableSlots.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No availability set for this date',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: availableSlots.length,
                    itemBuilder: (context, index) {
                      final slot = availableSlots[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.access_time, color: Colors.blue),
                          title: Text('${slot.startTime} - ${slot.endTime}'),
                          subtitle: Text(
                            'Type: ${slot.consultationType.map(_formatConsultationType).join(', ')}',
                          ),
                          trailing: const Icon(Icons.check_circle, color: Colors.green),
                        ),
                      );
                    },
                  ),
      ],
    );
  }
}


