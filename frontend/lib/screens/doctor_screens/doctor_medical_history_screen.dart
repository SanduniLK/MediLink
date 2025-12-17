import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _allRecords = {
    'lab_results': [],
    'past_prescriptions': [],
    'other': [],
  };

  @override
  void initState() {
    super.initState();
    _loadMedicalRecords();
  }

  Future<void> _loadMedicalRecords() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all records
      final allRecords = await _recordsService.getAllPatientMedicalRecords(widget.patientId);
      
      // Debug: Print counts
      debugPrint('📊 Medical History Records for ${widget.patientName}:');
      debugPrint('  Lab Results: ${allRecords['lab_results']?.length ?? 0}');
      debugPrint('  Prescriptions: ${allRecords['past_prescriptions']?.length ?? 0}');
      debugPrint('  Other: ${allRecords['other']?.length ?? 0}');
      
      // Debug: List all records
      debugPrint('📝 Detailed Records:');
      for (final category in ['lab_results', 'past_prescriptions', 'other']) {
        final records = allRecords[category] ?? [];
        if (records.isNotEmpty) {
          debugPrint('  $category:');
          for (final record in records) {
            debugPrint('    - ${record['fileName']} (${record['type']})');
          }
        }
      }
      
      setState(() {
        _allRecords = allRecords;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading medical records: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medical History - ${widget.patientName}'),
        backgroundColor: Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadMedicalRecords,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final int labResultsCount = _allRecords['lab_results']!.length;
    final int prescriptionsCount = _allRecords['past_prescriptions']!.length;
    final int otherCount = _allRecords['other']!.length;
    final int totalRecords = labResultsCount + prescriptionsCount + otherCount;

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
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                  'Patient ID: ${widget.patientId}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                
                SizedBox(height: 12),
                Divider(),
                SizedBox(height: 12),
                
                // Records Summary
                Text(
                  'Medical Records Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Total', '$totalRecords', Icons.summarize, Color(0xFF18A3B6)),
                    _buildSummaryItem('Lab Results', '$labResultsCount', Icons.science, Colors.blue),
                    _buildSummaryItem('Prescriptions', '$prescriptionsCount', Icons.medication, Colors.green),
                    _buildSummaryItem('Other', '$otherCount', Icons.folder, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 20),
        
        // Lab Results Section
        if (labResultsCount > 0)
          _buildCategorySection(
            category: 'lab_results',
            records: _allRecords['lab_results']!,
            title: 'Lab Test Results',
            icon: Icons.science,
            color: Colors.blue,
            count: labResultsCount,
          ),
        
        // Prescriptions Section
        if (prescriptionsCount > 0)
          _buildCategorySection(
            category: 'past_prescriptions',
            records: _allRecords['past_prescriptions']!,
            title: 'Prescriptions',
            icon: Icons.medication,
            color: Colors.green,
            count: prescriptionsCount,
          ),
        
        // Other Records Section
        if (otherCount > 0)
          _buildCategorySection(
            category: 'other',
            records: _allRecords['other']!,
            title: 'Other Medical Records',
            icon: Icons.folder,
            color: Colors.orange,
            count: otherCount,
          ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection({
    required String category,
    required List<Map<String, dynamic>> records,
    required String title,
    required IconData icon,
    required Color color,
    required int count,
  }) {
    final bool isExpanded = _expandedCategories[category] ?? false;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedCategories[category] = expanded;
          });
        },
        leading: Icon(icon, color: color, size: 28),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('$count record${count == 1 ? '' : 's'}'),
        trailing: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
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
    final bool isFirestorePrescription = record['type'] == 'firestore_prescription';
    final bool hasPrescriptionImage = record['fileUrl'] != null && 
                                   (record['fileUrl'] as String).isNotEmpty;
    final bool isStorageFile = record['type'] == 'storage_file';
    final bool isFirestoreRecord = record['type'] == 'firestore_record';

    // Determine the date to display
    DateTime displayDate;
    if (record['uploadDate'] != null) {
      displayDate = record['uploadDate'];
    } else if (record['createdAt'] != null) {
      displayDate = record['createdAt'];
    } else {
      displayDate = DateTime.now();
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: _buildRecordIcon(record),
        
        title: Text(
          record['fileName'] ?? 'Unknown File',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show diagnosis for prescriptions
            if (isFirestorePrescription && record['diagnosis'] != null && (record['diagnosis'] as String).isNotEmpty)
              Text(
                'Diagnosis: ${record['diagnosis']}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            
            // Show source type
            Text(
              _getSourceType(record),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            
            // Date
            Text('Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(displayDate)}'),
            
            // File size for storage files
            if (isStorageFile && record['fileSize'] != null && record['fileSize'] > 0)
              Text(_recordsService.getFileSizeString(record['fileSize'])),
          ],
        ),
        
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // View details button for Firestore prescriptions
            if (isFirestorePrescription)
              IconButton(
                icon: Icon(Icons.visibility, color: Color(0xFF18A3B6)),
                onPressed: () => _showPrescriptionDetails(record),
                tooltip: 'View Details',
              ),
            
            // View image button if prescription has image
            if (hasPrescriptionImage)
              IconButton(
                icon: Icon(Icons.image, color: Colors.green),
                onPressed: () => _viewPrescriptionImage(record['fileUrl']),
                tooltip: 'View Image',
              ),
            
            // Download button for files
            if (hasPrescriptionImage || isStorageFile || isFirestoreRecord)
              IconButton(
                icon: Icon(Icons.download, color: Color(0xFF18A3B6)),
                onPressed: () => _downloadRecord(record),
                tooltip: 'Download',
              ),
          ],
        ),
        
        onTap: isFirestorePrescription 
            ? () => _showPrescriptionDetails(record)
            : (hasPrescriptionImage || isStorageFile || isFirestoreRecord)
                ? () => _downloadRecord(record)
                : null,
      ),
    );
  }

  Widget _buildRecordIcon(Map<String, dynamic> record) {
    final bool isFirestorePrescription = record['type'] == 'firestore_prescription';
    
    if (isFirestorePrescription) {
      return Icon(Icons.medication, size: 32, color: Colors.green);
    }
    
    final String? fileName = record['fileName'];
    if (fileName == null) {
      return Icon(Icons.insert_drive_file, size: 32, color: Color(0xFF18A3B6));
    }
    
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

  String _getSourceType(Map<String, dynamic> record) {
    switch (record['type']) {
      case 'firestore_prescription':
        return 'Digital Prescription';
      case 'firestore_record':
        return 'Uploaded File';
      case 'storage_file':
        return 'Legacy File';
      default:
        return 'Unknown Source';
    }
  }

  // The rest of your methods (_showPrescriptionDetails, _viewPrescriptionImage, _downloadRecord)
  // remain the same as in your original code
  // ...

  void _showPrescriptionDetails(Map<String, dynamic> prescription) {
    final medicines = prescription['medicines'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prescription Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Basic Info
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(
                prescription['uploadDate'] ?? prescription['createdAt'] ?? DateTime.now()
              )),
              if (prescription['diagnosis'] != null && (prescription['diagnosis'] as String).isNotEmpty)
                _buildDetailRow('Diagnosis', prescription['diagnosis']),
              if (prescription['medicalCenter'] != null)
                _buildDetailRow('Medical Center', prescription['medicalCenter']),
              if (prescription['dispensingPharmacy'] != null && (prescription['dispensingPharmacy'] as String).isNotEmpty)
                _buildDetailRow('Pharmacy', prescription['dispensingPharmacy']),
              if (prescription['status'] != null)
                _buildDetailRow('Status', prescription['status'], 
                    color: prescription['status'] == 'completed' ? Colors.green : Colors.orange),
              
              SizedBox(height: 16),
              
              // Medicines
              Text(
                'Medications:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              
              if (medicines.isEmpty)
                Text('No medications listed', style: TextStyle(color: Colors.grey)),
              
              ...medicines.map<Widget>((medicine) {
                final med = medicine as Map<String, dynamic>;
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med['name'] ?? 'Unknown Medicine',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (med['dosage'] != null && (med['dosage'] as String).isNotEmpty)
                        Text('Dosage: ${med['dosage']}'),
                      if (med['frequency'] != null && (med['frequency'] as String).isNotEmpty)
                        Text('Frequency: ${med['frequency']}'),
                      if (med['duration'] != null && (med['duration'] as String).isNotEmpty)
                        Text('Duration: ${med['duration']}'),
                      if (med['instructions'] != null && (med['instructions'] as String).isNotEmpty)
                        Text('Instructions: ${med['instructions']}'),
                    ],
                  ),
                );
              }).toList(),
              
              // Notes
              if (prescription['notes'] != null && (prescription['notes'] as String).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(prescription['notes']),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (prescription['fileUrl'] != null && (prescription['fileUrl'] as String).isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _viewPrescriptionImage(prescription['fileUrl']);
              },
              child: Text('View Image'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: color != null ? TextStyle(color: color) : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewPrescriptionImage(String imageUrl) async {
    try {
      if (kIsWeb) {
        if (await canLaunchUrl(Uri.parse(imageUrl))) {
          await launchUrl(Uri.parse(imageUrl));
        }
      } else {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Container(
              constraints: BoxConstraints(maxWidth: 600, maxHeight: 800),
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Prescription Image',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: InteractiveViewer(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening image: $e')),
        );
      }
    }
  }

  Future<void> _downloadRecord(Map<String, dynamic> record) async {
    try {
      if (kIsWeb) {
        if (await canLaunchUrl(Uri.parse(record['fileUrl']))) {
          await launchUrl(Uri.parse(record['fileUrl']));
        }
        return;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/${record['fileName']}');

      final http.Response response = await http.get(Uri.parse(record['fileUrl']));
      await tempFile.writeAsBytes(response.bodyBytes);

      final OpenResult result = await OpenFile.open(tempFile.path);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File downloaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading file: $e')),
        );
      }
    }
  }
}