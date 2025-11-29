import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _feesController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String? _profileImageUrl;
  File? _pickedImage;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    if (user == null) return;
    
    try {
      var doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user!.uid)
          .get();
          
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          _fullnameController.text = data['fullname'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _qualificationController.text = data['qualification'] ?? '';
          _experienceController.text = (data['experience'] ?? 0).toString();
          _hospitalController.text = data['hospital'] ?? '';
          _feesController.text = (data['fees'] ?? 0).toString();
          _licenseController.text = data['license'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _dobController.text = data['dob'] ?? '';
          _profileImageUrl = data['profileImage'];
        });
        
        print('✅ Loaded doctor data');
      } else {
        print('❌ No doctor document found');
        await _createInitialDoctorDocument();
      }
    } catch (e) {
      print('❌ Error loading doctor data: $e');
      _showErrorSnackBar('Error loading profile: $e');
    }
  }

  Future<void> _createInitialDoctorDocument() async {
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user!.uid)
          .set({
            'uid': user!.uid,
            'fullname': user!.displayName ?? '',
            'email': user!.email ?? '',
            'role': 'doctor',
            'specialization': '',
            'qualification': '',
            'experience': 0,
            'hospital': '',
            'fees': 0,
            'license': '',
            'phone': '',
            'dob': '',
            'profileImage': '',
            'createdAt': FieldValue.serverTimestamp(),
            'isEmailVerified': user!.emailVerified,
          }, SetOptions(merge: true));
          
      print('✅ Created initial doctor document');
    } catch (e) {
      print('❌ Error creating initial doctor document: $e');
    }
  }

  //  Image Picker Method
  Future<void> _pickImage() async {
    try {
      // For mobile - use image_picker
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
      final fileName = 'profile_$timestamp.$fileExtension';
      
      
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('doctor_profile_images')
          .child(user!.uid)
          .child(fileName);
      
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getMimeType(fileExtension),
        customMetadata: {
          'uploadedBy': user!.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('📤 Uploading image to: doctor_profile_images/${user!.uid}/$fileName');
      
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await storageRef.getDownloadURL();
        
        print('✅ Image uploaded successfully! URL: $downloadUrl');
        
        setState(() {
          _profileImageUrl = downloadUrl;
          _pickedImage = imageFile;
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
      final newFileName = 'profile_$timestamp.$fileExtension';
      
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('doctor_profile_images')
          .child(user!.uid)
          .child(newFileName);
      
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getMimeType(fileExtension),
        customMetadata: {
          'uploadedBy': user!.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('📤 Uploading web image to: doctor_profile_images/${user!.uid}/$newFileName');
      
      final UploadTask uploadTask = storageRef.putData(bytes, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await storageRef.getDownloadURL();
        
        print('✅ Web image uploaded successfully! URL: $downloadUrl');
        
        setState(() {
          _profileImageUrl = downloadUrl;
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
          .collection('doctors')
          .doc(user!.uid)
          .update({
            'profileImage': imageUrl,
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

  Future<void> _saveProfile() async {
  if (!_formKey.currentState!.validate()) {
    _showErrorSnackBar('Please fill all required fields');
    return;
  }

  if (user == null) {
    _showErrorSnackBar('User not logged in');
    return;
  }

  if (_isSaving) return;

  setState(() => _isSaving = true);

  try {
    _showLoadingSnackBar('Saving profile...');

    final updateData = {
      'fullname': _fullnameController.text.trim(),
      'specialization': _specializationController.text.trim(),
      'qualification': _qualificationController.text.trim(),
      'experience': int.tryParse(_experienceController.text) ?? 0,
      'hospital': _hospitalController.text.trim(),
      'fees': double.tryParse(_feesController.text) ?? 0.0,
      'license': _licenseController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'dob': _dobController.text.trim(),
      'profileImage': _profileImageUrl ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'isProfileComplete': _isProfileComplete(),
    };

    await FirebaseFirestore.instance
        .collection('doctors')
        .doc(user!.uid)
        .set(updateData, SetOptions(merge: true));

    // Hide loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Show success message
    _showSuccessSnackBar('Profile updated successfully!');

    // Wait a bit for user to see the success message
    await Future.delayed(const Duration(milliseconds: 1500));

    // FIX: Simply navigate back - the previous screen should handle data refresh
    if (mounted) {
      Navigator.pop(context);
    }

  } catch (e) {
    print('❌ Error saving profile: $e');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _showErrorSnackBar('Error saving profile: $e');
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

  bool _isProfileComplete() {
    return _fullnameController.text.isNotEmpty &&
        _specializationController.text.isNotEmpty &&
        _qualificationController.text.isNotEmpty &&
        _hospitalController.text.isNotEmpty &&
        _licenseController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty;
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

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Doctor Profile'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
            tooltip: 'Save Profile',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image Section
              _buildProfileImageSection(),
              
              const SizedBox(height: 24),
              
              // Form Fields
              _buildTextField(_fullnameController, 'Full Name', Icons.person, isRequired: true),
              _buildTextField(_specializationController, 'Specialization', Icons.medical_services, isRequired: true),
              _buildTextField(_qualificationController, 'Qualification', Icons.school, isRequired: true),
              _buildTextField(_experienceController, 'Experience (Years)', Icons.work, isNumber: true),
              _buildTextField(_hospitalController, 'Hospital/Clinic', Icons.local_hospital, isRequired: true),
              _buildTextField(_feesController, 'Consultation Fees (LKR)', Icons.attach_money, isNumber: true),
              _buildTextField(_licenseController, 'Medical License Number', Icons.badge, isRequired: true),
              _buildTextField(_emailController, 'Email', Icons.email, isRequired: true),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone, isRequired: true),
              _buildTextField(_dobController, 'Date of Birth (YYYY-MM-DD)', Icons.cake),
              
              const SizedBox(height: 30),
              
              // Save Button
              _buildSaveButton(),
              
              const SizedBox(height: 20),
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
          _isUploadingImage ? 'Uploading...' : 'Tap to change photo',
          style: TextStyle(
            color: _isUploadingImage ? Colors.orange : Colors.grey[600], 
            fontSize: 12
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF18A3B6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
            : const Text(
                'Save Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  ImageProvider? _buildProfileImageProvider() {
    if (_pickedImage != null) {
      return FileImage(_pickedImage!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    } else {
      return  null;
    }
  }

  Widget? _buildProfileImagePlaceholder() {
    if (_pickedImage != null || (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)) {
      return null;
    } else {
      return const Icon(Icons.person, size: 50, color: Colors.grey);
    }
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    bool isRequired = false,
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          prefixIcon: Icon(icon, color: const Color(0xFF18A3B6)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF18A3B6), width: 2),
          ),
        ),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        } : null,
      ),
    );
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _specializationController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _hospitalController.dispose();
    _feesController.dispose();
    _licenseController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}