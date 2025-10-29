// lib/screens/doctor_screens/doctor_feedback_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/feedback_service.dart';
import '../../services/doctor_medical_feedback_service.dart';

class DoctorFeedbackDashboard extends StatefulWidget {
  const DoctorFeedbackDashboard({super.key});

  @override
  State<DoctorFeedbackDashboard> createState() => _DoctorFeedbackDashboardState();
}

class _DoctorFeedbackDashboardState extends State<DoctorFeedbackDashboard> {
  String? _doctorId;
  String? _doctorName;
  final List<Map<String, dynamic>> _medicalCenters = [];
  String _selectedTab = 'my_feedback';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allFeedback = [];
  List<Map<String, dynamic>> _doctorMedicalFeedback = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get doctor data
      final doctorSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (doctorSnapshot.docs.isNotEmpty) {
        final doctorData = doctorSnapshot.docs.first.data();
        setState(() {
          _doctorId = doctorData['uid'] ?? doctorSnapshot.docs.first.id;
          _doctorName = doctorData['fullname'] ?? 'Doctor';
        });

        // Load medical centers
        if (doctorData['medicalCenters'] != null && 
            doctorData['medicalCenters'] is List) {
          final medicalCentersList = doctorData['medicalCenters'] as List;
          
          for (final center in medicalCentersList) {
            if (center is Map<String, dynamic>) {
              final centerId = center['id'];
              if (centerId != null) {
                _medicalCenters.add({
                  'id': centerId,
                  'name': center['name'] ?? 'Unknown Medical Center',
                });
              }
            }
          }
        }

        // Load initial feedback data
        await _loadFeedbackData();
        await _loadDoctorMedicalFeedback();
      }
    } catch (error) {
      debugPrint('❌ Error loading data: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFeedbackData() async {
    try {
      final feedback = await FeedbackService.getAllFeedbackOnce();
      if (mounted) {
        setState(() {
          _allFeedback = feedback;
        });
      }
      debugPrint('✅ Loaded ${_allFeedback.length} patient feedback items');
    } catch (e) {
      debugPrint('❌ Error loading feedback: $e');
    }
  }

  Future<void> _loadDoctorMedicalFeedback() async {
    try {
      if (_doctorId != null) {
        // Get doctor's feedback for medical centers
        final snapshot = await FirebaseFirestore.instance
            .collection('doctorMedicalCenterFeedback')
            .where('doctorId', isEqualTo: _doctorId)
            .get();
        
        if (mounted) {
          setState(() {
            _doctorMedicalFeedback = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
              };
            }).toList();
          });
        }
        debugPrint('✅ Loaded ${_doctorMedicalFeedback.length} doctor medical feedback items');
      }
    } catch (e) {
      debugPrint('❌ Error loading doctor medical feedback: $e');
    }
  }

  // Filter feedback locally - NO FIREBASE QUERIES
  List<Map<String, dynamic>> _getFilteredFeedback() {
    if (_selectedTab == 'my_feedback') {
      return _allFeedback.where((feedback) {
        return feedback['doctorId'] == _doctorId && 
               feedback['status'] == 'approved';
      }).toList();
    } else if (_selectedTab == 'medical_center_feedback') {
      final centerIds = _medicalCenters.map((c) => c['id']).toList();
      return _allFeedback.where((feedback) {
        return centerIds.contains(feedback['medicalCenterId']) && 
               feedback['status'] == 'approved';
      }).toList();
    } else {
      return _doctorMedicalFeedback;
    }
  }

  void _showMedicalCenterFeedbackDialog() {
    if (_medicalCenters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No medical centers registered')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Medical Center'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _medicalCenters.length,
            itemBuilder: (context, index) {
              final medicalCenter = _medicalCenters[index];
              return ListTile(
                leading: const Icon(Icons.local_hospital, color: Color(0xFF18A3B6)),
                title: Text(medicalCenter['name']),
                trailing: const Icon(Icons.rate_review),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToMedicalCenterFeedback(medicalCenter);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToMedicalCenterFeedback(Map<String, dynamic> medicalCenter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicalCenterFeedbackForm(
          doctorId: _doctorId!,
          doctorName: _doctorName!,
          medicalCenter: medicalCenter,
          onFeedbackSubmitted: _loadDoctorMedicalFeedback,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Dashboard'),
        backgroundColor: const Color(0xFF18A3B6),
        actions: [
          // Rate Medical Center Button
          if (_medicalCenters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.rate_review),
              onPressed: _showMedicalCenterFeedbackDialog,
              tooltip: 'Rate Medical Center',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadFeedbackData();
              _loadDoctorMedicalFeedback();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab Selection
                _buildTabBar(),
                const SizedBox(height: 8),
                
                // Statistics
                _buildStatisticsCard(),
                const SizedBox(height: 8),
                
                // Feedback List
                Expanded(
                  child: _buildFeedbackList(),
                ),
              ],
            ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.3), blurRadius: 3)],
      ),
      child: Row(
        children: [
          _buildTabButton('My Feedback', 'my_feedback'),
          _buildTabButton(
            _medicalCenters.isEmpty 
                ? 'Medical Center' 
                : 'Med Center (${_medicalCenters.length})', 
            'medical_center_feedback'
          ),
          _buildTabButton('My Reviews', 'my_reviews'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, String tab) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF18A3B6) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: TextButton(
          onPressed: () => setState(() => _selectedTab = tab),
          style: TextButton.styleFrom(
            foregroundColor: isSelected ? const Color(0xFF18A3B6) : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final filteredFeedback = _getFilteredFeedback();
    
    double averageRating = 0;
    int totalReviews = filteredFeedback.length;
    Map<int, int> ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    if (totalReviews > 0) {
      double totalRating = 0;
      for (final feedback in filteredFeedback) {
        final rating = feedback['rating'] ?? 0;
        totalRating += rating;
        ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
      }
      averageRating = totalRating / totalReviews;
    }

    String title;
    if (_selectedTab == 'my_feedback') {
      title = 'Patient Feedback About Me';
    } else if (_selectedTab == 'medical_center_feedback') {
      title = 'Patient Feedback About Medical Centers';
    } else {
      title = 'My Medical Center Reviews';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18A3B6),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Average', '${averageRating.toStringAsFixed(1)} ⭐'),
                  _buildStatItem('Total', '$totalReviews'),
                  _buildStatItem('5 Star', '${ratingDistribution[5] ?? 0}'),
                ],
              ),
              if (_selectedTab == 'my_reviews' && _medicalCenters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_comment, size: 18),
                        onPressed: _showMedicalCenterFeedbackDialog,
                      ),
                      const Text(
                        'Add Review',
                        style: TextStyle(fontSize: 12, color: Color(0xFF18A3B6)),
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18A3B6),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFeedbackList() {
    final filteredFeedback = _getFilteredFeedback();

    if (_selectedTab == 'my_feedback' && _doctorId == null) {
      return _buildErrorState('Doctor data not available');
    }

    if (_selectedTab == 'medical_center_feedback' && _medicalCenters.isEmpty) {
      return _buildErrorState(
        'No Medical Centers Linked',
        'Please update your profile with medical center information',
      );
    }

    if (_selectedTab == 'my_reviews' && _medicalCenters.isEmpty) {
      return _buildErrorState(
        'No Medical Centers Linked',
        'Register at medical centers to write reviews',
      );
    }

    if (filteredFeedback.isEmpty) {
      return _buildEmptyState();
    }

    // Sort by date (newest first)
    filteredFeedback.sort((a, b) => (b['createdAt'] as DateTime)
        .compareTo(a['createdAt'] as DateTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredFeedback.length,
      itemBuilder: (context, index) {
        return _buildFeedbackCard(filteredFeedback[index]);
      },
    );
  }

  Widget _buildErrorState(String title, [String? subtitle]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          if (_selectedTab == 'my_reviews' && _medicalCenters.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.rate_review),
              onPressed: _showMedicalCenterFeedbackDialog,
             label:  const Text('Write First Review'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String title, subtitle;
    if (_selectedTab == 'my_feedback') {
      title = 'No patient feedback yet';
      subtitle = 'Patient feedback will appear here';
    } else if (_selectedTab == 'medical_center_feedback') {
      title = 'No medical center feedback yet';
      subtitle = 'Patient feedback for your medical centers will appear here';
    } else {
      title = 'No medical center reviews yet';
      subtitle = 'Write your first review about a medical center';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTab == 'my_reviews' ? Icons.rate_review : Icons.feedback_outlined,
            size: 64, 
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
          ),
          if (_selectedTab == 'my_reviews' && _medicalCenters.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_comment),
              onPressed: _showMedicalCenterFeedbackDialog,
             label:  const Text('Write Review'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadFeedbackData();
                _loadDoctorMedicalFeedback();
              },
              child: const Text('Refresh'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final rating = feedback['rating'] ?? 0;
    final comment = feedback['comment'] ?? '';
    final createdAt = feedback['createdAt'] as DateTime;

    if (_selectedTab == 'my_reviews') {
      // Doctor's medical center feedback
      final medicalCenterName = feedback['medicalCenterName'] ?? 'Unknown Center';
      final wouldRecommend = feedback['wouldRecommend'] ?? false;
      final isAnonymous = feedback['anonymous'] ?? false;
      final categories = feedback['categories'] ?? [];

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicalCenterName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          isAnonymous ? 'Anonymous Review' : 'Your Review',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Recommendation
              Row(
                children: [
                  Icon(
                    wouldRecommend ? Icons.thumb_up : Icons.thumb_down,
                    color: wouldRecommend ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wouldRecommend ? 'Would recommend to other doctors' : 'Would not recommend',
                    style: TextStyle(
                      color: wouldRecommend ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              // Categories
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: categories.map<Widget>((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F5FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getCategoryLabel(category),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF18A3B6),
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
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // Patient feedback
      final patientName = feedback['patientName'] ?? 'Anonymous';
      final wouldRecommend = feedback['wouldRecommend'] ?? false;
      final isAnonymous = feedback['anonymous'] ?? false;
      final medicalCenterName = feedback['medicalCenterName'] ?? 'Unknown Center';
      final doctorName = feedback['doctorName'] ?? 'Unknown Doctor';

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAnonymous ? 'Anonymous Patient' : patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_selectedTab == 'medical_center_feedback')
                          Text(
                            'Dr. $doctorName',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          medicalCenterName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Recommendation
              Row(
                children: [
                  Icon(
                    wouldRecommend ? Icons.thumb_up : Icons.thumb_down,
                    color: wouldRecommend ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wouldRecommend ? 'Would recommend' : 'Would not recommend',
                    style: TextStyle(
                      color: wouldRecommend ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
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
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getCategoryLabel(String category) {
    final labels = {
      'facilities': '🏥 Facilities',
      'staff_support': '👥 Staff',
      'equipment': '⚙️ Equipment',
      'admin_support': '📋 Admin',
      'working_environment': '💼 Environment',
      'resources': '📚 Resources'
    };
    return labels[category] ?? category;
  }
}

// Simple Medical Center Feedback Form
class MedicalCenterFeedbackForm extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final Map<String, dynamic> medicalCenter;
  final VoidCallback? onFeedbackSubmitted;

  const MedicalCenterFeedbackForm({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.medicalCenter,
    this.onFeedbackSubmitted,
  });

  @override
  State<MedicalCenterFeedbackForm> createState() => _MedicalCenterFeedbackFormState();
}

class _MedicalCenterFeedbackFormState extends State<MedicalCenterFeedbackForm> {
  int _rating = 0;
  bool _wouldRecommend = true;
  bool _anonymous = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await DoctorMedicalFeedbackService.submitMedicalCenterFeedback(
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        medicalCenterId: widget.medicalCenter['id'],
        medicalCenterName: widget.medicalCenter['name'],
        rating: _rating,
        comment: _commentController.text,
        wouldRecommend: _wouldRecommend,
        categories: [],
        anonymous: _anonymous,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        widget.onFeedbackSubmitted?.call();
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Medical Center'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medical Center Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medical Center',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.medicalCenter['name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'As a practicing doctor at this facility',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Rating Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Rating *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                          onPressed: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rating == 0 ? 'Tap to rate' : '${_rating} out of 5 stars',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Recommendation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Would you recommend this medical center to other doctors? *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Yes'),
                            value: true,
                            groupValue: _wouldRecommend,
                            onChanged: (value) {
                              setState(() {
                                _wouldRecommend = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('No'),
                            value: false,
                            groupValue: _wouldRecommend,
                            onChanged: (value) {
                              setState(() {
                                _wouldRecommend = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Comments
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Comments (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Share your experience working at this medical center...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Anonymous Option
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Checkbox(
                      value: _anonymous,
                      onChanged: (value) {
                        setState(() {
                          _anonymous = value!;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Submit feedback anonymously',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}