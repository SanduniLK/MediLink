import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/services/feedback_service.dart';

class FeedbackFormScreen extends StatefulWidget {
  final String patientId;
  final String doctorId; // Added: Doctor ID from appointment
  final String doctorName; // Added: Doctor name from appointment
  final String medicalCenterId; // Added: Medical center ID from appointment
  final String medicalCenterName; // Added: Medical center name from appointment
  final String appointmentDate; // Optional: For display

  const FeedbackFormScreen({
    Key? key,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.medicalCenterId,
    required this.medicalCenterName,
    this.appointmentDate = '',
  }) : super(key: key);

  @override
  _FeedbackFormScreenState createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  int _rating = 0;
  bool _wouldRecommend = true;
  bool _anonymous = false;
  String _feedbackType = 'doctor'; // Default to doctor feedback
  
  final TextEditingController _commentController = TextEditingController();
  
  Map<String, dynamic>? _doctorData;
  Map<String, dynamic>? _medicalCenterData;
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
    _loadAppointmentData();
  }

  Future<void> _loadAppointmentData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load doctor data
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(widget.doctorId)
            .get();
        
        if (doctorDoc.exists) {
          final data = doctorDoc.data()!;
          _doctorData = {
            'id': doctorDoc.id,
            'uid': data['uid'] ?? doctorDoc.id,
            'name': data['fullname'] ?? widget.doctorName,
            'specialization': data['specialization'] ?? 'General Practitioner',
            'profileImage': data['profileImage'] ?? '',
            'experience': data['experience'] ?? 0,
          };
        } else {
          _doctorData = {
            'id': widget.doctorId,
            'uid': widget.doctorId,
            'name': widget.doctorName,
            'specialization': 'Healthcare Provider',
            'profileImage': '',
            'experience': 0,
          };
        }
      } catch (e) {
        print('Error loading doctor data: $e');
        _doctorData = {
          'id': widget.doctorId,
          'uid': widget.doctorId,
          'name': widget.doctorName,
          'specialization': 'Healthcare Provider',
          'profileImage': '',
          'experience': 0,
        };
      }

      // Load medical center data
      try {
        QuerySnapshot<Map<String, dynamic>>? medicalCenterSnapshot;
        
        // Try different collections
        try {
          medicalCenterSnapshot = await FirebaseFirestore.instance
              .collection('medicalCenters')
              .where('uid', isEqualTo: widget.medicalCenterId)
              .get();
        } catch (e) {
          print('Not found in medicalCenters: $e');
        }
        
        if (medicalCenterSnapshot == null || medicalCenterSnapshot.docs.isEmpty) {
          try {
            medicalCenterSnapshot = await FirebaseFirestore.instance
                .collection('medical_centers')
                .where('uid', isEqualTo: widget.medicalCenterId)
                .get();
          } catch (e) {
            print('Not found in medical_centers: $e');
          }
        }
        
        if (medicalCenterSnapshot != null && medicalCenterSnapshot.docs.isNotEmpty) {
          final data = medicalCenterSnapshot.docs.first.data();
          _medicalCenterData = {
            'id': medicalCenterSnapshot.docs.first.id,
            'uid': data['uid'] ?? medicalCenterSnapshot.docs.first.id,
            'name': data['name'] ?? data['fullname'] ?? data['hospital'] ?? widget.medicalCenterName,
            'address': data['address']?.toString() ?? '',
            'email': data['email']?.toString() ?? '',
            'phone': data['phone']?.toString() ?? '',
          };
        } else {
          _medicalCenterData = {
            'id': widget.medicalCenterId,
            'uid': widget.medicalCenterId,
            'name': widget.medicalCenterName,
            'address': '',
            'email': '',
            'phone': '',
          };
        }
      } catch (e) {
        print('Error loading medical center data: $e');
        _medicalCenterData = {
          'id': widget.medicalCenterId,
          'uid': widget.medicalCenterId,
          'name': widget.medicalCenterName,
          'address': '',
          'email': '',
          'phone': '',
        };
      }

    } catch (error) {
      print('Error loading appointment data: $error');
      
      // Fallback data
      _doctorData = {
        'id': widget.doctorId,
        'uid': widget.doctorId,
        'name': widget.doctorName,
        'specialization': 'Healthcare Provider',
        'profileImage': '',
        'experience': 0,
      };
      
      _medicalCenterData = {
        'id': widget.medicalCenterId,
        'uid': widget.medicalCenterId,
        'name': widget.medicalCenterName,
        'address': '',
        'email': '',
        'phone': '',
      };
      
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please login to submit feedback');

      // Get patient data
      final patientData = await _getPatientData();
      final finalPatientName = _anonymous ? 'Anonymous' : patientData['name'];
      final finalPatientEmail = _anonymous ? '' : patientData['email'];

      // Submit feedback
      final result = await FeedbackService.submitFeedback(
        patientId: widget.patientId,
        patientName: finalPatientName ?? 'Patient',
        patientEmail: finalPatientEmail ?? '',
        medicalCenterId: _medicalCenterData?['uid']?.toString() ?? widget.medicalCenterId,
        medicalCenterName: _medicalCenterData?['name']?.toString() ?? widget.medicalCenterName,
        doctorId: _feedbackType == 'doctor' 
            ? (_doctorData?['uid']?.toString() ?? widget.doctorId)
            : '', 
        doctorName: _feedbackType == 'doctor' 
            ? (_doctorData?['name']?.toString() ?? widget.doctorName)
            : '', 
        rating: _rating,
        comment: _commentController.text,
        wouldRecommend: _wouldRecommend,
        categories: [],
        anonymous: _anonymous,
        feedbackType: _feedbackType,
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

  Widget _buildDoctorInfo() {
    return _buildSectionCard(
      title: 'Doctor Information',
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: _doctorData?['profileImage'] != null && 
                          _doctorData!['profileImage'].toString().isNotEmpty
              ? CachedNetworkImageProvider(_doctorData!['profileImage'].toString())
              : null,
          backgroundColor: _primaryColor,
          child: _doctorData?['profileImage'] == null || 
                 _doctorData!['profileImage'].toString().isEmpty
              ? Icon(Icons.medical_services, color: Colors.white, size: 20)
              : null,
        ),
        title: Text(
          'Dr. ${_doctorData?['name']?.toString() ?? widget.doctorName}',
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
              _doctorData?['specialization']?.toString() ?? 'General Practitioner',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if ((_doctorData?['experience'] ?? 0) > 0)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '${_doctorData?['experience']} years experience',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalCenterInfo() {
    return _buildSectionCard(
      title: 'Medical Center Information',
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: _primaryColor,
          child: Icon(Icons.local_hospital, color: Colors.white, size: 24),
        ),
        title: Text(
          _medicalCenterData?['name']?.toString() ?? widget.medicalCenterName,
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
            if (_medicalCenterData?['address'] != null && _medicalCenterData!['address'].toString().isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: _textSecondary),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _medicalCenterData!['address'].toString(),
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            if (_medicalCenterData?['phone'] != null && _medicalCenterData!['phone'].toString().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: _textSecondary),
                    SizedBox(width: 4),
                    Text(
                      _medicalCenterData!['phone'].toString(),
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
            'Loading appointment details...',
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
          // Header Section
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
                  'Share Your Experience',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Help us improve healthcare services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                if (widget.appointmentDate.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Appointment: ${widget.appointmentDate}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Form Content
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appointment Info - Doctor
                _buildDoctorInfo(),
                SizedBox(height: 16),
                
                // Appointment Info - Medical Center
                _buildMedicalCenterInfo(),
                SizedBox(height: 24),

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

                // Rating Section
                _buildSectionCard(
                  title: 'Overall Rating',
                  subtitle: 'How would you rate your experience with this ${_feedbackType == 'doctor' ? 'doctor' : 'medical center'}?',
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

  Widget _buildSubmitButton() {
    final isEnabled = !_isSubmitting && _rating > 0;

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