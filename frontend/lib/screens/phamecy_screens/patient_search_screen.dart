import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_profile_screen.dart';

class PatientSearchScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;
  
  const PatientSearchScreen({
    super.key, 
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<PatientSearchScreen> createState() => _PatientSearchScreenState();
}

class _PatientSearchScreenState extends State<PatientSearchScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  bool _isSearching = false;
  String _searchMethod = 'mobile'; // 'mobile' or 'patientId'

  Future<void> _searchPatient() async {
    if (_searchMethod == 'mobile' && _mobileController.text.isEmpty) {
      _showError('Please enter mobile number');
      return;
    }
    if (_searchMethod == 'patientId' && _patientIdController.text.isEmpty) {
      _showError('Please enter Patient ID');
      return;
    }

    setState(() => _isSearching = true);

    try {
      String searchQuery = _searchMethod == 'mobile' 
          ? _mobileController.text.trim()
          : _patientIdController.text.trim();

      QuerySnapshot querySnapshot;
      
      if (_searchMethod == 'mobile') {
        // Search by mobile number
        querySnapshot = await FirebaseFirestore.instance
            .collection('patients')
            .where('mobileNumber', isEqualTo: searchQuery)
            .limit(1)
            .get();
      } else {
        // Search by patient ID
        querySnapshot = await FirebaseFirestore.instance
            .collection('patients')
            .where('patientId', isEqualTo: searchQuery)
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        _showError('Patient not found. Please check the details or register new patient.');
        return;
      }

      final patientData = querySnapshot.docs.first.data() as Map<String, dynamic>;
      final patientId = querySnapshot.docs.first.id;

      // Navigate to patient profile
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientProfileScreen(
              patientId: patientId,
              patientData: patientData,
              pharmacyId: widget.pharmacyId,
              pharmacyName: widget.pharmacyName,
            ),
          ),
        );
      }

    } catch (e) {
      _showError('Error searching patient: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // Method to register new patient if not found
  Future<void> _registerNewPatient() async {
    if (_mobileController.text.isEmpty) {
      _showError('Please enter mobile number');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register New Patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Full Name'),
              onChanged: (value) {},
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement patient registration
              Navigator.pop(context);
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Patient'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Method Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Search Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Mobile Number'),
                            selected: _searchMethod == 'mobile',
                            onSelected: (selected) {
                              setState(() => _searchMethod = 'mobile');
                            },
                            selectedColor: const Color(0xFF18A3B6),
                            labelStyle: TextStyle(
                              color: _searchMethod == 'mobile' 
                                  ? Colors.white 
                                  : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Patient ID'),
                            selected: _searchMethod == 'patientId',
                            onSelected: (selected) {
                              setState(() => _searchMethod = 'patientId');
                            },
                            selectedColor: const Color(0xFF18A3B6),
                            labelStyle: TextStyle(
                              color: _searchMethod == 'patientId' 
                                  ? Colors.white 
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Search Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_searchMethod == 'mobile') ...[
                      TextField(
                        controller: _mobileController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                          hintText: 'Enter patient mobile number',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ] else ...[
                      TextField(
                        controller: _patientIdController,
                        decoration: const InputDecoration(
                          labelText: 'Patient ID',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          hintText: 'Enter patient ID',
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSearching ? null : _searchPatient,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18A3B6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Search Patient',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_searchMethod == 'mobile')
                      OutlinedButton(
                        onPressed: _registerNewPatient,
                        child: const Text('Register New Patient'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}