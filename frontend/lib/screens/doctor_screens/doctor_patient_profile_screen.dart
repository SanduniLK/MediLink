// screens/doctor_screens/doctor_patient_profile_screen.dart - BEAUTIFUL UI
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  }

  Future<void> _loadPatientData() async {
    try {
      // Get detailed patient data
      _patientDetails = await _patientService.getPatientData(widget.patientId);
      
      // Get medical stats
      _medicalStats = await _patientService.getPatientMedicalStats(widget.patientId);
    } catch (e) {
      debugPrint('Error loading patient data: $e');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patient Profile'),
          backgroundColor: const Color(0xFF18A3B6),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Patient Profile'),
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
            
            // Patient Information
            _buildPatientInfoSection(),
            
            // Health Metrics
            _buildHealthMetricsSection(),
            
            // Quick Actions
            _buildQuickActionsSection(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF18A3B6),
            const Color(0xFF18A3B6).withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Patient Photo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: _patientDetails['photoUrl'] != null
                  ? CachedNetworkImage(
                      imageUrl: _patientDetails['photoUrl'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.white,
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.white,
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.white,
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Patient Name
          Text(
            _patientDetails['name'] ?? widget.patientName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Patient ID
          Text(
            'ID: ${widget.patientId}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Basic Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_patientDetails['age'] != null)
                _buildInfoChip('${_patientDetails['age']} Years', Icons.cake),
              
              if (_patientDetails['gender'] != null)
                _buildInfoChip(_patientDetails['gender'], Icons.person),
              
              if (_patientDetails['bloodGroup'] != null)
                _buildInfoChip('${_patientDetails['bloodGroup']}', Icons.bloodtype),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
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
              
              // Records Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRecordStat('Lab Results', _medicalStats['labResultsCount'], Icons.science),
                  _buildRecordStat('Prescriptions', _medicalStats['prescriptionsCount'], Icons.medication),
                  _buildRecordStat('Other', _medicalStats['otherCount'], Icons.folder),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // View Medical History Button
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorMedicalHistoryScreen(
                          patientId: widget.patientId,
                          patientName: _patientDetails['name'] ?? widget.patientName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_edu, size: 24),
                  label: const Text(
                    'VIEW COMPLETE MEDICAL HISTORY',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordStat(String title, int count, IconData icon) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF18A3B6).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF18A3B6), size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18A3B6),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPatientInfoSection() {
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
                    'Patient Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              _buildInfoRow('Email', _patientDetails['email'], Icons.email),
              _buildInfoRow('Phone', _patientDetails['phone'], Icons.phone),
              _buildInfoRow('Age', _patientDetails['age']?.toString(), Icons.cake),
              _buildInfoRow('Gender', _patientDetails['gender'], Icons.person),
              _buildInfoRow('Blood Group', _patientDetails['bloodGroup'], Icons.bloodtype),
              if (_patientDetails['emergencyContact'] != null)
                _buildInfoRow('Emergency Contact', _patientDetails['emergencyContact'], Icons.emergency),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, IconData icon) {
    if (value == null) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
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
    
    if (weight == null && height == null) return const SizedBox();
    
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
                  if (weight != null && height != null)
                    _buildBMICard(weight, height),
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
            color: const Color(0xFF18A3B6).withOpacity(0.1),
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

  Widget _buildBMICard(double weight, double height) {
    final bmi = weight / ((height / 100) * (height / 100));
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
            color: color.withOpacity(0.1),
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

  Widget _buildQuickActionsSection() {
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
                  Icon(Icons.quick_contacts_dialer, color: Color(0xFF18A3B6), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildActionButton('Start Consultation', Icons.video_call, Colors.green),
                  _buildActionButton('Add Notes', Icons.note_add, Colors.orange),
                  _buildActionButton('Send Message', Icons.message, Colors.blue),
                  _buildActionButton('Schedule', Icons.calendar_today, Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _showComingSoon(text),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        backgroundColor: const Color(0xFF18A3B6),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}