// screens/doctor_screens/doctor_patient_profile_screen.dart - FIXED IMAGE LOADING
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/screens/doctor_screens/prescription_screen.dart';
import 'package:frontend/services/doctor_medical_records_service.dart';
import 'package:intl/intl.dart';
import '../../services/patient_services.dart';
import 'doctor_medical_history_screen.dart';

class DoctorPatientProfileScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final Map<String, dynamic> patientData;


  const DoctorPatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientData,
    
  });

  @override
  State<DoctorPatientProfileScreen> createState() => _DoctorPatientProfileScreenState();
}

class _DoctorPatientProfileScreenState extends State<DoctorPatientProfileScreen> {
  final PatientService _patientService = PatientService();
  late Map<String, dynamic> _patientDetails;
  late Map<String, dynamic> _medicalStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _loadMedicalStats();
  }

  Future<void> _loadPatientData() async {
    try {
      // Get detailed patient data
      _patientDetails = await _patientService.getPatientData(widget.patientId);
      
      // Get medical stats
      _medicalStats = await _patientService.getPatientMedicalStats(widget.patientId);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading patient data: $e');
      }
      _patientDetails = widget.patientData;
      _medicalStats = {
        'labResultsCount': 0,
        'prescriptionsCount': 0,
        'otherCount': 0,
        'totalRecords': 0,
        'lastUploadDate': null,
      };
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
 void _navigateToPrescriptionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionScreen(
        patientId: widget.patientId,
        patientName: _patientDetails['fullname'] ?? widget.patientName,
        patientAge: _patientDetails['age']?.toString() ?? '',
        patientData: _patientDetails,
        isFromProfile: true,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patient Profile'),
          backgroundColor: const Color(0xFF18A3B6),
          foregroundColor: Colors.white,
          elevation: 0,
           actions: [
          // ADD PRESCRIPTION BUTTON TO APP BAR
          IconButton(
            icon: const Icon(Icons.medical_services, color: Colors.white),
            onPressed: _navigateToPrescriptionScreen,
            tooltip: 'Write Prescription',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatientData,
            tooltip: 'Refresh',
          ),
        ],
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Patient Profile'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatientData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Patient Photo
            _buildHeaderSection(),
            

            // Medical Records Quick Access
            _buildMedicalRecordsSection(),
            
            _buildPrescriptionButtonSection(),
            // Personal Information
            _buildPersonalInfoSection(),
            
            // Health Metrics
            _buildHealthMetricsSection(),
            
            // Contact Information
            _buildContactInfoSection(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
 Widget _buildPrescriptionButtonSection() {
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
                            'Create new prescription for ${_patientDetails['fullname'] ?? widget.patientName}',
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
  Widget _buildHeaderSection() {
    final fullName = _patientDetails['fullname'] ?? _patientDetails['name'] ?? widget.patientName;
    final profilePic = _patientDetails['profilePic'];
    
    if (kDebugMode) {
      print('🎯 Building header with profilePic: $profilePic');
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18A3B6),
            Color(0xFF18A3B6),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Patient Photo with FIXED image loading
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
          
          // Basic Info Row
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
      return _buildDefaultProfileIcon();
    }

    if (kDebugMode) {
      print('🖼️ Loading profile image from: $profilePic');
    }

    // Try multiple approaches to load the image
    return _buildImageWithFallback(profilePic);
  }

  Widget _buildImageWithFallback(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, downloadProgress) => 
          Container(
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(
                value: downloadProgress.progress,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF18A3B6)),
              ),
            ),
          ),
      errorWidget: (context, url, error) {
        if (kDebugMode) {
          print('❌ CachedNetworkImage failed: $error');
          print('❌ Trying alternative approach...');
        }
        
        // Try alternative image loading approach
        return _buildAlternativeImageLoader(url);
      },
    );
  }

  Widget _buildAlternativeImageLoader(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.white,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF18A3B6)),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          print('❌ Image.network also failed: $error');
        }
        return _buildDefaultProfileIcon();
      },
    );
  }

  Widget _buildDefaultProfileIcon() {
    return Container(
      color: Colors.white,
      child: const Icon(
        Icons.person,
        size: 50,
        color: Color(0xFF18A3B6),
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

bool _isLoadingStats = true;


Future<void> _loadMedicalStats() async {
  try {
    final recordsService = DoctorMedicalRecordsService();
    final stats = await recordsService.getMedicalRecordsStats(widget.patientId);
    setState(() {
      _medicalStats = stats;
      _isLoadingStats = false;
    });
  } catch (e) {
    debugPrint('Error loading medical stats: $e');
    setState(() {
      _isLoadingStats = false;
    });
  }
}
 Widget _buildMedicalRecordsSection() {
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
                  'Medical Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Records Summary - Show loading or stats
            _isLoadingStats
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRecordStat(
                            'Lab Results',
                            _medicalStats['labResultsCount'] ?? 0,
                            Icons.science,
                            Colors.blue,
                          ),
                          _buildRecordStat(
                            'Prescriptions',
                            _medicalStats['prescriptionsCount'] ?? 0,
                            Icons.medication,
                            Colors.green,
                          ),
                          _buildRecordStat(
                            'Other',
                            _medicalStats['otherCount'] ?? 0,
                            Icons.folder,
                            Colors.orange,
                          ),
                        ],
                      ),
                      
                      // Show total count badge
                      if (_medicalStats['totalCount']! > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF18A3B6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Total: ${_medicalStats['totalCount']} records',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
            
            const SizedBox(height: 20),
            
            // View Medical History Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _medicalStats['totalCount']! > 0
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
                  'VIEW COMPLETE MEDICAL HISTORY',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _medicalStats['totalCount']! > 0
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
              _buildDetailRow('Address', _patientDetails['address'] ?? 'Katharagama'),
              _buildDetailRow('Blood Group', _patientDetails['bloodGroup']),
              if (_patientDetails['allergies'] != null)
                _buildDetailRow('Allergies', _patientDetails['allergies'], isImportant: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthMetricsSection() {
    final weight = _patientDetails['weight'];
    final height = _patientDetails['height'];
    final bmi = _patientDetails['bmi'];
    
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

  Widget _buildContactInfoSection() {
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
              
              _buildContactRow('Email', _patientDetails['email'], Icons.email),
              _buildContactRow('Mobile', _patientDetails['mobile'], Icons.phone),
              if (_patientDetails['isEmailVerified'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Email Verified',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildContactRow(String label, String? value, IconData icon) {
    if (value == null || value.isEmpty) return const SizedBox();
    
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
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
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
}