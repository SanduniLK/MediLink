import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SinglePatientProfileScreen extends StatelessWidget {
  final String patientUid;

  const SinglePatientProfileScreen({super.key, required this.patientUid});

  @override
  Widget build(BuildContext context) {
    final DocumentReference patientDoc =
        FirebaseFirestore.instance.collection('patients').doc(patientUid);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Profile"),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: patientDoc.get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading profile: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Patient not found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Icon
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF18A3B6),
                    child: const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                // Basic Info
                _buildInfo("Full Name", data['name'] ?? data['fullname'] ?? 'N/A'),
                _buildInfo("Mobile", data['mobile'] ?? 'N/A'),
                _buildInfo("Email", data['email'] ?? 'N/A'),
                _buildInfo("Address", data['address'] ?? 'N/A'),

                const SizedBox(height: 16),
                const Divider(),

                // Demographics
                _buildInfo("Date of Birth", data['dob'] ?? 'N/A'),
                _buildInfo("Age", data['age']?.toString() ?? 'N/A'),
                _buildInfo("Gender", data['gender'] ?? 'N/A'),

                const SizedBox(height: 16),
                const Divider(),

                // Medical Info
                _buildInfo("Blood Group", data['bloodGroup'] ?? 'N/A'),
                _buildInfo("Allergies", data['allergies'] ?? 'N/A'),

                const SizedBox(height: 16),
                const Divider(),

                // Health Stats
                _buildInfo("Height", data['height']?.toString() ?? 'N/A'),
                _buildInfo("Weight", data['weight']?.toString() ?? 'N/A'),
                _buildInfo("BMI", data['bmi']?.toStringAsFixed(2) ?? 'N/A'),
                _buildInfo("Lifestyle", data['lifestyle'] ?? 'N/A'),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper widget for consistent display
  Widget _buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
