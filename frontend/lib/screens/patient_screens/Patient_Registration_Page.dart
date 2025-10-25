import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientRegisterPage extends StatefulWidget {
  @override
  _PatientRegisterPageState createState() => _PatientRegisterPageState();
}

class _PatientRegisterPageState extends State<PatientRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emergencyController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController sexController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerPatient() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 1. Register with Firebase Auth
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        String uid = userCredential.user!.uid;

        // 2. Save details in Firestore
        await _firestore.collection("users").doc(uid).set({
          "fullName": fullNameController.text.trim(),
          "emergencyNumber": emergencyController.text.trim(),
          "phoneNumber": phoneController.text.trim(),
          "sex": sexController.text.trim(),
          "address": addressController.text.trim(),
          "email": emailController.text.trim(),
          "role": "patient",
          "createdAt": FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Patient Registered Successfully!")),
        );

        Navigator.pushReplacementNamed(context, "/login");

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration Failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Patient Registration")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: fullNameController,
                decoration: InputDecoration(labelText: "Full Name"),
                validator: (value) => value!.isEmpty ? "Enter full name" : null,
              ),
              TextFormField(
                controller: emergencyController,
                decoration: InputDecoration(labelText: "Emergency Number"),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? "Enter emergency number" : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? "Enter phone number" : null,
              ),
              TextFormField(
                controller: sexController,
                decoration: InputDecoration(labelText: "Sex (Male/Female/Other)"),
                validator: (value) => value!.isEmpty ? "Enter sex" : null,
              ),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: "Address"),
                validator: (value) => value!.isEmpty ? "Enter address" : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? "Enter email" : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (value) => value!.length < 6 ? "Password must be 6+ chars" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: registerPatient,
                child: Text("Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
