// services/patient_service.dart - COMPLETE UPDATED CODE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PatientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get patient data from patients collection
  Future<Map<String, dynamic>> getPatientData(String patientId) async {
    try {
      if (kDebugMode) {
        print('👤 Fetching patient data for: $patientId');
      }
      
      // Try patients collection first
      DocumentSnapshot patientDoc = await _firestore
          .collection('patients')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        if (kDebugMode) {
          print('✅ Found patient in patients collection');
        }
        Map<String, dynamic> patientData = patientDoc.data() as Map<String, dynamic>;
        
        // Process profile picture URL
        if (patientData['profilePic'] != null && patientData['profilePic'].isNotEmpty) {
          if (kDebugMode) {
            print('🖼️ Original profilePic: ${patientData['profilePic']}');
          }
          patientData['profilePic'] = _fixProfilePicUrl(patientData['profilePic'], patientId);
          if (kDebugMode) {
            print('🖼️ Fixed profilePic: ${patientData['profilePic']}');
          }
        } else {
          if (kDebugMode) {
            print('❌ No profilePic found in patient data, using default');
          }
          // Set default profile picture
          patientData['profilePic'] = null;
        }
        
        // Calculate age from dob if not already present
        if (patientData['dob'] != null && patientData['age'] == null) {
          patientData['age'] = _calculateAge(patientData['dob']);
        }
        
        // Calculate BMI if weight and height are available but BMI is not
        if (patientData['weight'] != null && patientData['height'] != null && patientData['bmi'] == null) {
          patientData['bmi'] = _calculateBMI(patientData['weight'], patientData['height']);
        }
        
        return patientData;
      } else {
        // Fallback to users collection if patient not found in patients collection
        if (kDebugMode) {
          print('⚠️ Patient not found in patients collection, trying users collection');
        }
        
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(patientId)
            .get();

        if (userDoc.exists) {
          if (kDebugMode) {
            print('✅ Found patient in users collection (fallback)');
          }
          Map<String, dynamic> patientData = userDoc.data() as Map<String, dynamic>;
          
          // Process profile picture URL
          if (patientData['profilePic'] != null && patientData['profilePic'].isNotEmpty) {
            patientData['profilePic'] = _fixProfilePicUrl(patientData['profilePic'], patientId);
          } else {
            patientData['profilePic'] = null;
          }
          
          // Calculate age from dob
          if (patientData['dob'] != null) {
            patientData['age'] = _calculateAge(patientData['dob']);
          }
          
          // Calculate BMI if not already present
          if (patientData['weight'] != null && patientData['height'] != null && patientData['bmi'] == null) {
            patientData['bmi'] = _calculateBMI(patientData['weight'], patientData['height']);
          }
          
          return patientData;
        } else {
          throw Exception('Patient not found in patients or users collection');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching patient data: $e');
      }
      rethrow;
    }
  }

  // Fix profile picture URL - handle different URL formats
  String _fixProfilePicUrl(String originalUrl, String patientId) {
    try {
      if (originalUrl.startsWith('gs://')) {
        return _convertGsUrlToHttps(originalUrl);
      }
      else if (originalUrl.contains('firebasestorage.googleapis.com')) {
        // If it's already a Firebase Storage URL, return as is
        return originalUrl;
      }
      else if (originalUrl.startsWith('http')) {
        return originalUrl;
      }
      else {
        // Assume it's a filename or invalid path, construct proper URL
        return _constructProfilePicUrl(patientId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fixing profile pic URL: $e');
      }
      return originalUrl; // Return original on error
    }
  }

  // Construct proper profile picture URL
  String _constructProfilePicUrl(String patientId) {
    // Use the correct path for patient profile images
    String encodedPath = 'patient_profile_images%2F$patientId.jpg';
    return 'https://firebasestorage.googleapis.com/v0/b/medilink-c7499.firebasestorage.app/o/$encodedPath?alt=media';
  }

  // Convert gs:// URL to HTTPS
  String _convertGsUrlToHttps(String gsUrl) {
    try {
      if (gsUrl.startsWith('gs://')) {
        String path = gsUrl.substring(5);
        int firstSlash = path.indexOf('/');
        if (firstSlash != -1) {
          String bucket = path.substring(0, firstSlash);
          String filePath = path.substring(firstSlash + 1);
          String encodedPath = filePath.replaceAll('/', '%2F');
          return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
        }
      }
      return gsUrl;
    } catch (e) {
      return gsUrl;
    }
  }

  // Get patient medical stats from medical_records
  Future<Map<String, dynamic>> getPatientMedicalStats(String patientId) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching medical stats for patient: $patientId');
      }
      
      // Get record counts from medical_records collection
      QuerySnapshot recordsSnapshot = await _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: patientId)
          .get();

      int labResultsCount = 0;
      int prescriptionsCount = 0;
      int otherCount = 0;
      DateTime? lastUploadDate;

      for (var doc in recordsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] ?? '';
        
        if (category == 'lab_results') labResultsCount++;
        else if (category == 'past_prescriptions') prescriptionsCount++;
        else if (category == 'other') otherCount++;

        final uploadDate = data['uploadDate'];
        if (uploadDate != null) {
          final date = uploadDate is Timestamp 
              ? uploadDate.toDate()
              : DateTime.fromMillisecondsSinceEpoch(uploadDate);
          if (lastUploadDate == null || date.isAfter(lastUploadDate)) {
            lastUploadDate = date;
          }
        }
      }

      if (kDebugMode) {
        print('📈 Medical stats - Lab: $labResultsCount, Prescriptions: $prescriptionsCount, Other: $otherCount');
      }

      return {
        'labResultsCount': labResultsCount,
        'prescriptionsCount': prescriptionsCount,
        'otherCount': otherCount,
        'totalRecords': labResultsCount + prescriptionsCount + otherCount,
        'lastUploadDate': lastUploadDate,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching medical stats: $e');
      }
      return {
        'labResultsCount': 0,
        'prescriptionsCount': 0,
        'otherCount': 0,
        'totalRecords': 0,
        'lastUploadDate': null,
      };
    }
  }

  // Helper method to calculate age from dob string
  int _calculateAge(String dobString) {
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating age from $dobString: $e');
      }
      return 0;
    }
  }

  // Helper method to calculate BMI
  double _calculateBMI(double weight, double height) {
    try {
      // Convert height from cm to meters and calculate BMI
      double heightInMeters = height / 100;
      double bmi = weight / (heightInMeters * heightInMeters);
      
      if (kDebugMode) {
        print('⚖️ Calculated BMI: $bmi from weight: $weight kg, height: $height cm');
      }
      
      return double.parse(bmi.toStringAsFixed(1));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating BMI: $e');
      }
      return 0.0;
    }
  }
}