import 'package:flutter/material.dart';

class InformationScreen extends StatelessWidget {
  const InformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('Information'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You have no information yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 20), // Adds space between the text and the image
            SizedBox(
              width: 300, // Set your desired width
              height: 300, // Set your desired height
              child: Image.asset(
                'assets/images/info.png', // Ensure this path is correct in your pubspec.yaml
                fit: BoxFit.contain, // Adjust the fit as needed
              ),
            ),
          ],
        ),
      ),
    );
  }
}