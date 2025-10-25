import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PatientProfileScreen extends StatefulWidget {
  final String uid;
  const PatientProfileScreen({super.key, required this.uid});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  final nameCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final bloodCtrl = TextEditingController();
  final allergyCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();

  String lifestyle = "Non-smoker";
  String? profilePicUrl;
  File? pickedImage;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    var snap = await FirebaseFirestore.instance
        .collection("patients")
        .doc(widget.uid)
        .get();

    if (snap.exists) {
      var data = snap.data()!;
      setState(() {
        nameCtrl.text = data["name"] ?? "";
        dobCtrl.text = data["dob"] ?? "";
        ageCtrl.text = data["age"]?.toString() ?? "";
        emailCtrl.text = data["email"] ?? "";
        addressCtrl.text = data["address"] ?? "";
        bloodCtrl.text = data["bloodGroup"] ?? "";
        allergyCtrl.text = data["allergies"] ?? "";
        heightCtrl.text = data["height"]?.toString() ?? "";
        weightCtrl.text = data["weight"]?.toString() ?? "";
        lifestyle = data["lifestyle"] ?? "Non-smoker";
        profilePicUrl = data["profilePic"];
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage(File file) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child("profilePics/${widget.uid}.jpg");
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _saveData() async {
    String? uploadedUrl = profilePicUrl;
    if (pickedImage != null) {
      uploadedUrl = await _uploadImage(pickedImage!);
    }

    // calculate BMI
    double h = double.tryParse(heightCtrl.text) ?? 0;
    double w = double.tryParse(weightCtrl.text) ?? 0;
    double bmi = (h > 0) ? (w / ((h / 100) * (h / 100))) : 0;

    await FirebaseFirestore.instance
        .collection("patients")
        .doc(widget.uid)
        .set({
      "name": nameCtrl.text,
      "dob": dobCtrl.text,
      "age": int.tryParse(ageCtrl.text) ?? 0,
      "email": emailCtrl.text,
      "address": addressCtrl.text,
      "bloodGroup": bloodCtrl.text,
      "allergies": allergyCtrl.text,
      "height": h,
      "weight": w,
      "bmi": bmi,
      "lifestyle": lifestyle,
      "profilePic": uploadedUrl,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Profile Updated!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Patient Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile picture with upload
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: pickedImage != null
                      ? FileImage(pickedImage!)
                      : (profilePicUrl != null
                          ? NetworkImage(profilePicUrl!)
                          : const AssetImage("assets/images/default.png"))
                          as ImageProvider,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Name displayed under profile picture
              Text(
                nameCtrl.text.isEmpty ? "Your Name" : nameCtrl.text,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              // Personal Details
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
              TextFormField(controller: dobCtrl, decoration: const InputDecoration(labelText: "Date of Birth")),
              TextFormField(controller: ageCtrl, decoration: const InputDecoration(labelText: "Age")),
              TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
              TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: "Address")),

              const SizedBox(height: 20),

              // Medical Info
              TextFormField(controller: bloodCtrl, decoration: const InputDecoration(labelText: "Blood Group")),
              TextFormField(controller: allergyCtrl, decoration: const InputDecoration(labelText: "Allergies")),

              const SizedBox(height: 20),

              // Health & Lifestyle
              TextFormField(controller: heightCtrl, decoration: const InputDecoration(labelText: "Height (cm)")),
              TextFormField(controller: weightCtrl, decoration: const InputDecoration(labelText: "Weight (kg)")),

              DropdownButtonFormField(
                value: lifestyle,
                decoration: const InputDecoration(labelText: "Lifestyle"),
                items: ["Non-smoker", "Smoker", "Alcohol", "Both"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => lifestyle = val!),
              ),

              const SizedBox(height: 20),

              // QR Code
              QrImageView(
                data: widget.uid,
                size: 120,
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveData,
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
