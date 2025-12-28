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
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, int> _reportStats = {
    'total': 0,
    'normal': 0,
    'abnormal': 0,
    'critical': 0,
  };
  bool _isStatsLoading = true;

  // Enhanced color scheme
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _primaryDark = const Color(0xFF12899B);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFFB2DEE6);
  final Color _backgroundColor = const Color(0xFFF8FBFD);
  final Color _cardColor = Colors.white;
  final Color _textPrimary = Color(0xFF2C3E50);
  final Color _textSecondary = Color(0xFF7F8C8D);
  final Color _successColor = Color(0xFF27AE60);
  final Color _warningColor = Color(0xFFE67E22);
  final Color _dangerColor = Color(0xFFE74C3C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
  try {
    print('🟡 START _loadInitialData()');
    setState(() {
      _isLoading = true;
      _isStatsLoading = true;
      _errorMessage = null;
    });

    print('🟡 Loading patients...');
    _patients = await TestReportService.getAllPatients();
    print('🟢 Loaded ${_patients.length} patients');
    
    print('🟡 Loading statistics...');
    _reportStats = await _getTestReportStats();
    print('🟢 Statistics loaded: $_reportStats');
    
    setState(() {
      print('🟡 Setting state: isLoading=false, isStatsLoading=false');
      _isLoading = false;
      _isStatsLoading = false;
    });
    print('🟢 _loadInitialData completed successfully');
    
  } catch (e) {
    print('🔴 Error in _loadInitialData: $e');
    debugPrint('Error loading initial data: $e');
    setState(() {
      _isLoading = false;
      _isStatsLoading = false;
      _errorMessage = 'Failed to load data: $e';
    });
  }
}
Widget _buildTestReportStats() {
  if (_isStatsLoading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Reports Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          'Reports Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
          children: [
            _buildCompactStatCard(_reportStats['total'] ?? 0, 'Total', Icons.assignment_outlined, _primaryColor),
            _buildCompactStatCard(_reportStats['normal'] ?? 0, 'Normal', Icons.check_circle_outlined, _successColor),
            _buildCompactStatCard(_reportStats['abnormal'] ?? 0, 'Abnormal', Icons.warning_amber_outlined, _warningColor),
            _buildCompactStatCard(_reportStats['critical'] ?? 0, 'Critical', Icons.error_outline, _dangerColor),
          ],
        ),
      ],
    ),
  );
}

Widget _buildCompactStatCard(int count, String title, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      ],
    ),
  );
}
  Widget _buildUploadTestReportSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.upload_file, color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload New Test Report',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            'Select a patient and upload their test results',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Search Section
          _buildPatientSearch(),

          const SizedBox(height: 24),

          // Patient Selection
          _buildPatientSelection(),

          const SizedBox(height: 32),

          // Upload Button
          Center(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _primaryDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  _showUploadTestReportDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Upload Test Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
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
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accentColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline, size: 40, color: _primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'No Patients Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Patients will appear here once they register in the system',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.people, size: 20, color: _primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Patient',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      '${_patients.length} patients available in system',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Patient List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _patients.length > 5 ? 5 : _patients.length,
              itemBuilder: (context, index) {
                final patient = _patients[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          patient['fullname']?.toString().substring(0, 1) ?? 'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      patient['fullname'] ?? 'Unknown Patient',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          patient['mobile'] ?? 'No phone number',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                          ),
                        ),
                        if (patient['age'] != null)
                          Text(
                            '${patient['age']} years old',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_patients.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '... and ${_patients.length - 5} more patients',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search patients by name, email, or mobile...',
          hintStyle: TextStyle(color: _textSecondary),
          prefixIcon: Icon(Icons.search, color: _primaryColor),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
  print('🟡 _showUploadTestReportDialog called');
  
  try {
    if (_patients.isEmpty) {
      print('🟡 No patients available');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No patients available to upload test reports'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    
    print('🟡 Showing dialog with ${_patients.length} patients');
    
    // Test if we can create the dialog first
    final testDialog = UploadTestReportDialog(
      patients: _patients,
      medicalCenterId: widget.medicalCenterId,
      medicalCenterName: widget.medicalCenterName,
      onReportUploaded: () {
        print('🟡 onReportUploaded callback triggered');
        _refreshStats();
        _loadInitialData();
      },
    );
    
    print('🟡 Dialog instance created successfully');
    
    showDialog(
      context: context,
      builder: (context) {
        print('🟡 Building UploadTestReportDialog in builder');
        return testDialog;
      },
    );
    
    print('🟢 Dialog shown successfully');
    
  } catch (e) {
    print('🔴 CRITICAL ERROR in _showUploadTestReportDialog: $e');
    print('🔴 Stack trace: ${e.toString()}');
    
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error opening dialog: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

Future<Map<String, int>> _getTestReportStats() async {
  try {
    print('🟡 Fetching test reports from Firestore...');
    
    final snapshot = await FirebaseFirestore.instance
        .collection('test_reports')
        .where('medicalCenterId', isEqualTo: widget.medicalCenterId)
        .get();

    print('🟢 Firestore query completed, ${snapshot.docs.length} documents found');
    
    final reports = snapshot.docs
        .map((doc) {
          print('🟡 Processing document: ${doc.id}');
          return TestReportModel.fromFirestore(doc);
        })
        .toList();

    final total = reports.length;
    final normal = reports.where((r) => r.status == 'normal').length;
    final abnormal = reports.where((r) => r.status == 'abnormal').length;
    final critical = reports.where((r) => r.status == 'critical').length;
    
    print('🟢 Stats calculated - Total: $total, Normal: $normal, Abnormal: $abnormal, Critical: $critical');
    
    return {
      'total': total,
      'normal': normal,
      'abnormal': abnormal,
      'critical': critical,
    };
  } catch (e) {
    print('🔴 Error in _getTestReportStats: $e');
    debugPrint('Error getting stats: $e');
    return {'total': 0, 'normal': 0, 'abnormal': 0, 'critical': 0};
  }
}
  Widget _buildTestReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: TestReportService.getMedicalCenterTestReports(widget.medicalCenterId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading test reports...',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _dangerColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, size: 40, color: _dangerColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Test Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _dangerColor,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 14,
                    ),
                  ),
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
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment, size: 50, color: _primaryColor),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Test Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload test reports to see them here',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            return _buildTestReportCard(reports[index]);
          },
        );
      },
    );
  }

 Widget _buildTestReportCard(TestReportModel report) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      report.statusColor.withOpacity(0.15),
                      report.statusColor.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: report.statusColor.withOpacity(0.3), width: 2),
                ),
                child: Icon(report.statusIcon, color: report.statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.testName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.patientName,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Test Date: ${report.formattedTestDate}',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: report.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: report.statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      report.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: report.statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.fileSize,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description
          if (report.description.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                report.description,
                style: TextStyle(
                  fontSize: 14,
                  color: _textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Notes
          if (report.notes.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 18, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notes: ${report.notes}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Actions
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          
          // FIXED: Wrap the Row with SingleChildScrollView to handle overflow
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildActionButton('View Report', Icons.visibility, _primaryColor, () => _viewTestReport(report)),
                const SizedBox(width: 8),
                _buildActionButton('Download', Icons.download, _secondaryColor, () => _downloadTestReport(report)),
                const SizedBox(width: 8),
                _buildActionButton('Delete', Icons.delete_outline, _dangerColor, () => _deleteTestReport(report)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
  return Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _viewTestReport(TestReportModel report) {
    // TODO: Implement view test report functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${report.testName}'),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
Future<void> _refreshStats() async {
  try {
    setState(() {
      _isStatsLoading = true;
    });
    
    final newStats = await _getTestReportStats();
    
    setState(() {
      _reportStats = newStats;
      _isStatsLoading = false;
    });
  } catch (e) {
    debugPrint('Error refreshing stats: $e');
    setState(() {
      _isStatsLoading = false;
    });
  }
}
  void _downloadTestReport(TestReportModel report) {
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${report.fileName}'),
        backgroundColor: _secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteTestReport(TestReportModel report) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _dangerColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete, color: _dangerColor),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Test Report',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the test report for "${report.testName}"? This action cannot be undone.',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _dangerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete Report',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
  try {
    await TestReportService.deleteTestReport(report.id);
    
    // Refresh statistics
    await _refreshStats();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test report deleted successfully'),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete test report: $e'),
          backgroundColor: _dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColor, _primaryDark],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.medical_services, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Reports Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.medicalCenterName,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
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
          ),
          
          // Stats
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildTestReportStats(),
            ),
          ),
          
          // Tabs
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: _primaryColor,
                unselectedLabelColor: _textSecondary,
                indicatorColor: _primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Upload Reports'),
                  Tab(text: 'All Reports'),
                ],
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading dashboard...',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
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