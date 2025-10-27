
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/doctor_medical_records_service.dart';

class DoctorMedicalHistoryScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorMedicalHistoryScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorMedicalHistoryScreen> createState() => _DoctorMedicalHistoryScreenState();
}

class _DoctorMedicalHistoryScreenState extends State<DoctorMedicalHistoryScreen> {
  final DoctorMedicalRecordsService _recordsService = DoctorMedicalRecordsService();
  final Map<String, bool> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medical History - ${widget.patientName}'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _recordsService.getAllPatientMedicalRecords(widget.patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading medical records: ${snapshot.error}'));
          }

          final allRecords = snapshot.data ?? {
            'lab_results': [],
            'past_prescriptions': [],
            'other': [],
          };

          final int totalRecords = allRecords['lab_results']!.length +
                                 allRecords['past_prescriptions']!.length +
                                 allRecords['other']!.length;

          if (totalRecords == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No Medical Records Found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${widget.patientName} has not uploaded any medical records yet',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Patient Summary Card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFF18A3B6),
                        radius: 30,
                        child: Text(
                          widget.patientName[0].toUpperCase(),
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        widget.patientName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Total Medical Records: $totalRecords',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Lab Results Section
              if (allRecords['lab_results']!.isNotEmpty)
                _buildCategorySection(
                  category: 'lab_results',
                  records: allRecords['lab_results']!,
                  title: 'Lab Test Results',
                  icon: '🧪',
                ),
              
              // Prescriptions Section
              if (allRecords['past_prescriptions']!.isNotEmpty)
                _buildCategorySection(
                  category: 'past_prescriptions',
                  records: allRecords['past_prescriptions']!,
                  title: 'Past Prescriptions',
                  icon: '💊',
                ),
              
              // Other Records Section
              if (allRecords['other']!.isNotEmpty)
                _buildCategorySection(
                  category: 'other',
                  records: allRecords['other']!,
                  title: 'Other Medical Records',
                  icon: '📁',
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategorySection({
    required String category,
    required List<Map<String, dynamic>> records,
    required String title,
    required String icon,
  }) {
    final bool isExpanded = _expandedCategories[category] ?? false;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedCategories[category] = expanded;
          });
        },
        leading: Text(icon, style: TextStyle(fontSize: 24)),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('${records.length} file${records.length == 1 ? '' : 's'}'),
        trailing: Chip(
          label: Text('${records.length}'),
          backgroundColor: Color(0xFF18A3B6),
          labelStyle: TextStyle(color: Colors.white),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: records.map((record) => _buildRecordItem(record)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildFileIcon(record['fileName']),
        title: Text(
          record['fileName'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uploaded: ${DateFormat('MMM dd, yyyy - HH:mm').format(record['uploadDate'])}'),
            Text(_recordsService.getFileSizeString(record['fileSize'])),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.download, color: Color(0xFF18A3B6)),
          onPressed: () => _downloadRecord(record),
          tooltip: 'Download',
        ),
      ),
    );
  }

  Widget _buildFileIcon(String fileName) {
    final String extension = fileName.split('.').last.toLowerCase();
    final Color iconColor = Color(0xFF18A3B6);

    if (extension == 'pdf') {
      return Icon(Icons.picture_as_pdf, size: 32, color: iconColor);
    } else if (['jpg', 'jpeg', 'png'].contains(extension)) {
      return Icon(Icons.image, size: 32, color: iconColor);
    } else {
      return Icon(Icons.insert_drive_file, size: 32, color: iconColor);
    }
  }

  Future<void> _downloadRecord(Map<String, dynamic> record) async {
    try {
      // For web, open in new tab
      if (kIsWeb) {
        if (await canLaunchUrl(Uri.parse(record['fileUrl']))) {
          await launchUrl(Uri.parse(record['fileUrl']));
        }
        return;
      }

      // For mobile, download and open
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/${record['fileName']}');

      final http.Response response = await http.get(Uri.parse(record['fileUrl']));
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
}