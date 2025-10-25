import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/Sadmin_screens/SinglePatientProfileScreen.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  State<PatientManagementScreen> createState() =>
      _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String _gender = 'Male';
  String _lifestyle = 'Non-smoker';

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _clearControllers() {
    _nameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _dobController.clear();
    _ageController.clear();
    _addressController.clear();
    _bloodGroupController.clear();
    _allergiesController.clear();
    _heightController.clear();
    _weightController.clear();
    _gender = 'Male';
    _lifestyle = 'Non-smoker';
  }

  Widget _buildTextField(TextEditingController controller, String label,
      [TextInputType keyboardType = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _addPatient() {
    _clearControllers();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Patient'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTextField(_nameController, 'Full Name'),
                    _buildTextField(_mobileController, 'Mobile Number',
                        TextInputType.phone),
                    _buildTextField(_emailController, 'Email',
                        TextInputType.emailAddress),
                    _buildTextField(_addressController, 'Address'),
                    _buildTextField(_dobController, 'Date of Birth'),
                    _buildTextField(_ageController, 'Age', TextInputType.number),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Add'),
                  onPressed: () async {
                    if (_nameController.text.isNotEmpty &&
                        _mobileController.text.isNotEmpty) {
                      DocumentReference newDocRef = await FirebaseFirestore
                          .instance
                          .collection('patients')
                          .add({
                        'name': _nameController.text.trim(),
                        'mobile': _mobileController.text.trim(),
                        'email': _emailController.text.trim(),
                        'dob': _dobController.text.trim(),
                        'age': int.tryParse(_ageController.text) ?? 0,
                        'address': _addressController.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      Navigator.of(context).pop();

                      // Go to profile page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SinglePatientProfileScreen(
                            patientUid: newDocRef.id,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deletePatient(String docId) {
    FirebaseFirestore.instance.collection('patients').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Patient Management")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('patients')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text("Error loading patients: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final patients = snapshot.data!.docs;

          if (patients.isEmpty) {
            return const Center(child: Text("No patients found."));
          }

          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final docId = patient.id;

              final name = patient.data().toString().contains('name')
                  ? patient['name']
                  : "No Name";
              final mobile = patient.data().toString().contains('mobile')
                  ? patient['mobile']
                  : "No Mobile";

              return Card(
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SinglePatientProfileScreen(
                          patientUid: docId,
                        ),
                      ),
                    );
                  },
                  title: Text(name),
                  subtitle: Text("Mobile: $mobile"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePatient(docId),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPatient,
        child: const Icon(Icons.add),
      ),
    );
  }
}
