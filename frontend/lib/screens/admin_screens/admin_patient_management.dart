import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  State<PatientManagementScreen> createState() =>
      _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  // Renamed controller for clarity and consistency with DB field
  final TextEditingController _mobileController = TextEditingController(); 

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose(); // Updated reference
    super.dispose();
  }

  // Add patient to Firestore
  void _addPatient() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Patient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Patient Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _mobileController, // Updated reference
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number', // Updated label
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _nameController.clear();
                _mobileController.clear(); // Updated reference
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () async {
                if (_nameController.text.isNotEmpty &&
                    _mobileController.text.isNotEmpty) { // Updated reference
                  await FirebaseFirestore.instance.collection('patients').add({
                    'name': _nameController.text,
                    // ✅ FIX 1: Use the correct field name 'mobile' (or 'phoneNumber' if that's what you used elsewhere)
                    'mobile': _mobileController.text, 
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  _nameController.clear();
                  _mobileController.clear(); // Updated reference
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Delete patient from Firestore (omitting for brevity, no changes needed)
  void _deletePatient(String docId) {
    // ... (Your delete code is fine)
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Patient'),
          content: const Text('Are you sure you want to delete this patient?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('patients')
                    .doc(docId)
                    .delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Patient Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
          ),

          // Fetch patients from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading patients"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                    
                    // Safe access for 'name'
                    final name = patient['name'] ?? 'No Name'; 
                    
                    // ✅ FIX 2: Use the correct field name 'mobile' and use safe access
                    // The crash happens here because 'contact' does not exist in the database.
                    final mobile = patient['mobile'] ?? 'No Mobile'; 

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF18A3B6),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(name),
                        // ✅ FIX 3: Update the subtitle text to reflect the field name
                        subtitle: Text('Mobile: $mobile'), 
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPatient,
        backgroundColor: const Color(0xFF32BACD),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}