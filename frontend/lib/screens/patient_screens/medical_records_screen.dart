// screens/patient_screens/medical_records_screen.dart - COMPLETE
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _debugCheckPrescriptions();
  }

  Future<void> _debugCheckPrescriptions() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    debugPrint('🔍 DEBUG: Checking prescriptions for patient: ${user.uid}');
    
    try {
      // Check prescriptions collection
      final snapshot = await _firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: user.uid)
          .limit(5)
          .get();
      
      debugPrint('📋 Found ${snapshot.docs.length} system prescriptions:');
      
      for (final doc in snapshot.docs) {
        debugPrint('  Prescription ID: ${doc.id}');
        doc.data().forEach((key, value) {
          debugPrint('    $key: $value (${value.runtimeType})');
        });
        debugPrint('  ---');
      }
      
      // Check medical_records collection for past prescriptions
      final recordsSnapshot = await _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: user.uid)
          .where('category', isEqualTo: 'pastPrescriptions')
          .get();
      
      debugPrint('📁 Found ${recordsSnapshot.docs.length} past prescription files');
      
    } catch (e) {
      debugPrint('❌ Debug error: $e');
    }
  }

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
          actions: [
            if (kDebugMode)
              IconButton(
                icon: Icon(Icons.bug_report),
                onPressed: _debugCheckPrescriptions,
                tooltip: 'Debug',
              ),
          ],
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
            _buildLabResultsList(user.uid),
            _buildAllPrescriptionsList(user.uid),
            _buildOtherRecordsList(user.uid),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showCategorySelectionDialog();
          },
          child: Icon(_isUploading ? Icons.hourglass_top : Icons.upload),
          backgroundColor: Color(0xFF18A3B6),
        ),
      ),
    );
  }

  // Lab Results - Only from medical_records
  Widget _buildLabResultsList(String patientId) {
    return StreamBuilder<List<MedicalRecord>>(
      stream: _recordsService.getPatientMedicalRecordsByCategory(patientId, RecordCategory.labResults),
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
                Icon(Icons.science, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No Lab Results',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to upload your first lab result',
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
            return _buildMedicalRecordItem(records[index]);
          },
        );
      },
    );
  }

  // ALL Prescriptions - SYSTEM + PAST (uploaded files)
  Widget _buildAllPrescriptionsList(String patientId) {
    return StreamBuilder<List<DocumentSnapshot>>(
      // Query for SYSTEM prescriptions (from prescriptions collection)
      stream: _firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            debugPrint('💊 SYSTEM Prescriptions found: ${snapshot.docs.length}');
            return snapshot.docs;
          }),
      builder: (context, systemPrescriptionSnapshot) {
        return StreamBuilder<List<MedicalRecord>>(
          // Query for PAST prescriptions (uploaded files)
          stream: _recordsService.getPatientMedicalRecordsByCategory(
            patientId, 
            RecordCategory.pastPrescriptions
          ).map((records) {
            debugPrint('📁 PAST Prescription files found: ${records.length}');
            return records;
          }),
          builder: (context, pastPrescriptionSnapshot) {
            // Combine loading states
            final isLoading = systemPrescriptionSnapshot.connectionState == ConnectionState.waiting ||
                            pastPrescriptionSnapshot.connectionState == ConnectionState.waiting;
            
            if (isLoading) {
              return Center(child: CircularProgressIndicator());
            }

            if (systemPrescriptionSnapshot.hasError) {
              return Center(child: Text('Error loading system prescriptions: ${systemPrescriptionSnapshot.error}'));
            }

            if (pastPrescriptionSnapshot.hasError) {
              return Center(child: Text('Error loading prescription files: ${pastPrescriptionSnapshot.error}'));
            }

            final systemPrescriptions = systemPrescriptionSnapshot.data ?? [];
            final pastPrescriptions = pastPrescriptionSnapshot.data ?? [];

            debugPrint('📊 TOTAL Prescriptions: ${systemPrescriptions.length} system + ${pastPrescriptions.length} files');

            // If both are empty
            if (systemPrescriptions.isEmpty && pastPrescriptions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medication, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No Prescriptions',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your prescriptions will appear here',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.all(16),
              children: [
                // SYSTEM Prescriptions Section (Digital)
                if (systemPrescriptions.isNotEmpty) ...[
                  _buildSectionHeader('System Prescriptions (Digital)', 
                    systemPrescriptions.length, Colors.green),
                  ...systemPrescriptions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildSystemPrescriptionItem(doc.id, data);
                  }).toList(),
                  SizedBox(height: 16),
                ],
                
                // PAST Prescriptions Section (Uploaded Files)
                if (pastPrescriptions.isNotEmpty) ...[
                  _buildSectionHeader('Uploaded Prescription Files', 
                    pastPrescriptions.length, Colors.blue),
                  ...pastPrescriptions.map((record) {
                    return _buildMedicalRecordItem(record);
                  }).toList(),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // Other Records - Only from medical_records
  Widget _buildOtherRecordsList(String patientId) {
    return StreamBuilder<List<MedicalRecord>>(
      stream: _recordsService.getPatientMedicalRecordsByCategory(patientId, RecordCategory.other),
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
                Icon(Icons.folder, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No Other Records',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to upload other medical records',
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
            return _buildMedicalRecordItem(records[index]);
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            color: color,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      )
    );
  }

  Widget _buildMedicalRecordItem(MedicalRecord record) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: _buildFileIcon(record.fileType, Colors.blue),
        ),
        title: Text(
          record.fileName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uploaded: ${DateFormat('MMM dd, yyyy').format(record.uploadDate)}'),
            if (record.description != null && record.description!.isNotEmpty) 
              Text(record.description!),
            Text(_recordsService.getFileSizeString(record.fileSize)),
            Text(
              'Uploaded File',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, color: Color(0xFF18A3B6)),
              onPressed: () => _downloadMedicalRecord(record),
              tooltip: 'Download',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteMedicalRecord(record),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemPrescriptionItem(String id, Map<String, dynamic> data) {
  try {
    // Handle both Timestamp and int for createdAt
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else {
      createdAt = DateTime.now();
    }
    
    final medicines = data['medicines'] as List<dynamic>? ?? [];
    final hasImage = data['prescriptionImageUrl'] != null && 
                   (data['prescriptionImageUrl'] as String).isNotEmpty;
    
    // Create display name
    String displayName = 'Prescription ${DateFormat('MMM dd, yyyy').format(createdAt)}';
    
    // Try different possible title fields
    if (data['title'] != null && (data['title'] as String).isNotEmpty) {
      displayName = data['title'];
    } else if (data['diagnosis'] != null && (data['diagnosis'] as String).isNotEmpty) {
      displayName = data['diagnosis'];
    } else if (data['patientName'] != null && (data['patientName'] as String).isNotEmpty) {
      displayName = 'Prescription for ${data['patientName']}';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.description, color: Colors.green),
        ),
        title: Text(
          displayName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt)}'),
            
            // Show any available info
            if (data['medicalCenter'] != null && (data['medicalCenter'] as String).isNotEmpty)
              Text('Medical Center: ${data['medicalCenter']}'),
            if (data['doctorName'] != null && (data['doctorName'] as String).isNotEmpty)
              Text('Doctor: ${data['doctorName']}'),
            if (data['doctorId'] != null && (data['doctorId'] as String).isNotEmpty)
              Text('Doctor ID: ${data['doctorId']}'),
              
            if (medicines.isNotEmpty)
              Text('${medicines.length} medication${medicines.length == 1 ? '' : 's'}'),
            Text(
              'Digital Prescription',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // View details button
            IconButton(
              icon: Icon(Icons.visibility, color: Color(0xFF18A3B6)),
              onPressed: () => _showSystemPrescriptionDetails(id, data),
              tooltip: 'View Details',
            ),
            // View image button if available
            if (hasImage)
              IconButton(
                icon: Icon(Icons.image, color: Colors.green),
                onPressed: () => _viewPrescriptionImage(data['prescriptionImageUrl']),
                tooltip: 'View Image',
              ),
          ],
        ),
        onTap: () => _showSystemPrescriptionDetails(id, data),
      ),
    );
  } catch (e) {
    debugPrint('❌ Error building system prescription item: $e');
    return Card(
      child: ListTile(
        leading: Icon(Icons.error, color: Colors.red),
        title: Text('Error loading prescription'),
        subtitle: Text('ID: $id'),
      ),
    );
  }
}

  Widget _buildFileIcon(String fileType, Color color) {
    final double iconSize = 24;

    if (fileType == 'pdf') {
      return Icon(Icons.picture_as_pdf, size: iconSize, color: color);
    } else if (['jpg', 'jpeg', 'png'].contains(fileType)) {
      return Icon(Icons.image, size: iconSize, color: color);
    } else {
      return Icon(Icons.insert_drive_file, size: iconSize, color: color);
    }
  }

void _showSystemPrescriptionDetails(String id, Map<String, dynamic> data) {
  try {
    final medicines = data['medicines'] as List<dynamic>? ?? [];
    
    // Handle both Timestamp and int for createdAt
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else {
      createdAt = DateTime.now();
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('System Prescription Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Basic Info
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(createdAt)),
              _buildDetailRow('Prescription ID', id),
              
              // Show all available data
              for (final entry in data.entries)
                if (entry.key != 'medicines' && 
                    entry.key != 'createdAt' && 
                    entry.value != null && 
                    entry.value.toString().isNotEmpty)
                  _buildDetailRow(entry.key, entry.value.toString()),
              
              SizedBox(height: 16),
              
              // Medicines
              Text(
                'Medications:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              
              if (medicines.isEmpty)
                Text('No medications listed', style: TextStyle(color: Colors.grey)),
              
              // Medicines list
              ...medicines.map<Widget>((medicine) {
                try {
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
                } catch (e) {
                  return Text('Error loading medicine: $e');
                }
              }).toList(),
              
              // Notes
              if (data['notes'] != null && (data['notes'] as String).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(data['notes']),
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
          if (data['prescriptionImageUrl'] != null && (data['prescriptionImageUrl'] as String).isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _viewPrescriptionImage(data['prescriptionImageUrl']);
              },
              child: Text('View Image'),
            ),
        ],
      ),
    );
  } catch (e) {
    debugPrint('❌ Error showing system prescription details: $e');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text('Could not load prescription details: $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
  Widget _buildDetailRow(String label, dynamic value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      )
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

  void _showCategorySelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Category'),
        content: Text('Choose the category for your medical record:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ...RecordCategory.values.map((category) {
            return ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startUploadForCategory(category);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getCategoryColor(category),
              ),
              child: Text(category.displayName),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getCategoryColor(RecordCategory category) {
    switch (category) {
      case RecordCategory.labResults:
        return Color(0xFF4CAF50);
      case RecordCategory.pastPrescriptions:
        return Color(0xFF2196F3);
      case RecordCategory.other:
        return Color(0xFF9C27B0);
    }
  }

  Future<void> _startUploadForCategory(RecordCategory category) async {
    try {
      final file = await _recordsService.pickMedicalRecord();
      if (file == null) return;

      setState(() {
        _isUploading = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              SizedBox(width: 16),
              Text('Uploading ${category.displayName.toLowerCase()}...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      final description = await _showDescriptionDialog();
      final user = _auth.currentUser!;
      final fileName = file.path.split('/').last;

      final MedicalRecord record = await _recordsService.uploadMedicalRecord(
        file: file,
        patientId: user.uid,
        fileName: fileName,
        category: category,
        description: description,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${category.displayName} uploaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Description (Optional)'),
            content: TextField(
              onChanged: (value) => description = value,
              decoration: InputDecoration(
                hintText: 'e.g., Blood Test Results - December 2024',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
          );
        },
      ),
    );
    return description;
  }

  Future<void> _downloadMedicalRecord(MedicalRecord record) async {
    try {
      if (kIsWeb) {
        if (await canLaunchUrl(Uri.parse(record.fileUrl))) {
          await launchUrl(Uri.parse(record.fileUrl));
        }
        return;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/${record.fileName}');

      final http.Response response = await http.get(Uri.parse(record.fileUrl));
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

  Future<void> _deleteMedicalRecord(MedicalRecord record) async {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Record deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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
}