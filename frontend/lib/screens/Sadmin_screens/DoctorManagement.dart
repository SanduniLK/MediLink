import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DoctorManagementScreenn extends StatefulWidget {
  const DoctorManagementScreenn({super.key});

  @override
  State<DoctorManagementScreenn> createState() => _DoctorManagementScreenState();
}

class _DoctorManagementScreenState extends State<DoctorManagementScreenn> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMedicalCenter = 'All Centers';
  List<String> _medicalCenters = ['All Centers'];

  @override
  void initState() {
    super.initState();
    _loadMedicalCenters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load medical centers from Firestore
  Future<void> _loadMedicalCenters() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('medical_centers')
          .get();

      setState(() {
        _medicalCenters = ['All Centers'];
        _medicalCenters.addAll(
          querySnapshot.docs.map((doc) => doc['name'] as String).toList(),
        );
      });
    } catch (e) {
      print('Error loading medical centers: $e');
    }
  }

  // Get only approved doctors from 'doctors' collection
  Stream<QuerySnapshot> _getDoctorsStream() {
    return FirebaseFirestore.instance
        .collection('doctors')
        .orderBy('fullname')
        .snapshots();
  }

  // Filter doctors based on search and medical center
  List<DocumentSnapshot> _filterDoctors(List<DocumentSnapshot> doctors, String searchQuery, String medicalCenter) {
    return doctors.where((doctor) {
      final data = doctor.data() as Map<String, dynamic>? ?? {};
      final String name = data['fullname']?.toString().toLowerCase() ?? '';
      final String specialization = data['specialization']?.toString().toLowerCase() ?? '';
      final String qualification = data['qualification']?.toString().toLowerCase() ?? '';
      
      // Search filter
      final bool matchesSearch = searchQuery.isEmpty ||
          name.contains(searchQuery.toLowerCase()) ||
          specialization.contains(searchQuery.toLowerCase()) ||
          qualification.contains(searchQuery.toLowerCase());

      // Medical center filter
      bool matchesMedicalCenter = true;
      if (medicalCenter != 'All Centers') {
        final List<dynamic> medicalCenters = data['medicalCenters'] ?? [];
        matchesMedicalCenter = medicalCenters.any((center) {
          if (center is Map) {
            final centerName = center['name']?.toString().toLowerCase();
            final searchCenter = medicalCenter.toLowerCase();
            return centerName == searchCenter;
          }
          return false;
        });
      }

      return matchesSearch && matchesMedicalCenter;
    }).toList();
  }

  // Format timestamp to readable date
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Not available';
    try {
      final DateTime date = (timestamp as Timestamp).toDate();
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Safe number conversion method
  int _safeIntConvert(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Safe double conversion method
  double _safeDoubleConvert(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Delete doctor
  void _deleteDoctor(String docId, String doctorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Doctor'),
        content: Text('Are you sure you want to delete $doctorName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance.collection('doctors').doc(docId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$doctorName deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Build doctor card with all details
  Widget _buildDoctorCard(DocumentSnapshot doctor) {
    final data = doctor.data() as Map<String, dynamic>;
    final docId = doctor.id;

    // Safe field extraction with type conversion
    final String fullname = data['fullname']?.toString() ?? 'No Name';
    final String specialization = data['specialization']?.toString() ?? 'Not specified';
    final String qualification = data['qualification']?.toString() ?? 'Not specified';
    final String email = data['email']?.toString() ?? 'Not specified';
    final String mobile = data['mobile']?.toString() ?? data['phone']?.toString() ?? 'Not specified';
    final String dob = data['dob']?.toString() ?? 'Not specified';
    final String address = data['address']?.toString() ?? 'Not specified';
    final String hospital = data['hospital']?.toString() ?? 'Not specified';
    final String regNumber = data['regNumber']?.toString() ?? 'Not specified';
    final String license = data['license']?.toString() ?? 'Not specified';
    
    // Safe number conversions
    final int experience = _safeIntConvert(data['experience']);
    final double fees = _safeDoubleConvert(data['fees']);
    
    final bool isEmailVerified = data['isEmailVerified'] == true;
    final bool isProfileComplete = data['isProfileComplete'] == true;
    final String profileImage = data['profileImage']?.toString() ?? '';
    final List<dynamic> medicalCenters = data['medicalCenters'] ?? [];
    final String createdAt = _formatTimestamp(data['createdAt']);
    final String updatedAt = _formatTimestamp(data['updatedAt']);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with profile image and basic info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF18A3B6),
                  child: profileImage.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            profileImage,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, color: Colors.white, size: 30);
                            },
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialization,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        qualification,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ✅ FIXED: Experience and Fees in a Column instead of Row to prevent overflow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Exp: $experience yrs',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fees: Rs. ${fees.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteDoctor(docId, fullname),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),

            // Contact Information
            _buildInfoSection('Contact Information', [
              _buildInfoRow('📧', 'Email', email, isEmailVerified ? Icons.verified : Icons.verified),
              _buildInfoRow('📱', 'Mobile', mobile),
              _buildInfoRow('🏥', 'Hospital', hospital),
              _buildInfoRow('📍', 'Address', address),
            ]),

            const SizedBox(height: 16),
            const Divider(),

            // Professional Details
            _buildInfoSection('Professional Details', [
              _buildInfoRow('🎓', 'Registration No', regNumber),
              _buildInfoRow('📄', 'License', license),
              _buildInfoRow('🎂', 'Date of Birth', dob),
            ]),

            const SizedBox(height: 16),
            const Divider(),

            // Medical Centers
            _buildInfoSection('Associated Medical Centers', [
              if (medicalCenters.isEmpty)
                const Text('No medical centers assigned', style: TextStyle(color: Colors.grey)),
              ...medicalCenters.map((center) {
                final centerMap = center as Map<String, dynamic>? ?? {};
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          centerMap['name']?.toString() ?? 'Unknown Center',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ]),

            const SizedBox(height: 16),
            const Divider(),

            // Status Information
            _buildInfoSection('Status Information', [
              _buildStatusRow('Email Verified', isEmailVerified),
              _buildStatusRow('Profile Complete', isProfileComplete),
              _buildInfoRow('📅', 'Created', createdAt),
              _buildInfoRow('✏️', 'Last Updated', updatedAt),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
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
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value, [IconData? verificationIcon]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji ', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: value == 'Not specified' ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
                if (verificationIcon != null)
                  Icon(verificationIcon, 
                      size: 16, 
                      color: verificationIcon == Icons.verified ? Colors.green : Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: status ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status ? 'Yes' : 'No',
              style: TextStyle(
                color: status ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Doctor Management'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search doctors...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Medical Center Filter
                DropdownButtonFormField<String>(
                  value: _selectedMedicalCenter,
                  items: _medicalCenters.map((center) {
                    return DropdownMenuItem(
                      value: center,
                      child: Text(center),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMedicalCenter = value!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Filter by Medical Center',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Doctors List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getDoctorsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading doctors: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final doctors = snapshot.data!.docs;
                final filteredDoctors = _filterDoctors(
                  doctors,
                  _searchController.text,
                  _selectedMedicalCenter,
                );

                print('=== APPROVED DOCTORS FOUND: ${doctors.length} ===');
                for (var doctor in doctors) {
                  final data = doctor.data() as Map<String, dynamic>;
                  print('✅ Approved Doctor: ${data['fullname']} - ${data['specialization']}');
                }
                print('=== FILTERED DOCTORS: ${filteredDoctors.length} ===');

                if (filteredDoctors.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty || _selectedMedicalCenter != 'All Centers'
                              ? 'No doctors found matching your criteria'
                              : 'No approved doctors found',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Note: Only approved doctors are shown here',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDoctors.length,
                  itemBuilder: (context, index) {
                    return _buildDoctorCard(filteredDoctors[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}