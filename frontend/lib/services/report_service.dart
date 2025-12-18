// services/report_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/report_model.dart';


class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate and save a report
  Future<String> generateReport(MedicalReport report) async {
    try {
      // Create a document reference
      final reportRef = _firestore.collection('medical_reports').doc();
      final reportId = reportRef.id;
      
      // Create report data
      final reportData = report.toMap();
      reportData['id'] = reportId;
      
      // Save to Firestore
      await reportRef.set(reportData);
      
      return reportId;
    } catch (e) {
      throw Exception('Failed to generate report: $e');
    }
  }

  // Get all reports for a patient
  Future<List<MedicalReport>> getPatientReports(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection('medical_reports')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MedicalReport.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get reports: $e');
    }
  }

  // Get reports by doctor
  Future<List<MedicalReport>> getDoctorReports(String doctorId) async {
    try {
      final snapshot = await _firestore
          .collection('medical_reports')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MedicalReport.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get doctor reports: $e');
    }
  }

  // Delete a report
  Future<void> deleteReport(String reportId) async {
    try {
      await _firestore.collection('medical_reports').doc(reportId).delete();
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }

  // Generate PDF (template method - you'll implement PDF generation separately)
  Future<String> generatePDF(MedicalReport report) async {
    // This is a placeholder - you'll need a PDF generation library
    // I'll show you this separately
    return 'PDF generated successfully';
  }
}