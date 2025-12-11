import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
String get medicalCenterName => _nameController.text.trim();
  Future<void> _addMedicalCenter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = "$medicalCenterName@12345";

      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = cred.user!.uid;

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

      _nameController.clear();
      _emailController.clear();
      _regNumberController.clear();
      _specializationController.clear();
      _medLicenseController.clear();

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auth Error: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteMedicalCenter(String centerId, String centerName) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Medical Center"),
        content: Text("Are you sure you want to delete '$centerName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      try {
        // Delete from Firebase Auth
        await FirebaseAuth.instance.currentUser?.delete();
        
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('medical_centers')
            .doc(centerId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Medical Center '$centerName' deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting medical center: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Medical Center Management"),
          backgroundColor: const Color(0xFF18A3B6),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.add_circle_outline),
                text: "Add New Center",
              ),
              Tab(
                icon: Icon(Icons.list),
                text: "All Centers",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Add Medical Center Form
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add New Medical Center",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF18A3B6),
                          ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Basic Information",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFormField(
                      controller: _nameController,
                      label: "Center Name",
                      icon: Icons.business,
                      isRequired: true,
                    ),
                    const SizedBox(height: 15),
                    _buildFormField(
                      controller: _emailController,
                      label: "Email Address",
                      icon: Icons.email,
                      isRequired: true,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),
                    _buildFormField(
                      controller: _regNumberController,
                      label: "Registration Number",
                      icon: Icons.numbers,
                      isRequired: true,
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Additional Details",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFormField(
                      controller: _specializationController,
                      label: "Specialization",
                      icon: Icons.medical_services,
                    ),
                    const SizedBox(height: 15),
                    _buildFormField(
                      controller: _medLicenseController,
                      label: "Medical License Number",
                      icon: Icons.verified_user,
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF18A3B6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF18A3B6).withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF18A3B6),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Default password: Medical center name@12345678\nMedical center can change it later.",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _addMedicalCenter,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF18A3B6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text(
                                "Add Medical Center",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab 2: List of Medical Centers
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medical_centers')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  if (snapshot.error.toString().contains('PERMISSION_DENIED')) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 60,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Permission Denied",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                "Please check your Firestore Security Rules to access medical centers data.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error,
                            color: Colors.orange,
                            size: 60,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Error: ${snapshot.error}",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "No Medical Centers",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Add your first medical center using the 'Add New Center' tab",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final centers = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: centers.length,
                  itemBuilder: (context, index) {
                    final center = centers[index].data() as Map<String, dynamic>;
                    final centerId = centers[index].id;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF18A3B6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: Color(0xFF18A3B6),
                          ),
                        ),
                        title: Text(
                          center['name'] ?? 'No Name',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              center['email'] ?? 'No Email',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (center['regNumber'] != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.numbers,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    center['regNumber']!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            if (center['specialization'] != null)
                              const SizedBox(height: 4),
                            if (center['specialization'] != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.medical_services,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    center['specialization']!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          onPressed: () => _deleteMedicalCenter(
                            centerId,
                            center['name'] ?? 'Medical Center',
                          ),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: "Delete Medical Center",
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              const Text(
                " *",
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF18A3B6)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return "This field is required";
                  }
                  if (label.toLowerCase().contains('email') &&
                      !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                    return "Please enter a valid email address";
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}