import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorManagementScreen extends StatefulWidget {
  final String medicalCenterName;
  const DoctorManagementScreen({super.key, required this.medicalCenterName});

  @override
  State<DoctorManagementScreen> createState() => _DoctorManagementScreenState();
}

class _DoctorManagementScreenState extends State<DoctorManagementScreen> {
  final Color _deepTeal = const Color(0xFF18A3B6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _deepTeal,
        title: Text(
          'Doctor Requests - ${widget.medicalCenterName}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
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
            
            // Debug print
            print("Checking doctor: ${doctorData['fullname']}");
            print("Medical centers they applied to: $medicalCenters");
            print("Looking for: ${widget.medicalCenterName}");
            
            // Check if this medical center is in the doctor's applied centers
            bool appliesHere = medicalCenters.any((center) {
              if (center is Map) {
                final centerName = center['name']?.toString() ?? '';
                print("Comparing: '$centerName' with '${widget.medicalCenterName}'");
                return centerName == widget.medicalCenterName;
              } else {
                final centerName = center.toString();
                print("Comparing: '$centerName' with '${widget.medicalCenterName}'");
                return centerName == widget.medicalCenterName;
              }
            });
            
            print("Applies here: $appliesHere");
            return appliesHere;
          }).toList();

          print("=== FILTERED DOCTORS: ${filteredDoctors.length} ===");

          if (filteredDoctors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Show all pending requests for debugging
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("All Pending Requests (Debug)"),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doctor = docs[index];
                                final data = doctor.data() as Map<String, dynamic>;
                                return ListTile(
                                  title: Text(data['fullname'] ?? 'No Name'),
                                  subtitle: Text("Centers: ${data['medicalCenters']?.toString() ?? 'None'}"),
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
                    child: const Text("Show All Requests (Debug)"),
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
    );
  }

  Widget _buildDoctorCard(DocumentSnapshot doctor) {
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
}