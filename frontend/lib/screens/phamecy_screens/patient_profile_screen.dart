
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/phamecy_screens/pharmacy_dispensing_screen.dart';
import 'package:intl/intl.dart';


class PatientProfileScreen extends StatefulWidget {
  final String patientId;
  final Map<String, dynamic> patientData;
  final String pharmacyId;
  final String pharmacyName;

  const PatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientData,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;
  Map<String, dynamic>? _patientDetails;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _loadPatientPrescriptions();
  }

  Future<void> _loadPatientData() async {
    try {
      // Fetch the latest patient data from Firestore
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();

      if (patientDoc.exists) {
        setState(() {
          _patientDetails = patientDoc.data()!;
        });
        print('✅ Loaded patient details: ${_patientDetails!['fullname']}');
      }
    } catch (e) {
      print('❌ Error loading patient details: $e');
    }
  }

Future<void> _loadPatientPrescriptions() async {
  try {
    print('🔄 Loading prescriptions for patient: ${widget.patientId}');
    
    List<Map<String, dynamic>> prescriptions = [];

    // Method 1: Search Firestore prescriptions collection
    try {
      final prescriptionsQuery = await FirebaseFirestore.instance
          .collection('prescriptions')  // Make sure this matches your collection name
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('createdAt', descending: true)
          .get();

      print('📋 Found ${prescriptionsQuery.docs.length} prescriptions in Firestore');

      for (var doc in prescriptionsQuery.docs) {
        final prescriptionData = doc.data() as Map<String, dynamic>;
        prescriptionData['prescriptionId'] = doc.id;
        
        // Debug the prescription data
        print('🎯 Prescription loaded:');
        print('   Medical Center: ${prescriptionData['medicalCenter']}');
        print('   Medicines count: ${prescriptionData['medicines']?.length ?? 0}');
        
        if (prescriptionData['medicines'] != null && prescriptionData['medicines'].isNotEmpty) {
          for (var medicine in prescriptionData['medicines']) {
            print('   Medicine: ${medicine['name']} - Duration: ${medicine['duration']}');
          }
        }
        
        prescriptions.add(prescriptionData);
      }
    } catch (e) {
      print('❌ Error loading from Firestore: $e');
    }

    setState(() {
      _prescriptions = prescriptions;
      _isLoading = false;
    });

    print('✅ Final prescriptions count: ${_prescriptions.length}');

  } catch (e) {
    print('❌ Error loading prescriptions: $e');
    setState(() => _isLoading = false);
  }
}

  // Get patient name with fallbacks
  String get _patientName {
    return _patientDetails?['fullname'] ?? 
           widget.patientData['fullname'] ?? 
           widget.patientData['fullName'] ?? 
           'Unknown Patient';
  }

  // Get patient mobile with fallbacks
  String get _patientMobile {
    return _patientDetails?['mobile'] ?? 
           widget.patientData['mobile'] ?? 
           widget.patientData['mobileNumber'] ?? 
           'No mobile number';
  }

  // Get patient age with fallbacks
  String get _patientAge {
    final age = _patientDetails?['age'] ?? widget.patientData['age'];
    return age != null ? age.toString() : 'Not specified';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Profile'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Info Card
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF18A3B6),
                                radius: 30,
                                child: Text(
                                  _patientName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _patientName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _patientMobile,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Age: $_patientAge',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Additional patient info
                          if (_patientDetails?['address'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Address: ${_patientDetails!['address']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                         
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Prescriptions Section
                  Row(
                    children: [
                      const Text(
                        'Prescriptions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${_prescriptions.length} found'),
                        backgroundColor: const Color(0xFF18A3B6),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_prescriptions.isEmpty)
                    _buildNoPrescriptionsCard()
                  else
                    ..._prescriptions.map((prescription) => 
                        _buildPrescriptionCard(prescription)),
                ],
              ),
            ),
    );
  }

  Widget _buildNoPrescriptionsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.medical_services_outlined, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Prescriptions Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This patient does not have any active prescriptions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _loadPatientPrescriptions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
Future<String> _getDoctorName(String doctorId) async {
  try {
    if (doctorId.isEmpty || doctorId == 'Unknown Doctor') {
      return 'Unknown Doctor';
    }
    
    final doctorDoc = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(doctorId)
        .get();
    
    if (doctorDoc.exists) {
      final doctorData = doctorDoc.data();
      final doctorName = doctorData?['fullname'] ?? 
                        doctorData?['name'] ?? 
                        doctorData?['displayName'] ?? 
                        'Dr. $doctorId';
      return doctorName;
    } else {
      return 'Dr. $doctorId';
    }
  } catch (e) {
    debugPrint('Error fetching doctor name: $e');
    return 'Dr. $doctorId';
  }
}
Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
  final doctorId = prescription['doctorId'] ?? 'Unknown Doctor';
  final medicalCenter = prescription['medicalCenter'] ?? 'Unknown Medical Center';
  final createdAt = prescription['createdAt'] ?? prescription['date'] ?? DateTime.now().millisecondsSinceEpoch;
  final medicines = prescription['medicines'] ?? [];
  final prescriptionImageUrl = prescription['prescriptionImageUrl'];
  final status = prescription['status'] ?? 'unknown';

  // Debug: Print medicine data to see what's available
  print('🔍 DEBUG: Medicines array: $medicines');
  if (medicines.isNotEmpty) {
    print('🔍 DEBUG: First medicine: ${medicines.first}');
    print('🔍 DEBUG: First medicine duration: ${medicines.first['duration']}');
  }

  return FutureBuilder<String>(
    future: _getDoctorName(doctorId),
    builder: (context, snapshot) {
      final doctorName = snapshot.data ?? 'Loading...';
      
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Doctor and Medical Center
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicalCenter,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18A3B6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctorName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${_formatDate(createdAt)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Duration Section Only
              if (medicines.isNotEmpty) ...[
                const Text(
                  'Treatment Duration:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF18A3B6),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Show only duration for each medicine
                ...medicines.map<Widget>((med) {
                  final medicineName = med['name'] ?? 'Unknown Medicine';
                  final duration = med['duration'] ?? 'Duration not specified';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medication, color: Color(0xFF18A3B6), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicineName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF18A3B6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Duration: $duration',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No medications specified in this prescription',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  if (prescriptionImageUrl != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility, size: 16),
                        onPressed: () => _viewPrescriptionImage(prescriptionImageUrl),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                        ),
                        label: const Text('View Original Rx'),
                      ),
                    ),
                  if (prescriptionImageUrl != null) const SizedBox(width: 8),
                 Expanded(
  child: ElevatedButton.icon(
    icon: const Icon(Icons.medical_services, size: 16),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PharmacyDispensingScreen( 
            prescription: prescription,
            patientData: _patientDetails ?? widget.patientData,
            pharmacyId: widget.pharmacyId,
            pharmacyName: widget.pharmacyName,
          ),
        ),
      ).then((success) {
        if (success == true) {
          // Refresh prescriptions if needed after dispensing
          _loadPatientPrescriptions();
        }
      });
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF18A3B6),
      foregroundColor: Colors.white,
    ),
    label: const Text('Dispense Medication'),
  ),
),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
      } else if (timestamp is int) {
        return DateFormat('MMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
      } else if (timestamp is String) {
        return timestamp;
      }
      return 'Unknown date';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getStatusColor(dynamic status) {
    // Normalize and handle nulls/different types
    final s = (status ?? 'unknown').toString().toLowerCase();

    switch (s) {
      case 'approved':
      case 'active':
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'in review':
        return Colors.orange;
      case 'rejected':
      case 'cancelled':
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _viewPrescriptionImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Prescription Image'),
              backgroundColor: const Color(0xFF18A3B6),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 50),
                        SizedBox(height: 16),
                        Text('Failed to load image'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}