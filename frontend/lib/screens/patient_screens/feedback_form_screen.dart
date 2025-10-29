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
  String _feedbackType = 'doctor'; // 'doctor' or 'medical_center'
  
  final TextEditingController _commentController = TextEditingController();
  
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _medicalCenters = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

 Future<void> _loadData() async {
  try {
    print('🔄 Loading doctors and medical centers from Firestore...');

    // Fetch doctors from the 'doctors' collection
    final doctorsSnapshot = await FirebaseFirestore.instance
        .collection('doctors')
        .where('role', isEqualTo: 'doctor')
        .get();

    print('📊 Found ${doctorsSnapshot.docs.length} doctors');

    _doctors = doctorsSnapshot.docs.map((doc) {
      final data = doc.data();
      print('👨‍⚕️ Doctor: ${data['fullname']} - ${data['specialization']}');
      return {
        'id': doc.id,
        'uid': data['uid'] ?? doc.id,
        'name': data['fullname'] ?? 'Unknown Doctor',
        'specialization': data['specialization'] ?? 'General',
        'hospital': data['hospital'] ?? 'Unknown Hospital',
        'profileImage': data['profileImage'] ?? '',
        'experience': data['experience'] ?? 0,
      };
    }).toList();

    // FIXED: Try different queries for medical centers
    List<QuerySnapshot<Map<String, dynamic>>> centerSnapshots = [];
    
    // Try multiple possible collection names and field names
    try {
      final snapshot1 = await FirebaseFirestore.instance
          .collection('medicalCenters')
          .get();
      centerSnapshots.add(snapshot1);
      print('🏥 Found ${snapshot1.docs.length} medical centers in "medicalCenters"');
    } catch (e) {
      print('❌ No medical centers in "medicalCenters": $e');
    }

    try {
      final snapshot2 = await FirebaseFirestore.instance
          .collection('medical_centers')
          .get();
      centerSnapshots.add(snapshot2);
      print('🏥 Found ${snapshot2.docs.length} medical centers in "medical_centers"');
    } catch (e) {
      print('❌ No medical centers in "medical_centers": $e');
    }

    // Combine all medical centers
    _medicalCenters = [];
    for (final snapshot in centerSnapshots) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('🏢 Medical Center Data: ${doc.id}: $data');
        
        // Try different field names for medical center name
        final name = data['name'] ?? data['fullname'] ?? data['hospital'] ?? 'Unknown Medical Center';
        final address = data['address'] ?? data['location'] ?? '';
        final phone = data['phone'] ?? data['mobile'] ?? data['contact'] ?? '';
        final email = data['email'] ?? '';
        
        _medicalCenters.add({
          'id': doc.id,
          'uid': data['uid'] ?? doc.id,
          'name': name,
          'address': address,
          'email': email,
          'phone': phone,
        });
      }
    }

    // If still no medical centers, add a default one for testing
    if (_medicalCenters.isEmpty) {
      print('⚠️ No medical centers found, adding default for testing');
      _medicalCenters.add({
        'id': 'default_center',
        'uid': 'default_center',
        'name': 'General Medical Center',
        'address': '123 Main Street',
        'email': 'info@medicalcenter.com',
        'phone': '+1 234 567 8900',
      });
    }

    setState(() {
      _isLoading = false;
    });

    print('✅ Data loading completed');
    print('   Doctors: ${_doctors.length}');
    print('   Medical Centers: ${_medicalCenters.length}');

  } catch (error) {
    print('❌ Error loading data: $error');
    if (error is FirebaseException) {
      print('Firebase Error: ${error.code} - ${error.message}');
    }
    
    // Add default data for testing
    _doctors = [
      {
        'id': 'default_doctor',
        'name': 'Test Doctor',
        'specialization': 'General',
        'hospital': 'Test Hospital',
        'profileImage': '',
        'experience': 5,
      }
    ];
    
    _medicalCenters = [
      {
        'id': 'default_center',
        'name': 'Test Medical Center',
        'address': '123 Test Street',
        'email': 'test@medical.com',
        'phone': '+1 234 567 8900',
      }
    ];
    
    setState(() {
      _isLoading = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Using demo data. Error: $error'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

 Future<void> _submitFeedback() async {
  if (_rating == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please provide a rating')),
    );
    return;
  }

  if (_feedbackType == 'doctor' && _selectedDoctorId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a doctor')),
    );
    return;
  }

  if (_feedbackType == 'medical_center' && _selectedMedicalCenterId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a medical center')),
    );
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get selected doctor data
    final selectedDoctor = _selectedDoctorId != null 
        ? _doctors.firstWhere(
            (doctor) => doctor['id'] == _selectedDoctorId,
            orElse: () => {
              'name': 'Unknown Doctor',
              'hospital': 'Unknown Hospital',
              'uid': 'unknown'
            },
          )
        : {
            'name': 'Unknown Doctor',
            'hospital': 'Unknown Hospital',
            'uid': 'unknown'
          };

    // Get selected medical center data
    final selectedMedicalCenter = _selectedMedicalCenterId != null
        ? _medicalCenters.firstWhere(
            (center) => center['id'] == _selectedMedicalCenterId,
            orElse: () => {
              'name': 'Unknown Medical Center',
              'uid': 'unknown'
            },
          )
        : {
            'name': 'Unknown Medical Center',
            'uid': 'unknown'
          };

    // FIXED: Get patient name properly
    String patientName = 'Patient';
    String patientEmail = user.email ?? '';
    
    // Try to get patient data from Firestore patients collection
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();
      
      if (patientDoc.exists) {
        final patientData = patientDoc.data();
        print('📋 Patient data from Firestore: $patientData');
        
        // Try different field names for patient name
        patientName = patientData?['fullname'] ?? 
                     patientData?['name'] ?? 
                     patientData?['displayName'] ?? 
                     'Patient';
        
        patientEmail = patientData?['email'] ?? user.email ?? '';
        
        print('✅ Using patient name from Firestore: $patientName');
      } else {
        // If no patient document, try to get from users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientId)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data();
          patientName = userData?['fullname'] ?? 
                       userData?['name'] ?? 
                       userData?['displayName'] ?? 
                       'Patient';
          print('✅ Using patient name from users collection: $patientName');
        } else {
          // Fallback to a default name
          patientName = 'Patient ${widget.patientId.substring(0, 6)}';
          print('⚠️ Using fallback patient name: $patientName');
        }
      }
    } catch (e) {
      print('⚠️ Could not fetch patient data: $e');
      // Final fallback
      patientName = 'Patient ${widget.patientId.substring(0, 6)}';
    }

    // Apply anonymous setting
    final finalPatientName = _anonymous ? 'Anonymous' : patientName;
    final finalPatientEmail = _anonymous ? '' : patientEmail;

    print('🎯 SUBMITTING FEEDBACK WITH PATIENT DATA:');
    print('   Patient ID: ${widget.patientId}');
    print('   Patient Name: $finalPatientName');
    print('   Patient Email: $finalPatientEmail');
    print('   Doctor: ${selectedDoctor['name']}');
    print('   Medical Center: ${selectedMedicalCenter['name']}');
    print('   Rating: $_rating');
    print('   Anonymous: $_anonymous');

    final result = await FeedbackService.submitFeedback(
      patientId: widget.patientId,
      patientName: finalPatientName, // Now this should have a real name
      patientEmail: finalPatientEmail,
      medicalCenterId: selectedMedicalCenter['uid'] ?? selectedMedicalCenter['id'],
      medicalCenterName: selectedMedicalCenter['name'],
      doctorId: selectedDoctor['uid'] ?? selectedDoctor['id'],
      doctorName: selectedDoctor['name'],
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
      Navigator.pop(context, true);
    } else {
      throw Exception(result['error']);
    }
  } catch (e) {
    print('❌ Error submitting feedback: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to submit feedback: $e')),
    );
  } finally {
    setState(() {
      _isSubmitting = false;
    });
  }
}

 Widget _buildDoctorItem(Map<String, dynamic> doctor) {
  return ListTile(
    leading: CircleAvatar(
      radius: 25,
      backgroundImage: doctor['profileImage'] != null && 
                      doctor['profileImage'].isNotEmpty
          ? CachedNetworkImageProvider(
              doctor['profileImage'],
              errorListener: (err) {
                print('❌ Error loading doctor image: $err');
              },
            )
          : null,
      backgroundColor: Colors.grey[300],
      child: doctor['profileImage'] == null || 
             doctor['profileImage'].isEmpty
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    ),
    title: Text(
      doctor['name'],
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(doctor['specialization']),
        Text(
          doctor['hospital'],
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        if (doctor['experience'] > 0)
          Text(
            '${doctor['experience']} years experience',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
      ],
    ),
  );
}

  Widget _buildMedicalCenterItem(Map<String, dynamic> center) {
    return ListTile(
      leading: const CircleAvatar(
        radius: 25,
        backgroundColor: Color(0xFF18A3B6),
        child: Icon(Icons.apartment_rounded, color: Colors.white),
      ),
      title: Text(
        center['name'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (center['address'] != null && center['address'].isNotEmpty)
            Text(
              center['address'],
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          if (center['phone'] != null && center['phone'].isNotEmpty)
            Text(
              center['phone'],
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading doctors and medical centers...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debug Info (remove in production)
                  if (_doctors.isEmpty && _medicalCenters.isEmpty)
                    Card(
                      color: Colors.orange[100],
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(height: 8),
                            Text(
                              'No doctors or medical centers found.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Please check your Firestore collections.'),
                          ],
                        ),
                      ),
                    ),

                  // Feedback Type Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Feedback For',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Doctor'),
                                  value: 'doctor',
                                  groupValue: _feedbackType,
                                  onChanged: (value) {
                                    setState(() {
                                      _feedbackType = value!;
                                      _selectedMedicalCenterId = null;
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Medical Center'),
                                  value: 'medical_center',
                                  groupValue: _feedbackType,
                                  onChanged: (value) {
                                    setState(() {
                                      _feedbackType = value!;
                                      _selectedDoctorId = null;
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

                  // Doctor Selection (only show for doctor feedback)
                  if (_feedbackType == 'doctor') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Select Doctor *',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${_doctors.length} available)',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_doctors.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Column(
                                  children: [
                                    Icon(Icons.person_off, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('No doctors available'),
                                  ],
                                ),
                              )
                            else
                              ..._doctors.map((doctor) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: _selectedDoctorId == doctor['id'] 
                                      ? const Color(0xFFE1F5FE) 
                                      : Colors.white,
                                  child: RadioListTile<String>(
                                    value: doctor['id'],
                                    groupValue: _selectedDoctorId,
                                    title: _buildDoctorItem(doctor),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDoctorId = value;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Medical Center Selection (only show for medical center feedback)
                  if (_feedbackType == 'medical_center') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Select Medical Center *',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${_medicalCenters.length} available)',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_medicalCenters.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Column(
                                  children: [
                                    Icon(Icons.apartment, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('No medical centers available'),
                                  ],
                                ),
                              )
                            else
                              ..._medicalCenters.map((center) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: _selectedMedicalCenterId == center['id'] 
                                      ? const Color(0xFFE1F5FE) 
                                      : Colors.white,
                                  child: RadioListTile<String>(
                                    value: center['id'],
                                    groupValue: _selectedMedicalCenterId,
                                    title: _buildMedicalCenterItem(center),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedMedicalCenterId = value;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

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
                            'Would you recommend? *',
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
                              hintText: 'Share your experience in detail...',
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
                      onPressed: (_isSubmitting || 
                                 (_feedbackType == 'doctor' && _selectedDoctorId == null) ||
                                 (_feedbackType == 'medical_center' && _selectedMedicalCenterId == null))
                          ? null
                          : _submitFeedback,
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