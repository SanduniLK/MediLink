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

  

  @override
  void initState() {
    super.initState();
    
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
      
      final selectedPatient = widget.patients.firstWhere(
        (patient) => patient['uid'] == _selectedPatientId,
      );

      debugPrint('📋 Patient: ${selectedPatient['fullname']}');
      debugPrint('📋 Test: ${_testNameController.text}');

      

      await TestReportService.addTestReport(
        patientId: _selectedPatientId!,
        patientName: selectedPatient['fullname'],
        medicalCenterId: widget.medicalCenterId,
        medicalCenterName: widget.medicalCenterName,
        testName: _testNameController.text,
        testType: _testTypeController.text,
        description: _descriptionController.text,
        platformFile: _selectedFile!,
        testDate: _selectedDate,
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

  

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF18A3B6), Color(0xFF2EC4B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 40,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload Test Report',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    widget.medicalCenterName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Selection
                        _buildSectionHeader('Patient Information', Icons.person_outline),
                        _buildCard(
                          DropdownButtonFormField<String>(
                            value: _selectedPatientId,
                            decoration: const InputDecoration(
                              labelText: 'Select Patient *',
                              border: InputBorder.none,
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                            ),
                            items: widget.patients.map<DropdownMenuItem<String>>((patient) {
                              return DropdownMenuItem<String>(
                                value: patient['uid'],
                                child: Text(
                                  '${patient['fullname']} - ${patient['mobile']}',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF18A3B6)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Test Details
                        _buildSectionHeader('Test Details', Icons.description_outlined),
                        _buildCard(
                          Column(
                            children: [
                              TextFormField(
                                controller: _testNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Test Name *',
                                  border: InputBorder.none,
                                  hintText: 'e.g., Complete Blood Count',
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter test name';
                                  }
                                  return null;
                                },
                              ),
                              const Divider(height: 20),
                              TextFormField(
                                controller: _testTypeController,
                                decoration: const InputDecoration(
                                  labelText: 'Test Type *',
                                  border: InputBorder.none,
                                  hintText: 'e.g., Blood Test, Urine Test',
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter test type';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Date and Status
                        _buildSectionHeader('Test Information', Icons.info_outline),
                        _buildCard(
                          Column(
                            children: [
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
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Test Date *',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(_selectedDate),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(Icons.calendar_today, color: Colors.grey.shade400),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 20),
                              // Status
                              DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Result Status *',
                                  border: InputBorder.none,
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'normal',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                                        SizedBox(width: 8),
                                        Text('Normal'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'abnormal',
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning, color: Colors.orange, size: 18),
                                        SizedBox(width: 8),
                                        Text('Abnormal'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'critical',
                                    child: Row(
                                      children: [
                                        Icon(Icons.error, color: Colors.red, size: 18),
                                        SizedBox(width: 8),
                                        Text('Critical'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStatus = value;
                                  });
                                },
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF18A3B6)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // File Upload
                        _buildSectionHeader('Attachment', Icons.attach_file),
                        _buildCard(
                          InkWell(
                            onTap: _pickFile,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    _selectedFile != null ? Icons.check_circle : Icons.cloud_upload,
                                    size: 48,
                                    color: _selectedFile != null ? Colors.green : Color(0xFF18A3B6),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedFile?.name ?? 'Tap to upload test report',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedFile != null ? Colors.green : Colors.grey.shade700,
                                    ),
                                  ),
                                  if (_selectedFile != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Size: ${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Supports: PDF, DOC, JPG, PNG',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Description
                        _buildSectionHeader('Description', Icons.notes_outlined),
                        _buildCard(
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Test Description',
                              border: InputBorder.none,
                              hintText: 'Brief description of the test...',
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                            ),
                            maxLines: 3,
                          ),
                        ),

                        const SizedBox(height: 20),

                        
                              
                            
                          
                        

                        const SizedBox(height: 20),

                        // Notes
                        _buildSectionHeader('Additional Notes', Icons.comment_outlined),
                        _buildCard(
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes & Recommendations',
                              border: InputBorder.none,
                              hintText: 'Any additional comments or recommendations...',
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                            ),
                            maxLines: 3,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadTestReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF18A3B6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        shadowColor: const Color(0xFF18A3B6).withOpacity(0.3),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload, size: 18),
                                SizedBox(width: 6),
                                Text('Upload', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF18A3B6)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF18A3B6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _testTypeController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
   
    super.dispose();
  }
}