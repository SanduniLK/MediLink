import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientDispensingHistoryScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String prescriptionId;

  const PatientDispensingHistoryScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.prescriptionId,
  });

  @override
  State<PatientDispensingHistoryScreen> createState() => _PatientDispensingHistoryScreenState();
}

class _PatientDispensingHistoryScreenState extends State<PatientDispensingHistoryScreen> {
  List<Map<String, dynamic>> _dispensingHistory = [];
  Map<String, dynamic> _remainingMedicines = {};
  bool _isLoading = true;
  String _errorMessage = '';

  // Duration mapping
  final Map<String, int> _durationToDaysMap = {
    '1 day': 1, '3 days': 3, '5 days': 5, '7 days': 7, '10 days': 10,
    '14 days': 14, '21 days': 21, '1 month': 30, '2 months': 60,
    '3 months': 90, '6 months': 180, '1 year': 365,
    '1 week': 7, '2 weeks': 14, '3 weeks': 21, '4 weeks': 28,
  };

  @override
  void initState() {
    super.initState();
    _loadDispensingHistoryWithDuration();
  }

  Future<void> _loadDispensingHistoryWithDuration() async {
    try {
      print('🔍 Loading history for:');
      print('   Patient ID: ${widget.patientId}');
      print('   Prescription ID: ${widget.prescriptionId}');

      // Get all dispensing records for this patient and prescription
      final historyQuery = FirebaseFirestore.instance
          .collection('dispensingRecords')
          .where('patientId', isEqualTo: widget.patientId)
          .where('prescriptionId', isEqualTo: widget.prescriptionId);

      final historySnapshot = await historyQuery.get();
      
      print('📊 Found ${historySnapshot.docs.length} dispensing records');

      final List<Map<String, dynamic>> history = [];
      
      // Get original prescription
      final prescriptionDoc = await FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(widget.prescriptionId)
          .get();

      if (!prescriptionDoc.exists) {
        throw Exception('❌ Prescription document not found for ID: ${widget.prescriptionId}');
      }

      final prescriptionData = prescriptionDoc.data()!;
      print('✅ Prescription data found');
      
      final originalMedicines = List<Map<String, dynamic>>.from(prescriptionData['medicines'] ?? []);
      print('💊 Original medicines count: ${originalMedicines.length}');
      
      // Print original medicines for debugging
      for (var medicine in originalMedicines) {
        print('   - ${medicine['name']}: ${medicine['duration']}');
      }
      
      // Calculate remaining duration for each medicine
      final Map<String, int> remainingDaysMap = {};
      final Map<String, dynamic> medicineDetailsMap = {};
      
      // Initialize with original durations
      for (var medicine in originalMedicines) {
        final medicineName = medicine['name'];
        final originalDuration = medicine['duration']?.toString() ?? '7 days';
        final originalDays = _parseDurationToDays(originalDuration);
        
        print('📝 Medicine: $medicineName, Original Duration: $originalDuration ($originalDays days)');
        
        remainingDaysMap[medicineName] = originalDays;
        medicineDetailsMap[medicineName] = medicine;
      }
      
      // Process dispensing history and subtract dispensed durations
      for (var doc in historySnapshot.docs) {
        final data = doc.data();
        print('🔄 Processing dispensing record: ${doc.id}');
        
        history.add(data);
        
        final medicines = List<Map<String, dynamic>>.from(data['dispensedMedicines'] ?? []);
        print('   Contains ${medicines.length} dispensed medicines');
        
        for (var dispensedMedicine in medicines) {
          final medicineName = dispensedMedicine['name'];
          final dispensedDuration = dispensedMedicine['pharmacyAdjustedDuration']?.toString() ?? 
                                  dispensedMedicine['originalDuration']?.toString() ?? '7 days';
          final dispensedDays = _parseDurationToDays(dispensedDuration);
          
          print('   💊 Dispensed: $medicineName, Duration: $dispensedDuration ($dispensedDays days)');
          
          if (remainingDaysMap.containsKey(medicineName)) {
            final before = remainingDaysMap[medicineName]!;
            remainingDaysMap[medicineName] = before - dispensedDays;
            print('   📉 Remaining days for $medicineName: $before -> ${remainingDaysMap[medicineName]}');
          } else {
            print('   ⚠️  Medicine $medicineName not found in original prescription');
          }
        }
      }
      
      // Prepare remaining medicines data
      final Map<String, dynamic> remainingMedicines = {};
      for (var medicineName in remainingDaysMap.keys) {
        final remainingDays = remainingDaysMap[medicineName]!;
        print('🎯 Final remaining for $medicineName: $remainingDays days');
        
        if (remainingDays > 0) {
          remainingMedicines[medicineName] = {
            'details': medicineDetailsMap[medicineName],
            'remainingDays': remainingDays,
            'originalDays': _parseDurationToDays(medicineDetailsMap[medicineName]?['duration']),
          };
        }
      }

      print('✅ Final remaining medicines count: ${remainingMedicines.length}');
      print('✅ Final history count: ${history.length}');

      setState(() {
        _dispensingHistory = history;
        _remainingMedicines = remainingMedicines;
        _isLoading = false;
        _errorMessage = '';
      });

    } catch (e) {
      print('❌ Error loading dispensing history: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  int _parseDurationToDays(String duration) {
    // Handle various duration formats
    duration = duration.toLowerCase().trim();
    
    if (_durationToDaysMap.containsKey(duration)) {
      return _durationToDaysMap[duration]!;
    }
    
    // Handle "1 weeka" typo and other variations
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
    
    // Try to parse as number
    final days = int.tryParse(duration);
    if (days != null) {
      return days;
    }
    
    return 7; // Default fallback
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
                'Loading dispensing history...',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Patient: ${widget.patientName}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dispensing History'),
          backgroundColor: const Color(0xFF18A3B6),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDispensingHistoryWithDuration,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispensing History'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Info
          _buildPatientInfo(),
          
          // Summary Cards
          _buildSummaryCards(),
          
          // Data status info
          if (_dispensingHistory.isEmpty)
            _buildEmptyState(),
          
          // Tabs for History and Remaining Medicines
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Dispensing History'),
                      Tab(text: 'Remaining Medicines'),
                    ],
                    labelColor: Color(0xFF18A3B6),
                    indicatorColor: Color(0xFF18A3B6),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildHistoryList(),
                        _buildRemainingMedicinesList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF18A3B6),
              child: Text(
                widget.patientName.isNotEmpty ? widget.patientName[0].toUpperCase() : 'P',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Prescription ID: ${widget.prescriptionId}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    'Patient ID: ${widget.patientId}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalRemainingDays = _remainingMedicines.values.fold<int>(0, 
      (sum, medicine) => sum + (medicine['remainingDays'] as int));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Total Dispensing Events
          Expanded(
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      _dispensingHistory.length.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text(
                      'Dispensing Events',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Remaining Days
          Expanded(
            child: Card(
              color: totalRemainingDays > 0 ? Colors.orange.shade50 : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      totalRemainingDays.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: totalRemainingDays > 0 ? Colors.orange : Colors.green,
                      ),
                    ),
                    Text(
                      totalRemainingDays > 0 ? 'Days Remaining' : 'All Complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: totalRemainingDays > 0 ? Colors.orange : Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.yellow.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.info, color: Colors.orange, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No Dispensing Records Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Patient ID: ${widget.patientId}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Prescription ID: ${widget.prescriptionId}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'This could mean:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '• No medicines have been dispensed yet\n• The prescription ID might be different\n• Check if dispensing records exist in Firestore',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_dispensingHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No dispensing history found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dispensingHistory.length,
      itemBuilder: (context, index) {
        final record = _dispensingHistory[index];
        final medicines = List<Map<String, dynamic>>.from(record['dispensedMedicines'] ?? []);
        final dispensingDate = _formatTimestamp(record['dispensingDate']);
        final pharmacyName = record['pharmacyName'] ?? 'Unknown Pharmacy';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date and pharmacy
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dispensed on: $dispensingDate',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pharmacy: $pharmacyName',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${medicines.length} meds',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Medicines list
                ...medicines.map((medicine) => _buildDispensedMedicineItem(medicine)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDispensedMedicineItem(Map<String, dynamic> medicine) {
    final medicineName = medicine['name'] ?? 'Unknown Medicine';
    final originalDuration = medicine['originalDuration'] ?? 'Not specified';
    final pharmacyDuration = medicine['pharmacyAdjustedDuration'] ?? originalDuration;
    final quantity = medicine['dispensedQuantity'] ?? 'N/A';
    final dispensedAt = _formatTimestamp(medicine['dispensedAt']);
    final dosage = medicine['originalDosage'] ?? 'Not specified';
    final frequency = medicine['originalFrequency'] ?? 'Not specified';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine name
          Row(
            children: [
              const Icon(Icons.medication, size: 16, color: Color(0xFF18A3B6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  medicineName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Medicine details
          _buildMedicineDetailRow('💊 Dosage', dosage),
          _buildMedicineDetailRow('🕒 Frequency', frequency),
          _buildMedicineDetailRow('🏥 Original Duration', originalDuration),
          _buildMedicineDetailRow('💊 Pharmacy Duration', pharmacyDuration),
          _buildMedicineDetailRow('📦 Quantity Dispensed', quantity.toString()),
          _buildMedicineDetailRow('🕒 Dispensed Time', dispensedAt),
          
          // Notes if available
          if (medicine['notes'] != null && medicine['notes'].isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildMedicineDetailRow('📝 Notes', medicine['notes']),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRemainingMedicinesList() {
    if (_remainingMedicines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All medicines have been dispensed!',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            SizedBox(height: 8),
            Text(
              'No remaining days left for any medicine',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _remainingMedicines.length,
      itemBuilder: (context, index) {
        final medicineName = _remainingMedicines.keys.elementAt(index);
        final medicineData = _remainingMedicines[medicineName];
        final medicineDetails = medicineData['details'] as Map<String, dynamic>;
        final remainingDays = medicineData['remainingDays'] as int;
        final originalDays = medicineData['originalDays'] as int;
        final dispensedDays = originalDays - remainingDays;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with remaining days
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        medicineName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$remainingDays days left',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Progress indicator
                LinearProgressIndicator(
                  value: dispensedDays / originalDays,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dispensed: $dispensedDays days',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Original: $originalDays days',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Medicine details
                _buildDetailRow('💊 Dosage', medicineDetails['dosage'] ?? 'Not specified'),
                _buildDetailRow('🕒 Frequency', medicineDetails['frequency'] ?? 'Not specified'),
                _buildDetailRow('📅 Original Duration', medicineDetails['duration'] ?? 'Not specified'),
                
                if (medicineDetails['notes'] != null && medicineDetails['notes'].isNotEmpty)
                  _buildDetailRow('📝 Notes', medicineDetails['notes']),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicineDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMM dd, yyyy - HH:mm').format(timestamp.toDate());
      } else if (timestamp is DateTime) {
        return DateFormat('MMM dd, yyyy - HH:mm').format(timestamp);
      } else if (timestamp is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return DateFormat('MMM dd, yyyy - HH:mm').format(date);
      }
      return 'Unknown date';
    } catch (e) {
      return 'Invalid date';
    }
  }
}