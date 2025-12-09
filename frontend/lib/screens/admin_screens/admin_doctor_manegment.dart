import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/admin_screens/admin_doctor_profile.dart';
import 'package:frontend/screens/patient_screens/doctor_profile_screen.dart';

class DoctorManagementScreen extends StatefulWidget {
  final String medicalCenterName;
  const DoctorManagementScreen({super.key, required this.medicalCenterName});

  @override
  State<DoctorManagementScreen> createState() => _DoctorManagementScreenState();
}

class _DoctorManagementScreenState extends State<DoctorManagementScreen> with SingleTickerProviderStateMixin {
  final Color _deepTeal = const Color(0xFF18A3B6);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _deepTeal,
        title: Text(
          'Doctor Management - ${widget.medicalCenterName}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending Requests'),
            Tab(text: 'Registered Doctors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingRequestsTab(),
          _buildRegisteredDoctorsTab(),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("doctor_requests")
          .where("status", isEqualTo: "pending")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
          );
        }

        // First get doctor_requests
        final doctorRequestsDocs = snapshot.data?.docs ?? [];
        
        // Now also check doctors collection for pending status in medicalCenters
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("doctors")
              .snapshots(),
          builder: (context, doctorsSnapshot) {
            if (doctorsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (doctorsSnapshot.hasError) {
              return Center(
                child: Text("Error: ${doctorsSnapshot.error}", style: const TextStyle(color: Colors.red)),
              );
            }

            final allDoctors = doctorsSnapshot.data?.docs ?? [];
            
            // Find doctors with pending status for THIS medical center
            final doctorsWithPending = allDoctors.where((doctorDoc) {
              final doctorData = doctorDoc.data() as Map<String, dynamic>;
              final medicalCenters = doctorData['medicalCenters'] ?? [];
              
              // Check if this doctor has this medical center with pending status
              for (var center in medicalCenters) {
                if (center is Map) {
                  final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
                  final centerStatus = center['status']?.toString() ?? '';
                  final targetName = widget.medicalCenterName.trim().toLowerCase();
                  
                  if ((centerName == targetName || 
                       centerName.contains(targetName) || 
                       targetName.contains(centerName)) && 
                      centerStatus == 'pending') {
                    return true;
                  }
                }
              }
              return false;
            }).toList();

            // Combine both sources
            final allPendingDoctors = [...doctorRequestsDocs, ...doctorsWithPending];
            
            if (allPendingDoctors.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No Pending Doctor Requests",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // Filter for this medical center
            final filteredDoctors = allPendingDoctors.where((doc) {
              final doctorData = doc.data() as Map<String, dynamic>;
              final medicalCenters = doctorData['medicalCenters'] ?? [];
              
              // Check if this medical center is in the doctor's centers
              for (var center in medicalCenters) {
                if (center is Map) {
                  final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
                  final targetName = widget.medicalCenterName.trim().toLowerCase();
                  
                  if (centerName == targetName || 
                      centerName.contains(targetName) || 
                      targetName.contains(centerName)) {
                    return true;
                  }
                } else {
                  final centerName = center.toString().trim().toLowerCase();
                  final targetName = widget.medicalCenterName.trim().toLowerCase();
                  
                  if (centerName == targetName || 
                      centerName.contains(targetName) || 
                      targetName.contains(centerName)) {
                    return true;
                  }
                }
              }
              return false;
            }).toList();

            if (filteredDoctors.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      "No requests for '${widget.medicalCenterName}'",
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Found ${allPendingDoctors.length} total pending requests",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: filteredDoctors.length,
              itemBuilder: (context, index) {
                return _buildPendingDoctorCard(filteredDoctors[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRegisteredDoctorsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("doctors")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
          );
        }
        
        final allDoctors = snapshot.data?.docs ?? [];
        
        // Filter doctors with APPROVED status for THIS medical center
        final registeredDoctors = allDoctors.where((doc) {
          final doctorData = doc.data() as Map<String, dynamic>;
          final medicalCenters = doctorData['medicalCenters'] ?? [];
          
          for (var center in medicalCenters) {
            if (center is Map) {
              final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
              final centerStatus = center['status']?.toString() ?? 'approved'; // Default to approved if no status
              final targetName = widget.medicalCenterName.trim().toLowerCase();
              
              // Check if name matches AND status is approved (or no status which means approved)
              if ((centerName == targetName || 
                   centerName.contains(targetName) || 
                   targetName.contains(centerName)) && 
                  (centerStatus == 'approved' || centerStatus.isEmpty)) {
                return true;
              }
            }
          }
          return false;
        }).toList();

        if (registeredDoctors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No Registered Doctors",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  "Doctors will appear here once approved",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: registeredDoctors.length,
          itemBuilder: (context, index) {
            return _buildRegisteredDoctorCard(registeredDoctors[index]);
          },
        );
      },
    );
  }

  Widget _buildPendingDoctorCard(DocumentSnapshot doctor) {
    final doctorData = doctor.data() as Map<String, dynamic>;
    final fullname = doctorData['fullname'] ?? "No Name";
    final specialization = doctorData['specialization'] ?? "-";
    final email = doctorData['email'] ?? "-";
    final regNumber = doctorData['regNumber'] ?? "-";
    final mobile = doctorData['mobile'] ?? doctorData['phone'] ?? "-";
    final medicalCenters = doctorData['medicalCenters'] ?? [];
    
    // Check if this is from doctor_requests or doctors collection
    final isFromDoctorRequests = doctor.reference.parent.id == 'doctor_requests';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(
                    fullname.isNotEmpty ? fullname[0].toUpperCase() : "D",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        specialization,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (isFromDoctorRequests)
                        Text(
                          "From: New Application",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Text(
                          "From: Existing Doctor",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: const Text(
                    "PENDING",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildInfoRow("Email", email, Icons.email),
            _buildInfoRow("Mobile", mobile, Icons.phone),
            _buildInfoRow("Registration No", regNumber, Icons.badge),
            const SizedBox(height: 8),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _rejectDoctor(doctor, isFromDoctorRequests),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("Reject"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveDoctor(doctor, isFromDoctorRequests),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Approve"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredDoctorCard(DocumentSnapshot doctor) {
    final doctorData = doctor.data() as Map<String, dynamic>;
    final fullname = doctorData['fullname'] ?? "No Name";
    final specialization = doctorData['specialization'] ?? "-";
    final email = doctorData['email'] ?? "-";
    final regNumber = doctorData['regNumber'] ?? "-";
    final mobile = doctorData['mobile'] ?? doctorData['phone'] ?? "-";
    final medicalCenters = doctorData['medicalCenters'] ?? [];
    final createdAt = doctorData['createdAt'] as Timestamp?;
    final joinDate = createdAt != null 
        ? "${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}"
        : "-";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _deepTeal,
                  child: Text(
                    fullname.isNotEmpty ? fullname[0].toUpperCase() : "D",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        specialization,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: const Text(
                    "ACTIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildInfoRow("Email", email, Icons.email),
            _buildInfoRow("Mobile", mobile, Icons.phone),
            _buildInfoRow("Registration No", regNumber, Icons.badge),
            _buildInfoRow("Joined Date", joinDate, Icons.calendar_today),
            const SizedBox(height: 8),
            _buildInfoRow("Registered Centers", 
                medicalCenters.map((center) {
                  if (center is Map) {
                    final name = center['name']?.toString() ?? 'Unknown';
                    final status = center['status']?.toString() ?? '';
                    return status.isNotEmpty ? "$name ($status)" : name;
                  } else {
                    return center.toString();
                  }
                }).join(', '), 
                Icons.medical_services),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _viewDoctorProfile(doctor),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text("View Profile"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _deepTeal,
                    side: BorderSide(color: _deepTeal),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _removeDoctor(doctor),
                  icon: const Icon(Icons.person_remove, size: 18),
                  label: const Text("Remove"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _approveDoctor(DocumentSnapshot doctorDoc, bool isFromDoctorRequests) async {
  final doctorData = doctorDoc.data() as Map<String, dynamic>;
  final doctorId = doctorDoc.id;
  final fullname = doctorData['fullname'] ?? doctorData['doctorName'] ?? 'Unknown Doctor';
  
  try {
    if (isFromDoctorRequests) {
      // Coming from doctor_requests collection (NEW doctor application)
      
      // 1. Get medical center info from the request
      final medicalCenterId = doctorData['medicalCenterId'] ?? '';
      final medicalCenterName = doctorData['medicalCenterName'] ?? widget.medicalCenterName;
      
      // 2. Update status in doctor_requests collection
      await FirebaseFirestore.instance
          .collection("doctor_requests")
          .doc(doctorId)
          .update({"status": "approved"});
      
      // 3. Check if doctor already exists in doctors collection
      final doctorRef = FirebaseFirestore.instance.collection("doctors").doc(doctorId);
      final doctorSnapshot = await doctorRef.get();
      
      if (doctorSnapshot.exists) {
        // Doctor already exists - update their medicalCenters array
        final currentData = doctorSnapshot.data() as Map<String, dynamic>;
        final medicalCenters = List.from(currentData['medicalCenters'] ?? []);
        
        bool centerFound = false;
        for (int i = 0; i < medicalCenters.length; i++) {
          if (medicalCenters[i] is Map) {
            final center = Map<String, dynamic>.from(medicalCenters[i]);
            final centerId = center['id']?.toString() ?? '';
            final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
            final targetName = widget.medicalCenterName.trim().toLowerCase();
            
            // Check if this is the same medical center
            if (centerId == medicalCenterId || 
                centerName == targetName || 
                centerName.contains(targetName) || 
                targetName.contains(centerName)) {
              // Update status to 'approved'
              center['status'] = 'approved';
              medicalCenters[i] = center;
              centerFound = true;
              break;
            }
          }
        }
        
        // If center not found in array, add it with approved status
        if (!centerFound) {
          medicalCenters.add({
            'id': medicalCenterId,
            'name': medicalCenterName,
            'address': doctorData['medicalCenterAddress'] ?? '',
            'phone': doctorData['medicalCenterPhone'] ?? '',
            'city': '',
            'joinedAt': Timestamp.now(),
            'status': 'approved',
          });
        }
        
        await doctorRef.update({
          "medicalCenters": medicalCenters,
          "updatedAt": FieldValue.serverTimestamp(),
        });
        
        print('✅ Updated existing doctor with approved medical center');
        
      } else {
        // Doctor doesn't exist - CREATE NEW DOCTOR in doctors collection
        // COPY ALL DATA from doctor_requests document
        final newDoctorData = {
          'uid': doctorId,
          'fullname': doctorData['fullname'] ?? doctorData['doctorName'] ?? 'Dr. Unknown',
          'email': doctorData['email'] ?? doctorData['doctorEmail'] ?? '',
          'phone': doctorData['mobile'] ?? doctorData['doctorPhone'] ?? '',
          'mobile': doctorData['mobile'] ?? doctorData['doctorPhone'] ?? '',
          'specialization': doctorData['specialization'] ?? doctorData['doctorSpecialization'] ?? '',
          'regNumber': doctorData['regNumber'] ?? '',
          'dob': doctorData['dob'] ?? '',
          'address': doctorData['address'] ?? '',
          'hospital': doctorData['hospital'] ?? '',
          'experience': doctorData['experience'] ?? 0,
          'fees': doctorData['fees'] ?? 0,
          'license': doctorData['license'] ?? '',
          'qualification': doctorData['qualification'] ?? '',
          'profileImage': doctorData['profileImage'] ?? '',
          'medicalCenters': [{
            'id': medicalCenterId,
            'name': medicalCenterName,
            'address': doctorData['medicalCenterAddress'] ?? '',
            'phone': doctorData['medicalCenterPhone'] ?? '',
            'city': '',
            'joinedAt': Timestamp.now(),
            'status': 'approved',
          }],
          'role': 'doctor',
          'status': 'approved',
          'isEmailVerified': doctorData['isEmailVerified'] ?? false,
          'isProfileComplete': doctorData['isProfileComplete'] ?? true, // If they're applying, profile should be complete
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // Remove any null or empty values that might cause issues
        final cleanedDoctorData = Map<String, dynamic>.from(newDoctorData)
          ..removeWhere((key, value) => value == null || (value is String && value.isEmpty && key != 'email'));
        
        await doctorRef.set(cleanedDoctorData);
        
        print('✅ Created NEW doctor in doctors collection with complete data from doctor_requests');
        print('📋 Doctor data copied:');
        print('  - Fullname: ${cleanedDoctorData['fullname']}');
        print('  - Email: ${cleanedDoctorData['email']}');
        print('  - Specialization: ${cleanedDoctorData['specialization']}');
        print('  - Reg Number: ${cleanedDoctorData['regNumber']}');
      }
      
    } else {
      // Coming from doctors collection (existing doctor with pending status)
      final doctorRef = FirebaseFirestore.instance.collection("doctors").doc(doctorId);
      final doctorSnapshot = await doctorRef.get();
      
      if (doctorSnapshot.exists) {
        final currentData = doctorSnapshot.data() as Map<String, dynamic>;
        final medicalCenters = List.from(currentData['medicalCenters'] ?? []);
        
        // Update status to 'approved' for this medical center
        for (int i = 0; i < medicalCenters.length; i++) {
          if (medicalCenters[i] is Map) {
            final center = Map<String, dynamic>.from(medicalCenters[i]);
            final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
            final targetName = widget.medicalCenterName.trim().toLowerCase();
            
            if (centerName == targetName || 
                centerName.contains(targetName) || 
                targetName.contains(centerName)) {
              center['status'] = 'approved';
              medicalCenters[i] = center;
              break;
            }
          }
        }
        
        await doctorRef.update({
          "medicalCenters": medicalCenters,
          "updatedAt": FieldValue.serverTimestamp(),
        });
        
        print('✅ Updated existing doctor medical center status to approved');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$fullname approved successfully!")),
    );
    
    setState(() {}); // Refresh the UI
  } catch (e) {
    print('❌ Error approving doctor: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error approving doctor: $e")),
    );
  }
}

  Future<void> _rejectDoctor(DocumentSnapshot doctorDoc, bool isFromDoctorRequests) async {
    final doctorData = doctorDoc.data() as Map<String, dynamic>;
    final doctorId = doctorDoc.id;
    final fullname = doctorData['fullname'] ?? 'Unknown Doctor';
    
    try {
      if (isFromDoctorRequests) {
        // Coming from doctor_requests - update status
        await FirebaseFirestore.instance
            .collection("doctor_requests")
            .doc(doctorId)
            .update({"status": "rejected"});
      } else {
        // Coming from doctors collection - remove this medical center
        final doctorRef = FirebaseFirestore.instance.collection("doctors").doc(doctorId);
        final doctorSnapshot = await doctorRef.get();
        final currentData = doctorSnapshot.data() as Map<String, dynamic>;
        final medicalCenters = List.from(currentData['medicalCenters'] ?? []);
        
        // Remove this medical center
        final updatedCenters = medicalCenters.where((center) {
          if (center is Map) {
            final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
            final targetName = widget.medicalCenterName.trim().toLowerCase();
            return !(centerName == targetName || 
                    centerName.contains(targetName) || 
                    targetName.contains(centerName));
          }
          return true;
        }).toList();
        
        await doctorRef.update({
          "medicalCenters": updatedCenters,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$fullname rejected.")),
      );
      
      setState(() {}); // Refresh the UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error rejecting doctor: $e")),
      );
    }
  }

  void _viewDoctorProfile(DocumentSnapshot doctorDoc) {
    final doctorData = doctorDoc.data() as Map<String, dynamic>;
    final doctorId = doctorDoc.id;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorProfileScreeen(doctorId: doctorId, doctorData: doctorData),
      ),
    );
  }

  Future<void> _removeDoctor(DocumentSnapshot doctorDoc) async {
    final doctorData = doctorDoc.data() as Map<String, dynamic>;
    final doctorId = doctorDoc.id;
    final fullname = doctorData['fullname'] ?? 'Unknown Doctor';
    
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Doctor"),
        content: Text("Are you sure you want to remove Dr. $fullname from your medical center?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        // Remove this medical center from the doctor's medicalCenters array
        final doctorRef = FirebaseFirestore.instance.collection("doctors").doc(doctorId);
        final doctorSnapshot = await doctorRef.get();
        final currentData = doctorSnapshot.data() as Map<String, dynamic>;
        final medicalCenters = List.from(currentData['medicalCenters'] ?? []);
        
        final updatedCenters = medicalCenters.where((center) {
          if (center is Map) {
            final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
            final targetName = widget.medicalCenterName.trim().toLowerCase();
            return !(centerName == targetName || 
                    centerName.contains(targetName) || 
                    targetName.contains(centerName));
          }
          return true;
        }).toList();

        await doctorRef.update({
          "medicalCenters": updatedCenters,
          "updatedAt": FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dr. $fullname removed from your medical center")),
        );
        
        setState(() {}); // Refresh the UI
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error removing doctor: $e")),
        );
      }
    }
  }
}