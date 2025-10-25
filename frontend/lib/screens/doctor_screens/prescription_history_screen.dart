// screens/doctor_screens/prescription_history_screen.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/model/prescription_model.dart';
import 'package:intl/intl.dart';

class PrescriptionHistoryScreen extends StatefulWidget {
  const PrescriptionHistoryScreen({super.key});

  @override
  State<PrescriptionHistoryScreen> createState() => _PrescriptionHistoryScreenState();
}

class _PrescriptionHistoryScreenState extends State<PrescriptionHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Prescription> _prescriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('prescriptions')
          .where('doctorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _prescriptions = querySnapshot.docs
            .map((doc) => Prescription.fromMap(doc.data()))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading prescriptions: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('Prescription History'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prescriptions.isEmpty
              ? const Center(child: Text('No prescriptions found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _prescriptions.length,
                  itemBuilder: (context, index) {
                    final prescription = _prescriptions[index];
                    return _buildPrescriptionCard(prescription);
                  },
                ),
    );
  }

  Widget _buildPrescriptionCard(Prescription prescription) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  prescription.patientName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(prescription.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    prescription.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(prescription.date)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Medicines: ${prescription.medicines.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (prescription.sharedPharmacies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Shared with ${prescription.sharedPharmacies.length} pharmacy(s)',
                style: TextStyle(color: Colors.green[700]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewPrescriptionDetails(prescription),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sharePrescription(prescription),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18A3B6),
                    ),
                    child: const Text(
                      'Share Again',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'shared':
        return Colors.green;
      case 'dispensed':
        return Colors.blue;
      case 'completed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _viewPrescriptionDetails(Prescription prescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prescription for ${prescription.patientName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: ${DateFormat('MMM dd, yyyy').format(prescription.date)}'),
              Text('Diagnosis: ${prescription.diagnosis ?? 'Not specified'}'),
              const SizedBox(height: 16),
              const Text(
                'Medicines:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...prescription.medicines.map((medicine) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${medicine.name}'),
                    Text('  Dosage: ${medicine.dosage}'),
                    Text('  Duration: ${medicine.duration}'),
                    if (medicine.frequency?.isNotEmpty ?? false)
                      Text('  Frequency: ${medicine.frequency}'),
                  ],
                ),
              )),
            ],
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

  void _sharePrescription(Prescription prescription) {
    // Implement re-sharing logic
  }
}