// lib/screens/admin_screens/admin_test_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/test_report_model.dart';
import '../../../services/test_report_service.dart';
import 'upload_test_report_dialog.dart';

class AdminTestReportsScreen extends StatefulWidget {
  final String medicalCenterId;
  final String medicalCenterName;

  const AdminTestReportsScreen({
    super.key,
    required this.medicalCenterId,
    required this.medicalCenterName,
  });

  @override
  State<AdminTestReportsScreen> createState() => _AdminTestReportsScreenState();
}

class _AdminTestReportsScreenState extends State<AdminTestReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _patients = [];
  List<TestReportModel> _testReports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load all patients (not filtered by medical center)
      _patients = await TestReportService.getAllPatients();
      
      debugPrint('Loaded ${_patients.length} patients');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Widget _buildTestReportStats() {
    final totalReports = _testReports.length;
    final normalReports = _testReports.where((r) => r.status == 'normal').length;
    final abnormalReports = _testReports.where((r) => r.status == 'abnormal').length;
    final criticalReports = _testReports.where((r) => r.status == 'critical').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCircle(totalReports, 'Total Reports', Colors.blue, Icons.assignment),
          _buildStatCircle(normalReports, 'Normal', Colors.green, Icons.check_circle),
          _buildStatCircle(abnormalReports, 'Abnormal', Colors.orange, Icons.warning),
          _buildStatCircle(criticalReports, 'Critical', Colors.red, Icons.error),
        ],
      ),
    );
  }

  Widget _buildStatCircle(int count, String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTestReportSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload New Test Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF18A3B6),
            ),
          ),
          const SizedBox(height: 16),
          _buildPatientSearch(),
          const SizedBox(height: 16),
          _buildPatientSelection(),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                _showUploadTestReportDialog();
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Test Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelection() {
    if (_patients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No Patients Found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Patients will appear here once they register in the system',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Patient for Test Report',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_patients.length} patients found in system',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Show limited patient preview with fixed height
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _patients.length > 3 ? 3 : _patients.length,
              itemBuilder: (context, index) {
                final patient = _patients[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF18A3B6),
                    radius: 20,
                    child: Text(
                      patient['fullname']?.toString().substring(0, 1) ?? 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    patient['fullname'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${patient['mobile'] ?? 'No phone'} • ${patient['age'] ?? '?'} years',
                    style: const TextStyle(fontSize: 12),
                  ),
                  dense: true,
                );
              },
            ),
          ),
          
          if (_patients.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... and ${_patients.length - 3} more patients',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search patients by name, email, or mobile...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (query) async {
          if (query.length >= 2) {
            final results = await TestReportService.searchPatients(query);
            setState(() {
              _patients = results;
            });
          } else if (query.isEmpty) {
            _loadInitialData(); // Reload all patients
          }
        },
      ),
    );
  }

  void _showUploadTestReportDialog() {
    if (_patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patients available to upload test reports')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => UploadTestReportDialog(
        patients: _patients,
        medicalCenterId: widget.medicalCenterId,
        medicalCenterName: widget.medicalCenterName,
        onReportUploaded: () {
          _loadInitialData();
        },
      ),
    );
  }

  Widget _buildTestReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: TestReportService.getMedicalCenterTestReports(widget.medicalCenterId),
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
                  'No Test Reports',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload test reports to see them here',
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
                        report.patientName,
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
                      report.fileSize,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Description
            if (report.description.isNotEmpty) ...[
              Text(
                report.description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
            ],
            
            // Lab Findings
            if (report.labFindings.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lab Findings:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...report.labFindings.entries.map((entry) {
                      return Text(
                        '• ${entry.key}: ${entry.value}',
                        style: const TextStyle(fontSize: 12),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Notes
            if (report.notes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Notes: ${report.notes}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _viewTestReport(report),
                  child: const Text('View Report'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.download, size: 18),
                  onPressed: () => _downloadTestReport(report),
                  tooltip: 'Download',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _deleteTestReport(report),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewTestReport(TestReportModel report) {
    // TODO: Implement view test report functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing ${report.testName}')),
    );
  }

  void _downloadTestReport(TestReportModel report) {
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${report.fileName}')),
    );
  }

  Future<void> _deleteTestReport(TestReportModel report) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Test Report'),
        content: const Text('Are you sure you want to delete this test report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      try {
        await TestReportService.deleteTestReport(report.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test report deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete test report: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test Reports Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.medicalCenterName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTestReportStats(),
          ),
          
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF18A3B6),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF18A3B6),
              tabs: const [
                Tab(text: 'Upload Reports'),
                Tab(text: 'All Reports'),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUploadTestReportSection(),
                      _buildTestReportsList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}