// services/medical_records_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/model/medical_record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';


class MedicalRecordsService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload medical record with category
  Future<MedicalRecord> uploadMedicalRecord({
    required File file,
    required String patientId,
    required String fileName,
    required RecordCategory category,
    String? description,
  }) async {
    try {
      debugPrint('📤 Uploading medical record: $fileName - ${category.displayName}');

      // Validate file type
      final String fileExtension = fileName.split('.').last.toLowerCase();
      if (!_isValidFileType(fileExtension)) {
        throw Exception('Invalid file type. Please upload PDF, JPG, or PNG files only.');
      }

      // Validate file size (max 20MB)
      final int fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        throw Exception('File size too large. Please select a file smaller than 20MB.');
      }

      // Create storage path with category
      final String storagePath = 'medical_records/$patientId/${category.name}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference storageRef = _storage.ref().child(storagePath);

      // Determine content type
      final String contentType = _getContentType(fileExtension);

      // Upload file
      final UploadTask uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Create record in Firestore
      final String recordId = _firestore.collection('medical_records').doc().id;
      final MedicalRecord record = MedicalRecord(
        id: recordId,
        patientId: patientId,
        fileName: fileName,
        fileUrl: downloadUrl,
        fileType: fileExtension,
        category: category,
        uploadDate: DateTime.now(),
        description: description,
        fileSize: fileSize,
      );

      await _firestore.collection('medical_records').doc(recordId).set(record.toMap());

      debugPrint('✅ Medical record uploaded successfully: $fileName');
      return record;
    } catch (e) {
      debugPrint('❌ Error uploading medical record: $e');
      rethrow;
    }
  }

  // Get all medical records for a patient
  Stream<List<MedicalRecord>> getPatientMedicalRecords(String patientId) {
    return _firestore
        .collection('medical_records')
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicalRecord.fromMap(doc.data()))
            .toList());
  }

  // Get medical records by category
  Stream<List<MedicalRecord>> getPatientMedicalRecordsByCategory(
      String patientId, RecordCategory category) {
    return _firestore
        .collection('medical_records')
        .where('patientId', isEqualTo: patientId)
        .where('category', isEqualTo: category.name)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicalRecord.fromMap(doc.data()))
            .toList());
  }

  // Delete medical record
  Future<void> deleteMedicalRecord(MedicalRecord record) async {
    try {
      // Delete from Firebase Storage
      final Reference storageRef = _storage.refFromURL(record.fileUrl);
      await storageRef.delete();

      // Delete from Firestore
      await _firestore.collection('medical_records').doc(record.id).delete();

      debugPrint('✅ Medical record deleted successfully: ${record.fileName}');
    } catch (e) {
      debugPrint('❌ Error deleting medical record: $e');
      rethrow;
    }
  }

  // Pick file with better permission handling
  Future<File?> pickMedicalRecord() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Validate file size
        if (await file.length() > 20 * 1024 * 1024) {
          throw Exception('File size too large. Please select a file smaller than 20MB.');
        }
        
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error picking medical record: $e');
      rethrow;
    }
  }

  // Helper methods
  bool _isValidFileType(String extension) {
    return ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'].contains(extension);
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
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
}