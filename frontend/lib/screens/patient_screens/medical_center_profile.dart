import 'package:flutter/material.dart';
import 'package:frontend/model/medical_center.dart';

// Import the MedicalCenter model

class MedicalCenterProfilePage extends StatelessWidget {
  final MedicalCenter medicalCenter;

  const MedicalCenterProfilePage({super.key, required this.medicalCenter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(medicalCenter.name),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Doctors at ${medicalCenter.name}:',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: medicalCenter.doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = medicalCenter.doctors[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(doctor.imageUrl),
                      ),
                      title: Text(doctor.name),
                      subtitle: Text(doctor.specialty),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}