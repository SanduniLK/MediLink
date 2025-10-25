import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image for "No Notifications"
            SizedBox(
              width: 250, // Adjust the size as needed
              height: 250,
              child: Image.asset(
                'assets/images/message-received.png', // <-- Ensure you have this image in your assets
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            // Message Text
            const Text(
              'No new notifications yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const Text(
              'We will let you know when we have new alerts for you.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}