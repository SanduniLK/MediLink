import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DoctorMedicalRecordsService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get total prescription count for a patient profile
  Future<int> getTotalPrescriptionCount(String patientId) async {
    try {
      final querySnapshot = await _firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: patientId)
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting prescription count: $e');
      return 0;
    }
  }

Future<Map<String, List<Map<String, dynamic>>>> getAllPatientMedicalRecords(String patientId) async {
  try {
    debugPrint('🔍 Loading ALL medical records for patient: $patientId');
    
    // Get records from medical_records collection
    final medicalRecordsSnapshot = await _firestore
        .collection('medical_records')
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadDate', descending: true)
        .get();

    debugPrint('📁 Found ${medicalRecordsSnapshot.docs.length} records in medical_records collection');
    
    // Initialize empty lists
    final List<Map<String, dynamic>> labResults = [];
    final List<Map<String, dynamic>> pastPrescriptions = [];
    final List<Map<String, dynamic>> otherRecords = [];

    // Process medical_records
    for (final doc in medicalRecordsSnapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final recordId = doc.id;
        final category = data['category']?.toString() ?? 'other';
        
        // Parse upload date
        DateTime uploadDate;
        if (data['uploadDate'] is Timestamp) {
          uploadDate = (data['uploadDate'] as Timestamp).toDate();
        } else if (data['uploadDate'] is int) {
          uploadDate = DateTime.fromMillisecondsSinceEpoch(data['uploadDate'] as int);
        } else {
          uploadDate = DateTime.now();
        }

        // Create record map
        final record = {
          'id': recordId,
          'fileName': data['fileName'] ?? 'Unknown File',
          'fileUrl': data['fileUrl'] ?? '',
          'fileType': data['fileType'] ?? '',
          'uploadDate': uploadDate,
          'fileSize': data['fileSize'] ?? 0,
          'description': data['description'] ?? '',
          'category': category,
          'type': 'firestore_record',
          'patientId': data['patientId'] ?? patientId,
          'source': 'medical_records',
        };

        // Add to appropriate list
        switch (category) {
          case 'labResults':
            labResults.add(record);
            break;
          case 'pastPrescriptions':
            pastPrescriptions.add(record);
            break;
          case 'other':
            otherRecords.add(record);
            break;
          default:
            otherRecords.add(record);
        }
      } catch (e) {
        debugPrint('❌ Error processing medical record ${doc.id}: $e');
      }
    }

    // Get digital prescriptions from Firestore
    final prescriptionsSnapshot = await _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();

    debugPrint('💊 Found ${prescriptionsSnapshot.docs.length} digital prescriptions in Firestore');
    
    // Process digital prescriptions
    for (final doc in prescriptionsSnapshot.docs) {
      try {
       final data = doc.data() as Map<String, dynamic>;
    final prescriptionId = doc.id;
    final doctorId = data['doctorId']?.toString() ?? '';
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else {
      debugPrint('⚠️ Unknown createdAt type in getAllPatientMedicalRecords: ${data['createdAt']?.runtimeType}');
      createdAt = DateTime.now();
    }
        
       
        
        // Create display name
        String fileName = 'Digital Prescription_${_formatDateForFileName(createdAt)}';
        if (data['diagnosis'] != null && (data['diagnosis'] as String).isNotEmpty) {
          fileName = '${data['diagnosis']}_${_formatDateForFileName(createdAt)}';
        }

        // Create digital prescription record
        final digitalPrescription = {
          'id': prescriptionId,
          'fileName': fileName,
          'fileUrl': data['prescriptionImageUrl'] ?? '',
          'uploadDate': createdAt,
          'createdAt': createdAt,
          'fileSize': 0,
          'category': 'past_prescriptions',
          'type': 'digital_prescription',
          'diagnosis': data['diagnosis'] ?? '',
          'medicalCenter': data['medicalCenter'] ?? '',
          'doctorId': doctorId,
          'status': data['status'] ?? '',
          'medicines': data['medicines'] ?? [],
          'notes': data['notes'] ?? '',
          'patientAge': data['patientAge'] ?? 0,
          'patientName': data['patientName'] ?? '',
          'dispensingPharmacy': data['dispensingPharmacy'] ?? '',
          'description': data['description'] ?? '',
          'source': 'firestore_prescriptions',
        };

        pastPrescriptions.add(digitalPrescription);
        
        // Now get storage prescriptions from this doctor if we have doctorId
        if (doctorId.isNotEmpty) {
          final storagePrescriptions = await _getPrescriptionsFromStorage(doctorId);
          
          // Filter storage prescriptions for this patient (by checking if they contain patient name or ID)
          for (final storagePrescription in storagePrescriptions) {
            // Add doctorId to the storage prescription
            storagePrescription['doctorId'] = doctorId;
            pastPrescriptions.add(storagePrescription);
          }
          
          debugPrint('📦 Added ${storagePrescriptions.length} storage prescriptions from doctor: $doctorId');
        }
      } catch (e) {
        debugPrint('❌ Error processing digital prescription ${doc.id}: $e');
      }
    }

    // Remove duplicates based on fileUrl and uploadDate
    final uniquePastPrescriptions = _removeDuplicateRecords(pastPrescriptions);
    
    // Sort all lists by date
    labResults.sort((a, b) => b['uploadDate'].compareTo(a['uploadDate']));
    uniquePastPrescriptions.sort((a, b) => b['uploadDate'].compareTo(a['uploadDate']));
    otherRecords.sort((a, b) => b['uploadDate'].compareTo(a['uploadDate']));

    // Log final counts
    debugPrint('📊 FINAL COUNTS for patient $patientId:');
    debugPrint('  Lab Results: ${labResults.length}');
    debugPrint('  Prescriptions: ${uniquePastPrescriptions.length}');
    debugPrint('    - Firestore medical_records: ${pastPrescriptions.where((p) => p['source'] == 'medical_records').length}');
    debugPrint('    - Firestore prescriptions: ${pastPrescriptions.where((p) => p['source'] == 'firestore_prescriptions').length}');
    debugPrint('    - Storage: ${pastPrescriptions.where((p) => p['source'] == 'storage').length}');
    debugPrint('  Other: ${otherRecords.length}');
    debugPrint('  Total: ${labResults.length + uniquePastPrescriptions.length + otherRecords.length}');

    return {
      'lab_results': labResults,
      'past_prescriptions': uniquePastPrescriptions,
      'other': otherRecords,
    };
  } catch (e) {
    debugPrint('❌ Error getting all patient medical records: $e');
    return {
      'lab_results': [],
      'past_prescriptions': [],
      'other': [],
    };
  }
}


  // Get records from Firestore collections (labResults, other)
  Future<List<Map<String, dynamic>>> _getRecordsFromFirestoreCollection(
    String patientId, 
    String category
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: patientId)
          .where('category', isEqualTo: category)
          .orderBy('uploadDate', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Handle timestamp conversion
        DateTime uploadDate;
        if (data['uploadDate'] is Timestamp) {
          uploadDate = (data['uploadDate'] as Timestamp).toDate();
        } else if (data['uploadDate'] is int) {
          uploadDate = DateTime.fromMillisecondsSinceEpoch(data['uploadDate'] as int);
        } else {
          uploadDate = DateTime.now();
        }

        return {
          'id': doc.id,
          'fileName': data['fileName'] ?? 'Unknown File',
          'fileUrl': data['fileUrl'] ?? '',
          'uploadDate': uploadDate,
          'fileSize': data['fileSize'] ?? 0,
          'category': category,
          'type': 'firestore_record',
          'fileType': data['fileType'] ?? '',
          'description': data['description'] ?? '',
          'patientId': data['patientId'] ?? patientId,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching $category from Firestore: $e');
      return [];
    }
  }

  // Get prescriptions from Firestore (prescriptions collection)
  Future<List<Map<String, dynamic>>> _getPrescriptionsFromFirestore(String patientId) async {
  try {
    final querySnapshot = await _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // FIX: Handle both Timestamp and int for createdAt
      DateTime createdAt;
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
      } else {
        debugPrint('⚠️ Unknown createdAt type: ${data['createdAt']?.runtimeType}');
        createdAt = DateTime.now();
      }
      
      // FIX: Handle both Timestamp and int for date
      DateTime? date;
      if (data['date'] != null) {
        if (data['date'] is Timestamp) {
          date = (data['date'] as Timestamp).toDate();
        } else if (data['date'] is int) {
          date = DateTime.fromMillisecondsSinceEpoch(data['date'] as int);
        }
      }
        
      // FIX: Handle both Timestamp and int for lastDispensedAt
      DateTime? lastDispensedAt;
      if (data['lastDispensedAt'] != null) {
        if (data['lastDispensedAt'] is Timestamp) {
          lastDispensedAt = (data['lastDispensedAt'] as Timestamp).toDate();
        } else if (data['lastDispensedAt'] is int) {
          lastDispensedAt = DateTime.fromMillisecondsSinceEpoch(data['lastDispensedAt'] as int);
        }
      }
      
      // FIX: Handle both Timestamp and int for updatedAt
      DateTime? updatedAt;
      if (data['updatedAt'] != null) {
        if (data['updatedAt'] is Timestamp) {
          updatedAt = (data['updatedAt'] as Timestamp).toDate();
        } else if (data['updatedAt'] is int) {
          updatedAt = DateTime.fromMillisecondsSinceEpoch(data['updatedAt'] as int);
        }
      }
      
      // Create display name
      String fileName = 'Prescription_${_formatDateForFileName(createdAt)}';
      if (data['diagnosis'] != null && (data['diagnosis'] as String).isNotEmpty) {
        fileName = '${data['diagnosis']}_${_formatDateForFileName(createdAt)}';
      }

      return {
        'id': doc.id,
        'fileName': fileName,
        'fileUrl': data['prescriptionImageUrl'] ?? '',
        'uploadDate': createdAt,
        'createdAt': createdAt,
        'date': date,
        'fileSize': 0,
        'category': 'past_prescriptions',
        'type': 'firestore_prescription',
        'diagnosis': data['diagnosis'] ?? '',
        'medicalCenter': data['medicalCenter'] ?? '',
        'doctorId': data['doctorId'] ?? '',
        'status': data['status'] ?? '',
        'medicines': data['medicines'] ?? [],
        'notes': data['notes'] ?? '',
        'patientAge': data['patientAge'] ?? 0,
        'patientName': data['patientName'] ?? '',
        'dispensingPharmacy': data['dispensingPharmacy'] ?? '',
        'description': data['description'] ?? '',
        'lastDispensedAt': lastDispensedAt,
        'updatedAt': updatedAt,
        'sharedPharmacies': data['sharedPharmacies'] ?? [],
        'signatureImage': data['signatureImage'],
        'signatureUrl': data['signatureUrl'],
        'drawingImage': data['drawingImage'],
      };
    }).toList();
  } catch (e) {
    debugPrint('❌ Error fetching prescriptions from Firestore: $e');
    return [];
  }
}

  // Remove duplicate records (same fileName and similar uploadDate)
  List<Map<String, dynamic>> _removeDuplicateRecords(List<Map<String, dynamic>> records) {
    final Map<String, Map<String, dynamic>> uniqueRecords = {};
    
    for (final record in records) {
      final key = '${record['fileName']}_${record['uploadDate']}';
      if (!uniqueRecords.containsKey(key)) {
        uniqueRecords[key] = record;
      }
    }
    
    return uniqueRecords.values.toList();
  }
Future<List<Map<String, dynamic>>> _getPrescriptionsFromStorage(String doctorId) async {
  try {
    debugPrint('📦 Loading prescriptions from storage for doctor: $doctorId');
    
    final ListResult result = await _storage.ref('prescriptions/$doctorId').listAll();
    
    debugPrint('📦 Found ${result.items.length} prescription files in storage');
    
    List<Map<String, dynamic>> prescriptions = [];
    
    for (final Reference ref in result.items) {
      try {
        final String path = ref.fullPath;
        final fileNameWithTimestamp = path.split('/').last;
        
        // Extract actual filename (remove timestamp prefix)
        String fileName;
        if (fileNameWithTimestamp.contains('_')) {
          fileName = fileNameWithTimestamp.substring(fileNameWithTimestamp.indexOf('_') + 1);
        } else {
          fileName = fileNameWithTimestamp;
        }
        
        final downloadUrl = await ref.getDownloadURL();
        final metadata = await ref.getMetadata();
        
        prescriptions.add({
          'fileName': fileName,
          'fileUrl': downloadUrl,
          'category': 'past_prescriptions',
          'uploadDate': metadata.timeCreated ?? DateTime.now(),
          'fileSize': metadata.size ?? 0,
          'fullPath': path,
          'type': 'storage_prescription',
          'source': 'storage',
          'doctorId': doctorId,
        });
        
        debugPrint('  📄 Storage prescription: $fileName');
      } catch (e) {
        debugPrint('❌ Error processing storage prescription: $e');
      }
    }
    
    // Sort by upload date (newest first)
    prescriptions.sort((a, b) => b['uploadDate'].compareTo(a['uploadDate']));
    
    return prescriptions;
  } catch (e) {
    debugPrint('❌ Error getting prescriptions from storage: $e');
    return [];
  }
}

Future<Map<String, int>> getMedicalRecordsStats(String patientId) async {
  try {
    // Get ALL records first
    final allRecords = await getAllPatientMedicalRecords(patientId);
    
    // Count from the combined data
    final labResultsCount = allRecords['lab_results']?.length ?? 0;
    final prescriptionsCount = allRecords['past_prescriptions']?.length ?? 0;
    final otherCount = allRecords['other']?.length ?? 0;
    final totalCount = labResultsCount + prescriptionsCount + otherCount;
    
    // Debug: Show breakdown
    debugPrint('📊 COMPREHENSIVE STATS for patient $patientId:');
    debugPrint('  Lab Results: $labResultsCount');
    debugPrint('  Prescriptions: $prescriptionsCount');
    debugPrint('    - Files: ${allRecords['past_prescriptions']?.where((p) => p['source'] == 'medical_records' || p['source'] == 'storage').length ?? 0}');
    debugPrint('    - Digital: ${allRecords['past_prescriptions']?.where((p) => p['source'] == 'firestore_prescriptions').length ?? 0}');
    debugPrint('  Other: $otherCount');
    debugPrint('  Total: $totalCount');
    
    return {
      'labResultsCount': labResultsCount,
      'prescriptionsCount': prescriptionsCount,
      'otherCount': otherCount,
      'totalCount': totalCount,
    };
  } catch (e) {
    debugPrint('❌ Error getting medical records stats: $e');
    return {
      'labResultsCount': 0,
      'prescriptionsCount': 0,
      'otherCount': 0,
      'totalCount': 0,
    };
  }
}
  // Helper method to format date for file name
  String _formatDateForFileName(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Get patient medical records by category (from Storage - backward compatibility)
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(String patientId, String category) async {
    try {
      // Map your category names to storage paths
      String storagePath = category;
      if (category == 'lab_results') storagePath = 'labResults';
      if (category == 'past_prescriptions') storagePath = 'prescriptions';
      
      final ListResult result = await _storage.ref('medical_records/$patientId/$storagePath').listAll();
      
      List<Map<String, dynamic>> records = [];
      
      for (final Reference ref in result.items) {
        try {
          final String path = ref.fullPath;
          final fileNameWithTimestamp = path.split('/').last;
          
          // Extract actual filename (remove timestamp prefix)
          String fileName;
          if (fileNameWithTimestamp.contains('_')) {
            fileName = fileNameWithTimestamp.substring(fileNameWithTimestamp.indexOf('_') + 1);
          } else {
            fileName = fileNameWithTimestamp;
          }
          
          final downloadUrl = await ref.getDownloadURL();
          final metadata = await ref.getMetadata();
          
          records.add({
            'fileName': fileName,
            'fileUrl': downloadUrl,
            'category': category,
            'uploadDate': metadata.timeCreated,
            'fileSize': metadata.size,
            'fullPath': path,
            'type': 'storage_file',
          });
        } catch (e) {
          debugPrint('❌ Error processing storage file: $e');
        }
      }
      
      // Sort by upload date (newest first)
      records.sort((a, b) => b['uploadDate'].compareTo(a['uploadDate']));
      return records;
    } catch (e) {
      debugPrint('❌ Error getting patient medical records from storage: $e');
      return [];
    }
  }

  // Rest of your existing methods...
  String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1048576) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
  }

  String getCategoryDisplayName(String category) {
    switch (category) {
      case 'lab_results':
      case 'labResults':
        return 'Lab Test Results';
      case 'past_prescriptions':
      case 'prescriptions':
        return 'Past Prescriptions';
      case 'other':
        return 'Other Medical Records';
      default:
        return category;
    }
  }

  String getCategoryIcon(String category) {
    switch (category) {
      case 'lab_results':
      case 'labResults':
        return '🧪';
      case 'past_prescriptions':
      case 'prescriptions':
        return '💊';
      case 'other':
        return '📁';
      default:
        return '📄';
    }
  }
}