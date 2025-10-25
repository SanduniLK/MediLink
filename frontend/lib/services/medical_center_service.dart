import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/medical_center_model.dart';

class MedicalCenterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'medicalCenters';

  // Get medical centers where doctor is registered
  static Stream<List<MedicalCenter>> getDoctorMedicalCenters(String doctorId) {
    return _firestore
        .collection('doctorMedicalCenters')
        .where('doctorId', isEqualTo: doctorId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final centers = <MedicalCenter>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final centerId = data['medicalCenterId'];
        
        final centerDoc = await _firestore
            .collection(collectionName)
            .doc(centerId)
            .get();
            
        if (centerDoc.exists) {
          centers.add(MedicalCenter.fromJson({
            'id': centerDoc.id,
            ...centerDoc.data()!,
          }));
        }
      }
      
      return centers;
    });
  }

  // Get medical center by admin ID
  static Stream<MedicalCenter?> getMedicalCenterByAdmin(String adminId) {
    return _firestore
        .collection(collectionName)
        .where('adminId', isEqualTo: adminId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return MedicalCenter.fromJson({
          'id': snapshot.docs.first.id,
          ...snapshot.docs.first.data(),
        });
      }
      return null;
    });
  }

  // Add mock data with admins
  static Future<void> addMockMedicalCenters() async {
    final mockCenters = [
      {
        'name': 'City General Hospital',
        'address': '123 Main Street, City Center',
        'phone': '+1 234-567-8900',
        'email': 'info@citygeneral.com',
        'adminId': 'admin_city_hospital', // Medical center admin ID
        'adminName': 'Dr. Sarah Johnson',
        'isActive': true,
      },
      {
        'name': 'Community Health Clinic',
        'address': '456 Oak Avenue, Suburbia', 
        'phone': '+1 234-567-8901',
        'email': 'contact@communityclinic.com',
        'adminId': 'admin_community_clinic',
        'adminName': 'Dr. Michael Brown',
        'isActive': true,
      },
    ];

    for (final centerData in mockCenters) {
      await _firestore.collection(collectionName).add(centerData);
    }
  }
}