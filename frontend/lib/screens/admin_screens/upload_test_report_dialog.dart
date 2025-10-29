// lib/screens/admin_screens/upload_test_report_dialog.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../services/test_report_service.dart';

class UploadTestReportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> patients;
  final String medicalCenterId;
  final String medicalCenterName;
  final VoidCallback onReportUploaded;

  const UploadTestReportDialog({
    super.key,
    required this.patients,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.onReportUploaded,
  });

  @override
  State<UploadTestReportDialog> createState() => _UploadTestReportDialogState();
}

class _UploadTestReportDialogState extends State<UploadTestReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _testNameController = TextEditingController();
  final TextEditingController _testTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedPatientId;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStatus = 'normal';
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  // Lab findings fields
  final Map<String, TextEditingController> _labFindingsControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize with some common lab findings
    _initializeLabFindings();
  }

  void _initializeLabFindings() {
    final commonFindings = ['Hemoglobin', 'WBC Count', 'RBC Count', 'Platelets', 'Glucose'];
    for (final finding in commonFindings) {
      _labFindingsControllers[finding] = TextEditingController();
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

 Future<void> _uploadTestReport() async {
  if (_selectedPatientId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a patient')),
    );
    return;
  }

  if (_selectedFile == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a test report file')),
    );
    return;
  }

  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isUploading = true;
  });

  try {
    debugPrint('🚀 Starting upload process...');
    
    // Get selected patient details
    final selectedPatient = widget.patients.firstWhere(
      (patient) => patient['uid'] == _selectedPatientId,
    );

    debugPrint('📋 Patient: ${selectedPatient['fullname']}');
    debugPrint('📋 Test: ${_testNameController.text}');

    // Prepare lab findings
    final Map<String, dynamic> labFindings = {};
    for (final entry in _labFindingsControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        labFindings[entry.key] = entry.value.text;
      }
    }

    debugPrint('🔬 Lab findings: ${labFindings.length} items');

    // Upload test report - NOW USING PlatformFile DIRECTLY
    await TestReportService.addTestReport(
      patientId: _selectedPatientId!,
      patientName: selectedPatient['fullname'],
      medicalCenterId: widget.medicalCenterId,
      medicalCenterName: widget.medicalCenterName,
      testName: _testNameController.text,
      testType: _testTypeController.text,
      description: _descriptionController.text,
      platformFile: _selectedFile!, // Pass PlatformFile directly
      testDate: _selectedDate,
      labFindings: labFindings,
      status: _selectedStatus!,
      notes: _notesController.text,
    );

    debugPrint('✅ Upload completed successfully!');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test report uploaded successfully!')),
      );
    }

    widget.onReportUploaded();
    
    if (mounted) {
      Navigator.pop(context);
    }

  } catch (e) {
    debugPrint('❌ Upload failed: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isUploading = false;
      });
    }
  }
}

  void _addLabFinding() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Lab Finding'),
        content: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Finding Name',
            hintText: 'e.g., Cholesterol Level',
          ),
          onFieldSubmitted: (value) {
            if (value.isNotEmpty && !_labFindingsControllers.containsKey(value)) {
              setState(() {
                _labFindingsControllers[value] = TextEditingController();
              });
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - Fixed
              const Text(
                'Upload Test Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18A3B6),
                ),
              ),
              const SizedBox(height: 20),
              
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Selection
                        DropdownButtonFormField<String>(
                          value: _selectedPatientId,
                          decoration: const InputDecoration(
                            labelText: 'Select Patient *',
                            border: OutlineInputBorder(),
                          ),
                          items: widget.patients.map<DropdownMenuItem<String>>((patient) {
                            return DropdownMenuItem<String>(
                              value: patient['uid'],
                              child: Text('${patient['fullname']} - ${patient['mobile']}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPatientId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a patient';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Test Details
                        TextFormField(
                          controller: _testNameController,
                          decoration: const InputDecoration(
                            labelText: 'Test Name *',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., Complete Blood Count',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter test name';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _testTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Test Type *',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., Blood Test, Urine Test',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter test type';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Test Date
                        InkWell(
                          onTap: () async {
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (selectedDate != null) {
                              setState(() {
                                _selectedDate = selectedDate;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Test Date *',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                                const Icon(Icons.calendar_today),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Status
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Result Status *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'abnormal', child: Text('Abnormal')),
                            DropdownMenuItem(value: 'critical', child: Text('Critical')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // File Upload
                        InkWell(
                          onTap: _pickFile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFile?.name ?? 'Click to upload test report file',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedFile != null ? Colors.green : Colors.grey.shade600,
                                    fontWeight: _selectedFile != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (_selectedFile != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Size: ${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            hintText: 'Brief description of the test...',
                          ),
                          maxLines: 2,
                        ),

                        const SizedBox(height: 16),

                        // Lab Findings Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Lab Findings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _addLabFinding,
                                      tooltip: 'Add Lab Finding',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._labFindingsControllers.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: entry.value,
                                            decoration: InputDecoration(
                                              labelText: entry.key,
                                              border: const OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _labFindingsControllers.remove(entry.key);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Additional Notes',
                            border: OutlineInputBorder(),
                            hintText: 'Any additional comments or recommendations...',
                          ),
                          maxLines: 3,
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Actions - Fixed at bottom
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadTestReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF18A3B6),
                        foregroundColor: Colors.white,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Upload Report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _testTypeController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    for (final controller in _labFindingsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}