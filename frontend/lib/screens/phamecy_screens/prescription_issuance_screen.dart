import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PrescriptionIssuanceScreen extends StatefulWidget {
  final Map<String, dynamic> prescription;
  final Map<String, dynamic> patientData;
  final String pharmacyId;
  final String pharmacyName;
  final int monthToIssue;

  const PrescriptionIssuanceScreen({
    super.key,
    required this.prescription,
    required this.patientData,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.monthToIssue,
  });

  @override
  State<PrescriptionIssuanceScreen> createState() => _PrescriptionIssuanceScreenState();
}

class _PrescriptionIssuanceScreenState extends State<PrescriptionIssuanceScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isIssuing = false;

  // Convert duration string to months for tracking
  int _getDurationInMonths(String duration) {
    if (duration.toLowerCase().contains('month')) {
      return int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    } else if (duration.toLowerCase().contains('day')) {
      final days = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 7;
      return (days / 30).ceil(); // Convert days to approximate months
    }
    return 1; // Default to 1 month
  }

  Future<void> _issueMedication() async {
    if (_isIssuing) return;

    setState(() => _isIssuing = true);

    try {
      final recordId = FirebaseFirestore.instance.collection('issuanceRecords').doc().id;
      final medicines = widget.prescription['medicines'] ?? [];
      final totalDuration = _getDurationInMonths(widget.prescription['duration'] ?? '7 days');
      
      final issuanceRecord = {
        'recordId': recordId,
        'prescriptionId': widget.prescription['prescriptionId'] ?? widget.prescription['id'],
        'patientId': widget.patientData['patientId'] ?? widget.patientData['id'],
        'patientMobile': widget.patientData['mobileNumber'] ?? 'Not provided',
        'patientName': widget.patientData['fullName'] ?? 'Unknown Patient',
        'pharmacyId': widget.pharmacyId,
        'pharmacyName': widget.pharmacyName,
        'issuanceDate': Timestamp.now(),
        'monthIssued': widget.monthToIssue,
        'totalDuration': totalDuration,
        'medicationsIssued': medicines.map((med) => {
          'name': med['name'] ?? 'Unknown',
          'dosage': med['dosage'] ?? '',
          'frequency': med['frequency'] ?? '',
          'quantityIssued': _calculateQuantity(med),
          'instructions': med['instructions'] ?? '',
        }).toList(),
        'issuedBy': widget.pharmacyName,
        'notes': _notesController.text.trim(),
        'createdAt': Timestamp.now(),
      };

      // Save issuance record
      await FirebaseFirestore.instance
          .collection('issuanceRecords')
          .doc(recordId)
          .set(issuanceRecord);

      // Update prescription status if this is the last month
      if (widget.monthToIssue >= totalDuration) {
        await FirebaseFirestore.instance
            .collection('prescriptions')
            .doc(widget.prescription['prescriptionId'] ?? widget.prescription['id'])
            .update({'status': 'completed'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication issued successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to patient profile
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error issuing medication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isIssuing = false);
    }
  }

  // Calculate quantity based on duration and frequency
  int _calculateQuantity(Map<String, dynamic> medication) {
    final duration = widget.prescription['duration'] ?? '7 days';
    final frequency = medication['frequency'] ?? '';
    
    // Simple calculation - you can make this more sophisticated
    if (duration.toLowerCase().contains('day')) {
      final days = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 7;
      if (frequency.toLowerCase().contains('daily')) {
        return days;
      } else if (frequency.toLowerCase().contains('twice')) {
        return days * 2;
      } else if (frequency.toLowerCase().contains('thrice')) {
        return days * 3;
      }
    }
    
    // Default quantity
    return 30; // Assume 30 units per month
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    } else if (timestamp is int) {
      return DateFormat('MMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    }
    return 'Unknown date';
  }

  @override
  Widget build(BuildContext context) {
    final medicines = widget.prescription['medicines'] ?? [];
    final totalDuration = _getDurationInMonths(widget.prescription['duration'] ?? '7 days');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Medication'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF18A3B6),
                      child: Text(
                        widget.patientData['fullName']?[0] ?? 'P',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patientData['fullName'] ?? 'Unknown Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(widget.patientData['mobileNumber'] ?? 'No mobile number'),
                          if (widget.patientData['age'] != null)
                            Text('Age: ${widget.patientData['age']}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Prescription Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prescription Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Doctor ID: ${widget.prescription['doctorId'] ?? 'Unknown'}'),
                    Text('Medical Center: ${widget.prescription['medicalCenter'] ?? 'Unknown'}'),
                    Text('Month: ${widget.monthToIssue} of $totalDuration'),
                    Text('Duration: ${widget.prescription['duration'] ?? "7 days"}'),
                    Text('Issue Date: ${_formatDate(widget.prescription['createdAt'])}'),
                    if (widget.prescription['diagnosis'] != null)
                      Text('Diagnosis: ${widget.prescription['diagnosis']}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Medications to Issue
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medications to Issue - Month ${widget.monthToIssue}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...medicines.map<Widget>((medication) => 
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  medication['name'] ?? 'Unknown Medicine',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF18A3B6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Qty: ${_calculateQuantity(medication)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF18A3B6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (medication['dosage'] != null)
                              Text('Dosage: ${medication['dosage']}'),
                            if (medication['frequency'] != null)
                              Text('Frequency: ${medication['frequency']}'),
                            if (medication['instructions'] != null && medication['instructions'].isNotEmpty)
                              Text('Instructions: ${medication['instructions']}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Issuance Notes (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add any notes about this issuance...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isIssuing ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isIssuing ? null : _issueMedication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18A3B6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isIssuing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Confirm Issuance',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This will record the issuance for Month ${widget.monthToIssue}. '
                'Patient will need to wait 28 days before the next month can be issued.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}