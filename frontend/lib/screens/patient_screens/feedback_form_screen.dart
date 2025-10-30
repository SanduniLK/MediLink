import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/services/feedback_service.dart';

class FeedbackFormScreen extends StatefulWidget {
  final String patientId;

  const FeedbackFormScreen({
    Key? key,
    required this.patientId,
  }) : super(key: key);

  @override
  _FeedbackFormScreenState createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  int _rating = 0;
  bool _wouldRecommend = true;
  bool _anonymous = false;
  String? _selectedDoctorId;
  String? _selectedMedicalCenterId;
  String _feedbackType = 'doctor';
  
  final TextEditingController _commentController = TextEditingController();
  
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _medicalCenters = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Professional color scheme
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Simulate loading delay for better UX
      await Future.delayed(Duration(milliseconds: 800));

      // Load doctors
      final doctorsSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .where('role', isEqualTo: 'doctor')
          .get();

      _doctors = doctorsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'uid': data['uid'] ?? doc.id,
          'name': data['fullname'] ?? 'Unknown Doctor',
          'specialization': data['specialization'] ?? 'General Practitioner',
          'hospital': data['hospital'] ?? 'Medical Center',
          'profileImage': data['profileImage'] ?? '',
          'experience': data['experience'] ?? 0,
        };
      }).toList();

      // Load medical centers
      List<QuerySnapshot<Map<String, dynamic>>> centerSnapshots = [];
      
      try {
        final snapshot1 = await FirebaseFirestore.instance
            .collection('medicalCenters')
            .get();
        centerSnapshots.add(snapshot1);
      } catch (e) {
        print('No medical centers in "medicalCenters": $e');
      }

      try {
        final snapshot2 = await FirebaseFirestore.instance
            .collection('medical_centers')
            .get();
        centerSnapshots.add(snapshot2);
      } catch (e) {
        print('No medical centers in "medical_centers": $e');
      }

      _medicalCenters = [];
      for (final snapshot in centerSnapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final name = data['name'] ?? data['fullname'] ?? data['hospital'] ?? 'Medical Center';
          
          
          _medicalCenters.add({
            'id': doc.id,
            'uid': data['uid'] ?? doc.id,
            'name': name,
            
          });
        }
      }

      // Add sample data for demo
      if (_medicalCenters.isEmpty) {
        _medicalCenters.addAll([
          {
            'id': 'center_1',
            'uid': 'center_1',
            'name': 'City General Hospital',
            'address': '123 Healthcare Avenue, Medical District',
            'email': 'info@citygeneral.com',
            'phone': '+1 (555) 123-4567',
          },
          {
            'id': 'center_2',
            'uid': 'center_2',
            'name': 'Community Health Center',
            'address': '456 Wellness Street, Downtown',
            'email': 'contact@communityhealth.org',
            'phone': '+1 (555) 987-6543',
          }
        ]);
      }

      // Add sample doctors if none found
      if (_doctors.isEmpty) {
        _doctors.addAll([
          {
            'id': 'doc_1',
            'name': 'Dr. Sarah Johnson',
            'specialization': 'Cardiology',
            'hospital': 'City General Hospital',
            'profileImage': '',
            'experience': 12,
          },
          {
            'id': 'doc_2',
            'name': 'Dr. Michael Chen',
            'specialization': 'Pediatrics',
            'hospital': 'Community Health Center',
            'profileImage': '',
            'experience': 8,
          }
        ]);
      }

    } catch (error) {
      print('Error loading data: $error');
      
      // Demo data for testing
      _doctors = [
        {
          'id': 'demo_doctor_1',
          'name': 'Dr. Emily Wilson',
          'specialization': 'General Medicine',
          'hospital': 'City Medical Center',
          'profileImage': '',
          'experience': 10,
        },
        {
          'id': 'demo_doctor_2',
          'name': 'Dr. James Rodriguez',
          'specialization': 'Dermatology',
          'hospital': 'Skin Care Clinic',
          'profileImage': '',
          'experience': 15,
        }
      ];
      
      _medicalCenters = [
        {
          'id': 'demo_center_1',
          'name': 'Metropolitan Hospital',
          'address': '789 Health Boulevard, Metro City',
          'email': 'info@metropolitan.org',
          'phone': '+1 (555) 246-8135',
        }
      ];
      
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      _showSnackBar('Please provide a rating before submitting');
      return;
    }

    if (_feedbackType == 'doctor' && _selectedDoctorId == null) {
      _showSnackBar('Please select a doctor to provide feedback');
      return;
    }

    if (_feedbackType == 'medical_center' && _selectedMedicalCenterId == null) {
      _showSnackBar('Please select a medical center to provide feedback');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please login to submit feedback');

      // Get selected entities
      final selectedDoctor = _selectedDoctorId != null 
          ? _doctors.firstWhere(
              (doctor) => doctor['id'] == _selectedDoctorId,
              orElse: () => _createDefaultDoctor(),
            )
          : _createDefaultDoctor();

      final selectedMedicalCenter = _selectedMedicalCenterId != null
          ? _medicalCenters.firstWhere(
              (center) => center['id'] == _selectedMedicalCenterId,
              orElse: () => _createDefaultMedicalCenter(),
            )
          : _createDefaultMedicalCenter();

      // Get patient data
      final patientData = await _getPatientData();
      final finalPatientName = _anonymous ? 'Anonymous' : patientData['name'];
      final finalPatientEmail = _anonymous ? '' : patientData['email'];

      // Submit feedback
      final result = await FeedbackService.submitFeedback(
        patientId: widget.patientId,
        patientName: finalPatientName ?? 'Patient',
        patientEmail: finalPatientEmail ?? '',
        medicalCenterId: selectedMedicalCenter['uid']?.toString() ?? selectedMedicalCenter['id']?.toString() ?? 'unknown',
        medicalCenterName: selectedMedicalCenter['name']?.toString() ?? 'Medical Center',
        doctorId: selectedDoctor['uid']?.toString() ?? selectedDoctor['id']?.toString() ?? 'unknown',
        doctorName: selectedDoctor['name']?.toString() ?? 'Healthcare Provider',
        rating: _rating,
        comment: _commentController.text,
        wouldRecommend: _wouldRecommend,
        categories: [],
        anonymous: _anonymous,
      );

      if (result['success'] == true) {
        _showSnackBar('Thank you for your valuable feedback!', isSuccess: true);
        await Future.delayed(Duration(milliseconds: 1500));
        Navigator.pop(context, true);
      } else {
        throw Exception(result['error']?.toString() ?? 'Submission failed. Please try again.');
      }
    } catch (e) {
      print('Error submitting feedback: $e');
      _showSnackBar('Unable to submit feedback. Please check your connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Map<String, dynamic> _createDefaultDoctor() {
    return {
      'name': 'Healthcare Provider',
      'hospital': 'Medical Facility',
      'uid': 'unknown',
      'id': 'unknown'
    };
  }

  Map<String, dynamic> _createDefaultMedicalCenter() {
    return {
      'name': 'Medical Facility',
      'uid': 'unknown',
      'id': 'unknown'
    };
  }

  Future<Map<String, String>> _getPatientData() async {
    final user = FirebaseAuth.instance.currentUser;
    String patientName = 'Patient';
    String patientEmail = user?.email ?? '';

    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();
      
      if (patientDoc.exists) {
        final patientData = patientDoc.data();
        patientName = patientData?['fullname']?.toString() ?? 
                     patientData?['name']?.toString() ?? 
                     patientData?['displayName']?.toString() ?? 
                     'Patient';
        patientEmail = patientData?['email']?.toString() ?? patientEmail;
      }
    } catch (e) {
      print('Could not fetch patient data: $e');
      patientName = 'Patient';
    }

    return {'name': patientName, 'email': patientEmail};
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? _successColor : _warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isSuccess ? 3 : 4),
      ),
    );
  }

  Widget _buildDoctorItem(Map<String, dynamic> doctor, bool isSelected) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? _accentColor : _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _primaryColor : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: doctor['profileImage'] != null && 
                          doctor['profileImage'].toString().isNotEmpty
              ? CachedNetworkImageProvider(doctor['profileImage'].toString())
              : null,
          backgroundColor: _primaryColor,
          child: doctor['profileImage'] == null || 
                 doctor['profileImage'].toString().isEmpty
              ? Icon(Icons.medical_services, color: Colors.white, size: 20)
              : null,
        ),
        title: Text(
          doctor['name']?.toString() ?? 'Healthcare Provider',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              doctor['specialization']?.toString() ?? 'Medical Specialist',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 2),
            Text(
              doctor['hospital']?.toString() ?? 'Medical Facility',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
              ),
            ),
            if ((doctor['experience'] ?? 0) > 0)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '${doctor['experience']} years experience',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        trailing: isSelected 
            ? Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              )
            : Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
      ),
    );
  }

  Widget _buildMedicalCenterItem(Map<String, dynamic> center, bool isSelected) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? _accentColor : _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _primaryColor : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: _primaryColor,
          child: Icon(Icons.local_hospital, color: Colors.white, size: 24),
        ),
        title: Text(
          center['name']?.toString() ?? 'Medical Center',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            if (center['address'] != null && center['address'].toString().isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: _textSecondary),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      center['address'].toString(),
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            if (center['phone'] != null && center['phone'].toString().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: _textSecondary),
                    SizedBox(width: 4),
                    Text(
                      center['phone'].toString(),
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: isSelected 
            ? Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              )
            : Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
      ),
    );
  }

  Widget _buildRatingStars() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = index + 1;
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 44,
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 12),
        Text(
          _rating == 0 ? 'Tap to rate your experience' : '${_rating} out of 5 stars',
          style: TextStyle(
            fontSize: 15,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_rating > 0) ...[
          SizedBox(height: 4),
          Text(
            _getRatingDescription(_rating),
            style: TextStyle(
              fontSize: 13,
              color: _primaryColor,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1: return 'Poor experience';
      case 2: return 'Needs improvement';
      case 3: return 'Satisfactory';
      case 4: return 'Good experience';
      case 5: return 'Excellent service';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Share Your Feedback',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Loading healthcare providers...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait a moment',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Section - Now scrolls with content
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.feedback_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 12),
                Text(
                  'Help Us Improve',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your feedback helps us provide better healthcare services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Form Content
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Feedback Type Selection
                _buildSectionCard(
                  title: 'I want to provide feedback for:',
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip('Doctor', 'doctor', Icons.medical_services),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeChip('Medical Center', 'medical_center', Icons.local_hospital),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Entity Selection
                if (_feedbackType == 'doctor') _buildDoctorSelection(),
                if (_feedbackType == 'medical_center') _buildMedicalCenterSelection(),

                // Rating Section
                _buildSectionCard(
                  title: 'Overall Rating',
                  subtitle: 'How would you rate your experience?',
                  child: _buildRatingStars(),
                ),
                SizedBox(height: 24),

                // Recommendation
                _buildSectionCard(
                  title: 'Recommendation',
                  subtitle: 'Would you recommend this ${_feedbackType == 'doctor' ? 'doctor' : 'medical center'} to others?',
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildRecommendationChip('Yes', true, Icons.thumb_up_alt_rounded),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildRecommendationChip('No', false, Icons.thumb_down_alt_rounded),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Comments
                _buildSectionCard(
                  title: 'Additional Comments',
                  subtitle: 'Share details about your experience (optional)',
                  child: TextField(
                    controller: _commentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Tell us about your visit, what went well, or what could be improved...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Anonymous Option
                _buildSectionCard(
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _primaryColor),
                        ),
                        child: Checkbox(
                          value: _anonymous,
                          onChanged: (value) {
                            setState(() {
                              _anonymous = value!;
                            });
                          },
                          activeColor: _primaryColor,
                          shape: CircleBorder(),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit anonymously',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: _textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Your name will not be shared with the ${_feedbackType == 'doctor' ? 'doctor' : 'medical center'}',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // Submit Button
                _buildSubmitButton(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child, String? title, String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                ),
              ),
            ],
            SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value, IconData icon) {
    final isSelected = _feedbackType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _feedbackType = value;
          if (value == 'doctor') {
            _selectedMedicalCenterId = null;
          } else {
            _selectedDoctorId = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : _primaryColor, size: 32),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationChip(String label, bool value, IconData icon) {
    final isSelected = _wouldRecommend == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _wouldRecommend = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : _primaryColor, size: 32),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorSelection() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Select Doctor',
          subtitle: 'Choose the doctor you want to provide feedback for',
          child: _doctors.isEmpty
              ? _buildEmptyState(
                  'No doctors available',
                  'Doctors will appear here once they are registered in the system',
                  Icons.medical_services,
                )
              : Column(
                  children: _doctors.map((doctor) {
                    final isSelected = _selectedDoctorId == doctor['id'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDoctorId = doctor['id'];
                        });
                      },
                      child: _buildDoctorItem(doctor, isSelected),
                    );
                  }).toList(),
                ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMedicalCenterSelection() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Select Medical Center',
          subtitle: 'Choose the medical center you want to provide feedback for',
          child: _medicalCenters.isEmpty
              ? _buildEmptyState(
                  'No medical centers available',
                  'Medical centers will appear here once they are registered in the system',
                  Icons.local_hospital,
                )
              : Column(
                  children: _medicalCenters.map((center) {
                    final isSelected = _selectedMedicalCenterId == center['id'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMedicalCenterId = center['id'];
                        });
                      },
                      child: _buildMedicalCenterItem(center, isSelected),
                    );
                  }).toList(),
                ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isEnabled = !_isSubmitting &&
        _rating > 0 &&
        ((_feedbackType == 'doctor' && _selectedDoctorId != null) ||
         (_feedbackType == 'medical_center' && _selectedMedicalCenterId != null));

    return SizedBox(
      width: double.infinity,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: isEnabled ? _primaryColor : Colors.grey.shade400,
        child: InkWell(
          onTap: isEnabled ? _submitFeedback : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSubmitting) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                ],
                Icon(
                  _isSubmitting ? Icons.hourglass_top : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}