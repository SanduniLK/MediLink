// services/prescription_firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PrescriptionFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Fetch ALL prescriptions from Firestore with image URLs
  Future<List<DoctorPrescription>> fetchAllDoctorsPrescriptions() async {
    try {
      print('🔄 Fetching ALL prescriptions from Firestore...');
      
      // Get all prescriptions ordered by date (newest first)
      final QuerySnapshot prescriptionSnapshot = await _firestore
          .collection('prescriptions')
          .orderBy('createdAt', descending: true)
          .get();

      print('📄 Found ${prescriptionSnapshot.docs.length} prescriptions in Firestore');

      // Group prescriptions by doctor
      Map<String, List<PrescriptionData>> doctorPrescriptionsMap = {};
      
      for (final doc in prescriptionSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Only include prescriptions that have an image URL
          if (data['prescriptionImageUrl'] != null) {
            final prescription = PrescriptionData.fromFirestore(data);
            final doctorId = prescription.doctorId;
            
            if (!doctorPrescriptionsMap.containsKey(doctorId)) {
              doctorPrescriptionsMap[doctorId] = [];
            }
            doctorPrescriptionsMap[doctorId]!.add(prescription);
          }
        } catch (e) {
          print('❌ Error parsing prescription ${doc.id}: $e');
        }
      }

      // Convert to DoctorPrescription objects
      List<DoctorPrescription> allDoctorsPrescriptions = [];
      
      for (final doctorId in doctorPrescriptionsMap.keys) {
        try {
          final doctorInfo = await _getDoctorInfo(doctorId);
          final profileImageUrl = await _getDoctorProfileImage(doctorId);
          final prescriptions = doctorPrescriptionsMap[doctorId]!;
          
          allDoctorsPrescriptions.add(DoctorPrescription(
            doctorId: doctorId,
            doctorName: doctorInfo['name'],
            doctorSpecialization: doctorInfo['specialization'],
            prescriptions: prescriptions,
            prescriptionCount: prescriptions.length,
            profileImageUrl: profileImageUrl,
          ));
        } catch (e) {
          print('❌ Error processing doctor $doctorId: $e');
        }
      }

      // Sort by prescription count (most active first)
      allDoctorsPrescriptions.sort((a, b) => b.prescriptionCount.compareTo(a.prescriptionCount));

      print('🎉 TOTAL: Loaded ${allDoctorsPrescriptions.length} doctors with ${prescriptionSnapshot.docs.length} prescriptions');
      return allDoctorsPrescriptions;
      
    } catch (e) {
      print('❌ Error fetching prescriptions from Firestore: $e');
      throw Exception('Failed to load prescriptions: $e');
    }
  }

  // Fetch prescriptions for a specific doctor
  Future<List<PrescriptionData>> fetchDoctorPrescriptions(String doctorId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('prescriptions')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .where((doc) => doc['prescriptionImageUrl'] != null)
          .map((doc) => PrescriptionData.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error fetching doctor prescriptions: $e');
      return [];
    }
  }

  // Get doctor info from Firestore
  Future<Map<String, dynamic>> _getDoctorInfo(String doctorId) async {
    try {
      final doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();
      if (doctorDoc.exists) {
        final data = doctorDoc.data()!;
        return {
          'name': data['fullname'] ?? 'Dr. Unknown',
          'specialization': data['specialization'] ?? 'General Practitioner',
          'medicalCenter': data['hospital'] ?? data['medicalCenter'] ?? 'Unknown Medical Center',
          'regNumber': data['regNumber'] ?? '',
        };
      }
    } catch (e) {
      print('⚠️ Error fetching doctor info: $e');
    }
    return {
      'name': 'Dr. Unknown',
      'specialization': 'General Practitioner',
      'medicalCenter': 'Unknown Medical Center',
      'regNumber': '',
    };
  }

  // Get doctor profile image
  Future<String?> _getDoctorProfileImage(String doctorId) async {
    try {
      // Check Firestore first
      final doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();
      if (doctorDoc.exists) {
        final profileImageUrl = doctorDoc.data()?['profileImage'];
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          return profileImageUrl;
        }
      }

      // Check Storage
      try {
        final doctorFolderRef = _storage.ref().child('doctor_profile_images/$doctorId');
        final result = await doctorFolderRef.listAll();
        
        for (final item in result.items) {
          try {
            return await item.getDownloadURL();
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        print('❌ No profile image in storage for doctor $doctorId');
      }

      return null;
    } catch (e) {
      print('❌ Error getting doctor profile image: $e');
      return null;
    }
  }
  static Future<Map<String, dynamic>?> getPrescriptionByAppointmentId(String appointmentId) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('appointmentId', isEqualTo: appointmentId)
        .limit(1)
        .get();
    
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    }
    return null;
  } catch (e) {
    print('❌ Error fetching prescription: $e');
    return null;
  }
}
}

// Updated Model Classes
class DoctorPrescription {
  final String doctorId;
  final String doctorName;
  final String doctorSpecialization;
  final List<PrescriptionData> prescriptions;
  final int prescriptionCount;
  final String? profileImageUrl;

  DoctorPrescription({
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialization,
    required this.prescriptions,
    required this.prescriptionCount,
    this.profileImageUrl,
  });
}

class PrescriptionData {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final int? patientAge;
  final DateTime date;
  final String prescriptionImageUrl;
  final String diagnosis;
  final String description;
  final String notes;
  final List<Medicine> medicines;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrescriptionData({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.patientAge,
    required this.date,
    required this.prescriptionImageUrl,
    required this.diagnosis,
    required this.description,
    required this.notes,
    required this.medicines,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrescriptionData.fromFirestore(Map<String, dynamic> data) {
    // Convert timestamp numbers to DateTime
    DateTime convertTimestamp(dynamic timestamp) {
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else {
        return DateTime.now();
      }
    }

    // Parse medicines array
    List<Medicine> parseMedicines(List<dynamic> medicinesList) {
      return medicinesList.map((medicine) {
        final medMap = medicine as Map<String, dynamic>;
        return Medicine(
          name: medMap['name']?.toString() ?? '',
          dosage: medMap['dosage']?.toString() ?? '',
          duration: medMap['duration']?.toString() ?? '',
          frequency: medMap['frequency']?.toString() ?? '',
          instructions: medMap['instructions']?.toString() ?? '',
        );
      }).toList();
    }

    return PrescriptionData(
      id: data['id']?.toString() ?? '',
      doctorId: data['doctorId']?.toString() ?? '',
      patientId: data['patientId']?.toString() ?? '',
      patientName: data['patientName']?.toString() ?? 'Unknown Patient',
      patientAge: data['patientAge'] is int ? data['patientAge'] as int? : null,
      date: convertTimestamp(data['date']),
      prescriptionImageUrl: data['prescriptionImageUrl']?.toString() ?? '',
      diagnosis: data['diagnosis']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      medicines: data['medicines'] != null ? parseMedicines(data['medicines'] as List<dynamic>) : [],
      status: data['status']?.toString() ?? 'completed',
      createdAt: convertTimestamp(data['createdAt']),
      updatedAt: convertTimestamp(data['updatedAt']),
    );
  }
}

class Medicine {
  final String name;
  final String dosage;
  final String duration;
  final String frequency;
  final String instructions;

  Medicine({
    required this.name,
    required this.dosage,
    required this.duration,
    required this.frequency,
    required this.instructions,
  });
}