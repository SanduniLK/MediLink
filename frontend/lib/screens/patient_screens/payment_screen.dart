import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/token_service.dart';


class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  final double amount;
  final String doctorName;
  final String doctorSpecialty;
  final String selectedDate;
  final String selectedTime;
  final String medicalCenterName;
  final String scheduleId;
  final String doctorId;

  const PaymentScreen({
    Key? key,
    required this.appointmentData,
    required this.amount,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.selectedDate,
    required this.selectedTime,
    required this.medicalCenterName,
    required this.scheduleId,
    required this.doctorId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
 
}

 
 
class _PaymentScreenState extends State<PaymentScreen> {
  bool _processingPayment = false;
  final DynamicTokenService _tokenService = DynamicTokenService();
    String _consultationType = 'video';

    @override
  void initState() {
    super.initState();
    _determineConsultationType();
  }
void _determineConsultationType() {
    final appointmentType = widget.appointmentData['appointmentType'] ?? 'physical';
    
    if (appointmentType == 'video' || appointmentType == 'audio') {
      _consultationType = appointmentType;
    } else {
      _consultationType = 'video'; // Default for telemedicine
    }
    
    print('🎯 Consultation type determined: $_consultationType');
  }

Future<void> _processPayment() async {
  if (_processingPayment) return;

  setState(() {
    _processingPayment = true;
  });

  try {
    print('💳 Processing payment...');

    // First, double-check appointment availability
    final scheduleDoc = await FirebaseFirestore.instance
        .collection('doctorSchedules')
        .doc(widget.scheduleId)
        .get();

    if (!scheduleDoc.exists) {
      _showErrorSnackBar('Schedule not found. Please try again.');
      return;
    }

    final scheduleData = scheduleDoc.data()!;
    final currentBooked = (scheduleData['bookedAppointments'] as int? ?? 0);
    final maxAppointments = (scheduleData['maxAppointments'] as int? ?? 10);

    if (currentBooked >= maxAppointments) {
      _showErrorSnackBar('Sorry, this slot is no longer available.');
      return;
    }

    // ✅ STEP 1: ASSIGN TOKEN NUMBER AFTER PAYMENT SUCCESS
    print('🎫 Assigning token number after payment...');
    final tokenNumber = await _tokenService.assignTokenNumber(
      widget.doctorId, 
      widget.selectedDate
    );

    print('✅ Token assigned: $tokenNumber');

    // ✅ STEP 2: Update appointment data with token
    final updatedAppointmentData = {
      ...widget.appointmentData,
      'tokenNumber': tokenNumber, // Add token number
      'queueStatus': 'waiting',
      'paymentStatus': 'paid', // Update payment status
      'status': 'confirmed', // Update appointment status
      'paidAt': FieldValue.serverTimestamp(),
      'consultationType': widget.appointmentData['appointmentType'], 
    };

    // ✅ STEP 3: Update the booked appointments count
    await FirebaseFirestore.instance
        .collection('doctorSchedules')
        .doc(widget.scheduleId)
        .update({
      'bookedAppointments': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ✅ STEP 4: Save the appointment to Firestore WITH TOKEN
    final appointmentRef = await FirebaseFirestore.instance
        .collection('appointments')
        .add(updatedAppointmentData);

    print('✅ Appointment saved with ID: ${appointmentRef.id}');
    print('✅ Token $tokenNumber confirmed for appointment');

    // ✅ STEP 5: IF TELEMEDICINE APPOINTMENT, CREATE TELEMEDICINE SESSION
    final appointmentType = widget.appointmentData['appointmentType'] ?? 'physical';
    
    if (appointmentType == 'video' || appointmentType == 'audio') {
      await _createTelemedicineSession(appointmentRef.id, tokenNumber);
    }

    // ✅ STEP 6: Store token locally
    await _tokenService.storeTokenLocally(widget.scheduleId, tokenNumber);

    // ✅ STEP 7: Show success with token number
    _showSuccessDialog(tokenNumber, appointmentRef.id);

  } catch (e) {
    print('❌ Payment error: $e');
    _showErrorSnackBar('Payment failed. Please try again.');
    setState(() {
      _processingPayment = false;
    });
  }
}

// NEW METHOD: Create Telemedicine Session
Future<void> _createTelemedicineSession(String appointmentId, int tokenNumber) async {
  try {
    print('🎥 Creating telemedicine session...');
    
    // Generate unique IDs
    final telemedicineId = 'T${DateTime.now().millisecondsSinceEpoch}';
    final chatRoomId = 'C${DateTime.now().millisecondsSinceEpoch}';
        final consultationType = widget.appointmentData['appointmentType'] ?? 'video';
    // Create telemedicine session data
    final telemedicineSession = {
      'telemedicineId': telemedicineId,
      'doctorId': widget.doctorId,
      'patientId': widget.appointmentData['patientId'],
      'chatRoomId': chatRoomId,
      'videoLink': 'https://medilink.app/call/$telemedicineId',
      'date': widget.selectedDate,
      'timeSlot': widget.selectedTime,
      'status': 'Scheduled',
      'createdAt': DateTime.now().toIso8601String(),
      'appointmentId': appointmentId, // Link to original appointment
      'tokenNumber': tokenNumber,
      'consultationType': consultationType,
      // Add doctor/patient info for easy access
      'doctorName': widget.doctorName,
      'doctorSpecialty': widget.doctorSpecialty,
      'patientName': widget.appointmentData['patientName'],
      'medicalCenterName': widget.medicalCenterName,
    };

    // Save to telemedicine_sessions collection
    await FirebaseFirestore.instance
        .collection('telemedicine_sessions')
        .doc(telemedicineId)
        .set(telemedicineSession);

    print('✅ Telemedicine session created: $telemedicineId');

    // Also update the original appointment with telemedicine IDs
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({
      'telemedicineId': telemedicineId,
      'chatRoomId': chatRoomId,
      'videoLink': 'https://medilink.app/call/$telemedicineId',
      'consultationType': consultationType,
    });

    print('✅ Appointment updated with telemedicine IDs');

  } catch (e) {
    print('❌ Error creating telemedicine session: $e');
    // Don't fail the entire payment if telemedicine session creation fails
  }
}

  void _showSuccessDialog(int tokenNumber, String appointmentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Booking Confirmed! 🎉'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doctor: Dr. ${widget.doctorName}'),
                Text('Date: ${widget.selectedDate}'),
                Text('Time: ${widget.selectedTime}'),
                const SizedBox(height: 16),
                // Token display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF18A3B6)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Token Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '#$tokenNumber',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Show this token at the clinic',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can view this appointment in "My Appointments" section.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Appointment ID: ${appointmentId.substring(0, 8)}...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Go to Home'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
              ),
              child: const Text('View My Appointments'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView( // ✅ FIXED: Added SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appointment Summary
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointment Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Appointment Details
                    _buildDetailRow('Doctor', 'Dr. ${widget.doctorName}'),
                    _buildDetailRow('Specialty', widget.doctorSpecialty),
                    _buildDetailRow('Medical Center', widget.medicalCenterName),
                    _buildDetailRow('Date', widget.selectedDate),
                    _buildDetailRow('Time', widget.selectedTime),
                    _buildDetailRow('Appointment Type', 
                      _formatConsultationType(widget.appointmentData['appointmentType'] ?? 'physical')),
                    _buildDetailRow('Token', 'Will be assigned after payment'),
                    
                    // Patient Notes if available
                    if (widget.appointmentData['patientNotes'] != null && 
                        widget.appointmentData['patientNotes'].toString().isNotEmpty)
                      _buildDetailRow('Your Notes', widget.appointmentData['patientNotes']),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            

            // Payment Amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs. ${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Token number will be assigned after successful payment',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processingPayment ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18A3B6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _processingPayment
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing Payment...'),
                        ],
                      )
                    : const Text(
                        'Pay Now',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Payment Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, size: 16, color: Color(0xFF18A3B6)),
                      SizedBox(width: 8),
                      Text(
                        'Secure Payment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Your payment information is secure\n'
                    '• Token will be assigned immediately after payment\n'
                    '• Full refund available if cancelled 2 hours before appointment',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF18A3B6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20), // Extra space at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600, 
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatConsultationType(String type) {
    switch (type) {
      case 'physical': return 'Physical Visit';
      case 'audio': return 'Audio Call';
      case 'video': return 'Video Call';
      default: return 'Physical Visit';
    }
  }
}