// screens/doctor_screens/report_generation_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/report_model.dart';
import 'package:intl/intl.dart';

import '../../services/report_service.dart';

class ReportGenerationScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? appointmentId;
  final String? scheduleId;

  const ReportGenerationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.appointmentId,
    this.scheduleId,
  });

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  final ReportService _reportService = ReportService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _treatmentController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  String _selectedReportType = 'prescription';
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _tests = [];
  bool _isGenerating = false;

  final List<String> _reportTypes = [
    'prescription',
    'lab_request',
    'diagnosis',
    'medical_certificate',
    'referral',
    'summary',
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Medical Report for ${widget.patientName}';
  }

  void _addMedication() {
    showDialog(
      context: context,
      builder: (context) => MedicationDialog(
        onSave: (medication) {
          setState(() {
            _medications.add(medication);
          });
        },
      ),
    );
  }

  void _addTest() {
    showDialog(
      context: context,
      builder: (context) => TestDialog(
        onSave: (test) {
          setState(() {
            _tests.add(test);
          });
        },
      ),
    );
  }

  Future<void> _generateReport() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Get current user (doctor)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get doctor info
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .get();
      
      final doctorName = doctorDoc.data()?['fullname'] ?? 'Doctor';

      // Create report data based on type
      Map<String, dynamic> reportData = {
        'diagnosis': _diagnosisController.text,
        'treatment': _treatmentController.text,
        'notes': _notesController.text,
        'medications': _medications,
        'tests': _tests,
        'generatedDate': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      };

      // Create report object
      final report = MedicalReport(
        id: '',
        patientId: widget.patientId,
        patientName: widget.patientName,
        doctorId: user.uid,
        doctorName: doctorName,
        reportType: _selectedReportType,
        title: _titleController.text,
        data: reportData,
        createdAt: DateTime.now(),
        appointmentId: widget.appointmentId,
        scheduleId: widget.scheduleId,
      );

      // Save report
      final reportId = await _reportService.generateReport(report);

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generated successfully! ID: $reportId'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back or show preview
        Navigator.pop(context, reportId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Medical Report'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: () {
              // Preview report
              _previewReport();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF18A3B6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text('Patient ID: ${widget.patientId}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Report Type
            _buildSectionTitle('Report Type'),
            DropdownButtonFormField<String>(
              value: _selectedReportType,
              items: _reportTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_formatReportType(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedReportType = value!;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Select Report Type',
              ),
            ),

            const SizedBox(height: 20),

            // Report Title
            _buildSectionTitle('Report Title'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Report Title',
                hintText: 'Enter report title',
              ),
            ),

            const SizedBox(height: 20),

            // Diagnosis
            _buildSectionTitle('Diagnosis'),
            TextField(
              controller: _diagnosisController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Diagnosis',
                hintText: 'Enter diagnosis details',
              ),
            ),

            const SizedBox(height: 20),

            // Treatment
            _buildSectionTitle('Treatment Plan'),
            TextField(
              controller: _treatmentController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Treatment',
                hintText: 'Enter treatment details',
              ),
            ),

            const SizedBox(height: 20),

            // Medications Section
            _buildSectionTitle('Medications'),
            if (_medications.isNotEmpty) ...[
              ..._medications.map((med) => _buildMedicationItem(med)),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.add),
              label: const Text('Add Medication'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // Tests Section
            _buildSectionTitle('Lab Tests'),
            if (_tests.isNotEmpty) ...[
              ..._tests.map((test) => _buildTestItem(test)),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              onPressed: _addTest,
              icon: const Icon(Icons.add),
              label: const Text('Add Lab Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // Notes
            _buildSectionTitle('Additional Notes'),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notes',
                hintText: 'Any additional notes or instructions',
              ),
            ),

            const SizedBox(height: 30),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'GENERATE REPORT',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF18A3B6),
        ),
      ),
    );
  }

  Widget _buildMedicationItem(Map<String, dynamic> medication) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.medication, color: Colors.blue),
        title: Text(medication['name']),
        subtitle: Text('${medication['dosage']} - ${medication['frequency']}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              _medications.remove(medication);
            });
          },
        ),
      ),
    );
  }

  Widget _buildTestItem(Map<String, dynamic> test) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.science, color: Colors.orange),
        title: Text(test['testName']),
        subtitle: Text(test['instructions'] ?? 'No special instructions'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              _tests.remove(test);
            });
          },
        ),
      ),
    );
  }

  String _formatReportType(String type) {
    switch (type) {
      case 'prescription':
        return 'Prescription';
      case 'lab_request':
        return 'Lab Test Request';
      case 'diagnosis':
        return 'Diagnosis Report';
      case 'medical_certificate':
        return 'Medical Certificate';
      case 'referral':
        return 'Referral Letter';
      case 'summary':
        return 'Medical Summary';
      default:
        return type;
    }
  }

  void _previewReport() {
    // Show preview of the report
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${widget.patientName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Report Type: ${_formatReportType(_selectedReportType)}'),
              if (_diagnosisController.text.isNotEmpty)
                Text('Diagnosis: ${_diagnosisController.text}'),
              if (_medications.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Medications:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._medications.map((m) => Text('• ${m['name']} - ${m['dosage']}')),
                  ],
                ),
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
}

// Medication Dialog
class MedicationDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const MedicationDialog({super.key, required this.onSave});

  @override
  State<MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<MedicationDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Medication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medication Name'),
            ),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(labelText: 'Dosage (e.g., 500mg)'),
            ),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(labelText: 'Frequency (e.g., 2 times daily)'),
            ),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (e.g., 7 days)'),
            ),
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(labelText: 'Special Instructions'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final medication = {
              'name': _nameController.text,
              'dosage': _dosageController.text,
              'frequency': _frequencyController.text,
              'duration': _durationController.text,
              'instructions': _instructionsController.text,
            };
            widget.onSave(medication);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Test Dialog
class TestDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const TestDialog({super.key, required this.onSave});

  @override
  State<TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends State<TestDialog> {
  final TextEditingController _testNameController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Lab Test'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _testNameController,
              decoration: const InputDecoration(labelText: 'Test Name'),
            ),
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(labelText: 'Special Instructions'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final test = {
              'testName': _testNameController.text,
              'instructions': _instructionsController.text,
            };
            widget.onSave(test);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}