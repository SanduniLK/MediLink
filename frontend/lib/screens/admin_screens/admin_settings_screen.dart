// lib/screens/admin_screens/admin_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:intl/intl.dart';

class AdminSettingsScreen extends StatefulWidget {
  final String medicalCenterId;
  final String medicalCenterName;

  const AdminSettingsScreen({
    super.key,
    required this.medicalCenterId,
    required this.medicalCenterName,
  });

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _testFeesController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic> _adminData = {};

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    debugPrint('🔄 Loading medical center data...');

    // Only load from medical_centers collection
    final medicalCenterDoc = await _firestore
        .collection('medical_centers')
        .doc(widget.medicalCenterId)
        .get();

    if (medicalCenterDoc.exists) {
      setState(() {
        _adminData = medicalCenterDoc.data() ?? {};
        _populateFormFields();
        _isLoading = false;
      });
      debugPrint('✅ Loaded data from medical_centers collection');
    } else {
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Medical center document not found');
    }

  } catch (e) {
    debugPrint('❌ Error loading medical center data: $e');
    setState(() {
      _isLoading = false;
    });
  }
}

  void _populateFormFields() {
    _nameController.text = _adminData['name'] ?? '';
    _emailController.text = _adminData['email'] ?? '';
    _regNumberController.text = _adminData['regNumber'] ?? '';
    _licenseNumberController.text = _adminData['melicenseNumber'] ?? '';
    _specializationController.text = _adminData['specialization'] ?? '';
    _testFeesController.text = _adminData['testFees']?.toString() ?? '';
  }

 Future<void> _updateAdminProfile() async {
  if (!_formKey.currentState!.validate()) return;

  try {
    setState(() {
      _isLoading = true;
    });

    final updatedData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'regNumber': _regNumberController.text.trim(),
      'melicenseNumber': _licenseNumberController.text.trim(),
      'specialization': _specializationController.text.trim(),
      'testFees': double.tryParse(_testFeesController.text) ?? 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      debugPrint('💾 Updating medical center profile...');

      // Only update medical_centers collection
      await _firestore
          .collection('medical_centers')
          .doc(widget.medicalCenterId)
          .update(updatedData);
      
      debugPrint('✅ Profile updated successfully in medical_centers collection');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Update UI state
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }

      // Reload data to get updated timestamp
      await _loadAdminData();
    }
  } catch (e) {
    debugPrint('❌ Error updating admin profile: $e');
    
    // Show error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Not available';
      
      if (timestamp is Timestamp) {
        return DateFormat('dd MMMM yyyy HH:mm').format(timestamp.toDate());
      } else if (timestamp is int) {
        return DateFormat('dd MMMM yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
      } else {
        return timestamp.toString();
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              readOnly: readOnly,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              validator: validator,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile Settings'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit Profile',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _populateFormFields(); // Reset form to original values
                });
              },
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Profile Header
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF18A3B6),
                        radius: 40,
                        child: Text(
                          _adminData['name']?.toString().substring(0, 1).toUpperCase() ?? 'A',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _adminData['name'] ?? 'Medical Center',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _adminData['specialization'] ?? 'General Medical Center',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (!_isEditing) ...[
                // View Mode - Display Information
                _buildInfoCard('Medical Center Name', _adminData['name'] ?? 'Not set'),
                const SizedBox(height: 12),
                _buildInfoCard('Email', _adminData['email'] ?? 'Not set'),
                const SizedBox(height: 12),
                _buildInfoCard('Registration Number', _adminData['regNumber'] ?? 'Not set'),
                const SizedBox(height: 12),
                _buildInfoCard('License Number', _adminData['melicenseNumber'] ?? 'Not set'),
                const SizedBox(height: 12),
                _buildInfoCard('Specialization', _adminData['specialization'] ?? 'Not set'),
                const SizedBox(height: 12),
                _buildInfoCard(
                  'Test Fees', 
                  _adminData['testFees'] != null 
                    ? 'LKR ${_adminData['testFees']}' 
                    : 'Not set'
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  'Created At', 
                  _formatTimestamp(_adminData['createdAt'])
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  'Last Updated', 
                  _formatTimestamp(_adminData['updatedAt'] ?? _adminData['createdAt'])
                ),
              ] else ...[
                // Edit Mode - Form Fields
                _buildFormField(
                  label: 'Medical Center Name *',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter medical center name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'Email *',
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.emailAddress,
                  readOnly: true, // Make email read-only to avoid auth issues
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'Registration Number *',
                  controller: _regNumberController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter registration number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'License Number *',
                  controller: _licenseNumberController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter license number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'Specialization *',
                  controller: _specializationController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter specialization';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'Test Fees (LKR) *',
                  controller: _testFeesController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter test fees';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 24),

                // Update Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateAdminProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18A3B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Update Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 12),

                // Cancel Button
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isEditing = false;
                            _populateFormFields();
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Additional Settings Section
              if (!_isEditing) ...[
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Account Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.blue),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showChangePasswordDialog();
                  },
                ),
                
                
                const Divider(),
 
  ListTile(
    leading: const Icon(Icons.logout, color: Colors.red),
    title: const Text(
      'Sign Out',
      style: TextStyle(
        color: Colors.red,
        fontWeight: FontWeight.bold,
      ),
    ),
    subtitle: const Text('Sign out from your account'),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
    onTap: _signOut,
  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final user = _auth.currentUser;
                  final credential = EmailAuthProvider.credential(
                    email: user!.email!,
                    password: currentPasswordController.text,
                  );
                  
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update password: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        );
      },
    );
  }
  // Sign Out Method
Future<void> _signOut() async {
  try {
    // Show confirmation dialog
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await _auth.signOut();
      
      // Navigate to sign in page and remove all routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SignInPage(),
        ),
        (route) => false,
      );
    }
  } catch (e) {
    debugPrint('Error signing out: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error signing out: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _regNumberController.dispose();
    _licenseNumberController.dispose();
    _specializationController.dispose();
    _testFeesController.dispose();
    super.dispose();
  }
}