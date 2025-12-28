import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/medical_record.dart';
import 'package:frontend/services/medical_records_service.dart';

class LabReportConfirmationScreen extends StatefulWidget {
  final MedicalRecord record;
  final Map<String, dynamic> extractedData;
  final String category;
  final String? testDate;
  final String patientId;

  const LabReportConfirmationScreen({
    super.key,
    required this.record,
    required this.extractedData,
    required this.category,
    this.testDate,
    required this.patientId,
  });

  @override
  _LabReportConfirmationScreenState createState() => _LabReportConfirmationScreenState();
}

class _LabReportConfirmationScreenState extends State<LabReportConfirmationScreen> {
  final MedicalRecordsService _recordsService = MedicalRecordsService();
  final TextEditingController _dateController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = widget.testDate ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final parameters = (widget.extractedData['parameters'] as List?) ?? [];
    final extractedText = widget.record.extractedText ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm Lab Report'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📄 ${widget.record.fileName}'),
                    SizedBox(height: 8),
                    Text('📋 ${widget.category}'),
                    SizedBox(height: 12),
                    
                    // Test Date
                    TextField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Test Date (DD/MM/YYYY)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Extracted Text
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted Text:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      constraints: BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Text(
                          extractedText.length > 1000 
                            ? '${extractedText.substring(0, 1000)}...\n\n[Full text: ${extractedText.length} characters]'
                            : extractedText,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Parameters
            if (parameters.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extracted Parameters (${parameters.length}):',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 12),
                      
                      ...parameters.asMap().entries.map((entry) {
                        final index = entry.key;
                        final param = entry.value;
                        return _buildParameterItem(index, param);
                      }).toList(),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveConfirmedData,
                    child: _isSaving
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Confirm & Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF18A3B6),
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterItem(int index, Map<String, dynamic> param) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF18A3B6).withOpacity(0.1),
              radius: 16,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18A3B6),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    param['parameter']?.toString() ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: Text('${param['value']} ${param['unit']}'),
                        backgroundColor: Colors.blue[100],
                      ),
                      SizedBox(width: 8),
                      Chip(
                        label: Text(param['normalRange']?.toString() ?? 'N/A'),
                        backgroundColor: Colors.green[100],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfirmedData() async {
    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the test date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Prepare verified parameters
      final parameters = (widget.extractedData['parameters'] as List?) ?? [];
      final verifiedResults = parameters.map((param) {
        return {
          'parameter': param['parameter']?.toString() ?? 'Unknown',
          'value': param['value'] ?? 0,
          'unit': param['unit']?.toString() ?? '',
          'normalRange': param['normalRange']?.toString() ?? 'N/A',
          'isVerified': true,
        };
      }).toList();

      // Save to Firestore using MedicalRecordsService
      await _recordsService.saveVerifiedLabReport(
        recordId: widget.record.id,
        patientId: widget.patientId,
        verifiedData: {
          'testDate': _dateController.text,
          'testCategory': widget.category,
          'results': verifiedResults,
          'verifiedAt': Timestamp.now(),
        },
        category: widget.category,
        fileName: widget.record.fileName,
        extractedText: widget.record.extractedText,
      );

      // Show success and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Lab report confirmed and saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back to medical records screen
      Navigator.pop(context); // Close confirmation screen
      Navigator.pop(context); // Close initial verification screen

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }
}