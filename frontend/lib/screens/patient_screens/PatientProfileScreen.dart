import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';

class PatientProfileScreen extends StatefulWidget {
  final String uid;
  const PatientProfileScreen({super.key, required this.uid});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

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
  bool _isUploadingImage = false;
  bool _isSaving = false;

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
        nameCtrl.text = data["fullname"] ?? "";
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
    try {
      // For mobile
      if (Platform.isAndroid || Platform.isIOS) {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        
        if (pickedFile != null) {
          final imageFile = File(pickedFile.path);
          await _uploadImageMobile(imageFile);
        }
      } 
      // For web/desktop
      else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          PlatformFile file = result.files.first;
          
          if (file.bytes != null) {
            await _uploadImageWeb(file.bytes!, file.name);
          } else if (file.path != null) {
            final imageFile = File(file.path!);
            await _uploadImageMobile(imageFile);
          }
        }
      }
    } catch (e) {
      print('❌ Image picker error: $e');
      _showErrorSnackBar('Error selecting image: ${e.toString()}');
    }
  }

  Future<void> _uploadImageMobile(File imageFile) async {
    try {
      setState(() => _isUploadingImage = true);
      
      // Check file size
      final fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        _showErrorSnackBar('Image size too large. Please select image less than 10MB.');
        setState(() => _isUploadingImage = false);
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'patient_profile_$timestamp.$fileExtension';
      
      // Upload to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('patient_profile_images')
          .child(widget.uid)
          .child(fileName);
      
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getMimeType(fileExtension),
        customMetadata: {
          'uploadedBy': widget.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'patient_profile',
        },
      );
      
      print('📤 Uploading patient image to: patient_profile_images/${widget.uid}/$fileName');
      
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await storageRef.getDownloadURL();
        
        print('✅ Patient image uploaded successfully! URL: $downloadUrl');
        
        setState(() {
          profilePicUrl = downloadUrl;
          pickedImage = imageFile;
          _isUploadingImage = false;
        });
        
        _showSuccessSnackBar('Profile image updated successfully!');
        
        // Auto-save the profile image URL to Firestore
        await _saveProfileImageToFirestore(downloadUrl);
      }
    } catch (e) {
      print('❌ Mobile upload error: $e');
      setState(() => _isUploadingImage = false);
      _showErrorSnackBar('Upload failed: ${e.toString()}');
    }
  }

  Future<void> _uploadImageWeb(Uint8List bytes, String fileName) async {
    try {
      setState(() => _isUploadingImage = true);
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last.toLowerCase();
      final newFileName = 'patient_profile_$timestamp.$fileExtension';
      
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('patient_profile_images')
          .child(widget.uid)
          .child(newFileName);
      
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getMimeType(fileExtension),
        customMetadata: {
          'uploadedBy': widget.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'patient_profile',
        },
      );
      
      final UploadTask uploadTask = storageRef.putData(bytes, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await storageRef.getDownloadURL();
        
        setState(() {
          profilePicUrl = downloadUrl;
          _isUploadingImage = false;
        });
        
        _showSuccessSnackBar('Profile image updated successfully!');
        await _saveProfileImageToFirestore(downloadUrl);
      }
    } catch (e) {
      print('❌ Web upload error: $e');
      setState(() => _isUploadingImage = false);
      _showErrorSnackBar('Upload failed: ${e.toString()}');
    }
  }

  Future<void> _saveProfileImageToFirestore(String imageUrl) async {
    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.uid)
          .update({
            'profilePic': imageUrl,
            'profileImageUpdatedAt': FieldValue.serverTimestamp(),
          });
      print('✅ Profile image URL saved to Firestore');
    } catch (e) {
      print('❌ Error saving image URL to Firestore: $e');
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _saveData() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      String? uploadedUrl = profilePicUrl;
      
      // Upload custom image if selected
      if (pickedImage != null) {
        uploadedUrl = await _uploadImage(pickedImage!);
      }

      // calculate BMI
      double h = double.tryParse(heightCtrl.text) ?? 0;
      double w = double.tryParse(weightCtrl.text) ?? 0;
      double bmi = (h > 0) ? (w / ((h / 100) * (h / 100))) : 0;

      final updateData = {
        "fullname": nameCtrl.text,
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
        "updatedAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection("patients")
          .doc(widget.uid)
          .set(updateData, SetOptions(merge: true));

      _showSuccessSnackBar("Profile Updated!");
      
      // Reload data to ensure consistency
      await _loadPatientData();

    } catch (e) {
      print('❌ Error saving profile: $e');
      _showErrorSnackBar('Error saving profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Legacy upload method for backward compatibility
  Future<String> _uploadImage(File file) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child("profilePics/${widget.uid}.jpg");
    await ref.putFile(file);
    return await ref.getDownloadURL();
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Profile"),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile picture section only - avatar selection removed
              _buildProfileImageSection(),
              
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
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Patient QR Code',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      QrImageView(
                        data: widget.uid,
                        size: 120,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Scan for patient information',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18A3B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text("Save Profile"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _isUploadingImage ? null : _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _buildProfileImageProvider(),
                child: _buildProfileImagePlaceholder(),
              ),
            ),
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            if (!_isUploadingImage)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF18A3B6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isUploadingImage ? 'Uploading...' : 'Tap to upload profile photo',
          style: TextStyle(
            color: _isUploadingImage ? Colors.orange : Colors.grey[600], 
            fontSize: 12
          ),
        ),
      ],
    );
  }

  ImageProvider _buildProfileImageProvider() {
    if (pickedImage != null) {
      return FileImage(pickedImage!);
    } else if (profilePicUrl != null && profilePicUrl!.isNotEmpty) {
      return NetworkImage(profilePicUrl!);
    } else {
      return const AssetImage("assets/images/default.png");
    }
  }

  Widget? _buildProfileImagePlaceholder() {
    if (pickedImage != null || (profilePicUrl != null && profilePicUrl!.isNotEmpty)) {
      return null;
    } else {
      return const Icon(Icons.person, size: 50, color: Colors.grey);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    dobCtrl.dispose();
    ageCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    bloodCtrl.dispose();
    allergyCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    super.dispose();
  }
}