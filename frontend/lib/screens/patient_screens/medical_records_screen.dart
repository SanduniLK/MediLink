// screens/patient_screens/medical_records_screen.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/model/medical_record.dart';
import 'package:frontend/services/medical_records_service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';


class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final MedicalRecordsService _recordsService = MedicalRecordsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RecordCategory _selectedCategory = RecordCategory.labResults;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Please login to view medical records')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Medical Records'),
          backgroundColor: Color(0xFF18A3B6),
          foregroundColor: Colors.white,
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.science),
                text: 'Lab Results',
              ),
              Tab(
                icon: Icon(Icons.medication),
                text: 'Prescriptions',
              ),
              Tab(
                icon: Icon(Icons.folder),
                text: 'Other',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRecordsList(user.uid, RecordCategory.labResults),
            _buildRecordsList(user.uid, RecordCategory.pastPrescriptions),
            _buildRecordsList(user.uid, RecordCategory.other),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showUploadDialog,
          child: Icon(Icons.upload),
          backgroundColor: Color(0xFF18A3B6),
        ),
      ),
    );
  }

  Widget _buildRecordsList(String patientId, RecordCategory category) {
    return StreamBuilder<List<MedicalRecord>>(
      stream: _recordsService.getPatientMedicalRecordsByCategory(patientId, category),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading records: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No ${category.displayName}',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to upload your first record',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            return _buildRecordItem(records[index]);
          },
        );
      },
    );
  }

  Widget _buildRecordItem(MedicalRecord record) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildFileIcon(record.fileType),
        title: Text(
          record.fileName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uploaded: ${DateFormat('MMM dd, yyyy').format(record.uploadDate)}'),
            if (record.description != null) Text(record.description!),
            Text(_recordsService.getFileSizeString(record.fileSize)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, color: Color(0xFF18A3B6)),
              onPressed: () => _downloadRecord(record),
              tooltip: 'Download',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRecord(record),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(String fileType) {
    final double iconSize = 32;
    final Color iconColor = Color(0xFF18A3B6);

    if (fileType == 'pdf') {
      return Icon(Icons.picture_as_pdf, size: iconSize, color: iconColor);
    } else if (['jpg', 'jpeg', 'png'].contains(fileType)) {
      return Icon(Icons.image, size: iconSize, color: iconColor);
    } else {
      return Icon(Icons.insert_drive_file, size: iconSize, color: iconColor);
    }
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload Medical Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select category for this record:'),
            SizedBox(height: 16),
            DropdownButton<RecordCategory>(
              value: _selectedCategory,
              onChanged: (RecordCategory? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
              items: RecordCategory.values.map((RecordCategory category) {
                return DropdownMenuItem<RecordCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Text(category.icon),
                      SizedBox(width: 8),
                      Text(category.displayName),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _uploadMedicalRecord,
            child: Text('Upload File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF18A3B6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadMedicalRecord() async {
    Navigator.pop(context); // Close dialog
    
    try {
      final file = await _recordsService.pickMedicalRecord();
      if (file == null) return;

      setState(() {
        _isUploading = true;
      });

      final user = _auth.currentUser!;
      final fileName = file.path.split('/').last;

      // Show description dialog
      final description = await _showDescriptionDialog();

      await _recordsService.uploadMedicalRecord(
        file: file,
        patientId: user.uid,
        fileName: fileName,
        category: _selectedCategory,
        description: description,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medical record uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading record: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<String?> _showDescriptionDialog() async {
    String? description;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Description (Optional)'),
        content: TextField(
          onChanged: (value) => description = value,
          decoration: InputDecoration(
            hintText: 'e.g., Blood Test Results - December 2024',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF18A3B6),
            ),
          ),
        ],
      ),
    );
    return description;
  }

  Future<void> _downloadRecord(MedicalRecord record) async {
    try {
      // For web, open in new tab
      if (kIsWeb) {
        if (await canLaunchUrl(Uri.parse(record.fileUrl))) {
          await launchUrl(Uri.parse(record.fileUrl));
        }
        return;
      }

      // For mobile, download and open
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/${record.fileName}');

      final http.Response response = await http.get(Uri.parse(record.fileUrl));
      await tempFile.writeAsBytes(response.bodyBytes);

      final OpenResult result = await OpenFile.open(tempFile.path);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File downloaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
    }
  }

  Future<void> _deleteRecord(MedicalRecord record) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Record'),
        content: Text('Are you sure you want to delete "${record.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _recordsService.deleteMedicalRecord(record);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Record deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting record: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}