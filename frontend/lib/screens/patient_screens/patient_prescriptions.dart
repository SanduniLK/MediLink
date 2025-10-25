import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientPrescriptionsScreen extends StatefulWidget {
  final String patientId;

  const PatientPrescriptionsScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  State<PatientPrescriptionsScreen> createState() => _PatientPrescriptionsScreenState();
}

class _PatientPrescriptionsScreenState extends State<PatientPrescriptionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // 'all', 'dispensed', 'not_dispensed'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5), // Very light blue
      appBar: AppBar(
        title: const Text(
          'My Prescriptions',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF18A3B6), // Deep teal
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(),
          
          // Prescriptions List
          Expanded(
            child: _buildPrescriptionsList(),
          ),
        ],
      ),
    );
  }

  // Filter Section
  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF18A3B6), // Deep teal
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFilterChip('All', 'all'),
              _buildFilterChip('Dispensed', 'dispensed'),
              _buildFilterChip('Not Dispensed', 'not_dispensed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF32BACD) : const Color(0xFFB2DEE6), // Bright cyan : Soft aqua
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF18A3B6), // White : Deep teal
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Prescriptions List
  Widget _buildPrescriptionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPrescriptionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF18A3B6)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medication_outlined,
                  size: 80,
                  color: const Color(0xFF85CEDA).withOpacity(0.5), // Teal-blue
                ),
                const SizedBox(height: 16),
                const Text(
                  'No prescriptions found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF18A3B6), // Deep teal
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFilter == 'all' 
                    ? 'You have no prescriptions yet'
                    : 'No ${_selectedFilter.replaceAll('_', ' ')} prescriptions',
                  style: const TextStyle(
                    color: Color(0xFF32BACD), // Bright cyan
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var prescription = doc.data() as Map<String, dynamic>;
            
            return _buildPrescriptionCard(doc.id, prescription);
          },
        );
      },
    );
  }

  // Firestore Query Stream
  Stream<QuerySnapshot> _getPrescriptionsStream() {
    Query query = _firestore
        .collection('prescriptions')
        .where('sharedPharmacies', arrayContains: widget.patientId)
        .orderBy('createdAt', descending: true);

    // Apply status filter
    if (_selectedFilter == 'dispensed') {
      query = query.where('status', isEqualTo: 'dispensed');
    } else if (_selectedFilter == 'not_dispensed') {
      query = query.where('status', whereIn: ['pending', 'active', 'completed']);
    }

    return query.snapshots();
  }

  // Prescription Card Widget
  Widget _buildPrescriptionCard(String docId, Map<String, dynamic> prescription) {
    final isDispensed = prescription['status'] == 'dispensed';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prescription #${docId.substring(docId.length - 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF18A3B6), // Deep teal
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDispensed ? const Color(0xFF85CEDA) : const Color(0xFFB2DEE6), // Teal-blue : Soft aqua
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    prescription['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      color: isDispensed ? Colors.white : const Color(0xFF18A3B6), // White : Deep teal
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Date
            if (prescription['createdAt'] != null)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: const Color(0xFF32BACD)), // Bright cyan
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(prescription['createdAt']),
                    style: const TextStyle(
                      color: Color(0xFF18A3B6), // Deep teal
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 8),
            
            // Doctor ID (you might want to fetch doctor name instead)
            if (prescription['doctorId'] != null)
              Row(
                children: [
                  Icon(Icons.medical_services, size: 16, color: const Color(0xFF32BACD)), // Bright cyan
                  const SizedBox(width: 8),
                  Text(
                    'Dr. ${_formatDoctorId(prescription['doctorId'])}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            
            const SizedBox(height: 8),
            
            // Diagnosis
            if (prescription['diagnosis'] != null && prescription['diagnosis'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diagnosis:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6), // Deep teal
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prescription['diagnosis'],
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            
            const SizedBox(height: 12),
            
            // Medications
            if (prescription['medicines'] != null && (prescription['medicines'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medications:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6), // Deep teal
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildMedicationsList(prescription['medicines']),
                ],
              ),
            
            const SizedBox(height: 12),
            
            // Description
            if (prescription['description'] != null && prescription['description'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6), // Deep teal
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prescription['description'],
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Build medications list
  List<Widget> _buildMedicationsList(dynamic medications) {
    if (medications is List) {
      return medications.map<Widget>((med) {
        final medicine = med as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF0F5), // Very light blue
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💊 ${medicine['name'] ?? 'Unknown Medicine'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18A3B6), // Deep teal
                ),
              ),
              if (medicine['dosage'] != null) 
                Text('Dosage: ${medicine['dosage']}'),
              if (medicine['frequency'] != null) 
                Text('Frequency: ${medicine['frequency']}'),
              if (medicine['duration'] != null) 
                Text('Duration: ${medicine['duration']}'),
              if (medicine['instructions'] != null) 
                Text('Instructions: ${medicine['instructions']}'),
            ],
          ),
        );
      }).toList();
    }
    return [const Text('No medications listed')];
  }

  // Format timestamp to readable date
  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return '${date.day}/${date.month}/${date.year}';
      } else if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Unknown date';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Format doctor ID (you might want to fetch actual doctor name)
  String _formatDoctorId(String doctorId) {
    if (doctorId.length > 8) {
      return '${doctorId.substring(0, 4)}...${doctorId.substring(doctorId.length - 4)}';
    }
    return doctorId;
  }
}