import 'package:flutter/material.dart';

class AdminQueueScreen extends StatelessWidget {
  const AdminQueueScreen({super.key});

  // Mock data for each doctor's queue
  final List<Map<String, dynamic>> doctorQueues = const [
    {
      'doctorName': 'Dr. Smith',
      'totalPatients': 10,
      'servedPatients': 3,
      'currentPatient': 'Alice',
    },
    {
      'doctorName': 'Dr. Johnson',
      'totalPatients': 8,
      'servedPatients': 5,
      'currentPatient': 'Bob',
    },
    {
      'doctorName': 'Dr. Williams',
      'totalPatients': 12,
      'servedPatients': 7,
      'currentPatient': 'Charlie',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Queue Overview'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: doctorQueues.length,
          itemBuilder: (context, index) {
            final queue = doctorQueues[index];
            final progressPercent =
                queue['servedPatients'] / queue['totalPatients'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(queue['doctorName'],
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progressPercent,
                      color: Colors.green,
                      backgroundColor: Colors.grey.shade300,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Patients Served: ${queue['servedPatients']}/${queue['totalPatients']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Current Patient: ${queue['currentPatient']}',
                      style: const TextStyle(
                          fontSize: 16, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
