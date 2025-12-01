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

  // Get all patient medical records (from Firestore + Storage)
  Future<Map<String, List<Map<String, dynamic>>>> getAllPatientMedicalRecords(String patientId) async {
    try {
      // Get records from Firestore collections
      final firestoreLabResults = await _getRecordsFromFirestoreCollection(patientId, 'labResults');
      final firestoreOtherRecords = await _getRecordsFromFirestoreCollection(patientId, 'other');
      
      // Get prescriptions from Firestore
      final firestorePrescriptions = await _getPrescriptionsFromFirestore(patientId);
      
      // Get records from Storage (backward compatibility)
      final storageLabResults = await getPatientMedicalRecords(patientId, 'lab_results');
      final storagePrescriptions = await getPatientMedicalRecords(patientId, 'past_prescriptions');
      final storageOther = await getPatientMedicalRecords(patientId, 'other');

      // Combine all records
      final allLabResults = [...firestoreLabResults, ...storageLabResults];
      final allPrescriptions = [...firestorePrescriptions, ...storagePrescriptions];
      final allOtherRecords = [...firestoreOtherRecords, ...storageOther];

      // Remove duplicates
      final uniqueLabResults = _removeDuplicateRecords(allLabResults);
      final uniquePrescriptions = _removeDuplicateRecords(allPrescriptions);
      final uniqueOtherRecords = _removeDuplicateRecords(allOtherRecords);

      // Sort by date (newest first)
      uniqueLabResults.sort((a, b) {
        final dateA = a['uploadDate'] ?? a['createdAt'] ?? DateTime.now();
        final dateB = b['uploadDate'] ?? b['createdAt'] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      uniquePrescriptions.sort((a, b) {
        final dateA = a['uploadDate'] ?? a['createdAt'] ?? DateTime.now();
        final dateB = b['uploadDate'] ?? b['createdAt'] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      uniqueOtherRecords.sort((a, b) {
        final dateA = a['uploadDate'] ?? a['createdAt'] ?? DateTime.now();
        final dateB = b['uploadDate'] ?? b['createdAt'] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      return {
        'lab_results': uniqueLabResults,
        'past_prescriptions': uniquePrescriptions,
        'other': uniqueOtherRecords,
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
        
        // Convert timestamp fields
        final createdAt = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
        final date = data['date'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(data['date'] as int)
            : null;
          
        // Handle timestamp conversion
        DateTime? lastDispensedAt;
        if (data['lastDispensedAt'] != null) {
          if (data['lastDispensedAt'] is Timestamp) {
            lastDispensedAt = (data['lastDispensedAt'] as Timestamp).toDate();
          } else if (data['lastDispensedAt'] is int) {
            lastDispensedAt = DateTime.fromMillisecondsSinceEpoch(data['lastDispensedAt'] as int);
          }
        }
        
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