import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AssistantManagementPage extends StatefulWidget {
  const AssistantManagementPage({super.key});

  @override
  State<AssistantManagementPage> createState() => _AssistantManagementPageState();
}

class _AssistantManagementPageState extends State<AssistantManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _bgColor = const Color(0xFFDDF0F5);
  
  List<Assistant> _assistants = [];
  bool _isLoading = true;
  bool _showAddForm = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  String _currentMedicalCenterId = '';
  String _currentMedicalCenterName = '';

  @override
  void initState() {
    super.initState();
    _loadMedicalCenterData();
  }

  Future<void> _loadMedicalCenterData() async {
  try {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get medical center data - FIXED: We need to get the medical center where uid matches current user
    final centerDoc = await _firestore
        .collection('medical_centers')
        .where('uid', isEqualTo: user.uid)
        .get();

    if (centerDoc.docs.isNotEmpty) {
      final centerData = centerDoc.docs.first.data();
      setState(() {
        _currentMedicalCenterId = centerDoc.docs.first.id; // This is the document ID
        _currentMedicalCenterName = centerData['name']?.toString() ?? 'Medical Center';
      });
      
      // Load assistants
      await _loadAssistants();
    } else {
      // Alternative: Check if user is a medical center admin directly
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        if (userData['role'] == 'medical_center') {
          // Get medical center by email instead
          final centerDocByEmail = await _firestore
              .collection('medical_centers')
              .where('email', isEqualTo: user.email)
              .get();
              
          if (centerDocByEmail.docs.isNotEmpty) {
            final centerData = centerDocByEmail.docs.first.data();
            setState(() {
              _currentMedicalCenterId = centerDocByEmail.docs.first.id;
              _currentMedicalCenterName = centerData['name']?.toString() ?? 'Medical Center';
            });
            
            await _loadAssistants();
          }
        }
      }
    }
  } catch (e) {
    print('Error loading medical center data: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}

 Future<void> _loadAssistants() async {
  try {
    print('Loading assistants for medical center ID: $_currentMedicalCenterId');
    
    final assistantsSnapshot = await _firestore
        .collection('assistants')
        .where('medicalCenterId', isEqualTo: _currentMedicalCenterId)
        .orderBy('createdAt', descending: true)
        .get();

    print('Found ${assistantsSnapshot.docs.length} assistants');
    
    _assistants = assistantsSnapshot.docs.map((doc) {
      final data = doc.data();
      print('Assistant: ${data['name']}, Email: ${data['email']}');
      return Assistant(
        id: doc.id,
        name: data['name']?.toString() ?? 'Unknown',
        email: data['email']?.toString() ?? '',
        medicalCenterId: data['medicalCenterId']?.toString() ?? '',
        medicalCenterName: data['medicalCenterName']?.toString() ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        isActive: data['isActive'] ?? true,
      );
    }).toList();
    
    setState(() {});
  } catch (e) {
    print('Error loading assistants: $e');
  }
}
Future<void> _addAssistant() async {
  if (_nameController.text.isEmpty || 
      _emailController.text.isEmpty || 
      _passwordController.text.isEmpty) {
    _showErrorDialog('All fields are required');
    return;
  }

  if (_passwordController.text.length < 6) {
    _showErrorDialog('Password must be at least 6 characters long');
    return;
  }

  if (_passwordController.text != _confirmPasswordController.text) {
    _showErrorDialog('Passwords do not match');
    return;
  }

  setState(() => _isLoading = true);

  try {
    print('Creating assistant with email: ${_emailController.text}');
    print('Medical Center ID: $_currentMedicalCenterId');
    print('Medical Center Name: $_currentMedicalCenterName');

    // 1. Create user in Firebase Auth
    final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final String assistantId = userCredential.user!.uid;
    print('Assistant created with UID: $assistantId');

    // 2. Create assistant document
    await _firestore.collection('assistants').doc(assistantId).set({
      'id': assistantId,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'medicalCenterId': _currentMedicalCenterId,
      'medicalCenterName': _currentMedicalCenterName,
      'role': 'assistant',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'isActive': true,
    });

    print('Assistant document created in Firestore');

    // 3. Create user document for authentication
    await _firestore.collection('users').doc(assistantId).set({
      'uid': assistantId,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'role': 'assistant',
      'medicalCenterId': _currentMedicalCenterId,
      'medicalCenterName': _currentMedicalCenterName,
      'isEmailVerified': true,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    print('User document created in Firestore');

    // 4. Clear form and reload
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    
    setState(() {
      _showAddForm = false;
    });
    
    await _loadAssistants();
    
    _showSuccessDialog('Assistant added successfully!');
    
  } on FirebaseAuthException catch (e) {
    String errorMessage = 'Error creating assistant';
    if (e.code == 'email-already-in-use') {
      errorMessage = 'This email is already registered';
    } else if (e.code == 'invalid-email') {
      errorMessage = 'Invalid email address';
    } else if (e.code == 'weak-password') {
      errorMessage = 'Password is too weak';
    }
    _showErrorDialog(errorMessage);
  } catch (e) {
    _showErrorDialog('Error: $e');
    print('Full error: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
  Future<void> _toggleAssistantStatus(String assistantId, bool currentStatus) async {
    try {
      await _firestore.collection('assistants').doc(assistantId).update({
        'isActive': !currentStatus,
        'updatedAt': Timestamp.now(),
      });
      
      await _loadAssistants();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentStatus ? 'Assistant deactivated' : 'Assistant activated'),
          backgroundColor: currentStatus ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog('Error updating assistant status: $e');
    }
  }

  Future<void> _deleteAssistant(String assistantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this assistant? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // 1. Delete assistant document
      await _firestore.collection('assistants').doc(assistantId).delete();
      
      // 2. Delete user document
      await _firestore.collection('users').doc(assistantId).delete();
      
      // 3. Delete Firebase Auth user (admin should have permission)
      try {
        final user = await _auth.currentUser;
        if (user != null && user.uid != assistantId) {
          // Note: Deleting other users requires admin privileges
          // For now, just mark as inactive or use Cloud Functions
          await _firestore.collection('users').doc(assistantId).update({
            'isActive': false,
            'deletedAt': Timestamp.now(),
          });
        }
      } catch (e) {
        print('Error deleting auth user: $e');
      }
      
      await _loadAssistants();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assistant deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog('Error deleting assistant: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar:  AppBar(
  backgroundColor: Colors.white,
  elevation: 0,
  leading: IconButton(
    icon: Icon(Icons.arrow_back, color: _primaryColor),
    onPressed: () => Navigator.pop(context),
  ),
  title: Text(
    'Assistant Management',
    style: TextStyle(
      color: _primaryColor,
      fontWeight: FontWeight.bold,
    ),
  ),
  actions: [
    if (!_showAddForm) ...[
      IconButton(
        icon: Icon(Icons.refresh, color: _primaryColor),
        onPressed: () async {
          setState(() => _isLoading = true);
          await _loadMedicalCenterData();
        },
      ),
      IconButton(
        icon: Icon(Icons.add, color: _primaryColor),
        onPressed: () {
          setState(() => _showAddForm = true);
        },
      ),
    ],
  ],
),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: _primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showAddForm) ...[
                    _buildAddAssistantForm(),
                    const SizedBox(height: 20),
                  ],
                  
                  // Assistant List
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, color: _primaryColor, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'Assistants List',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _lightColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_assistants.length} assistants',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          if (_assistants.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    color: Colors.grey[400],
                                    size: 60,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Assistants Found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add assistants to help manage your medical center',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._assistants.map((assistant) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _lightColor),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: assistant.isActive ? _primaryColor : Colors.grey,
                                    child: Text(
                                      assistant.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    assistant.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: assistant.isActive ? Colors.black : Colors.grey,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        assistant.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (assistant.createdAt != null)
                                        Text(
                                          'Added: ${DateFormat('dd MMM yyyy').format(assistant.createdAt!)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: assistant.isActive 
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          assistant.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: assistant.isActive ? Colors.green : Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: _primaryColor),
                                    onSelected: (value) {
                                      if (value == 'toggle') {
                                        _toggleAssistantStatus(assistant.id, assistant.isActive);
                                      } else if (value == 'delete') {
                                        _deleteAssistant(assistant.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(
                                              assistant.isActive ? Icons.person_off : Icons.person,
                                              color: _primaryColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(assistant.isActive ? 'Deactivate' : 'Activate'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red, size: 20),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAddAssistantForm() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_add, color: _primaryColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Add New Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _showAddForm = false);
                    _nameController.clear();
                    _emailController.clear();
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Assistant Name',
                prefixIcon: Icon(Icons.person, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
                helperText: 'Minimum 6 characters',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _showAddForm = false);
                      _nameController.clear();
                      _emailController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: _primaryColor),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: _primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addAssistant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Add Assistant',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Assistant {
  final String id;
  final String name;
  final String email;
  final String medicalCenterId;
  final String medicalCenterName;
  final DateTime? createdAt;
  final bool isActive;

  Assistant({
    required this.id,
    required this.name,
    required this.email,
    required this.medicalCenterId,
    required this.medicalCenterName,
    this.createdAt,
    required this.isActive,
  });
}