// services/doctor_medical_records_service.dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DoctorMedicalRecordsService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all patients with their medical records summary
  Future<List<Map<String, dynamic>>> getPatientsWithMedicalRecords(String doctorId) async {
    try {
      // Get patients from telemedicine sessions
      final sessionsSnapshot = await _firestore
          .collection('telemedicine_sessions')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      final List<Map<String, dynamic>> patients = [];

      for (final session in sessionsSnapshot.docs) {
        final sessionData = session.data();
        final patientId = sessionData['patientId'];
        final patientName = sessionData['patientName'];

        if (patientId != null && patientName != null) {
          // Check if patient already added
          if (!patients.any((p) => p['patientId'] == patientId)) {
            // Get medical records summary for this patient
            final recordsSummary = await _getPatientRecordsSummary(patientId);
            
            patients.add({
              'patientId': patientId,
              'patientName': patientName,
              'sessionId': session.id,
              'recordsSummary': recordsSummary,
            });
          }
        }
      }

      return patients;
    } catch (e) {
      debugPrint('❌ Error getting patients with medical records: $e');
      return [];
    }
  }

  // Get medical records summary for a patient
  Future<Map<String, dynamic>> _getPatientRecordsSummary(String patientId) async {
    try {
      int labResultsCount = 0;
      int prescriptionsCount = 0;
      int otherCount = 0;
      DateTime? lastUploadDate;

      try {
        // Count lab results
        final labResults = await _storage.ref('medical_records/$patientId/lab_results').listAll();
        labResultsCount = labResults.items.length;
        
        // Count prescriptions  
        final prescriptions = await _storage.ref('medical_records/$patientId/past_prescriptions').listAll();
        prescriptionsCount = prescriptions.items.length;
        
        // Count other records
        final other = await _storage.ref('medical_records/$patientId/other').listAll();
        otherCount = other.items.length;

        // Get latest upload date
        final allItems = [...labResults.items, ...prescriptions.items, ...other.items];
        if (allItems.isNotEmpty) {
          final metadata = await allItems.first.getMetadata();
          lastUploadDate = metadata.timeCreated;
        }
      } catch (e) {
        debugPrint('No medical records found for patient: $patientId');
      }

      return {
        'labResultsCount': labResultsCount,
        'prescriptionsCount': prescriptionsCount,
        'otherCount': otherCount,
        'totalCount': labResultsCount + prescriptionsCount + otherCount,
        'lastUploadDate': lastUploadDate,
      };
    } catch (e) {
      debugPrint('❌ Error getting patient records summary: $e');
      return {
        'labResultsCount': 0,
        'prescriptionsCount': 0,
        'otherCount': 0,
        'totalCount': 0,
        'lastUploadDate': null,
      };
    }
  }
// Add this method to your DoctorMedicalRecordsService
Future<Map<String, List<Map<String, dynamic>>>> getAllPatientMedicalRecords(String patientId) async {
  try {
    final Map<String, List<Map<String, dynamic>>> allRecords = {
      'lab_results': [],
      'past_prescriptions': [],
      'other': [],
    };

    for (final category in allRecords.keys) {
      try {
        final records = await getPatientMedicalRecords(patientId, category);
        allRecords[category] = records;
      } catch (e) {
        debugPrint('❌ Error loading $category for patient $patientId: $e');
        allRecords[category] = [];
      }
    }

    return allRecords;
  } catch (e) {
    debugPrint('❌ Error getting all patient medical records: $e');
    return {
      'lab_results': [],
      'past_prescriptions': [],
      'other': [],
    };
  }
}
  // Get patient medical records by category
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(String patientId, String category) async {
    try {
      final ListResult result = await _storage.ref('medical_records/$patientId/$category').listAll();
      
      List<Map<String, dynamic>> records = [];
      
      for (final Reference ref in result.items) {
        try {
          final String path = ref.fullPath;
          final fileNameWithTimestamp = path.split('/').last;
          final fileName = fileNameWithTimestamp.substring(fileNameWithTimestamp.indexOf('_') + 1);
          
          final downloadUrl = await ref.getDownloadURL();
          final metadata = await ref.getMetadata();
          
          records.add({
            'fileName': fileName,
            'fileUrl': downloadUrl,
            'category': category,
            'uploadDate': metadata.timeCreated,
            'fileSize': metadata.size,
            'fullPath': path,
          });
        } catch (e) {
          debugPrint('❌ Error processing file: $e');
        }
      }
      
      // Sort by upload date (newest first)
      records.sort((a, b) => b['uploadDate'].compareTo(a['uploadDate']));
      return records;
    } catch (e) {
      debugPrint('❌ Error getting patient medical records: $e');
      return [];
    }
  }

  

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
        return 'Lab Test Results';
      case 'past_prescriptions':
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
        return '🧪';
      case 'past_prescriptions':
        return '💊';
      case 'other':
        return '📁';
      default:
        return '📄';
    }
  }
}