// lib/screens/patient_screens/patient_test_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/model/test_report_model.dart';
import 'package:frontend/screens/admin_screens/admin_test_reports_screen.dart';
import 'package:frontend/screens/patient_screens/test_report_view_screen.dart';
import 'package:intl/intl.dart';
import '../../../services/test_report_service.dart';


class PatientTestReportsScreen extends StatefulWidget {
  const PatientTestReportsScreen({super.key});

  @override
  State<PatientTestReportsScreen> createState() => _PatientTestReportsScreenState();
}

class _PatientTestReportsScreenState extends State<PatientTestReportsScreen> {
  List<TestReportModel> _testReports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTestReports();
  }

  void _loadTestReports() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
  }

  Widget _buildTestReportsList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('Please login to view test reports'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: TestReportService.getPatientTestReports(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error Loading Test Reports',
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final reports = snapshot.data?.docs
            .map((doc) => TestReportModel.fromFirestore(doc))
            .toList() ?? [];

        _testReports = reports;

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No Test Reports Available',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your test reports will appear here once they are uploaded by your medical center',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            return _buildTestReportCard(reports[index]);
          },
        );
      },
    );
  }

  Widget _buildTestReportCard(TestReportModel report) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: report.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(report.statusIcon, color: report.statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.testName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.medicalCenterName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Test Date: ${report.formattedTestDate}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: report.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: report.statusColor),
                      ),
                      child: Text(
                        report.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: report.statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.formattedUploadDate,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Quick Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: report.statusColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: report.statusColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${report.status.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: report.statusColor,
                    ),
                  ),
                  if (report.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      report.notes,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Key Findings (show first 3)
            if (report.labFindings.isNotEmpty) ...[
              Text(
                'Key Findings:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              ...report.labFindings.entries.take(3).map((entry) {
                return Text(
                  '• ${entry.key}: ${entry.value}',
                  style: const TextStyle(fontSize: 12),
                );
              }),
              if (report.labFindings.length > 3) ...[
                Text(
                  '• ...and ${report.labFindings.length - 3} more',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 12),
            ],
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TestReportViewScreen(testReport: report),
                      ),
                    );
                  },
                  child: const Text('View Full Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Test Reports'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: _buildTestReportsList(),
    );
  }
}