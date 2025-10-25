import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalCenterManagementScreen extends StatefulWidget {
  const MedicalCenterManagementScreen({super.key});

  @override
  State<MedicalCenterManagementScreen> createState() =>
      _MedicalCenterManagementScreenState();
}

class _MedicalCenterManagementScreenState
    extends State<MedicalCenterManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _medLicenseController = TextEditingController();

  bool isLoading = false;

  Future<void> _addMedicalCenter() async {
    // Validate the form before proceeding (checks email format now)
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = "12345678"; // default password

      // 1️⃣ Create Firebase Auth account.
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = cred.user!.uid;

      // 2️⃣ Create Firestore document.
      await FirebaseFirestore.instance.collection('medical_centers').doc(uid).set({
        "uid": uid,
        "name": _nameController.text.trim(),
        "email": email,
        "regNumber": _regNumberController.text.trim(),
        "specialization": _specializationController.text.trim(),
        "melicenseNumber": _medLicenseController.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "role": "medical_center",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Medical Center added successfully! Email: $email, Password: $password"),
        ),
      );

      // Clear fields
      _nameController.clear();
      _emailController.clear();
      _regNumberController.clear();
      _specializationController.clear();
      _medLicenseController.clear();

    } on FirebaseAuthException catch (e) {
      // Catches specific errors like 'invalid-email', 'email-already-in-use', etc.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auth Error: ${e.message}")),
      );
    } catch (e) {
      // Catches other errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medical Center Management"),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Center Name",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? "Please enter center name" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter email";
                      }
                      // Simple regex check for email format
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return "Please enter a valid email address (e.g., name@domain.com)";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _regNumberController,
                    decoration: const InputDecoration(
                      labelText: "Registration Number",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? "Please enter reg number" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _specializationController,
                    decoration: const InputDecoration(
                      labelText: "Specialization",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _medLicenseController,
                    decoration: const InputDecoration(
                      labelText: "Medical License Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _addMedicalCenter,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF18A3B6)),
                          child: const Text("Add Medical Center"),
                        ),
                  const Divider(thickness: 2),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medical_centers')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Check for the permission denied error
                  if (snapshot.hasError) {
                    if (snapshot.error.toString().contains('PERMISSION_DENIED')) {
                      return const Center(
                        child: Text(
                          "Permission Denied: Please check your Firestore Security Rules for 'medical_centers'.",
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Center(child: Text("Error fetching centers: ${snapshot.error}"));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No medical centers found."));
                  }

                  final centers = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: centers.length,
                    itemBuilder: (context, index) {
                      final center = centers[index].data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(center['name'] ?? 'No Name'),
                          subtitle: Text(center['email'] ?? 'No Email'),
                          trailing: Text(center['regNumber'] ?? ''),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
