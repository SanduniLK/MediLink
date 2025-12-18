import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class MedicalCenterSelectionScreen extends StatefulWidget {
  const MedicalCenterSelectionScreen({super.key});

  @override
  State<MedicalCenterSelectionScreen> createState() => _MedicalCenterSelectionScreenState();
}

class _MedicalCenterSelectionScreenState extends State<MedicalCenterSelectionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _allMedicalCenters = [];
  List<Map<String, dynamic>> _selectedCenters = [];
  List<Map<String, dynamic>> _currentDoctorCenters = [];
  Map<String, dynamic>? _doctorData;
  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Load doctor data first
      final doctorDoc = await _firestore.collection('doctors').doc(user.uid).get();
      if (doctorDoc.exists) {
        _doctorData = doctorDoc.data()!;
        final currentCenters = _doctorData!['medicalCenters'] ?? [];
        _currentDoctorCenters = List<Map<String, dynamic>>.from(currentCenters);
        _selectedCenters = List<Map<String, dynamic>>.from(_currentDoctorCenters);
      }

      // Load all medical centers
      final centersSnapshot = await _firestore
          .collection('medical_centers')
          .get();

      _allMedicalCenters = centersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Center',
          'address': data['address'] ?? '',
          'phone': data['phone'] ?? '',
          'email': data['email'] ?? '',
          'registrationNumber': data['registrationNumber'] ?? '',
          'city': data['city'] ?? '',
          'isActive': data['isActive'] ?? true,
        };
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      _showErrorSnackBar('Failed to load medical centers');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredMedicalCenters {
  // First filter by search query
  List<Map<String, dynamic>> filtered = _allMedicalCenters;
  
  if (_searchQuery.isNotEmpty) {
    filtered = _allMedicalCenters.where((center) {
      final name = center['name'].toString().toLowerCase();
      final address = center['address'].toString().toLowerCase();
      final city = center['city'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || 
             address.contains(query) || 
             city.contains(query);
    }).toList();
  }
  
  // Now filter out already approved centers
  return filtered.where((center) {
    // Check if this center is already APPROVED
    final isApproved = _currentDoctorCenters.any((existingCenter) {
      // Check by ID if both have IDs
      if (existingCenter['id']?.isNotEmpty == true && 
          center['id'] == existingCenter['id'] &&
          existingCenter['status'] == 'approved') {
        return true;
      }
      
      // OR check by name (case insensitive)
      final existingName = existingCenter['name']?.toString().trim().toLowerCase() ?? '';
      final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
      
      if (existingName == centerName && 
          existingCenter['status'] == 'approved') {
        return true;
      }
      
      return false;
    });
    
    // Return FALSE if approved (to hide it), TRUE if not approved (to show it)
    return !isApproved;
  }).toList();
}

  bool _isCenterSelected(Map<String, dynamic> center) {
    return _selectedCenters.any((selected) => selected['id'] == center['id']);
  }

 

Future<void> _saveMedicalCenters() async {
  if (_isSaving) return;

  final user = _auth.currentUser;
  if (user == null) {
    _showErrorSnackBar('You must be logged in');
    return;
  }

  setState(() => _isSaving = true);

  try {
    final now = DateTime.now();
    final timestampString = now.toIso8601String();
    
    // Filter out already approved centers from selected centers
    final centersToProcess = _selectedCenters.where((center) {
      final existingCenter = _currentDoctorCenters.firstWhere(
        (c) => c['id'] == center['id'],
        orElse: () => {},
      );
      
      // Don't include already approved centers
      return existingCenter.isEmpty || existingCenter['status'] != 'approved';
    }).toList();
    
    if (centersToProcess.isEmpty) {
      _showSuccessSnackBar('No new centers to register');
      setState(() => _isSaving = false);
      return;
    }

    // Format centers to process
    final formattedCenters = centersToProcess.map((center) {
      final existingCenter = _currentDoctorCenters.firstWhere(
        (c) => c['id'] == center['id'],
        orElse: () => {},
      );
      
      return {
        'id': center['id'],
        'name': center['name'],
        'address': center['address'],
        'phone': center['phone'] ?? '',
        'city': center['city'] ?? '',
        'joinedAt': timestampString,
        'status': 'pending',
      };
    }).toList();

    // Update doctor document - combine existing approved centers with new pending ones
    final existingApprovedCenters = _currentDoctorCenters.where(
      (c) => c['status'] == 'approved'
    ).toList();
    
    final allCenters = [...existingApprovedCenters, ...formattedCenters];
    
    await _firestore.collection('doctors').doc(user.uid).update({
      'medicalCenters': allCenters,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create requests for new centers
    int newRequestsCount = 0;
    for (final center in centersToProcess) {
      try {
        final existingRequests = await _firestore
            .collection('doctor_requests')
            .where('doctorId', isEqualTo: user.uid)
            .where('medicalCenterId', isEqualTo: center['id'])
            .where('status', isEqualTo: 'pending')
            .get();
        
        if (existingRequests.docs.isEmpty) {
          await _firestore.collection('doctor_requests').add({
            'doctorId': user.uid,
            'doctorName': _doctorData?['fullname'] ?? 'Dr. Unknown',
            'doctorEmail': _doctorData?['email'] ?? '',
            'doctorPhone': _doctorData?['phone'] ?? '',
            'doctorSpecialization': _doctorData?['specialization'] ?? '',
            'medicalCenterId': center['id'],
            'medicalCenterName': center['name'],
            'medicalCenterAddress': center['address'],
            'medicalCenterPhone': center['phone'] ?? '',
            'requestDate': Timestamp.now(),
            'status': 'pending',
            'notes': '',
            'processedBy': '',
            'processedDate': null,
          });
          
          newRequestsCount++;
        }
      } catch (e) {
        print('Error creating request: $e');
      }
    }

    if (mounted) {
      if (newRequestsCount > 0) {
        _showWaitingForApprovalDialog(newRequestsCount);
      } else {
        _showSuccessSnackBar('Medical centers updated!');
        Navigator.pop(context, true);
      }
    }
    
  } catch (e) {
    if (mounted) {
      _showErrorSnackBar('Failed to save medical centers. Please try again.');
    }
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

  void _showWaitingForApprovalDialog(int requestCount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pending, color: Colors.orange),
            SizedBox(width: 10),
            Text('Requests Sent'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$requestCount request(s) sent for admin approval.'),
            const SizedBox(height: 12),
            const Text(
              'Your requests have been sent to the medical center administrators.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be notified once your requests are approved.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can check your request status anytime in your profile.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCenterDetails(Map<String, dynamic> center) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(center['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Address:', center['address']),
              _buildDetailRow('City:', center['city']),
              _buildDetailRow('Phone:', center['phone']),
              _buildDetailRow('Email:', center['email'] ?? 'Not provided'),
              _buildDetailRow('Registration:', center['registrationNumber'] ?? 'Not provided'),
              const SizedBox(height: 16),
              Text(
                'Status: ${center['isActive'] == true ? '✅ Active' : '❌ Inactive'}',
                style: TextStyle(
                  color: center['isActive'] == true ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_isCenterSelected(center))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _toggleCenterSelection(center);
              },
              child: const Text('Remove'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _toggleCenterSelection(center);
              },
              child: const Text('Add to My Centers'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAlreadyRegisteredDialog(Map<String, dynamic> center) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(center['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are already approved for this medical center.'),
            const SizedBox(height: 12),
            Text(
              'To request removal, please contact the medical center administration.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Medical Centers'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search medical centers...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                
                // Selected Centers Count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blue[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected: ${_selectedCenters.length} center${_selectedCenters.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      if (_selectedCenters.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedCenters.clear());
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                
                                // Medical Centers List
                Expanded(
  child: _filteredMedicalCenters.isEmpty
      ? _buildEmptyState()
      : // Inside the ListView.builder in build method
ListView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: _filteredMedicalCenters.length,
  itemBuilder: (context, index) {
    final center = _filteredMedicalCenters[index];
    final isSelected = _isCenterSelected(center);
    
    // Check if this center has a PENDING request
    final hasPendingRequest = _currentDoctorCenters.any((existingCenter) {
      // Check by ID
      if (existingCenter['id']?.isNotEmpty == true && 
          center['id'] == existingCenter['id'] &&
          existingCenter['status'] == 'pending') {
        return true;
      }
      
      // OR check by name
      final existingName = existingCenter['name']?.toString().trim().toLowerCase() ?? '';
      final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
      
      return existingName == centerName && existingCenter['status'] == 'pending';
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasPendingRequest ? Colors.orange : Colors.grey.shade300,
          width: hasPendingRequest ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: hasPendingRequest ? Colors.orange[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.local_hospital,
            color: hasPendingRequest ? Colors.orange : Colors.blue,
            size: 30,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                center['name'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasPendingRequest ? Colors.orange : null,
                ),
              ),
            ),
            if (hasPendingRequest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              center['address'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              center['city'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            if (hasPendingRequest)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Waiting for admin approval',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: hasPendingRequest
            ? const Icon(
                Icons.pending,
                color: Colors.orange,
              )
            : Icon(
                isSelected ? Icons.check_circle : Icons.add_circle_outline,
                color: isSelected ? Colors.green : Colors.grey,
              ),
        onTap: () {
          if (hasPendingRequest) {
            // Show message that request is pending
            _showPendingRequestDialog(center);
          } else {
            _toggleCenterSelection(center);
          }
        },
        onLongPress: () => _showCenterDetails(center),
      ),
    );
  },
),

),

                
                // Save Button
                if (_selectedCenters.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveMedicalCenters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18A3B6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Saving...'),
                                ],
                              )
                            : const Text(
                                'Save Medical Centers',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading medical centers...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No medical centers available'
                : 'No medical centers found for "$_searchQuery"',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear search'),
            ),
        ],
      ),
    );
  }
void _toggleCenterSelection(Map<String, dynamic> center) {
  setState(() {
    if (_isCenterSelected(center)) {
      _selectedCenters.removeWhere((c) => c['id'] == center['id']);
    } else {
      _selectedCenters.add(center);
    }
  });
}
void _showPendingRequestDialog(Map<String, dynamic> center) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(center['name']),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your request for "${center['name']}" is pending approval.'),
          const SizedBox(height: 12),
          Text(
            'Please wait for the medical center admin to approve your request.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
}