// screens/doctor_screens/doctor_patient_profile_screen.dart - COMPLETE FIXED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';
import 'package:frontend/services/doctor_medical_records_service.dart';
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
}