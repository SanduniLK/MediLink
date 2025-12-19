// lib/services/medical_records_service.dart - UPDATED
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/model/medical_record.dart';
import 'dart:io';
import 'google_vision_service.dart';

class MedicalRecordsService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload medical record with SILENT text extraction
  Future<MedicalRecord> uploadMedicalRecord({
    required File file,
    required String patientId,
    required String fileName,
    required RecordCategory category,
    String? description,
  }) async {
    try {
      debugPrint('📤 Starting upload: $fileName');
      
      // First extract text SILENTLY
      debugPrint('🔍 Extracting text silently...');
      Map<String, dynamic> extractedData = await GoogleVisionService.extractMedicalText(file);
      
      String? extractedText = extractedData['success'] ? extractedData['fullText'] : null;
      Map<String, dynamic>? medicalInfo = extractedData['success'] ? extractedData['medicalInfo'] : null;
      
      // Validate file type
      final String fileExtension = fileName.split('.').last.toLowerCase();
      if (!_isValidFileType(fileExtension)) {
        throw Exception('Invalid file type. Please upload PDF, JPG, or PNG files only.');
      }

      // Get file size
      final int fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        throw Exception('File size too large. Please select a file smaller than 20MB.');
      }

      //  Create storage path
      final String storagePath = 'medical_records/$patientId/${category.name}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference storageRef = _storage.ref().child(storagePath);

      //  Upload file to Firebase Storage
      final UploadTask uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: _getContentType(fileExtension)),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Create record ID
      final String recordId = _firestore.collection('medical_records').doc().id;
      
      // Create MedicalRecord object
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
        // Store minimal extraction info in medical_record
        extractedText: extractedText != null ? 'Text extracted (${extractedText.length} chars)' : null,
        medicalInfo: medicalInfo,
        textExtractionStatus: extractedData['success'] ? 'extracted' : 'failed',
        textExtractedAt: DateTime.now(),
      );

      // 8. Save to Firestore (medical_records collection)
      await _firestore.collection('medical_records').doc(recordId).set(record.toMap());

      // 9. 🔥 SILENTLY SAVE EXTRACTED TEXT TO PATIENT_NOTES COLLECTION
      if (extractedText != null && extractedText.isNotEmpty) {
        await _saveExtractedTextToPatientNotes(
          patientId: patientId,
          recordId: recordId,
          fileName: fileName,
          category: category,
          extractedText: extractedText,
          medicalInfo: medicalInfo,
        );
      }

      debugPrint('✅ Upload complete. Extraction: ${extractedData['success']}');
      debugPrint('✅ Extracted text saved to patient_notes collection');
      
      return record;
      
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      rethrow;
    }
  }

  // 🔥 NEW: Save extracted text to patient_notes collection
  Future<void> _saveExtractedTextToPatientNotes({
    required String patientId,
    required String recordId,
    required String fileName,
    required RecordCategory category,
    required String extractedText,
    Map<String, dynamic>? medicalInfo,
  }) async {
    try {
      final noteId = _firestore.collection('patient_notes').doc().id;
      
      final noteData = {
        'id': noteId,
        'patientId': patientId,
        'medicalRecordId': recordId,
        'fileName': fileName,
        'category': category.name,
        'extractedText': extractedText,
        'medicalInfo': medicalInfo ?? {},
        'extractedAt': Timestamp.now(),
        'wordCount': extractedText.split(' ').length,
        'charCount': extractedText.length,
        'hasMedications': (medicalInfo?['medications'] as List?)?.isNotEmpty ?? false,
        'hasLabResults': (medicalInfo?['labResults'] as List?)?.isNotEmpty ?? false,
        'noteType': 'extracted_from_document',
        'isProcessed': false, // For future AI processing
      };

      await _firestore.collection('patient_notes').doc(noteId).set(noteData);
      
      debugPrint('📝 Saved extracted text to patient_notes: $noteId');
      debugPrint('📝 Word count: ${noteData['wordCount']}, Char count: ${noteData['charCount']}');
      
    } catch (e) {
      debugPrint('❌ Error saving to patient_notes: $e');
      // Don't rethrow - we don't want to fail the whole upload if note saving fails
    }
  }

  // 🔥 NEW: Get extracted notes for a patient
  Stream<List<Map<String, dynamic>>> getPatientExtractedNotes(String patientId) {
    return _firestore
        .collection('patient_notes')
        .where('patientId', isEqualTo: patientId)
        .orderBy('extractedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  // 🔥 NEW: Search in extracted notes
  Stream<List<Map<String, dynamic>>> searchInPatientNotes(String patientId, String query) {
    return _firestore
        .collection('patient_notes')
        .where('patientId', isEqualTo: patientId)
        .orderBy('extractedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final notes = snapshot.docs.map((doc) => doc.data()).toList();
          return notes.where((note) {
            final text = note['extractedText']?.toString().toLowerCase() ?? '';
            return text.contains(query.toLowerCase());
          }).toList();
        });
  }

  // NEW: Get notes by category
  Stream<List<Map<String, dynamic>>> getPatientNotesByCategory(
      String patientId, String category) {
    return _firestore
        .collection('patient_notes')
        .where('patientId', isEqualTo: patientId)
        .where('category', isEqualTo: category)
        .orderBy('extractedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  // Existing methods remain the same...
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

  Future<void> deleteMedicalRecord(MedicalRecord record) async {
    try {
      // Delete from Firebase Storage
      final Reference storageRef = _storage.refFromURL(record.fileUrl);
      await storageRef.delete();

      // Delete from Firestore (medical_records)
      await _firestore.collection('medical_records').doc(record.id).delete();

      // 🔥 ALSO DELETE FROM PATIENT_NOTES COLLECTION
      final notesQuery = await _firestore
          .collection('patient_notes')
          .where('medicalRecordId', isEqualTo: record.id)
          .get();
      
      for (final doc in notesQuery.docs) {
        await doc.reference.delete();
      }

      debugPrint('✅ Medical record deleted: ${record.fileName}');
      debugPrint('✅ Associated notes deleted from patient_notes');
    } catch (e) {
      debugPrint('❌ Error deleting medical record: $e');
      rethrow;
    }
  }

  Future<File?> pickMedicalRecord() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
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
      debugPrint('❌ Error picking file: $e');
      rethrow;
    }
  }

  // Helper methods
  bool _isValidFileType(String extension) {
    return ['pdf', 'jpg', 'jpeg', 'png'].contains(extension);
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