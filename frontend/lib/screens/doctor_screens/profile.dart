import 'dart:io';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:image_picker/image_picker.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  // Controllers
  final _nameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _licenseController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _bioController = TextEditingController();

  String? _imageUrl;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    _hospitalController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Load existing profile
  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final docRef = FirebaseFirestore.instance.collection('doctors').doc(uid);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _emailController.text = data['email'] ?? _auth.currentUser?.email ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _licenseController.text = data['licenseNumber'] ?? '';
          _hospitalController.text = data['hospital'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _imageUrl = data['profileImageUrl'];
        });
      } else {
        // Pre-fill email from FirebaseAuth
        _emailController.text = _auth.currentUser?.email ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  // Pick + Upload Image
  Future<void> _pickAndUploadImage() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        final storageRef =
            FirebaseStorage.instance.ref().child('doctor_profiles/$uid.jpg');
        final uploadTask = storageRef.putFile(_imageFile!);

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          _imageUrl = downloadUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture uploaded!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  // Save profile to Firestore
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;

        await FirebaseFirestore.instance.collection('doctors').doc(uid).set({
          'uid': uid,
          'name': _nameController.text,
          'specialization': _specializationController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
          'licenseNumber': _licenseController.text,
          'hospital': _hospitalController.text,
          'bio': _bioController.text,
          'profileImageUrl': _imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save profile: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text(
          "Doctor Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _imageUrl != null
                        ? NetworkImage(_imageUrl!)
                        : const AssetImage("assets/images/doctor.png")
                            as ImageProvider,
                    child: _imageUrl == null
                        ? const Icon(Icons.person,
                            size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF18A3B6),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: _pickAndUploadImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildSectionTitle("Personal Details"),
                  _buildTextField("Full Name", _nameController),
                  _buildTextField("Address", _addressController),
                  _buildTextField("Mobile Number", _phoneController,
                      keyboardType: TextInputType.phone),
                  _buildTextField("Email", _emailController,
                      keyboardType: TextInputType.emailAddress),

                  const SizedBox(height: 20),
                  _buildSectionTitle("Professional Details"),
                  _buildTextField("Specialization", _specializationController),
                  _buildTextField("License Number", _licenseController),
                  _buildTextField("Work Hospital / Clinic", _hospitalController),
                  _buildTextField("Bio", _bioController, maxLines: 5),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18A3B6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _saveProfile,
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType? keyboardType, int? maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) =>
            value == null || value.isEmpty ? "Please enter $label" : null,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18A3B6),
          ),
        ),
      ),
    );
  }
}
