import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PharmacyManagementScreen extends StatefulWidget {
  const PharmacyManagementScreen({super.key});

  @override
  State<PharmacyManagementScreen> createState() => _PharmacyManagementScreenState();
}

class _PharmacyManagementScreenState extends State<PharmacyManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();

  bool isLoading = false;

  Future<void> _addPharmacy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = "12345678"; // default password

      // 1️⃣ Create Firebase Auth account
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = cred.user!.uid;

      // 2️⃣ Create Firestore document in pharmacies collection
      await FirebaseFirestore.instance.collection('pharmacies').doc(uid).set({
        "uid": uid,
        "name": _nameController.text.trim(),
        "email": email,
        "address": _addressController.text.trim(),
        "phone": _phoneController.text.trim(),
        "licenseNumber": _licenseController.text.trim(),
        "ownerName": _ownerController.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "role": "pharmacy",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Pharmacy added successfully!\nEmail: $email\nPassword: $password"),
          duration: const Duration(seconds: 5),
        ),
      );

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _addressController.clear();
      _phoneController.clear();
      _licenseController.clear();
      _ownerController.clear();

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Error adding pharmacy";
      if (e.code == 'email-already-in-use') {
        errorMessage = "This email is already registered";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email address";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deletePharmacy(String pharmacyId, String pharmacyName) async {
    try {
      await FirebaseFirestore.instance.collection('pharmacies').doc(pharmacyId).delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$pharmacyName deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting pharmacy: $e")),
      );
    }
  }

  void _showDeleteConfirmation(String pharmacyId, String pharmacyName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Pharmacy"),
        content: Text("Are you sure you want to delete $pharmacyName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePharmacy(pharmacyId, pharmacyName);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyCard(DocumentSnapshot pharmacy) {
    final pharmacyData = pharmacy.data() as Map<String, dynamic>;
    final name = pharmacyData['name'] ?? 'No Name';
    final email = pharmacyData['email'] ?? 'No Email';
    final owner = pharmacyData['ownerName'] ?? 'N/A';
    final phone = pharmacyData['phone'] ?? 'N/A';
    final license = pharmacyData['licenseNumber'] ?? 'N/A';
    final address = pharmacyData['address'] ?? 'N/A';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF18A3B6),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "P",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "License: $license",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(pharmacy.id, name),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildInfoRow("Owner", owner, Icons.person),
            _buildInfoRow("Email", email, Icons.email),
            _buildInfoRow("Phone", phone, Icons.phone),
            _buildInfoRow("Address", address, Icons.location_on),
            _buildInfoRow("License No", license, Icons.badge),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Add Pharmacy Form
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add New Pharmacy",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Pharmacy Name *",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.local_pharmacy),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? "Please enter pharmacy name" : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _licenseController,
                            decoration: const InputDecoration(
                              labelText: "License Number *",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? "Please enter license number" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email Address *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter email";
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return "Please enter a valid email address";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ownerController,
                            decoration: const InputDecoration(
                              labelText: "Owner Name *",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? "Please enter owner name" : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: "Phone Number *",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value!.isEmpty ? "Please enter phone number" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: "Address *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                      validator: (value) =>
                          value!.isEmpty ? "Please enter address" : null,
                    ),
                    const SizedBox(height: 16),
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addPharmacy,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF18A3B6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                "Add Pharmacy",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          const Divider(thickness: 2),
          const SizedBox(height: 10),
          
          // Pharmacy List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.list, color: Color(0xFF18A3B6)),
                const SizedBox(width: 8),
                const Text(
                  "All Pharmacies",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
                ),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('pharmacies').snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Text(
                      "Total: $count",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          // Pharmacy List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pharmacies')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error loading pharmacies: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_pharmacy, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "No Pharmacies Found",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Add a pharmacy using the form above",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final pharmacies = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: pharmacies.length,
                  itemBuilder: (context, index) {
                    return _buildPharmacyCard(pharmacies[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _ownerController.dispose();
    super.dispose();
  }
}