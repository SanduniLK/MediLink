import 'package:flutter/material.dart';
import 'package:frontend/model/doctor_schedule_model.dart';
import 'package:frontend/services/doctor_schedule_service.dart';

class PatientScheduleView extends StatefulWidget {
  const PatientScheduleView({super.key});

  @override
  State<PatientScheduleView> createState() => _PatientScheduleViewState();
}

class _PatientScheduleViewState extends State<PatientScheduleView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Doctors'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<DoctorSchedule>>(
        stream: DoctorScheduleService.getSchedulesForPatients(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final schedules = snapshot.data ?? [];
          
          if (schedules.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No doctors available at the moment',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please check back later',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              return _buildDoctorCard(schedules[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildDoctorCard(DoctorSchedule schedule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF18A3B6),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${schedule.doctorName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        schedule.medicalCenterName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'AVAILABLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Available Times:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            
            ...schedule.weeklySchedule
                .where((day) => day.available && day.timeSlots.isNotEmpty)
                .map((day) {
              final timeSlot = day.timeSlots.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        _capitalize(day.day),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text('${timeSlot.startTime} - ${timeSlot.endTime}'),
                    const Spacer(),
                    Text('${timeSlot.slotDuration}min'),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Book appointment functionality
                  _bookAppointment(schedule);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Book Appointment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bookAppointment(DoctorSchedule schedule) {
    // Implement booking logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking appointment with Dr. ${schedule.doctorName}'),
      ),
    );
  }

  String _capitalize(String text) {
    return text[0].toUpperCase() + text.substring(1);
  }
}