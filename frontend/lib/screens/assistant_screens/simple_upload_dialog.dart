// Create this as a new file: lib/screens/admin_screens/simple_upload_dialog.dart
import 'package:flutter/material.dart';

class SimpleUploadDialog extends StatefulWidget {
  final List<Map<String, dynamic>> patients;
  final String medicalCenterId;
  final String medicalCenterName;

  const SimpleUploadDialog({
    super.key,
    required this.patients,
    required this.medicalCenterId,
    required this.medicalCenterName,
  });

  @override
  State<SimpleUploadDialog> createState() => _SimpleUploadDialogState();
}

class _SimpleUploadDialogState extends State<SimpleUploadDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    print('🟡 SimpleUploadDialog building...');
    
    return AlertDialog(
      title: const Text('Upload Test Report'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a patient and upload file'),
            const SizedBox(height: 20),
            if (widget.patients.isNotEmpty)
              DropdownButtonFormField<String>(
                items: widget.patients.take(3).map((patient) {
                  return DropdownMenuItem<String>(
                    value: patient['id']?.toString(),
                    child: Text(patient['fullname']?.toString() ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (value) {
                  print('🟡 Patient selected: $value');
                },
                decoration: const InputDecoration(
                  labelText: 'Patient',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('🟡 File picker button clicked');
              },
              child: const Text('Select File'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            print('🟡 Cancel button clicked');
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  print('🟡 Upload button clicked');
                  setState(() {
                    _isLoading = true;
                  });
                  
                  // Simulate upload
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Upload successful!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  });
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }
}