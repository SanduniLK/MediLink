import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/enroll_screnns/OtpVerificationPage.dart';
import 'package:frontend/enroll_screnns/sign_in_page.dart';
import 'package:intl/intl.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  String _role = "patient"; // default role
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // patient-specific
  String? _gender;
  int? _age;

  // doctor-specific
  final _specializationController = TextEditingController();
  final _regNumberController = TextEditingController();
  List<Map<String, String>> _selectedMedicalCenters = [];

  // pharmacy-specific
  final _licenseController = TextEditingController();
  final _ownerController = TextEditingController();

  bool isLoading = false;

  // Colors
  static const Color _deepTeal = Color(0xFF18A3B6);
  static const Color _brightCyan = Color(0xFF32BACD);
  static const Color _softAqua = Color(0xFFB2DEE6);
  static const Color _lightBlueBg = Color(0xFFDDF0F5);

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _specializationController.dispose();
    _regNumberController.dispose();
    _licenseController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  void _calculateAge(String dob) {
    try {
      DateTime birthDate = DateFormat("yyyy-MM-dd").parse(dob);
      DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      setState(() => _age = age);
    } catch (e) {
      setState(() => _age = null);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == "doctor" && _selectedMedicalCenters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one Medical Center")));
      return;
    }

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user!.uid;

      // ✅ SEND EMAIL VERIFICATION FOR ALL USERS
      await cred.user!.sendEmailVerification();

      // Store in users collection
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "role": _role,
        "fullname": _fullnameController.text.trim(),
        "email": _emailController.text.trim(),
        "uid": uid,
        "isEmailVerified": false, // ✅ All users start as not verified
        "createdAt": FieldValue.serverTimestamp(),
      });

      // ✅ STORE IN SPECIFIC COLLECTIONS BASED ON ROLE
      if (_role == "patient") {
        await FirebaseFirestore.instance.collection("patients").doc(uid).set({
          "uid": uid,
          "fullname": _fullnameController.text.trim(),
          "dob": _dobController.text.trim(),
          "age": _age,
          "mobile": _mobileController.text.trim(),
          "gender": _gender,
          "email": _emailController.text.trim(),
          "address": _addressController.text.trim(),
          "role": "patient",
          "isEmailVerified": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } else if (_role == "doctor") {
        await FirebaseFirestore.instance.collection("doctor_requests").doc(uid).set({
          "uid": uid,
          "fullname": _fullnameController.text.trim(),
          "email": _emailController.text.trim(),
          "specialization": _specializationController.text.trim(),
          "address": _addressController.text.trim(),
          "mobile": _mobileController.text.trim(),
          "dob": _dobController.text.trim(),
          "regNumber": _regNumberController.text.trim(),
          "medicalCenters": _selectedMedicalCenters,
          "role": "doctor",
          "isEmailVerified": false,
          "createdAt": FieldValue.serverTimestamp(),
          "status": "pending",
        });
      } else if (_role == "pharmacy") {
        await FirebaseFirestore.instance.collection("pharmacy_requests").doc(uid).set({
          "uid": uid,
          "name": _fullnameController.text.trim(),
          "email": _emailController.text.trim(),
          "address": _addressController.text.trim(),
          "phone": _mobileController.text.trim(),
          "licenseNumber": _licenseController.text.trim(),
          "ownerName": _ownerController.text.trim(),
          "role": "pharmacy",
          "isEmailVerified": false,
          "createdAt": FieldValue.serverTimestamp(),
          "status": "pending",
        });
      }

      // ✅ SUCCESS MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration successful! Please verify your email."),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ REDIRECT TO EMAIL VERIFICATION PAGE FOR ALL USERS
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(email: _emailController.text.trim()),
        ),
      );

    } on FirebaseAuthException catch (e) {
      String message = "Registration failed. Please try again.";
      if (e.code == 'email-already-in-use') {
        message = "This email is already in use. Try logging in.";
      } else if (e.code == 'weak-password') {
        message = "The password provided is too weak.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("An unknown error occurred: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brightCyan, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBlueBg,
      appBar: AppBar(
        backgroundColor: _deepTeal,
        title: const Text("Create Account",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Secure Registration",
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: _deepTeal),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text("Join our platform as Patient, Doctor or Pharmacy",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 30),

              // Role selection - ONLY PATIENT, DOCTOR, PHARMACY
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _softAqua, width: 2),
                ),
                child: DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(
                        value: "patient",
                        child: Row(children: [
                          Icon(Icons.person_outline, color: _brightCyan),
                          SizedBox(width: 8),
                          Text("Patient")
                        ])),
                    DropdownMenuItem(
                        value: "doctor",
                        child: Row(children: [
                          Icon(Icons.medical_services_outlined, color: _brightCyan),
                          SizedBox(width: 8),
                          Text("Doctor")
                        ])),
                    DropdownMenuItem(
                        value: "pharmacy",
                        child: Row(children: [
                          Icon(Icons.local_pharmacy_outlined, color: _brightCyan),
                          SizedBox(width: 8),
                          Text("Pharmacy")
                        ])),
                    // ❌ MEDICAL CENTER REMOVED - Only super admin can register
                  ],
                  onChanged: (val) => setState(() {
                    _role = val!;
                    if (_role != 'doctor') _selectedMedicalCenters = [];
                  }),
                  decoration: InputDecoration(
                    labelText: "Register as",
                    labelStyle:
                        const TextStyle(color: _deepTeal, fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Common fields for all roles
              TextFormField(
                controller: _fullnameController,
                decoration: _inputDecoration(
                  _role == "pharmacy" ? "Pharmacy Name" : "Full Name", 
                  _role == "pharmacy" ? Icons.local_pharmacy_outlined : Icons.badge_outlined
                ),
                validator: (val) => val!.isEmpty ? 
                  (_role == "pharmacy" ? "Enter pharmacy name" : "Enter full name") : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("Email Address", Icons.email_outlined),
                validator: (val) => val!.isEmpty ? "Enter email" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                decoration: _inputDecoration(
                  _role == "pharmacy" ? "Phone Number" : "Mobile Number", 
                  Icons.phone_android_outlined
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val!.isEmpty ? 
                  (_role == "pharmacy" ? "Enter phone number" : "Enter mobile number") : null,
              ),

              // Date of Birth (only for patient and doctor)
              if (_role != "pharmacy") ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dobController,
                  decoration: _inputDecoration("Date of Birth (yyyy-MM-dd)", Icons.calendar_month),
                  onChanged: _calculateAge,
                  keyboardType: TextInputType.datetime,
                  validator: (val) => val!.isEmpty ? "Enter DOB (yyyy-MM-dd)" : null,
                ),
                if (_age != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Text(
                      "Age: $_age years",
                      style: TextStyle(color: _deepTeal, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
              const SizedBox(height: 12),

              // Patient-specific
              if (_role == "patient") ...[
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                  ],
                  onChanged: (val) => setState(() => _gender = val),
                  decoration: _inputDecoration("Gender", Icons.face_outlined),
                  validator: (val) => val == null ? "Select gender" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: _inputDecoration("Address", Icons.location_on_outlined),
                  maxLines: 2,
                ),
              ],

              // Doctor-specific
              if (_role == "doctor") ...[
                TextFormField(
                  controller: _specializationController,
                  decoration: _inputDecoration("Specialization", Icons.star_border),
                  validator: (val) => val!.isEmpty ? "Enter specialization" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: _inputDecoration(
                      "Clinic/Office Address", Icons.location_city_outlined),
                  maxLines: 2,
                  validator: (val) => val!.isEmpty ? "Enter clinic address" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _regNumberController,
                  decoration: _inputDecoration(
                      "Medical Registration Number", Icons.confirmation_number_outlined),
                  keyboardType: TextInputType.text,
                  validator: (val) => val!.isEmpty ? "Enter registration number" : null,
                ),
                const SizedBox(height: 16),

                // Multi-select Medical Centers - FIXED
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMedicalCenters.isEmpty && !isLoading
                          ? Colors.red.shade300
                          : _softAqua,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.apartment, color: _deepTeal, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            "Select Medical Centers (Required)",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _deepTeal),
                          ),
                        ],
                      ),
                      const Divider(height: 15, thickness: 1, color: Color(0xFFE0E0E0)),
                      
                      // ✅ FIXED: Fetch from medical_centers collection
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('medical_centers')
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                                child: CircularProgressIndicator(color: _brightCyan));
                          }
                          
                          if (snapshot.hasError) {
                            print('❌ Error loading medical centers: ${snapshot.error}');
                            return Column(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  "Error loading medical centers",
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "${snapshot.error}",
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }
                          
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                children: [
                                  Icon(Icons.local_hospital_outlined, color: Colors.grey, size: 40),
                                  SizedBox(height: 8),
                                  Text(
                                    "No medical centers available",
                                    style: TextStyle(
                                        fontStyle: FontStyle.italic, 
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Please contact admin to add medical centers first",
                                    style: TextStyle(color: Colors.orange),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          final centers = snapshot.data!.docs;
                          print('✅ Loaded ${centers.length} medical centers');
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: centers.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final centerName = data['name'] ?? "Unnamed Center";
                              final centerId = doc.id;
                              
                              // Debug: Print all available fields
                              print('🏥 Medical Center: $centerName');
                              print('   Available fields: ${data.keys.join(', ')}');
                              
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(
                                  centerName,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (data['specialization'] != null && data['specialization'].toString().isNotEmpty)
                                      Text(
                                        "Specialty: ${data['specialization']}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (data['email'] != null && data['email'].toString().isNotEmpty)
                                      Text(
                                        "Email: ${data['email']}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    
                                  ],
                                ),
                                value: _selectedMedicalCenters.any((center) => center['id'] == centerId),
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedMedicalCenters.add({
                                        'id': centerId,
                                        'name': centerName
                                      });
                                    } else {
                                      _selectedMedicalCenters.removeWhere((center) => center['id'] == centerId);
                                    }
                                  });
                                },
                                activeColor: _brightCyan,
                                secondary: Icon(Icons.local_hospital, color: _deepTeal),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Pharmacy-specific
              if (_role == "pharmacy") ...[
                TextFormField(
                  controller: _ownerController,
                  decoration: _inputDecoration("Owner Name", Icons.person_outlined),
                  validator: (val) => val!.isEmpty ? "Enter owner name" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _licenseController,
                  decoration: _inputDecoration("License Number", Icons.badge_outlined),
                  validator: (val) => val!.isEmpty ? "Enter license number" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: _inputDecoration("Pharmacy Address", Icons.location_on_outlined),
                  maxLines: 2,
                  validator: (val) => val!.isEmpty ? "Enter pharmacy address" : null,
                ),
              ],

              const SizedBox(height: 12),

              // Password fields
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration("Password", Icons.lock_outline),
                validator: (val) =>
                    val!.length < 6 ? "Password must be at least 6 characters" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: _inputDecoration("Confirm Password", Icons.lock_reset_outlined),
                validator: (val) {
                  if (val!.isEmpty) return "Confirm password";
                  if (val != _passwordController.text.trim()) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 24),

              isLoading
                  ? Center(child: CircularProgressIndicator(color: _deepTeal))
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _deepTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                      child: const Text("Register",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),

              const SizedBox(height: 16),

              // Already have an account?
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?",
                      style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInPage()),
                      );
                    },
                    child: const Text("Sign In",
                        style: TextStyle(
                            color: _deepTeal, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}