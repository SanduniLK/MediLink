import 'package:flutter/material.dart';
import 'package:frontend/screens/phamecy_screens/PatientDispensingHistory.dart';
import 'package:frontend/screens/phamecy_screens/prescription_image_viewer_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PharmacyDispensingScreen extends StatefulWidget {
  final Map<String, dynamic> prescription;
  final Map<String, dynamic> patientData;
  final String pharmacyId;
  final String pharmacyName;

  const PharmacyDispensingScreen({
    super.key,
    required this.prescription,
    required this.patientData,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<PharmacyDispensingScreen> createState() => _PharmacyDispensingScreenState();
}

class _PharmacyDispensingScreenState extends State<PharmacyDispensingScreen> {
  List<MedicineItem> _medicines = [];
  bool _isDispensing = false;
  bool _isLoading = true;
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, String> _selectedDurations = {};
  final Map<String, int> _remainingDays = {};

  // Duration mapping
  final Map<String, int> _durationToDaysMap = {
    '1 day': 1, '3 days': 3, '5 days': 5, '7 days': 7, '10 days': 10,
    '14 days': 14, '21 days': 21, '1 month': 30, '2 months': 60,
    '3 months': 90, '6 months': 180, '1 year': 365,
    '1 week': 7, '2 weeks': 14, '3 weeks': 21, '4 weeks': 28,
  };

  // Duration options for pharmacy to select
  final List<String> _durationOptions = [
    '1 day', '3 days', '5 days', '7 days', '10 days', '14 days', 
    '21 days', '1 month', '2 months', '3 months', '6 months', '1 year'
  ];

  @override
  void initState() {
    super.initState();
    _loadRemainingMedicines();
  }

  Future<void> _loadRemainingMedicines() async {
    try {
      final patientId = widget.patientData['uid'] ?? widget.prescription['patientId'];
      final prescriptionId = widget.prescription['prescriptionId'] ?? widget.prescription['id'];

      if (patientId == null || prescriptionId == null) {
        _initializeAllMedicines();
        return;
      }

      // Get original prescription medicines
      final originalMedicines = widget.prescription['medicines'] ?? [];
      
      // Get dispensing history for this prescription
      final historySnapshot = await FirebaseFirestore.instance
          .collection('dispensingRecords')
          .where('patientId', isEqualTo: patientId)
          .where('prescriptionId', isEqualTo: prescriptionId)
          .get();

      // Calculate remaining duration for each medicine
      final Map<String, int> remainingDaysMap = {};
      final Map<String, dynamic> medicineDetailsMap = {};

      // Initialize with original durations
      for (var medicine in originalMedicines) {
        final medicineName = medicine['name'];
        final originalDuration = medicine['duration']?.toString() ?? '7 days';
        final originalDays = _parseDurationToDays(originalDuration);
        
        remainingDaysMap[medicineName] = originalDays;
        medicineDetailsMap[medicineName] = medicine;
      }

      // Subtract dispensed durations from remaining
      for (var doc in historySnapshot.docs) {
        final data = doc.data();
        final medicines = List<Map<String, dynamic>>.from(data['dispensedMedicines'] ?? []);
        
        for (var dispensedMedicine in medicines) {
          final medicineName = dispensedMedicine['name'];
          final dispensedDuration = dispensedMedicine['pharmacyAdjustedDuration']?.toString() ?? 
                                  dispensedMedicine['originalDuration']?.toString() ?? '7 days';
          final dispensedDays = _parseDurationToDays(dispensedDuration);
          
          if (remainingDaysMap.containsKey(medicineName)) {
            remainingDaysMap[medicineName] = remainingDaysMap[medicineName]! - dispensedDays;
          }
        }
      }

      // Filter medicines that still have remaining duration
      final remainingMedicines = originalMedicines.where((medicine) {
        final medicineName = medicine['name'];
        final remainingDays = remainingDaysMap[medicineName] ?? 0;
        return remainingDays > 0;
      }).toList();

      // Store remaining days for each medicine
      for (var medicine in remainingMedicines) {
        final medicineName = medicine['name'];
        _remainingDays[medicineName] = remainingDaysMap[medicineName] ?? 0;
      }

      _initializeMedicines(remainingMedicines);

    } catch (e) {
      print('Error loading remaining medicines: $e');
      _initializeAllMedicines();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeAllMedicines() {
    final originalMedicines = widget.prescription['medicines'] ?? [];
    _initializeMedicines(originalMedicines);
    
    // Initialize remaining days with original durations
    for (var medicine in originalMedicines) {
      final medicineName = medicine['name'];
      final originalDuration = medicine['duration']?.toString() ?? '7 days';
      _remainingDays[medicineName] = _parseDurationToDays(originalDuration);
    }
  }

  void _initializeMedicines(List<dynamic> medicinesList) {
    _medicines.clear();
    _quantityControllers.clear();
    _selectedDurations.clear();
    
    for (var i = 0; i < medicinesList.length; i++) {
      final medicine = medicinesList[i];
      final medicineName = medicine['name'];
      final medicineId = '${medicineName}_$i';
      
      _medicines.add(MedicineItem(
        id: medicineId,
        data: Map<String, dynamic>.from(medicine),
      ));
      
      _quantityControllers[medicineId] = TextEditingController(text: '1');
      
      // Set default duration based on remaining days
      final remainingDays = _remainingDays[medicineName] ?? 7;
      final defaultDuration = _getDurationFromDays(remainingDays);
      _selectedDurations[medicineId] = defaultDuration;
    }
  }

  int _parseDurationToDays(String duration) {
    duration = duration.toLowerCase().trim();
    
    if (_durationToDaysMap.containsKey(duration)) {
      return _durationToDaysMap[duration]!;
    }
    
    if (duration.contains('week')) {
      final weekMatch = RegExp(r'(\d+)\s*week').firstMatch(duration);
      if (weekMatch != null) {
        final weeks = int.tryParse(weekMatch.group(1)!) ?? 1;
        return weeks * 7;
      }
      return 7;
    }
    
    if (duration.contains('month')) {
      final monthMatch = RegExp(r'(\d+)\s*month').firstMatch(duration);
      if (monthMatch != null) {
        final months = int.tryParse(monthMatch.group(1)!) ?? 1;
        return months * 30;
      }
      return 30;
    }
    
    if (duration.contains('day')) {
      final dayMatch = RegExp(r'(\d+)\s*day').firstMatch(duration);
      if (dayMatch != null) {
        return int.tryParse(dayMatch.group(1)!) ?? 7;
      }
      return 7;
    }
    
    final days = int.tryParse(duration);
    if (days != null) {
      return days;
    }
    
    return 7;
  }

  String _getDurationFromDays(int days) {
    // Find the closest duration option that doesn't exceed remaining days
    for (var duration in _durationOptions.reversed) {
      if (_durationToDaysMap[duration]! <= days) {
        return duration;
      }
    }
    return '1 day';
  }

  int _getDaysFromDuration(String duration) {
    return _durationToDaysMap[duration] ?? 7;
  }

  int _calculateQuantity(String frequency, String duration) {
    final frequencyMap = {
      'Once daily': 1, 'Twice daily': 2, 'Thrice daily': 3, 'Four times daily': 4,
      'Every 6 hours': 4, 'Every 8 hours': 3, 'Every 12 hours': 2, 'As needed': 1,
    };

    final dailyDoses = frequencyMap[frequency] ?? 1;
    final days = _getDaysFromDuration(duration);
    
    return dailyDoses * days;
  }

  String _calculateEndDate(String duration) {
    final now = DateTime.now();
    final days = _getDaysFromDuration(duration);
    final endDate = now.add(Duration(days: days));
    return DateFormat('MMM dd, yyyy').format(endDate);
  }

  Timestamp _calculateEndDateTimestamp(String duration) {
    final now = DateTime.now();
    final days = _getDaysFromDuration(duration);
    final endDate = now.add(Duration(days: days));
    return Timestamp.fromDate(endDate);
  }

  Future<void> _dispenseMedicines() async {
    // First check if there are any medicines to dispense
    if (_medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No medicines available to dispense. All medicines may have been already dispensed.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate dispensing limits before proceeding
    try {
      await _validateDispensingLimits();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isDispensing = true);

    try {
      _validateMedicinesBeforeDispensing();

      final patientId = widget.patientData['uid'] ?? widget.prescription['patientId'];
      final patientName = widget.patientData['fullname'] ?? widget.prescription['patientName'];
      final prescriptionId = widget.prescription['prescriptionId'] ?? widget.prescription['id'];
      
      if (patientId == null || patientName == null || prescriptionId == null) {
        throw Exception('Missing required patient or prescription data');
      }

      final batch = FirebaseFirestore.instance.batch();
      final currentTimestamp = Timestamp.now();
      
      // Create dispensing record
      final dispensingRef = FirebaseFirestore.instance.collection('dispensingRecords').doc();
      
      final dispensedMedicines = <Map<String, dynamic>>[];
      
      for (var medicineItem in _medicines) {
        final medicine = medicineItem.data;
        final medicineName = medicine['name'];
        final selectedDuration = _selectedDurations[medicineItem.id] ?? '7 days';
        final dispensedDays = _getDaysFromDuration(selectedDuration);
        final remainingDaysBefore = _remainingDays[medicineName] ?? 0;
        final remainingDaysAfter = remainingDaysBefore - dispensedDays;
        
        final medicineData = {
          'name': medicineName,
          'originalDosage': medicine['dosage']?.toString() ?? 'Not specified',
          'originalFrequency': medicine['frequency']?.toString() ?? 'Once daily',
          'originalDuration': medicine['duration']?.toString() ?? '7 days',
          'pharmacyAdjustedDuration': selectedDuration,
          'dispensedQuantity': _calculateQuantity(
            medicine['frequency']?.toString() ?? 'Once daily',
            selectedDuration
          ),
          'dispensedDays': dispensedDays,
          'remainingDaysBefore': remainingDaysBefore,
          'remainingDaysAfter': remainingDaysAfter,
          'startDate': currentTimestamp,
          'expectedEndDate': _calculateEndDateTimestamp(selectedDuration),
          'dispensedAt': currentTimestamp,
          'notes': medicine['notes']?.toString() ?? '',
        };
        
        dispensedMedicines.add(medicineData);
      }

      final dispensingData = {
        'dispensingId': dispensingRef.id,
        'patientId': patientId,
        'patientName': patientName.toString(),
        'pharmacyId': widget.pharmacyId,
        'pharmacyName': widget.pharmacyName,
        'prescriptionId': prescriptionId,
        'originalDoctorId': widget.prescription['doctorId']?.toString() ?? '',
        'originalMedicalCenter': widget.prescription['medicalCenter']?.toString() ?? '',
        'dispensedMedicines': dispensedMedicines,
        'totalMedicines': _medicines.length,
        'dispensingDate': FieldValue.serverTimestamp(),
        'status': 'dispensed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(dispensingRef, dispensingData);

      // Update prescription status
      final prescriptionRef = FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(prescriptionId);
      
      batch.update(prescriptionRef, {
        'lastDispensedAt': FieldValue.serverTimestamp(),
        'dispensingPharmacy': widget.pharmacyName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create medicine history records
      for (var medicineItem in _medicines) {
        final medicine = medicineItem.data;
        final historyRef = FirebaseFirestore.instance.collection('medicineHistory').doc();
        final selectedDuration = _selectedDurations[medicineItem.id] ?? '7 days';
        final medicineName = medicine['name'];
        final remainingDaysBefore = _remainingDays[medicineName] ?? 0;
        final dispensedDays = _getDaysFromDuration(selectedDuration);
        
        final historyData = {
          'historyId': historyRef.id,
          'patientId': patientId,
          'medicineName': medicineName,
          'dosage': medicine['dosage']?.toString() ?? 'Not specified',
          'frequency': medicine['frequency']?.toString() ?? 'Once daily',
          'originalDuration': medicine['duration']?.toString() ?? '7 days',
          'pharmacyAdjustedDuration': selectedDuration,
          'dispensedDays': dispensedDays,
          'remainingDaysBefore': remainingDaysBefore,
          'remainingDaysAfter': remainingDaysBefore - dispensedDays,
          'quantityDispensed': _calculateQuantity(
            medicine['frequency']?.toString() ?? 'Once daily',
            selectedDuration
          ),
          'dispensingId': dispensingRef.id,
          'pharmacyId': widget.pharmacyId,
          'pharmacyName': widget.pharmacyName,
          'startDate': currentTimestamp,
          'expectedEndDate': _calculateEndDateTimestamp(selectedDuration),
          'endDateDisplay': _calculateEndDate(selectedDuration),
          'status': remainingDaysBefore - dispensedDays > 0 ? 'partial' : 'completed',
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        batch.set(historyRef, historyData);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_medicines.length} medicines dispensed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dispensing medicines: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Dispensing error details: $e');
    } finally {
      if (mounted) {
        setState(() => _isDispensing = false);
      }
    }
  }

  Future<void> _validateDispensingLimits() async {
    for (var medicineItem in _medicines) {
      final medicine = medicineItem.data;
      final medicineName = medicine['name'];
      final selectedDuration = _selectedDurations[medicineItem.id] ?? '7 days';
      final dispensedDays = _getDaysFromDuration(selectedDuration);
      final remainingDays = _remainingDays[medicineName] ?? 0;
      
      if (dispensedDays > remainingDays) {
        throw Exception('Cannot dispense $dispensedDays days for $medicineName. Only $remainingDays days remaining. Please adjust the duration.');
      }
      
      if (remainingDays <= 0) {
        throw Exception('Medicine $medicineName has no remaining days to dispense.');
      }
    }
  }

  void _validateMedicinesBeforeDispensing() {
    for (var medicineItem in _medicines) {
      final medicine = medicineItem.data;
      if (medicine['name'] == null || medicine['name'].toString().isEmpty) {
        throw Exception('Medicine name cannot be empty');
      }
      if (medicine['frequency'] == null || medicine['frequency'].toString().isEmpty) {
        throw Exception('Medicine frequency cannot be empty');
      }
    }
  }

  void _checkDispensingHistory() {
    final patientId = widget.patientData['uid'] ?? widget.prescription['patientId'];
    final patientName = widget.patientData['fullname'] ?? widget.prescription['patientName'];
    final prescriptionId = widget.prescription['prescriptionId'] ?? widget.prescription['id'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDispensingHistoryScreen(
          patientId: patientId!,
          patientName: patientName!,
          prescriptionId: prescriptionId!,
        ),
      ),
    );
  }
void _viewOriginalPrescriptionImage() {
  final prescriptionImageUrl = widget.prescription['prescriptionImageUrl'];
  
  if (prescriptionImageUrl == null || prescriptionImageUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No prescription image available'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PrescriptionImageViewerScreen(
        imageUrl: prescriptionImageUrl,
        patientName: widget.patientData['fullname'] ?? 'Patient',
        medicalCenter: widget.prescription['medicalCenter'] ?? 'Medical Center',
        
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading medicines...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispense Medications'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Patient Info Card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF18A3B6),
                    child: Text(
                      (widget.patientData['fullname']?[0] ?? 'P').toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patientData['fullname'] ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Age: ${widget.patientData['age'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Prescription from: ${widget.prescription['medicalCenter']}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Remaining Days Summary
          if (_medicines.isNotEmpty) _buildRemainingDaysSummary(),

          // Today's Date
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // History Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Check Dispensing History'),
                onPressed: _checkDispensingHistory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF18A3B6),
                  side: const BorderSide(color: Color(0xFF18A3B6)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
         Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.image, size: 18),
              label: const Text('View Original Prescription'),
              onPressed: _viewOriginalPrescriptionImage,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
          // Medicines List
          Expanded(
            child: _medicines.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_services, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No medications to dispense',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All prescribed medicines have been fully dispensed',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _medicines.length,
                    itemBuilder: (context, index) {
                      final medicineItem = _medicines[index];
                      final medicine = medicineItem.data;
                      final medicineName = medicine['name'];
                      final selectedDuration = _selectedDurations[medicineItem.id] ?? '7 days';
                      final calculatedQuantity = _calculateQuantity(
                        medicine['frequency'] ?? 'Once daily',
                        selectedDuration
                      );
                      final endDate = _calculateEndDate(selectedDuration);
                      final remainingDays = _remainingDays[medicineName] ?? 0;
                      final dispensedDays = _getDaysFromDuration(selectedDuration);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Medicine Header with Remaining Days
                              Row(
                                children: [
                                  const Icon(Icons.medication, color: Color(0xFF18A3B6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      medicineName ?? 'Unknown Medicine',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: remainingDays > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: remainingDays > 0 ? Colors.orange : Colors.green,
                                      ),
                                    ),
                                    child: Text(
                                      '$remainingDays days left',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: remainingDays > 0 ? Colors.orange : Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Original Prescription Details
                              _buildDetailRow('💊 Dosage', medicine['dosage'] ?? 'Not specified'),
                              _buildDetailRow('🕒 Frequency', medicine['frequency'] ?? 'Not specified'),
                              _buildDetailRow('📅 Original Duration', medicine['duration'] ?? 'Not specified'),
                              
                              const SizedBox(height: 12),

                              // Pharmacy Adjustable Duration with Remaining Days Info
                              _buildDurationSelectorWithRemaining(
                                medicineItem.id, 
                                medicine, 
                                endDate, 
                                remainingDays,
                                dispensedDays
                              ),
                              
                              const SizedBox(height: 8),

                              // Calculated Quantity and End Date
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.inventory, size: 16, color: Colors.green),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Quantity: $calculatedQuantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_month, size: 16, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Will finish on: $endDate',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Notes
                              if (medicine['notes'] != null && medicine['notes'].isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Notes: ${medicine['notes']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Dispense Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isDispensing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.medical_services, size: 20),
                label: Text(
                  _isDispensing ? 'Dispensing...' : 'Dispense ${_medicines.length} Medicines',
                  style: const TextStyle(fontSize: 16),
                ),
                onPressed: _isDispensing ? null : _dispenseMedicines,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingDaysSummary() {
    final totalRemainingDays = _remainingDays.values.fold(0, (sum, days) => sum + days);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: totalRemainingDays > 0 ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: totalRemainingDays > 0 ? Colors.orange : Colors.green,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            totalRemainingDays > 0 ? Icons.warning : Icons.check_circle,
            color: totalRemainingDays > 0 ? Colors.orange : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            totalRemainingDays > 0 
                ? 'Total $totalRemainingDays days remaining across all medicines'
                : 'All medicines fully dispensed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: totalRemainingDays > 0 ? Colors.orange : Colors.green,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelectorWithRemaining(
    String medicineId, 
    Map<String, dynamic> medicine, 
    String endDate, 
    int remainingDays,
    int dispensedDays
  ) {
    final currentDuration = _selectedDurations[medicineId] ?? '7 days';
    final medicineName = medicine['name'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📦 Adjust Dispensing Duration:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        
        // Remaining days info
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, size: 14, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Available: $remainingDays days • Dispensing: $dispensedDays days',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: currentDuration,
            isExpanded: true,
            underline: const SizedBox(),
            items: _durationOptions.where((duration) {
              final durationDays = _getDaysFromDuration(duration);
              return durationDays <= remainingDays;
            }).map((String duration) {
              final durationDays = _getDaysFromDuration(duration);
              return DropdownMenuItem<String>(
                value: duration,
                child: Text(
                  '$duration (${durationDays} days)',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedDurations[medicineId] = newValue;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Treatment ends: $endDate',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

// Helper class to handle duplicate medicine names
class MedicineItem {
  final String id;
  final Map<String, dynamic> data;

  MedicineItem({
    required this.id,
    required this.data,
  });
}