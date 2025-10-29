// lib/services/test_report_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class TestReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload test report file to Firebase Storage - MOBILE COMPATIBLE
  static Future<String> uploadTestReportFile(PlatformFile platformFile) async {
    try {
      debugPrint('🟡 [Storage] Starting file upload...');
      debugPrint('🟡 File name: ${platformFile.name}');
      debugPrint('🟡 File size: ${platformFile.size} bytes');

      // Create unique file name
      final String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${_sanitizeFileName(platformFile.name)}';
      final Reference ref = _storage.ref().child('test_reports/$uniqueFileName');
      
      debugPrint('🟡 Storage path: test_reports/$uniqueFileName');
      
      final UploadTask uploadTask;
      
      if (platformFile.bytes != null) {
        // Use bytes if available (works on both web and mobile)
        uploadTask = ref.putData(
          platformFile.bytes!,
          SettableMetadata(
            contentType: _getMimeType(platformFile.name),
            customMetadata: {
              'originalName': platformFile.name,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        );
      } else if (platformFile.path != null && !kIsWeb) {
        // For mobile, use file path
        final file = File(platformFile.path!);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: _getMimeType(platformFile.name),
            customMetadata: {
              'originalName': platformFile.name,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        );
      } else {
        throw Exception('No file data available for upload');
      }

      // Listen for state changes
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.totalBytes != null && snapshot.totalBytes! > 0
            ? (snapshot.bytesTransferred / snapshot.totalBytes!) * 100
            : 0;
        debugPrint('🟡 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('🟢 [Storage] File uploaded successfully!');
        debugPrint('🟢 Download URL: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('🔴 [Storage] File upload failed: $e');
      rethrow;
    }
  }

  // Sanitize file name for Firebase Storage
  static String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  // Helper method to determine MIME type
  static String? _getMimeType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf': return 'application/pdf';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default: return 'application/octet-stream';
    }
  }

  // Add new test report - MOBILE COMPATIBLE
  static Future<String> addTestReport({
    required String patientId,
    required String patientName,
    required String medicalCenterId,
    required String medicalCenterName,
    required String testName,
    required String testType,
    required String description,
    required PlatformFile platformFile,
    required DateTime testDate,
    required Map<String, dynamic> labFindings,
    required String status,
    required String notes,
  }) async {
    try {
      debugPrint('🚀 [1/4] Starting test report upload process...');
      debugPrint('🟡 Patient: $patientName ($patientId)');
      debugPrint('🟡 Medical Center: $medicalCenterName ($medicalCenterId)');
      debugPrint('🟡 Test: $testName ($testType)');
      debugPrint('🟡 Status: $status');
      debugPrint('🟡 Lab findings count: ${labFindings.length}');

      // Validate inputs
      if (patientId.isEmpty) throw Exception('Patient ID is required');
      if (testName.isEmpty) throw Exception('Test name is required');
      if (testType.isEmpty) throw Exception('Test type is required');
      if (platformFile.name.isEmpty) throw Exception('File is required');

      // Calculate file size
      final String fileSize = platformFile.size > 0 
          ? '${(platformFile.size / 1024 / 1024).toStringAsFixed(2)} MB'
          : 'Unknown size';

      debugPrint('🟡 File name: ${platformFile.name}');
      debugPrint('🟡 File size: $fileSize');

      // Upload file to storage
      debugPrint('📤 [2/4] Uploading file to Firebase Storage...');
      final String fileUrl = await uploadTestReportFile(platformFile);

      debugPrint('🟢 File uploaded successfully!');
      debugPrint('🟢 File URL: $fileUrl');

      // Create test report document
      final reportData = {
        'id': '', // Will be set after document creation
        'patientId': patientId,
        'patientName': patientName.trim(),
        'medicalCenterId': medicalCenterId,
        'medicalCenterName': medicalCenterName.trim(),
        'testName': testName.trim(),
        'testType': testType.trim(),
        'description': description.trim(),
        'fileUrl': fileUrl,
        'fileName': platformFile.name,
        'fileSize': fileSize,
        'testDate': Timestamp.fromDate(testDate),
        'uploadedAt': Timestamp.now(),
        'uploadedBy': _auth.currentUser?.uid ?? 'unknown',
        'uploadedByName': _auth.currentUser?.email ?? 'admin',
        'labFindings': labFindings,
        'status': status,
        'notes': notes.trim(),
        'updatedAt': Timestamp.now(),
      };

      debugPrint('💾 [3/4] Saving to Firestore...');
      debugPrint('🟡 Report data prepared');

      // Save to Firestore and get document reference
      final DocumentReference docRef = await _firestore.collection('test_reports').add(reportData);
      
      // Update the document with its ID
      await docRef.update({'id': docRef.id});
      
      debugPrint('✅ [4/4] Test report saved successfully!');
      debugPrint('✅ Document ID: ${docRef.id}');
      debugPrint('✅ Test report uploaded for patient: $patientName');
      debugPrint('✅ Total process completed successfully!');

      return docRef.id;

    } catch (e) {
      debugPrint('🔴 ERROR in addTestReport: $e');
      debugPrint('🔴 Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        debugPrint('🔴 Firebase error code: ${e.code}');
        debugPrint('🔴 Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // ... (keep all other methods the same as your original)
  // Get test reports for a patient with error handling
  static Stream<QuerySnapshot> getPatientTestReports(String patientId) {
    try {
      if (patientId.isEmpty) {
        throw Exception('Patient ID cannot be empty');
      }
      
      debugPrint('🟡 Getting test reports for patient: $patientId');
      return _firestore
          .collection('test_reports')
          .where('patientId', isEqualTo: patientId)
          .orderBy('testDate', descending: true)
          .snapshots()
          .handleError((error) {
            debugPrint('🔴 Error in getPatientTestReports stream: $error');
            throw error;
          });
    } catch (e) {
      debugPrint('🔴 Error setting up patient test reports stream: $e');
      rethrow;
    }
  }

  // Get test reports for a medical center with error handling
  static Stream<QuerySnapshot> getMedicalCenterTestReports(String medicalCenterId) {
    try {
      if (medicalCenterId.isEmpty) {
        throw Exception('Medical Center ID cannot be empty');
      }
      
      debugPrint('🟡 Getting test reports for medical center: $medicalCenterId');
      return _firestore
          .collection('test_reports')
          .where('medicalCenterId', isEqualTo: medicalCenterId)
          .orderBy('testDate', descending: true)
          .snapshots()
          .handleError((error) {
            debugPrint('🔴 Error in getMedicalCenterTestReports stream: $error');
            throw error;
          });
    } catch (e) {
      debugPrint('🔴 Error setting up medical center test reports stream: $e');
      rethrow;
    }
  }

  // Get all patients with enhanced error handling and fallbacks
  static Future<List<Map<String, dynamic>>> getAllPatients() async {
    try {
      debugPrint('🟡 Fetching all patients...');

      // Try patients collection first
      final patientsSnapshot = await _firestore
          .collection('patients')
          .where('role', isEqualTo: 'patient')
          .get();

      if (patientsSnapshot.docs.isNotEmpty) {
        debugPrint('🟢 Found ${patientsSnapshot.docs.length} patients in patients collection');
        return patientsSnapshot.docs.map((doc) {
          final data = doc.data();
          return _buildPatientData(doc.id, data);
        }).toList();
      }

      debugPrint('🟡 No patients found in patients collection, trying users collection...');
      
      // Fallback to users collection
      return await _getPatientsFromUsersCollection();
      
    } catch (e) {
      debugPrint('🔴 Error fetching patients: $e');
      // Final fallback to users collection
      return await _getPatientsFromUsersCollection();
    }
  }

  // Alternative method to get patients from users collection
  static Future<List<Map<String, dynamic>>> _getPatientsFromUsersCollection() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();

      debugPrint('🟢 Found ${snapshot.docs.length} patients in users collection');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _buildPatientData(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('🔴 Error fetching patients from users collection: $e');
      return [];
    }
  }

  // Helper method to build patient data consistently
  static Map<String, dynamic> _buildPatientData(String docId, Map<String, dynamic> data) {
    return {
      'uid': docId,
      'fullname': data['fullname'] ?? data['name'] ?? 'Unknown',
      'email': data['email'] ?? '',
      'mobile': data['mobile'] ?? data['phone'] ?? '',
      'age': data['age'] ?? 0,
      'gender': data['gender'] ?? '',
      'bloodGroup': data['bloodGroup'] ?? '',
      'address': data['address'] ?? '',
      'allergies': data['allergies'] ?? '',
      'dob': data['dob'] ?? '',
      'height': data['height'] ?? 0,
      'weight': data['weight'] ?? 0,
    };
  }

  // Delete test report with comprehensive cleanup
  static Future<void> deleteTestReport(String reportId) async {
    try {
      debugPrint('🟡 Starting deletion of test report: $reportId');

      if (reportId.isEmpty) {
        throw Exception('Report ID cannot be empty');
      }

      // Get report data to delete file from storage
      final reportDoc = await _firestore.collection('test_reports').doc(reportId).get();
      
      if (!reportDoc.exists) {
        throw Exception('Test report with ID $reportId does not exist');
      }

      final reportData = reportDoc.data()!;
      
      // Delete file from storage if URL exists
      if (reportData['fileUrl'] != null) {
        try {
          final fileUrl = reportData['fileUrl'] as String;
          debugPrint('🟡 Deleting file from storage: $fileUrl');
          final ref = _storage.refFromURL(fileUrl);
          await ref.delete();
          debugPrint('🟢 File deleted from storage successfully');
        } catch (e) {
          debugPrint('🟡 Could not delete file from storage (may already be deleted): $e');
          // Continue with document deletion even if file deletion fails
        }
      }
      
      // Delete document from Firestore
      debugPrint('🟡 Deleting document from Firestore');
      await _firestore.collection('test_reports').doc(reportId).delete();
      
      debugPrint('✅ Test report deleted successfully: $reportId');

    } catch (e) {
      debugPrint('🔴 Error deleting test report: $e');
      rethrow;
    }
  }

  // Update test report with validation
  static Future<void> updateTestReport({
    required String reportId,
    required String testName,
    required String testType,
    required String description,
    required DateTime testDate,
    required Map<String, dynamic> labFindings,
    required String status,
    required String notes,
  }) async {
    try {
      debugPrint('🟡 Updating test report: $reportId');

      if (reportId.isEmpty) throw Exception('Report ID cannot be empty');
      if (testName.isEmpty) throw Exception('Test name cannot be empty');
      if (testType.isEmpty) throw Exception('Test type cannot be empty');

      final updateData = {
        'testName': testName.trim(),
        'testType': testType.trim(),
        'description': description.trim(),
        'testDate': Timestamp.fromDate(testDate),
        'labFindings': labFindings,
        'status': status,
        'notes': notes.trim(),
        'updatedAt': Timestamp.now(),
      };

      await _firestore.collection('test_reports').doc(reportId).update(updateData);
      
      debugPrint('✅ Test report updated successfully: $reportId');

    } catch (e) {
      debugPrint('🔴 Error updating test report: $e');
      rethrow;
    }
  }

  // Search patients by name, email, or mobile with improved search
  static Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    try {
      debugPrint('🔍 Searching patients with query: "$query"');

      if (query.length < 2) {
        debugPrint('🟡 Query too short, returning empty results');
        return [];
      }

      final allPatients = await getAllPatients();
      final searchQuery = query.toLowerCase().trim();

      final results = allPatients.where((patient) {
        final fullname = patient['fullname']?.toString().toLowerCase() ?? '';
        final email = patient['email']?.toString().toLowerCase() ?? '';
        final mobile = patient['mobile']?.toString().toLowerCase() ?? '';
        
        return fullname.contains(searchQuery) || 
               email.contains(searchQuery) || 
               mobile.contains(searchQuery);
      }).toList();

      debugPrint('🟢 Found ${results.length} patients matching "$query"');
      return results;

    } catch (e) {
      debugPrint('🔴 Error searching patients: $e');
      return [];
    }
  }

  // Get single test report by ID
  static Future<Map<String, dynamic>?> getTestReportById(String reportId) async {
    try {
      if (reportId.isEmpty) return null;

      final doc = await _firestore.collection('test_reports').doc(reportId).get();
      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }
      return null;
    } catch (e) {
      debugPrint('🔴 Error getting test report by ID: $e');
      return null;
    }
  }

  // Get test reports count for statistics
  static Future<Map<String, int>> getTestReportsStats(String medicalCenterId) async {
    try {
      final snapshot = await _firestore
          .collection('test_reports')
          .where('medicalCenterId', isEqualTo: medicalCenterId)
          .get();

      final total = snapshot.docs.length;
      final normal = snapshot.docs.where((doc) => doc['status'] == 'normal').length;
      final abnormal = snapshot.docs.where((doc) => doc['status'] == 'abnormal').length;
      final critical = snapshot.docs.where((doc) => doc['status'] == 'critical').length;

      return {
        'total': total,
        'normal': normal,
        'abnormal': abnormal,
        'critical': critical,
      };
    } catch (e) {
      debugPrint('🔴 Error getting test reports stats: $e');
      return {'total': 0, 'normal': 0, 'abnormal': 0, 'critical': 0};
    }
  }
}