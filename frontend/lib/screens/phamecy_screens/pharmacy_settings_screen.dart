import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';

class PharmacySettingsScreen extends StatefulWidget {
  final String uid;
  const PharmacySettingsScreen({super.key, required this.uid});

  @override
  State<PharmacySettingsScreen> createState() => _PharmacySettingsScreenState();
}

class _PharmacySettingsScreenState extends State<PharmacySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final nameCtrl = TextEditingController();
  final licenseCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final ownerNameCtrl = TextEditingController();
  
  // Change Password Controllers
  final currentPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  bool _showChangePasswordSection = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadPharmacyData();
  }

  Future<void> _loadPharmacyData() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection("pharmacies")
          .doc(widget.uid)
          .get();

      if (snap.exists && mounted) {
        var data = snap.data()!;
        setState(() {
          nameCtrl.text = data["name"] ?? "";
          licenseCtrl.text = data["licenseNumber"] ?? "";
          emailCtrl.text = data["email"] ?? "";
          phoneCtrl.text = data["phone"] ?? "";
          addressCtrl.text = data["address"] ?? "";
          ownerNameCtrl.text = data["ownerName"] ?? "";
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Pharmacy profile not found');
      }
    } catch (e) {
      print('❌ Error loading pharmacy data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load profile data');
      }
    }
  }

  Future<void> _saveData() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields correctly');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updateData = {
        "name": nameCtrl.text.trim(),
        "licenseNumber": licenseCtrl.text.trim().toUpperCase(),
        "email": emailCtrl.text.trim(),
        "phone": phoneCtrl.text.trim(),
        "address": addressCtrl.text.trim(),
        "ownerName": ownerNameCtrl.text.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      };

      // Verify the document exists before updating
      final docRef = FirebaseFirestore.instance
          .collection("pharmacies")
          .doc(widget.uid);
      
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        _showErrorSnackBar('Pharmacy profile not found');
        return;
      }

      await docRef.set(updateData, SetOptions(merge: true));
      _showSuccessSnackBar("Profile Updated Successfully!");
      
      await _loadPharmacyData();

    } on FirebaseException catch (e) {
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_isChangingPassword) return;

    // Validation
    if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }

    if (newPasswordCtrl.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters long');
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Reauthenticate user with actual authenticated email
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '', // Use authenticated user's email
          password: currentPasswordCtrl.text,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        // Change password
        await user.updatePassword(newPasswordCtrl.text);
        
        _showSuccessSnackBar('Password changed successfully!');
        
        // Clear password fields and hide section
        setState(() {
          currentPasswordCtrl.clear();
          newPasswordCtrl.clear();
          confirmPasswordCtrl.clear();
          _showChangePasswordSection = false;
        });
      } else {
        _showErrorSnackBar('User not found. Please sign in again.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to change password';
      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        errorMessage = 'New password is too weak';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please sign in again to change password';
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('Error changing password: $e');
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
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

  // Get first letter of pharmacy name for avatar
  String get _getFirstLetter {
    if (nameCtrl.text.isEmpty) return 'P';
    return nameCtrl.text[0].toUpperCase();
  }

  // Get avatar color based on first letter
  Color get _avatarColor {
    final colors = [
      const Color(0xFF18A3B6), // Teal
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.indigo.shade600,
    ];
    final index = _getFirstLetter.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pharmacy Settings"),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveData,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: _isLoading
    ? const Center(child: CircularProgressIndicator())
    : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Pharmacy Avatar with first letter
              _buildPharmacyAvatar(),
              
              const SizedBox(height: 10),

              // Pharmacy Name
              Text(
                nameCtrl.text.isEmpty ? "Pharmacy Name" : nameCtrl.text,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              
              Text(
                licenseCtrl.text.isEmpty ? "License Number" : "License: ${licenseCtrl.text}",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 20),

              // Change Password Section
              _buildChangePasswordSection(),

              const SizedBox(height: 20),

              // Pharmacy Details Form
              _buildFormFields(),

              const SizedBox(height: 30),
              
              // Save Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
    
  }


  Widget _buildPharmacyAvatar() {
    return CircleAvatar(
      radius: 60,
      backgroundColor: _avatarColor,
      child: Text(
        _getFirstLetter,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildChangePasswordSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Change Password",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18A3B6),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showChangePasswordSection ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF18A3B6),
                  ),
                  onPressed: () {
                    setState(() {
                      _showChangePasswordSection = !_showChangePasswordSection;
                      // Clear fields when collapsing
                      if (!_showChangePasswordSection) {
                        currentPasswordCtrl.clear();
                        newPasswordCtrl.clear();
                        confirmPasswordCtrl.clear();
                      }
                    });
                  },
                ),
              ],
            ),
            
            if (_showChangePasswordSection) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Current Password *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (_showChangePasswordSection && (value == null || value.isEmpty)) {
                    return 'Please enter current password';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (_showChangePasswordSection && (value == null || value.isEmpty)) {
                    return 'Please enter new password';
                  }
                  if (_showChangePasswordSection && value != null && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (value) {
                  if (_showChangePasswordSection && (value == null || value.isEmpty)) {
                    return 'Please confirm new password';
                  }
                  if (_showChangePasswordSection && value != newPasswordCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChangingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isChangingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text("Change Password"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Pharmacy Information
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Pharmacy Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: "Pharmacy Name *",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_pharmacy),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter pharmacy name';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: licenseCtrl,
          decoration: const InputDecoration(
            labelText: "License Number *",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge),
          ),
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter license number';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: ownerNameCtrl,
          decoration: const InputDecoration(
            labelText: "Owner Name",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        // Contact Information
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Contact Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: emailCtrl,
          decoration: const InputDecoration(
            labelText: "Email Address *",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter email address';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: phoneCtrl,
          decoration: const InputDecoration(
            labelText: "Phone Number",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: addressCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "Pharmacy Address",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
            alignLabelWithHint: true,
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveData,
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
                "Save Changes",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    licenseCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    ownerNameCtrl.dispose();
    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }
}