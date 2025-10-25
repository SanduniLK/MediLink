import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  // Mock counts
  final int totalPatients = 120;
  final int totalDoctors = 25;
  final int totalMedicalCenters = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Analysis'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCard('Total Patients', totalPatients, Colors.blue),
            const SizedBox(height: 16),
            _buildCard('Total Doctors', totalDoctors, Colors.green),
            const SizedBox(height: 16),
            _buildCard('Total Medical Centers', totalMedicalCenters, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, int count, Color color) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color,
              child: Text(
                count.toString(),
                style: const TextStyle(
                    fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
