// frontend/lib/screens/doctor_screens/doctor_confirmed_slots_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DoctorConfirmedSlotsScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorConfirmedSlotsScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorConfirmedSlotsScreen> createState() => _DoctorConfirmedSlotsScreenState();
}

class _DoctorConfirmedSlotsScreenState extends State<DoctorConfirmedSlotsScreen> {
  List<dynamic> confirmedSlots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfirmedSlots();
  }

  Future<void> _loadConfirmedSlots() async {
    try {
      setState(() => isLoading = true);
      
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/doctors/confirmed-slots?doctorId=${widget.doctorId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          confirmedSlots = data['data'] ?? [];
        });
      } else {
        throw Exception('Failed to load confirmed slots');
      }
    } catch (e) {
      print('Error loading confirmed slots: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading confirmed slots: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    final date = DateTime.parse(slot['date']);
    final formattedDate = '${date.day}/${date.month}/${date.year}';
    
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
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    'CONFIRMED',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Time: ${slot['startTime']} - ${slot['endTime']}'),
            Text('Type: ${slot['appointmentType']}'),
            Text('Max Appointments: ${slot['maxAppointments']}'),
            const SizedBox(height: 8),
            Text(
              'Status: Available for patients to book',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${widget.doctorName} - Confirmed Slots'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfirmedSlots,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : confirmedSlots.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Confirmed Slots',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your schedule needs admin approval first',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${confirmedSlots.length} confirmed slot(s) available for patients',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Confirmed Appointment Slots:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: confirmedSlots.length,
                          itemBuilder: (context, index) {
                            return _buildSlotCard(confirmedSlots[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}