// screens/doctor_screens/doctor_patient_profile_screen.dart - COMPLETE FIXED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';
import 'package:frontend/screens/patient_screens/health_analysis_page.dart';
import 'package:frontend/services/doctor_medical_records_service.dart';
import 'package:intl/intl.dart';
import '../../services/patient_services.dart';
import 'doctor_medical_history_screen.dart';

class DoctorPatientProfileScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final Map<String, dynamic> patientData;
  final String? accessType;
  final String? scheduleId; 
  final String? appointmentId;
  
  const DoctorPatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientData,
    this.accessType = 'appointment',
    this.scheduleId, 
    this.appointmentId,
  });

  @override
  State<DoctorPatientProfileScreen> createState() => _DoctorPatientProfileScreenState();
}

class _DoctorPatientProfileScreenState extends State<DoctorPatientProfileScreen> {
  final PatientService _patientService = PatientService();
  final DoctorMedicalRecordsService _recordsService = DoctorMedicalRecordsService();
  
  late Map<String, dynamic> _patientDetails;
  Map<String, int> _medicalStats = {
    'labResultsCount': 0,
    'prescriptionsCount': 0,
    'otherCount': 0,
    'totalCount': 0,
  };
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Load all data in one method to avoid duplicates
  Future<void> _loadAllData() async {
    try {
      // Load patient details
      _patientDetails = await _patientService.getPatientData(widget.patientId);
      
      // Load medical stats - SINGLE CALL
      final stats = await _recordsService.getMedicalRecordsStats(widget.patientId);
      _medicalStats = {
        'labResultsCount': stats['labResultsCount'] ?? 0,
        'prescriptionsCount': stats['prescriptionsCount'] ?? 0,
        'otherCount': stats['otherCount'] ?? 0,
        'totalCount': stats['totalCount'] ?? 0,
      };
      
      // Debug: Print the stats to verify
      debugPrint('📊 Medical Stats loaded for patient ${widget.patientId}:');
      debugPrint('  Lab Results: ${_medicalStats['labResultsCount']}');
      debugPrint('  Prescriptions: ${_medicalStats['prescriptionsCount']}');
      debugPrint('  Other: ${_medicalStats['otherCount']}');
      debugPrint('  Total: ${_medicalStats['totalCount']}');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading patient data: $e');
      if (mounted) {
        setState(() {
          _patientDetails = widget.patientData;
          _isLoading = false;
        });
      }
    }
  }

  // Refresh all data
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadAllData();
  }

  // Debug method to check what's actually in the database
  Future<void> _debugMedicalRecords() async {
    try {
      debugPrint('🔍 DEBUG: Checking medical records for patient: ${widget.patientId}');
      
      // Check medical_records collection
      final medicalRecordsSnapshot = await FirebaseFirestore.instance
          .collection('medical_records')
          .where('patientId', isEqualTo: widget.patientId)
          .get();
      
      debugPrint('📁 medical_records collection: ${medicalRecordsSnapshot.docs.length} records');
      for (final doc in medicalRecordsSnapshot.docs) {
        final data = doc.data();
        debugPrint('  - ${data['fileName']} (${data['category']}) - ID: ${doc.id}');
      }
      
      // Check prescriptions collection
      final prescriptionsSnapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('patientId', isEqualTo: widget.patientId)
          .get();
      
      debugPrint('💊 prescriptions collection: ${prescriptionsSnapshot.docs.length} records');
      for (final doc in prescriptionsSnapshot.docs) {
        final data = doc.data();
        debugPrint('  - ${data['diagnosis'] ?? 'No diagnosis'} - ID: ${doc.id}');
      }
      
    } catch (e) {
      debugPrint('❌ Debug error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Patient Profile'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Debug button - remove in production
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _debugMedicalRecords,
              tooltip: 'Debug Records',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final fullName = _patientDetails['fullname'] ?? widget.patientName;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Section with Profile
          _buildHeaderSection(fullName),
          
          // Medical Records Section
          _buildMedicalRecordsSection(),
          
          // Prescription Button Section
          _buildPrescriptionButtonSection(fullName),
          
          // Personal Information Section
          _buildPersonalInfoSection(),
          
          // Health Metrics Section
          _buildHealthMetricsSection(),
          
          // Contact Information Section
          _buildContactInfoSection(),
          _buildFamilyBackgroundSection(),
        
        // Lifestyle Section
        _buildLifestyleSection(),
        
        // Pregnancy Section
        _buildPregnancySection(),
        
        // Blood Pressure Section
        _buildBloodPressureSection(),
        
        // Medical History Section
        _buildMedicalHistorySection(),
        
        // Analysis Report Button
        _buildAnalysisButtonSection(),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(String fullName) {
    final profilePic = _patientDetails['profilePic'];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18A3B6), Color(0xFF32BACD)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Profile Image
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildProfileImage(profilePic),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Patient Name
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Patient ID
          Text(
            'Patient ID: ${widget.patientId}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Basic Info Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_patientDetails['age'] != null)
                _buildInfoChip('${_patientDetails['age']} Years', Icons.cake),
              
              if (_patientDetails['gender'] != null)
                _buildInfoChip(_patientDetails['gender'], Icons.person),
              
              if (_patientDetails['bloodGroup'] != null)
                _buildInfoChip('Blood ${_patientDetails['bloodGroup']}', Icons.bloodtype),
              
              if (_patientDetails['lifestyle'] != null)
                _buildInfoChip(_patientDetails['lifestyle'], Icons.fitness_center),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? profilePic) {
    if (profilePic == null || profilePic.isEmpty) {
      return Container(
        color: Colors.white,
        child: const Icon(
          Icons.person,
          size: 50,
          color: Color(0xFF18A3B6),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: profilePic,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF18A3B6)),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.white,
        child: const Icon(
          Icons.person,
          size: 50,
          color: Color(0xFF18A3B6),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildMedicalRecordsSection() {
  final labResultsCount = _medicalStats['labResultsCount'] ?? 0;
  final prescriptionsCount = _medicalStats['prescriptionsCount'] ?? 0;
  final otherCount = _medicalStats['otherCount'] ?? 0;
  final totalCount = _medicalStats['totalCount'] ?? 0;
  final hasRecords = totalCount > 0;
  
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.medical_services, color: Color(0xFF18A3B6), size: 24),
                SizedBox(width: 8),
                Text(
                  'Medical Files',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Simple counts - no double counting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRecordStat('Lab Files', labResultsCount, Icons.science, Colors.blue),
                _buildRecordStat('Prescription Files', prescriptionsCount, Icons.medication, Colors.green),
                _buildRecordStat('Other Files', otherCount, Icons.folder, Colors.orange),
              ],
            ),
            
            // Total count
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF18A3B6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total: $totalCount files',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // View Medical History Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasRecords
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DoctorMedicalHistoryScreen(
                              patientId: widget.patientId,
                              patientName: _patientDetails['fullname'] ?? widget.patientName,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.history_edu, size: 24),
                label: const Text(
                  'VIEW ALL MEDICAL FILES',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasRecords
                      ? const Color(0xFF18A3B6)
                      : Colors.grey[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            // Optional: Show note about digital prescriptions
            if (prescriptionsCount == 0 && labResultsCount == 0 && otherCount == 0)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Note: Digital prescriptions are shown separately',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildRecordStat(String title, int count, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionButtonSection(String fullName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF18A3B6), Color(0xFF32BACD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _navigateToPrescriptionScreen,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.draw,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Write Prescription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create new prescription for $fullName',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPrescriptionScreen() {
    debugPrint('📝 Navigating to prescription screen');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionScreen(
          patientId: widget.patientId,
          patientName: _patientDetails['fullname'] ?? widget.patientName,
          patientAge: _patientDetails['age']?.toString() ?? '',
          patientData: _patientDetails,
          isFromProfile: true,
          appointmentId: widget.appointmentId,
          scheduleId: widget.scheduleId,
          onPrescriptionComplete: () {
            // Refresh data after prescription is created
            _refreshData();
          },
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_outline, color: Color(0xFF18A3B6), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              _buildDetailRow('Full Name', _patientDetails['fullname']),
              _buildDetailRow('Date of Birth', _patientDetails['dob']),
              _buildDetailRow('Age', _patientDetails['age']?.toString()),
              _buildDetailRow('Gender', _patientDetails['gender']),
              _buildDetailRow('Lifestyle', _patientDetails['lifestyle']),
              _buildDetailRow('Address', _patientDetails['address'] ?? 'Not provided'),
              _buildDetailRow('Blood Group', _patientDetails['bloodGroup']),
              if (_patientDetails['allergies'] != null && _patientDetails['allergies'].isNotEmpty)
                _buildDetailRow('Allergies', _patientDetails['allergies'], isImportant: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isImportant = false}) {
    if (value == null || value.isEmpty) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isImportant ? FontWeight.bold : FontWeight.w500,
                color: isImportant ? Colors.red : Colors.black87,
                fontStyle: isImportant ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricsSection() {
    final weight = _patientDetails['weight'];
    final height = _patientDetails['height'];
    final bmi = _patientDetails['bmi'];
    
    // Only show if we have at least one metric
    if (weight == null && height == null && bmi == null) {
      return const SizedBox();
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart, color: Color(0xFF18A3B6), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Health Metrics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (weight != null)
                    _buildMetricCard('Weight', '$weight kg', Icons.fitness_center),
                  if (height != null)
                    _buildMetricCard('Height', '$height cm', Icons.height),
                  if (bmi != null)
                    _buildBMICard(bmi),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF18A3B6).withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF18A3B6), size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBMICard(double bmi) {
    String category;
    Color color;
    
    if (bmi < 18.5) {
      category = 'Underweight';
      color = Colors.blue;
    } else if (bmi < 25) {
      category = 'Normal';
      color = Colors.green;
    } else if (bmi < 30) {
      category = 'Overweight';
      color = Colors.orange;
    } else {
      category = 'Obese';
      color = Colors.red;
    }
    
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.scale, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          bmi.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          'BMI',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          category,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    final email = _patientDetails['email'];
    final mobile = _patientDetails['mobile'];
    final isEmailVerified = _patientDetails['isEmailVerified'] == true;
    
    // Only show if we have contact info
    if (email == null && mobile == null) {
      return const SizedBox();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.contact_phone, color: Color(0xFF18A3B6), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              if (email != null)
                _buildContactRow('Email', email, Icons.email, isEmailVerified),
              if (mobile != null)
                _buildContactRow('Mobile', mobile, Icons.phone, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(String label, String value, IconData icon, bool isVerified) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isVerified)
                      const Row(
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAnalysisButtonSection() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Color(0xFF18A3B6), size: 24),
                SizedBox(width: 8),
                Text(
                  'Health Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Analysis Report Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToAnalysisReport();
                },
                icon: const Icon(Icons.insert_chart, size: 24),
                label: const Text(
                  'VIEW ANALYSIS REPORT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Optional: Brief description
            const Text(
              'View comprehensive health analysis with family history, lifestyle, and medical data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
void _navigateToAnalysisReport() {
  // Replace 'AnalysisReportScreen' with your actual analysis screen class name
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => HealthAnalysisPage(
        patientId: widget.patientId,
        additionalDetails: _patientDetails,
      ),
    ),
  );
}
Widget _buildFamilyBackgroundSection() {
  final additionalDetails = _patientDetails['additionalDetails'];
  if (additionalDetails == null || additionalDetails is! Map<String, dynamic>) {
    return const SizedBox();
  }

  final familyBloodPressure = additionalDetails['familyBloodPressure'];
  final familyDiabetes = additionalDetails['familyDiabetes'];
  final familyKidney = additionalDetails['familyKidney'];

  // Only show if there's any family history data
  if (familyBloodPressure == null && familyDiabetes == null && familyKidney == null) {
    return const SizedBox();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.family_restroom, color: Color(0xFF18A3B6), size: 24),
                SizedBox(width: 8),
                Text(
                  'Family Background',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Family History Grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (familyBloodPressure != null)
                  _buildFamilyHistoryCard(
                    'Blood Pressure',
                    familyBloodPressure,
                    Icons.monitor_heart,
                    familyBloodPressure == 'Yes' ? Colors.red : Colors.green,
                  ),
                
                if (familyDiabetes != null)
                  _buildFamilyHistoryCard(
                    'Diabetes',
                    familyDiabetes,
                    Icons.water_drop,
                    familyDiabetes == 'Yes' ? Colors.orange : Colors.green,
                  ),
                
                if (familyKidney != null)
                  _buildFamilyHistoryCard(
                    'Kidney Disease',
                    familyKidney,
                    Icons.filter_vintage,
                    familyKidney == 'Yes' ? Colors.purple : Colors.green,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildFamilyHistoryCard(String title, String value, IconData icon, Color color) {
  return Container(
    width: 110,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}
Widget _buildLifestyleSection() {
  final additionalDetails = _patientDetails['additionalDetails'];
  if (additionalDetails == null || additionalDetails is! Map<String, dynamic>) {
    return const SizedBox();
  }

  final dietType = additionalDetails['dietType'];
  final physicalActivity = additionalDetails['physicalActivity'];
  final lifestyle = _patientDetails['lifestyle'];

  // Only show if there's lifestyle data
  if (dietType == null && physicalActivity == null && lifestyle == null) {
    return const SizedBox();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.restaurant, color: Color(0xFF18A3B6), size: 24),
                SizedBox(width: 8),
                Text(
                  'Lifestyle & Diet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Lifestyle Details
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (dietType != null)
                  _buildLifestyleCard(
                    'Diet Type',
                    dietType,
                    Icons.restaurant_menu,
                    Colors.green,
                  ),
                
                if (physicalActivity != null)
                  _buildLifestyleCard(
                    'Physical Activity',
                    physicalActivity,
                    Icons.directions_run,
                    Colors.blue,
                  ),
                
                if (lifestyle != null)
                  _buildLifestyleCard(
                    'Lifestyle Habits',
                    lifestyle,
                    Icons.style,
                    Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildLifestyleCard(String title, String value, IconData icon, Color color) {
  return Container(
    width: 110,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
Widget _buildPregnancySection() {
  final additionalDetails = _patientDetails['additionalDetails'];
  if (additionalDetails == null || additionalDetails is! Map<String, dynamic>) {
    return const SizedBox();
  }

  final pregnancyStatus = additionalDetails['pregnancyStatus'];
  final currentPregnancy = additionalDetails['currentPregnancy'];
  final pregnancyWeeks = additionalDetails['pregnancyWeeks'];
  final childrenCount = additionalDetails['childrenCount'];
  final childrenStatus = additionalDetails['childrenStatus'];

  // Only show for female patients
  final gender = _patientDetails['gender'];
  if (gender != 'Female') {
    return const SizedBox();
  }

  // Only show if there's pregnancy/children data
  if (pregnancyStatus == null && childrenCount == null) {
    return const SizedBox();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.child_care, color: Color(0xFF18A3B6), size: 24),
                SizedBox(width: 8),
                Text(
                  'Pregnancy & Children',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Pregnancy Status
            if (pregnancyStatus != null)
              _buildDetailItemWithIcon(
                'Pregnancy Status',
                pregnancyStatus,
                Icons.pregnant_woman,
                pregnancyStatus == 'Yes' ? Colors.pink : Colors.grey,
              ),
            
            if (pregnancyStatus == 'Yes') ...[
              if (currentPregnancy != null)
                _buildDetailItemWithIcon(
                  'Current Pregnancy',
                  currentPregnancy,
                  Icons.timeline,
                  Colors.purple,
                ),
              
              if (pregnancyWeeks != null)
                _buildDetailItemWithIcon(
                  'Pregnancy Weeks',
                  '$pregnancyWeeks weeks',
                  Icons.date_range,
                  Colors.blue,
                ),
            ],
            
            if (childrenCount != null)
              _buildDetailItemWithIcon(
                'Children Count',
                childrenCount.toString(),
                Icons.family_restroom,
                Colors.amber,
              ),
            
            if (childrenStatus != null)
              _buildDetailItemWithIcon(
                'Children Status',
                childrenStatus,
                Icons.child_friendly,
                Colors.green,
              ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildDetailItemWithIcon(String label, String value, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildBloodPressureSection() {
  final additionalDetails = _patientDetails['additionalDetails'];
  if (additionalDetails == null || additionalDetails is! Map<String, dynamic>) {
    return const SizedBox();
  }

  final bpReadings = additionalDetails['bpReadings'];
  if (bpReadings == null || bpReadings is! List || bpReadings.isEmpty) {
    return const SizedBox();
  }

  // Sort by date (most recent first)
  final sortedReadings = List.from(bpReadings);
  sortedReadings.sort((a, b) {
    final dateA = a['date'] as Timestamp?;
    final dateB = b['date'] as Timestamp?;
    return dateB?.compareTo(dateA ?? Timestamp(0, 0)) ?? 0;
  });

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor_heart, color: Color(0xFF18A3B6), size: 24),
                SizedBox(width: 8),
                Text(
                  'Blood Pressure History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              '${sortedReadings.length} recorded reading${sortedReadings.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Latest Reading
            const Text(
              'Latest Reading:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            if (sortedReadings.isNotEmpty)
              _buildBPReadingCard(sortedReadings.first, true),
            
            const SizedBox(height: 16),
            
            // Previous Readings
            if (sortedReadings.length > 1) ...[
              const Text(
                'Previous Readings:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              
              ...sortedReadings.skip(1).take(3).map((reading) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildBPReadingCard(reading, false),
                );
              }).toList(),
              
              if (sortedReadings.length > 4)
                Text(
                  'and ${sortedReadings.length - 4} more readings',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
Widget _buildBPReadingCard(Map<String, dynamic> reading, bool isLatest) {
  final systolic = reading['systolic'] ?? 0;
  final diastolic = reading['diastolic'] ?? 0;
  final date = reading['date'] as Timestamp?;
  final note = reading['note'];
  
  Color bpColor;
  String bpStatus;
  
  // BP classification
  if (systolic < 120 && diastolic < 80) {
    bpColor = Colors.green;
    bpStatus = 'Normal';
  } else if (systolic < 130 && diastolic < 80) {
    bpColor = Colors.blue;
    bpStatus = 'Elevated';
  } else if (systolic < 140 && diastolic < 90) {
    bpColor = Colors.orange;
    bpStatus = 'Stage 1 Hypertension';
  } else if (systolic < 180 || diastolic < 120) {
    bpColor = Colors.red;
    bpStatus = 'Stage 2 Hypertension';
  } else {
    bpColor = Colors.red[900]!;
    bpStatus = 'Hypertensive Crisis';
  }
  
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isLatest ? bpColor.withOpacity(0.1) : Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isLatest ? bpColor.withOpacity(0.3) : Colors.grey[300]!,
        width: isLatest ? 2 : 1,
      ),
    ),
    child: Row(
      children: [
        // BP Value
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bpColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                '$systolic/$diastolic',
                style: TextStyle(
                  fontSize: isLatest ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: bpColor,
                ),
              ),
              Text(
                'mmHg',
                style: TextStyle(
                  fontSize: 10,
                  color: bpColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Date and Status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(date?.toDate()),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bpStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: bpColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (note != null && note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Note: $note',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        
        if (isLatest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bpColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'LATEST',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );
}
Widget _buildMedicalHistorySection() {
  final additionalDetails = _patientDetails['additionalDetails'];
  if (additionalDetails == null || additionalDetails is! Map<String, dynamic>) {
    return const SizedBox();
  }

  final pastSurgeries = additionalDetails['pastSurgeries'];
  final allergies = _patientDetails['allergies'];
  final maritalStatus = additionalDetails['maritalStatus'];

  // Only show if there's medical history data
  if (pastSurgeries == null && allergies == null && maritalStatus == null) {
    return const SizedBox();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.medical_services, color: Color(0xFF18A3B6), size: 24),
                SizedBox(width: 8),
                Text(
                  'Medical History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (maritalStatus != null)
              _buildMedicalHistoryItem(
                'Marital Status',
                maritalStatus,
                Icons.favorite,
                Colors.purple,
              ),
            
            if (pastSurgeries != null)
              _buildMedicalHistoryItem(
                'Past Surgeries',
                pastSurgeries,
                Icons.medical_services,
                Colors.red,
                isImportant: pastSurgeries.toLowerCase() != 'no',
              ),
            
            if (allergies != null && allergies.isNotEmpty)
              _buildMedicalHistoryItem(
                'Allergies',
                allergies,
                Icons.warning,
                Colors.orange,
                isImportant: true,
              ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildMedicalHistoryItem(String label, String value, IconData icon, Color color, {bool isImportant = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isImportant ? FontWeight.bold : FontWeight.w500,
                  color: isImportant ? color : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown date';
  return DateFormat('dd MMM yyyy').format(date);
}
}