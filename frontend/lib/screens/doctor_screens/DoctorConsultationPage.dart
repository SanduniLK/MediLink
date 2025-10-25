import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConsultationPage extends StatefulWidget {
  final String doctorId; // Pass logged-in doctor ID
  const ConsultationPage({super.key, required this.doctorId});

  @override
  _ConsultationPageState createState() => _ConsultationPageState();
}

class _ConsultationPageState extends State<ConsultationPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCenter;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _appointmentType = "Physical";
  int _maxAppointments = 10;

  final CollectionReference _consultationRef =
      FirebaseFirestore.instance.collection('doctorSchedules');

  // Submits the new schedule with "status": "pending"
  Future<void> _submitConsultation() async {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _startTime != null &&
        _endTime != null &&
        _selectedCenter != null) {
      try {
        await _consultationRef.add({
          "doctorId": widget.doctorId,
          "medicalCenterId": _selectedCenter,
          "date": _selectedDate,
          "startTime":
              "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}",
          "endTime":
              "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}",
          "appointmentType": _appointmentType.toLowerCase(),
          "maxAppointments": _maxAppointments,
          "status": "pending", 
          "createdAt": FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Consultation request sent!")),
        );

        // Clear form
        setState(() {
          _selectedCenter = null;
          _selectedDate = null;
          _startTime = null;
          _endTime = null;
          _appointmentType = "Physical";
          _maxAppointments = 10;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
    }
  }

  // Date and Time pickers
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Consultations"),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // List of Doctor's existing schedules
              SizedBox(
                height: 250,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _consultationRef
                      .where('doctorId', isEqualTo: widget.doctorId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No consultations yet."));
                    }
                    return ListView(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final dateString = data['date'] != null 
                            ? (data['date'] as Timestamp).toDate().toString().split(" ")[0] 
                            : 'N/A';
                        return Card(
                          child: ListTile(
                            title: Text(
                                "${data['appointmentType'] ?? 'N/A'} @ ${data['startTime'] ?? 'N/A'} - ${data['endTime'] ?? 'N/A'}"),
                            subtitle: Text(
                                "Date: $dateString\nStatus: ${data['status'] ?? 'N/A'}"),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
              
              // Form for submitting new consultation request
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Medical Center Dropdown
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('medical_centers')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        List<DropdownMenuItem<String>> centers =
                            snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['name'] ?? 'N/A'),
                          );
                        }).toList();

                        return DropdownButtonFormField<String>(
                          value: _selectedCenter,
                          items: centers,
                          hint: const Text("Select Medical Center"),
                          onChanged: (val) =>
                              setState(() => _selectedCenter = val),
                          validator: (val) => val == null
                              ? "Please select a medical center"
                              : null,
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    // Date, Start Time, End Time
                    ListTile(
                      title: Text(_selectedDate == null ? "Choose Date" : _selectedDate.toString().split(" ")[0]),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickDate,
                    ),

                    ListTile(
                      title: Text(_startTime == null ? "Choose Start Time" : _startTime!.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _pickTime(true),
                    ),

                    ListTile(
                      title: Text(_endTime == null ? "Choose End Time" : _endTime!.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _pickTime(false),
                    ),

                    const SizedBox(height: 16),

                    // Appointment Type
                    DropdownButtonFormField<String>(
                      value: _appointmentType,
                      items: ["Physical", "Video"].map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() {
                        _appointmentType = val!;
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Max Appointments
                    TextFormField(
                      initialValue: _maxAppointments.toString(),
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: "Max Appointments"),
                      onChanged: (val) =>
                          _maxAppointments = int.tryParse(val) ?? 10,
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _submitConsultation,
                      child: const Text("Submit Consultation"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}