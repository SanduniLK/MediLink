import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/medical_record.dart';
import 'package:frontend/model/record_category.dart';
import 'package:frontend/screens/patient_screens/enhanced_medical_dashboard.dart';
import 'package:frontend/screens/patient_screens/lab_report_verification_screen.dart';
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
      final snapshot = await _firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: user.uid)
          .limit(5)
          .get();
      
      debugPrint('📋 Found ${snapshot.docs.length} system prescriptions');
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
      length: 3, // CHANGED: Reduced from 4 to 3
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
              // REMOVED: Test Results tab
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLabResultsList(user.uid),
            _buildAllPrescriptionsList(user.uid),
            _buildOtherRecordsList(user.uid),
            // REMOVED: Test Results tab content
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
          stream: _recordsService.getPatientMedicalRecordsByCategory(
            patientId, 
            RecordCategory.prescriptions
          ).map((records) {
            debugPrint('📁 PAST Prescription files found: ${records.length}');
            return records;
          }),
          builder: (context, pastPrescriptionSnapshot) {
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
                if (systemPrescriptions.isNotEmpty) ...[
                  _buildSectionHeader('System Prescriptions (Digital)', 
                    systemPrescriptions.length, Colors.green),
                  ...systemPrescriptions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildSystemPrescriptionItem(doc.id, data);
                  }).toList(),
                  SizedBox(height: 16),
                ],
                
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
      
      String displayName = 'Prescription ${DateFormat('MMM dd, yyyy').format(createdAt)}';
      
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
              IconButton(
                icon: Icon(Icons.visibility, color: Color(0xFF18A3B6)),
                onPressed: () => _showSystemPrescriptionDetails(id, data),
                tooltip: 'View Details',
              ),
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

  // REMOVED: _buildTestResultsCard and related methods since we removed the Test Results tab

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
                _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(createdAt)),
                _buildDetailRow('Prescription ID', id),
                
                for (final entry in data.entries)
                  if (entry.key != 'medicines' && 
                      entry.key != 'createdAt' && 
                      entry.value != null && 
                      entry.value.toString().isNotEmpty)
                    _buildDetailRow(entry.key, entry.value.toString()),
                
                SizedBox(height: 16),
                
                Text(
                  'Medications:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                
                if (medicines.isEmpty)
                  Text('No medications listed', style: TextStyle(color: Colors.grey)),
                
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

  // Main category selection dialog
  void _showCategorySelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Record Type'),
        content: Text('What type of medical record are you uploading?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ...RecordCategory.values.map((category) {
            return ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (category == RecordCategory.labResults) {
                  _showLabReportCategoryDialog();
                } else if (category == RecordCategory.prescriptions) {
                  _showPrescriptionUploadDialog();
                } else {
                  _showSimpleUploadDialog(category);
                }
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

  void _showPrescriptionUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Upload Prescription'),
          content: Text('Select a file to upload.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Add upload logic here, e.g., pick file and upload
                Navigator.of(context).pop();
              },
              child: Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  void _showSimpleUploadDialog(RecordCategory category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Upload ${category.displayName}'),
          content: Text('Select a file to upload for ${category.displayName}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Add upload logic here (e.g., file picker and upload)
                Navigator.of(context).pop();
              },
              child: Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  void _showLabReportCategoryDialog() {
    String? selectedCategory;
    TextEditingController dateController = TextEditingController();
    bool showDateError = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.all(20),
            child: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF18A3B6),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.science, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lab Report Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Test Date
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Test Date (Optional)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextField(
                                    controller: dateController,
                                    decoration: InputDecoration(
                                      hintText: 'DD/MM/YYYY or leave blank',
                                      prefixIcon: Icon(Icons.calendar_today, size: 20),
                                      border: OutlineInputBorder(),
                                      errorText: showDateError ? 'Use DD/MM/YYYY format' : null,
                                    ),
                                    onChanged: (value) {
                                      if (showDateError) setState(() => showDateError = false);
                                    },
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Will be auto-extracted from document if left blank',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Category Selection
                          Text(
                            'Select Test Category',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          
                          // Category Grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: MedicalRecordsService.testReportCategories.map((category) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedCategory = category;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedCategory == category 
                                          ? Color(0xFF18A3B6) 
                                          : Colors.grey[300]!,
                                      width: selectedCategory == category ? 2 : 1,
                                    ),
                                    color: selectedCategory == category 
                                        ? Color(0xFF18A3B6).withOpacity(0.1) 
                                        : Colors.white,
                                  ),
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _getTestCategoryIcon(category),
                                        style: TextStyle(fontSize: 24),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        category,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: selectedCategory == category 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                          color: selectedCategory == category 
                                              ? Color(0xFF18A3B6) 
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Actions
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                        ),
                        ElevatedButton(
                          onPressed: selectedCategory == null 
                              ? null 
                              : () {
                                if (dateController.text.isNotEmpty && 
                                    !_isValidDateFormat(dateController.text)) {
                                  setState(() => showDateError = true);
                                  return;
                                }
                                
                                Navigator.pop(context);
                                _startLabReportUpload(
                                  category: selectedCategory!,
                                  testDate: dateController.text.isNotEmpty ? dateController.text : null,
                                );
                              },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF18A3B6),
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text('Upload Lab Report'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startLabReportUpload({
    required String category,
    String? testDate,
  }) async {
    try {
      final file = await _recordsService.pickMedicalRecord();
      if (file == null) return;

      setState(() {
        _isUploading = true;
      });

      // Show uploading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Uploading...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF18A3B6)),
              SizedBox(height: 16),
              Text('Uploading $category report...'),
              SizedBox(height: 8),
              Text(
                'Extracting text and analyzing...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );

      final description = await _showDescriptionDialog();
      final user = _auth.currentUser!;
      final fileName = file.path.split('/').last;

      // Upload and extract text
      final MedicalRecord record = await _recordsService.uploadMedicalRecord(
        file: file,
        patientId: user.uid,
        fileName: fileName,
        category: RecordCategory.labResults,
        description: description,
        testReportCategory: category,
        testDate: testDate,
        context: context,
      );

      // Close uploading dialog
      Navigator.pop(context);

      // Check if verification is needed
      if (record.textExtractionStatus == 'pending_verification') {
        // Show verification screen
        _showVerificationScreen(record, category, testDate);
      } else if (record.textExtractionStatus == 'extracted') {
        // Show success and analysis
        _showUploadSuccess(record, category);
      } else {
        // Show simple success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Lab report uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      Navigator.pop(context); // Close any open dialogs
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

  void _showVerificationScreen(MedicalRecord record, String category, String? testDate) {
    // Extract the medical info from the record
    final extractedData = record.medicalInfo ?? {};
    final extractedText = record.extractedText ?? '';
    
    // Show verification screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LabReportVerificationScreen(
          record: record,
          extractedData: extractedData,
          extractedText: extractedText,
          category: category,
          testDate: testDate,
          onVerified: (verifiedData) {
            _saveVerifiedReport(record, verifiedData, category);
          }, patientId: '',
        ),
      ),
    );
  }

  void _showUploadSuccess(MedicalRecord record, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Upload Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ $category report uploaded and analyzed.'),
            SizedBox(height: 12),
            if (record.extractedText?.isNotEmpty ?? false)
              Text('📝 Text extracted: ${record.extractedText!.length} characters'),
            if (record.medicalInfo?['labResults'] != null)
              Text('🔬 ${(record.medicalInfo!['labResults'] as List).length} lab results found'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to analysis dashboard
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedMedicalDashboard(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF18A3B6),
            ),
            child: Text('View Analysis'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveVerifiedReport(
    MedicalRecord record, 
    Map<String, dynamic> verifiedData,
    String category,
  ) async {
    try {
      // Update the record with verified data
      await _firestore.collection('medical_records').doc(record.id).update({
        'textExtractionStatus': 'verified',
        'verifiedParameters': verifiedData,
        'verifiedAt': Timestamp.now(),
      });

      // Save to patient_notes as verified analysis
      final noteId = _firestore.collection('patient_notes').doc().id;
      
      await _firestore.collection('patient_notes').doc(noteId).set({
        'id': noteId,
        'patientId': record.patientId,
        'medicalRecordId': record.id,
        'fileName': record.fileName,
        'category': 'labResults',
        'testReportCategory': category,
        'extractedText': record.extractedText,
        'verifiedParameters': verifiedData,
        'analysisDate': Timestamp.now(),
        'noteType': 'verified_report_analysis',
        'isProcessed': true,
        'verifiedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Lab report verified and saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving verified report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // FIXED: Removed the context parameter from the method signature
  void _showTestReportCategoryDialog() {
    String? selectedCategory;
    TextEditingController dateController = TextEditingController();
    bool showDateError = false;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF18A3B6),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.medical_services, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          'Test Report Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Test Date Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'When was this test done?',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: dateController,
                                decoration: InputDecoration(
                                  labelText: 'Test Date (DD/MM/YYYY)',
                                  hintText: 'e.g., 24/06/2023',
                                  prefixIcon: Icon(Icons.calendar_today, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  errorText: showDateError ? 'Use DD/MM/YYYY format' : null,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                keyboardType: TextInputType.datetime,
                                onChanged: (value) {
                                  if (showDateError) setState(() => showDateError = false);
                                },
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Optional - Will be extracted from document if left blank',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 24),
                          
                          Text(
                            'What type of test is this?',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 12),
                          
                          // Categories List
                          ...MedicalRecordsService.testReportCategories.map((category) {
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              elevation: selectedCategory == category ? 2 : 0,
                              color: selectedCategory == category 
                                  ? Color(0xFF18A3B6).withOpacity(0.1) 
                                  : Colors.white,
                              child: ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: selectedCategory == category 
                                        ? Color(0xFF18A3B6) 
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getTestCategoryIcon(category),
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  category,
                                  style: TextStyle(
                                    fontWeight: selectedCategory == category 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                    color: selectedCategory == category 
                                        ? Color(0xFF18A3B6) 
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  _getTestCategoryDescription(category),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                                trailing: selectedCategory == category 
                                    ? Icon(Icons.check_circle, color: Color(0xFF18A3B6))
                                    : null,
                                onTap: () {
                                  setState(() {
                                    selectedCategory = category;
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  
                  // Actions
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: selectedCategory == null 
                              ? null 
                              : () {
                                if (dateController.text.isNotEmpty) {
                                  if (!_isValidDateFormat(dateController.text)) {
                                    setState(() => showDateError = true);
                                    return;
                                  }
                                }
                                
                                Navigator.pop(context);
                                _startUploadForTestReport(
                                  category: selectedCategory!,
                                  testDate: dateController.text.isNotEmpty ? dateController.text : null,
                                );
                              },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF18A3B6),
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isValidDateFormat(String date) {
    try {
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(date)) {
        List<String> parts = date.split('/');
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1900 && year <= 2100) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String _getTestCategoryIcon(String category) {
    if (category.contains('Urine')) return '💧';
    if (category.contains('Blood Count') || category.contains('FBC')) return '🩸';
    if (category.contains('TSH') || category.contains('Thyroid')) return '🧪';
    if (category.contains('Cholesterol') || category.contains('LDL')) return '🔬';
    if (category.contains('Sugar') || category.contains('Glucose')) return '🍬';
    
    if (category.contains('Lipid')) return '🩺';
    return '📋';
  }

  String _getTestCategoryDescription(String category) {
    switch (category) {
      case 'Urine Analysis':
        return 'Tests for glucose, protein, blood cells in urine';
      case 'Full Blood Count (FBC)':
        return 'Complete blood test (Hemoglobin, WBC, RBC, Platelets)';
      case 'Thyroid (TSH) Test':
        return 'Thyroid function test';
      case 'Cholesterol (LDL) Test':
        return 'Cholesterol levels test';
      case 'Blood Sugar Test':
        return 'Glucose levels (fasting, HbA1c)';
      case 'Lipid Profile':
        return 'Complete cholesterol test';
      
       
      default:
        return 'General test report';
    }
  }

  Color _getCategoryColor(RecordCategory category) {
    switch (category) {
      case RecordCategory.labResults:
        return Color(0xFF4CAF50);
      case RecordCategory.prescriptions:
        return Color(0xFF2196F3);
      
      case RecordCategory.other:
        return Color(0xFF607D8B);
    }
  }

  // FIXED: Correct method signature - removed the context parameter
  Future<void> _startUploadForTestReport({
    required String category,
    String? testDate,
  }) async {
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
              Text('Uploading $category...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      final description = await _showDescriptionDialog();
      final user = _auth.currentUser!;
      final fileName = file.path.split('/').last;

      // Upload the medical record
      final MedicalRecord record = await _recordsService.uploadMedicalRecord(
        file: file,
        patientId: user.uid,
        fileName: fileName,
        category: RecordCategory.labResults,
        description: description,
        testReportCategory: category,
        testDate: testDate,
        context: context,
      );

      // Check if verification is needed
      if (record.textExtractionStatus == 'pending_verification') {
        // Don't show success message - verification screen will handle it
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $category uploaded successfully!'),
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

  Future<void> _startUploadForCategory(RecordCategory category, BuildContext context) async {
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
              Text('Uploading ${category.displayName}...'),
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
        context: context,
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
                hintText: 'e.g., Annual checkup, Follow-up test',
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

  Future<void> _deleteTestNote(String noteId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Test Note'),
        content: Text('Are you sure you want to delete this test report analysis?'),
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
        await _firestore.collection('patient_notes').doc(noteId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Test note deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting test note: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showTestReportDetails(Map<String, dynamic> noteData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.medical_services, color: Color(0xFF18A3B6)),
            SizedBox(width: 10),
            Text('Test Report Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Test Type', noteData['testReportCategory'] ?? 'Not specified'),
              _buildDetailRow('Test Date', noteData['testDate'] ?? 'Not specified'),
              _buildDetailRow('Patient Age', noteData['patientAge'] ?? 'Not specified'),
              _buildDetailRow('Patient Gender', noteData['patientGender'] ?? 'Not specified'),
              _buildDetailRow('File Name', noteData['fileName'] ?? 'Not specified'),
              
              SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip('Total', noteData['totalResults'] ?? 0, Colors.blue),
                  _buildStatChip('High', noteData['highCount'] ?? 0, Colors.red),
                  _buildStatChip('Normal', noteData['normalCount'] ?? 0, Colors.green),
                  _buildStatChip('Low', noteData['lowCount'] ?? 0, Colors.orange),
                ],
              ),
              
              SizedBox(height: 20),
              
              if ((noteData['abnormalities'] as List?)?.isNotEmpty ?? false) ...[
                Text(
                  'Abnormalities:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 8),
                ...(noteData['abnormalities'] as List).map((abnormality) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('• $abnormality'),
                  );
                }).toList(),
                SizedBox(height: 16),
              ],
              
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showExtractedText(noteData['extractedText'] ?? 'No text extracted');
                },
                child: Text('View Extracted Text'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, dynamic value, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _showExtractedText(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Extracted Text'),
        content: Container(
          constraints: BoxConstraints(maxHeight: 400, maxWidth: 500),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
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