import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

        final docs = snapshot.data!.docs;
        
        // Filter doctors who applied to THIS medical center
        final filteredDoctors = docs.where((doc) {
          final doctorData = doc.data() as Map<String, dynamic>;
          final medicalCenters = doctorData['medicalCenters'] ?? [];
          
          // Check if this medical center is in the doctor's applied centers
          bool appliesHere = medicalCenters.any((center) {
            if (center is Map) {
              final centerName = center['name']?.toString() ?? '';
              return centerName == widget.medicalCenterName;
            } else {
              final centerName = center.toString();
              return centerName == widget.medicalCenterName;
            }
          });
          
          return appliesHere;
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
                  "Found ${docs.length} total pending requests",
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
      
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

      final allDoctors = snapshot.data!.docs;
      
      // Debug: Print all doctors and their medical centers
      print("=== ALL DOCTORS FOUND: ${allDoctors.length} ===");
      for (var doc in allDoctors) {
        final doctorData = doc.data() as Map<String, dynamic>;
        final medicalCenters = doctorData['medicalCenters'] ?? [];
        print("Doctor: ${doctorData['fullname']}");
        print("Medical Centers: $medicalCenters");
        print("---");
      }
      
      // Filter doctors registered with THIS medical center
      final registeredDoctors = allDoctors.where((doc) {
        final doctorData = doc.data() as Map<String, dynamic>;
        final medicalCenters = doctorData['medicalCenters'] ?? [];
        
        print("🔍 Checking doctor: ${doctorData['fullname']}");
        print("Looking for medical center: '${widget.medicalCenterName}'");
        
        // Check if this medical center is in the doctor's registered centers
       // Replace the filtering logic with this more flexible version:
bool registeredHere = false;

for (var center in medicalCenters) {
  if (center is Map) {
    final centerName = center['name']?.toString().trim().toLowerCase() ?? '';
    final targetName = widget.medicalCenterName.trim().toLowerCase();
    
    print("  - Comparing: '$centerName' with '$targetName'");
    
    // Flexible matching - check for partial matches or contains
    if (centerName == targetName || 
        centerName.contains(targetName) || 
        targetName.contains(centerName)) {
      registeredHere = true;
      print("  ✅ MATCH FOUND!");
      break;
    }
  } else {
    final centerName = center.toString().trim().toLowerCase();
    final targetName = widget.medicalCenterName.trim().toLowerCase();
    
    print("  - Comparing: '$centerName' with '$targetName'");
    
    if (centerName == targetName || 
        centerName.contains(targetName) || 
        targetName.contains(centerName)) {
      registeredHere = true;
      print("  ✅ MATCH FOUND!");
      break;
    }
  }
}
        print("✅ Registered here: $registeredHere");
        return registeredHere;
      }).toList();

      print("=== FILTERED REGISTERED DOCTORS: ${registeredDoctors.length} ===");

      if (registeredDoctors.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.medical_services, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "No doctors registered with '${widget.medicalCenterName}'",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Found ${allDoctors.length} total registered doctors in system",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Show all doctors for debugging
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("All Doctors (Debug)"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: allDoctors.length,
                          itemBuilder: (context, index) {
                            final doctor = allDoctors[index];
                            final data = doctor.data() as Map<String, dynamic>;
                            final centers = data['medicalCenters'] ?? [];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['fullname'] ?? 'No Name',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text("Email: ${data['email'] ?? '-'}"),
                                    Text("Medical Centers: ${centers.map((c) => c is Map ? c['name'] : c.toString()).join(', ')}"),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text("Show All Doctors (Debug)"),
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
    final mobile = doctorData['mobile'] ?? "-";
    final medicalCenters = doctorData['medicalCenters'] ?? [];

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
            _buildInfoRow("Applied Centers", 
                medicalCenters.map((center) => center is Map ? center['name'] : center.toString()).join(', '), 
                Icons.medical_services),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _rejectDoctor(doctor),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("Reject"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveDoctor(doctor),
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
    final mobile = doctorData['mobile'] ?? "-";
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
                medicalCenters.map((center) => center is Map ? center['name'] : center.toString()).join(', '), 
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

  Future<void> _approveDoctor(DocumentSnapshot doctorDoc) async {
    final doctorData = doctorDoc.data() as Map<String, dynamic>;
    
    try {
      // Add to doctors collection
      await FirebaseFirestore.instance.collection("doctors").doc(doctorDoc.id).set({
        'uid': doctorDoc.id,
        'fullname': doctorData['fullname'] ?? '',
        'email': doctorData['email'] ?? '',
        'specialization': doctorData['specialization'] ?? '',
        'regNumber': doctorData['regNumber'] ?? '',
        'mobile': doctorData['mobile'] ?? '',
        'dob': doctorData['dob'] ?? '',
        'address': doctorData['address'] ?? '',
        'medicalCenters': doctorData['medicalCenters'] ?? [],
        'role': 'doctor',
        'createdAt': FieldValue.serverTimestamp(),
        'isEmailVerified': doctorData['isEmailVerified'] ?? false,
      });

      // Update status in doctor_requests
      await FirebaseFirestore.instance
          .collection("doctor_requests")
          .doc(doctorDoc.id)
          .update({"status": "approved"});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${doctorData['fullname']} approved successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error approving doctor: $e")),
      );
    }
  }

  Future<void> _rejectDoctor(DocumentSnapshot doctorDoc) async {
    final doctorData = doctorDoc.data() as Map<String, dynamic>;
    final fullname = doctorData['fullname'] ?? 'Unknown Doctor';
    
    try {
      await FirebaseFirestore.instance
          .collection("doctor_requests")
          .doc(doctorDoc.id)
          .update({"status": "rejected"});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$fullname rejected.")),
      );
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
      builder: (context) => DoctorProfileScreen(
        doctorId: doctorId,
        doctorData: doctorData,
      ),
    ),
  );
}

 

  Future<void> _removeDoctor(DocumentSnapshot doctorDoc) async {
    final doctorData = doctorDoc.data() as Map<String, dynamic>;
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
        final currentCenters = List.from(doctorData['medicalCenters'] ?? []);
        final updatedCenters = currentCenters.where((center) {
          if (center is Map) {
            return center['name'] != widget.medicalCenterName;
          } else {
            return center.toString() != widget.medicalCenterName;
          }
        }).toList();

        await FirebaseFirestore.instance
            .collection("doctors")
            .doc(doctorDoc.id)
            .update({
          "medicalCenters": updatedCenters
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dr. $fullname removed from your medical center")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error removing doctor: $e")),
        );
      }
    }
  }
}