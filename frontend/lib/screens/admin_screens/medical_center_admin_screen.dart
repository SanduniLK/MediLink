import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/model/doctor_schedule_model.dart';
import 'package:frontend/services/doctor_schedule_service.dart';


class MedicalCenterAdminScreen extends StatefulWidget {
  const MedicalCenterAdminScreen({super.key});

  @override
  State<MedicalCenterAdminScreen> createState() => _MedicalCenterAdminScreenState();
}

class _MedicalCenterAdminScreenState extends State<MedicalCenterAdminScreen> {
  Map<String, dynamic>? medicalCenter;
  String? adminId;

  @override
  void initState() {
    super.initState();
    _getCurrentAdmin();
  }

  void _getCurrentAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        adminId = user.uid;
      });
      _loadMedicalCenter(user.uid);
    }
  }

  void _loadMedicalCenter(String adminId) {
    // Get medical center by admin ID
    FirebaseFirestore.instance
        .collection('medicalCenters')
        .where('adminId', isEqualTo: adminId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          medicalCenter = {
            'id': snapshot.docs.first.id,
            ...snapshot.docs.first.data(),
          };
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Center Admin'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: adminId == null
          ? const Center(child: CircularProgressIndicator())
          : medicalCenter == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medical Center Info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.medical_services, 
                                      color: Color(0xFF18A3B6), size: 40),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          medicalCenter!['name'] ?? 'Medical Center',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(medicalCenter!['address'] ?? ''),
                                        Text('Admin: ${medicalCenter!['adminName'] ?? 'Admin'}'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Pending Schedules Section
                      const Text(
                        'Pending Schedule Approvals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Approve or reject doctor schedules for your medical center',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      
                      // Pending Schedules List
                      Expanded(
                        child: _buildPendingSchedulesList(adminId!),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPendingSchedulesList(String adminId) {
    return StreamBuilder<List<DoctorSchedule>>(
      stream: DoctorScheduleService.getPendingSchedulesForMedicalCenterAdmin(adminId),
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
                Icon(Icons.schedule, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending schedules',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            return _buildScheduleCard(schedules[index]);
          },
        );
      },
    );
  }

  Widget _buildScheduleCard(DoctorSchedule schedule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dr. ${schedule.doctorName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Text('Medical Center: ${schedule.medicalCenterName}'),
            
            const SizedBox(height: 12),
            const Text(
              'Schedule:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            
            ...schedule.weeklySchedule
                .where((day) => day.available && day.timeSlots.isNotEmpty)
                .map((day) {
              final timeSlot = day.timeSlots.first;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${_capitalize(day.day)}: ${timeSlot.startTime} - ${timeSlot.endTime} (${timeSlot.slotDuration}min)',
                ),
              );
            }).toList(),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveSchedule(schedule.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectSchedule(schedule.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveSchedule(String scheduleId) async {
    try {
      await DoctorScheduleService.approveScheduleByMedicalCenterAdmin(scheduleId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule approved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving schedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectSchedule(String scheduleId) async {
    try {
      await DoctorScheduleService.rejectScheduleByMedicalCenterAdmin(scheduleId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule rejected.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting schedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _capitalize(String text) {
    return text[0].toUpperCase() + text.substring(1);
  }
}