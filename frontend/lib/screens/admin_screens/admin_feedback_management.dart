// lib/screens/admin_screens/admin_feedback_management.dart
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminFeedbackManagement extends StatefulWidget {
  final String medicalCenterId;
  final String medicalCenterName;

  const AdminFeedbackManagement({
    super.key,
    required this.medicalCenterId,
    required this.medicalCenterName,
  });

  @override
  State<AdminFeedbackManagement> createState() => _AdminFeedbackManagementState();
}

class _AdminFeedbackManagementState extends State<AdminFeedbackManagement> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _patientFeedback = [];
  List<Map<String, dynamic>> _doctorFeedback = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllFeedbackData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllFeedbackData() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('Loading feedback for medical center: ${widget.medicalCenterId}');

    // Load Patient Feedback - ONLY patient->medical center feedback
    final patientSnapshot = await FirebaseFirestore.instance
        .collection('feedback')
        .get();

    debugPrint('Found ${patientSnapshot.docs.length} total patient feedback documents');

    final patientFeedback = patientSnapshot.docs
        .where((doc) {
          final data = doc.data();
          final medicalCenterId = data['medicalCenterId'];
          final doctorId = data['doctorId'];
          final status = data['status'];
          final feedbackType = data['feedbackType'];
          
          // Only show patient->medical center feedback (no doctorId or empty doctorId)
          final isPatientToMedicalCenter = (doctorId == null || doctorId.toString().isEmpty) && 
                                         feedbackType == 'medical_center';
          
          final matches = medicalCenterId == widget.medicalCenterId && 
                        status == 'approved' && 
                        isPatientToMedicalCenter;
          
          if (matches) {
            debugPrint('Found patient->medical center feedback: ${doc.id} - ${data['patientName']}');
          }
          return matches;
        })
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'type': 'patient',
            ...data,
            'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          };
        }).toList();

    debugPrint('Filtered to ${patientFeedback.length} patient->medical center feedback');

    // Sort by date manually
    patientFeedback.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

    // Load Doctor Feedback (doctor->medical center)
    final doctorSnapshot = await FirebaseFirestore.instance
        .collection('doctorMedicalCenterFeedback')
        .where('medicalCenterId', isEqualTo: widget.medicalCenterId)
        .get();

    debugPrint('Found ${doctorSnapshot.docs.length} doctor feedback documents');

    final doctorFeedback = doctorSnapshot.docs.map((doc) {
      final data = doc.data();
      debugPrint('Found doctor feedback: ${doc.id} - ${data['doctorName']}');
      return {
        'id': doc.id,
        'type': 'doctor',
        ...data,
        'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
      };
    }).toList();

    setState(() {
      _patientFeedback = patientFeedback;
      _doctorFeedback = doctorFeedback;
      _isLoading = false;
    });

    debugPrint('Loading complete - Patient->MedicalCenter: ${_patientFeedback.length}, Doctor->MedicalCenter: ${_doctorFeedback.length}');

  } catch (e) {
    debugPrint('Error loading feedback: $e');
    setState(() {
      _isLoading = false;
      _errorMessage = 'Failed to load feedback: $e';
    });
  }
}

  Widget _buildFeedbackStats() {
    final pendingPatient = _patientFeedback.where((f) => f['status'] == 'pending').length;
    final approvedPatient = _patientFeedback.where((f) => f['status'] == 'approved').length;
    final totalPatient = _patientFeedback.length;
    final totalDoctor = _doctorFeedback.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCircle(totalPatient, 'Patient Reviews', Colors.blue, Icons.person),
          _buildStatCircle(totalDoctor, 'Doctor Reviews', Colors.purple, Icons.medical_services),
        
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
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
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

  Widget _buildPatientFeedbackList() {
    if (_patientFeedback.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Patient Feedback Yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Patient feedback will appear here once they submit reviews',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patientFeedback.length,
      itemBuilder: (context, index) {
        return _buildPatientFeedbackCard(_patientFeedback[index]);
      },
    );
  }

  Widget _buildDoctorFeedbackList() {
    if (_doctorFeedback.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Doctor Reviews Yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Doctor reviews will appear here once they rate the medical center',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _doctorFeedback.length,
      itemBuilder: (context, index) {
        return _buildDoctorFeedbackCard(_doctorFeedback[index]);
      },
    );
  }

  Widget _buildPatientFeedbackCard(Map<String, dynamic> feedback) {
    final rating = feedback['rating'] ?? 0;
    final comment = feedback['comment'] ?? '';
    final patientName = feedback['patientName'] ?? 'Anonymous';
    final doctorName = feedback['doctorName'] ?? 'Unknown Doctor';
    final createdAt = feedback['createdAt'] as DateTime;
    final status = feedback['status'] ?? 'approved';
    final isAnonymous = feedback['anonymous'] ?? false;

    

    

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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '👥 Patient Feedback',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAnonymous ? 'Anonymous Patient' : patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                     
                      Text(
                        _formatDate(createdAt),
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
                 
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Comment
            if (comment.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorFeedbackCard(Map<String, dynamic> feedback) {
    final rating = feedback['rating'] ?? 0;
    final comment = feedback['comment'] ?? '';
    final doctorName = feedback['doctorName'] ?? 'Unknown Doctor';
    final createdAt = feedback['createdAt'] as DateTime;
    final wouldRecommend = feedback['wouldRecommend'] ?? false;
    final isAnonymous = feedback['anonymous'] ?? false;
    final categories = feedback['categories'] ?? [];

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
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '👨‍⚕️ Doctor Review',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAnonymous ? 'Anonymous Doctor' : doctorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'About Medical Center',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDate(createdAt),
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
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'APPROVED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Recommendation
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: wouldRecommend ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: wouldRecommend ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        wouldRecommend ? Icons.thumb_up : Icons.thumb_down,
                        size: 14,
                        color: wouldRecommend ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        wouldRecommend ? 'Recommends this center' : 'Does not recommend',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: wouldRecommend ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Categories
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: categories.map<Widget>((category) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getCategoryLabel(category),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.purple,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            // Comment
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _getCategoryLabel(String category) {
    final labels = {
      'facilities': '🏥 Facilities',
      'staff_support': '👥 Staff Support',
      'equipment': '⚙️ Equipment',
      'admin_support': '📋 Admin Support',
      'working_environment': '💼 Work Environment',
      'resources': '📚 Resources'
    };
    return labels[category] ?? category;
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Feedback Management',
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
                      color: Colors.orange.withOpacity(0.1),
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
            child: _buildFeedbackStats(),
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
                Tab(text: 'Patient Feedback'),
                Tab(text: 'Doctor Reviews'),
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
                      _buildPatientFeedbackList(),
                      _buildDoctorFeedbackList(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadAllFeedbackData,
        backgroundColor: const Color(0xFF18A3B6),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}