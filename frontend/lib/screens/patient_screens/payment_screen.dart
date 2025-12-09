// payment_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/token_service.dart';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';

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
  String _selectedDateOnly = '';
  @override
  void initState() {
    super.initState();
    _determineConsultationType();
    _selectedDateOnly = _parseSelectedDate();
  }

   void _determineConsultationType() {
    final appointmentType =
        widget.appointmentData['appointmentType'] ?? 'physical';

    if (appointmentType == 'video' || appointmentType == 'audio') {
      _consultationType = appointmentType;
    } else {
      _consultationType = 'video'; // Default for telemedicine
    }

    print('🎯 Consultation type determined: $_consultationType');
  }

 String _parseSelectedDate() {
  final dateString = widget.selectedDate;
  
  print('📅 Original date string: "$dateString"');
  
  // Case 1: Contains parentheses like "Today (5/12/2025)" or "Tomorrow (8/12/2025)"
  if (dateString.contains('(') && dateString.contains(')')) {
    final start = dateString.indexOf('(') + 1;
    final end = dateString.indexOf(')');
    if (start < end) {
      final extracted = dateString.substring(start, end).trim();
      print('📅 Extracted date from parentheses: "$extracted"');
      return extracted;
    }
  }
  
  // Case 2: Just return as is if no parentheses
  print('📅 Using original date as is: "$dateString"');
  return dateString.trim();
}

  // Build PayHere payment object
  Map<String, dynamic> _createPayHerePaymentObject() {
    final patientName = widget.appointmentData['patientName'] ?? 'Patient';
    final parts = patientName.toString().split(' ');
    final firstName = parts.isNotEmpty ? parts.first : 'Patient';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return {
      "sandbox": true, // set to false in production
      "merchant_id": "1232989", // replace
      "merchant_secret":
          "Mzk1NTgwMDc5MDE4NTY4NTA1NzMzNzc2NTI5MzUyMzQ5OTk2Mzc5NA==", // replace if needed
      "notify_url":
          "https://yourbackend.com/payhere/notify", // optional but recommended

      "order_id": "MEDILINK_${DateTime.now().millisecondsSinceEpoch}",
      "items": "Doctor Appointment - ${widget.doctorName}",
      "amount": widget.amount.toStringAsFixed(2),
      "currency": "LKR",

      "first_name": firstName,
      "last_name": lastName,
      "email": widget.appointmentData['email'] ?? "no-reply@medilink.app",
      "phone": widget.appointmentData['patientPhone'] ?? "0700000000",

      "address": widget.appointmentData['address'] ?? "Sri Lanka",
      "city": widget.appointmentData['city'] ?? "Colombo",
      "country": widget.appointmentData['country'] ?? "Sri Lanka",

      // optional delivery fields
      "delivery_address": widget.appointmentData['address'] ?? "Sri Lanka",
      "delivery_city": widget.appointmentData['city'] ?? "Colombo",
      "delivery_country": widget.appointmentData['country'] ?? "Sri Lanka",
    };
  }

  Future<void> _storePaymentRecord(
    String appointmentId,
    int tokenNumber,
    String payherePaymentId,
  ) async {
    try {
      final paymentId = 'PAY_${DateTime.now().millisecondsSinceEpoch}';

      final paymentRecord = {
        'paymentId': paymentId,
        'appointmentId': appointmentId,
        'scheduleId': widget.scheduleId,
        'doctorId': widget.doctorId,
        'patientId': widget.appointmentData['patientId'],
        'patientName': widget.appointmentData['patientName'],
        'amount': widget.amount,
        'appointmentType':
            widget.appointmentData['appointmentType'] ?? 'physical',
        'consultationType': _consultationType,
        'tokenNumber': tokenNumber,
        'payherePaymentId': payherePaymentId,
        'orderId': "MEDILINK_${DateTime.now().millisecondsSinceEpoch}",
        'paymentStatus': 'completed',
        'paidAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'doctorName': widget.doctorName,
        'doctorSpecialty': widget.doctorSpecialty,
        'medicalCenterName': widget.medicalCenterName,
        'appointmentDate': widget.selectedDate,
        'appointmentTime': widget.selectedTime,
      };

      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .set(paymentRecord);

      print('✅ Payment record stored: $paymentId');
    } catch (e) {
      print('❌ Error storing payment record: $e');
    }
  }

  // NEW METHOD: Store failed payment record
  Future<void> _storeFailedPaymentRecord(
    String payherePaymentId,
    String error,
  ) async {
    try {
      final paymentId = 'PAY_${DateTime.now().millisecondsSinceEpoch}';

      final paymentRecord = {
        'paymentId': paymentId,
        'amount': widget.amount,
        'currency': 'LKR',
        'appointmentType':
            widget.appointmentData['appointmentType'] ?? 'physical',
        'consultationType': _consultationType,
        'payherePaymentId': payherePaymentId,
        'paymentStatus': 'failed',
        'errorMessage': error,
        'failedAt': FieldValue.serverTimestamp(),
        'patientName': widget.appointmentData['patientName'],
        'doctorName': widget.doctorName,
        'date': _selectedDateOnly,
        'appointmentTime': widget.selectedTime,
      };

      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .set(paymentRecord);

      print('✅ Failed payment record stored: $paymentId');
    } catch (e) {
      print('❌ Error storing failed payment record: $e');
    }
  }

  // Start PayHere flow, return true if payment success
  Future<bool> _startPayHere() async {
    final paymentObject = _createPayHerePaymentObject();

    final completer = Completer<bool>();

    try {
      PayHere.startPayment(
        paymentObject,
        (paymentId) async {
          // Success callback
          print("✔ PAYHERE SUCCESS - paymentId: $paymentId");
          completer.complete(true);
        },
        (error) {
          // Error callback
          print("❌ PAYHERE ERROR - $error");
          completer.complete(false);
        },
        () {
          // Cancel callback
          print("⚠ PAYHERE CANCELED");
          completer.complete(false);
        },
      );
    } catch (e) {
      print("❌ PAYHERE start failed: $e");
      completer.complete(false);
    }

    // Wait for the callback
    return completer.future;
  }

  Future<void> _processPayment() async {
    if (_processingPayment) return;

    setState(() {
      _processingPayment = true;
    });

    String? payherePaymentId; // Declare the variable here

    try {
      print('💳 Starting PayHere payment...');
      final paymentOk = await _startPayHere();

      if (!paymentOk) {
        _showErrorSnackBar("Payment failed or canceled. Try again.");
        setState(() => _processingPayment = false);
        return;
      }

      print("💰 PayHere payment successful! Continuing booking flow...");

      // Generate a unique payment ID for PayHere
      payherePaymentId = 'PH${DateTime.now().millisecondsSinceEpoch}';

      // 1) Re-check schedule availability
      final scheduleSnap = await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .doc(widget.scheduleId)
          .get();

      if (!scheduleSnap.exists) {
        _showErrorSnackBar('Schedule not found. Please try again.');
        setState(() => _processingPayment = false);
        return;
      }

      final scheduleData = scheduleSnap.data()!;
      final currentBooked = (scheduleData['bookedAppointments'] as int?) ?? 0;
      final maxAppointments = (scheduleData['maxAppointments'] as int?) ?? 10;

      if (currentBooked >= maxAppointments) {
        _showErrorSnackBar('Sorry, this slot is no longer available.');
        setState(() => _processingPayment = false);
        return;
      }

      // 2) Assign token number
      print('🎫 Assigning token number after payment...');
      final tokenNumber = await _tokenService.assignTokenNumberForSchedule(
  widget.scheduleId,  // Pass scheduleId instead of doctorId
  widget.doctorId,
  _selectedDateOnly,
);
      print('Schedule Token assigned: $tokenNumber');

      // 3) Prepare updated appointment data
      final updatedAppointmentData = {
        ...widget.appointmentData,
        'tokenNumber': tokenNumber,
        'scheduleId': widget.scheduleId, 
        'queueStatus': 'waiting',
        'paymentStatus': 'paid',
        'status': 'confirmed',
        'paidAt': FieldValue.serverTimestamp(),
        'consultationType':
            widget.appointmentData['appointmentType'] ?? _consultationType,
        'doctorName': widget.doctorName,
        'doctorSpecialty': widget.doctorSpecialty,
        'medicalCenterName': widget.medicalCenterName,
        'appointmentDate': _selectedDateOnly,
        'selectedTime': widget.selectedTime,
        'paymentId': 'PAY_${DateTime.now().millisecondsSinceEpoch}',
      };

      // 4) Update bookedAppointments count (transaction to be safe)
      final scheduleRef = FirebaseFirestore.instance
          .collection('doctorSchedules')
          .doc(widget.scheduleId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final freshSnap = await tx.get(scheduleRef);
        if (!freshSnap.exists) throw Exception('Schedule disappeared');
        final freshData = freshSnap.data()!;
        final freshBooked = (freshData['bookedAppointments'] as int?) ?? 0;
        final freshMax = (freshData['maxAppointments'] as int?) ?? 10;
        if (freshBooked >= freshMax) {
          throw Exception('Slot full');
        }
        tx.update(scheduleRef, {
          'bookedAppointments': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // 5) Save appointment to Firestore
      final appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(updatedAppointmentData);

      print('✅ Appointment saved with ID: ${appointmentRef.id}');
      print('✅ Token $tokenNumber confirmed for appointment');

      // 6) Store payment record - CALL THE METHOD HERE
      await _storePaymentRecord(
        appointmentRef.id,
        tokenNumber,
        payherePaymentId!,
      );

      // 7) If telemedicine, create session
      final appointmentType =
          widget.appointmentData['appointmentType'] ?? 'physical';
      if (appointmentType == 'video' || appointmentType == 'audio') {
        await _createTelemedicineSession(appointmentRef.id, tokenNumber);
      }

      // 8) Store token locally
      await _tokenService.storeTokenLocally(widget.scheduleId, tokenNumber);

      // 9) Show success dialog
      _showSuccessDialog(tokenNumber, appointmentRef.id);
    } catch (e, st) {
      print('❌ Payment/Booking error: $e\n$st');

      // Store failed payment record if we have the PayHere payment ID
      if (payherePaymentId != null) {
        await _storeFailedPaymentRecord(payherePaymentId, e.toString());
      }

      // If runTransaction threw 'Slot full' or similar, show friendly message
      final msg = (e is Exception && e.toString().contains('Slot full'))
          ? 'Sorry, this slot was just taken. Your payment will be refunded by PayHere.'
          : 'Payment succeeded but booking failed. Contact support.';
      _showErrorSnackBar(msg);
    } finally {
      setState(() {
        _processingPayment = false;
      });
    }
  }

  // NEW METHOD: Create Telemedicine Session
  Future<void> _createTelemedicineSession(
    String appointmentId,
    int tokenNumber,
  ) async {
    try {
      print('🎥 Creating telemedicine session...');

      final telemedicineId = 'T${DateTime.now().millisecondsSinceEpoch}';
      final chatRoomId = 'C${DateTime.now().millisecondsSinceEpoch}';
      final consultationType =
          widget.appointmentData['appointmentType'] ?? 'video';

      final telemedicineSession = {
        'telemedicineId': telemedicineId,
        'doctorId': widget.doctorId,
        'patientId': widget.appointmentData['patientId'],
        'chatRoomId': chatRoomId,
        'videoLink': 'https://medilink.app/call/$telemedicineId',
        'date': _selectedDateOnly,
        'timeSlot': widget.selectedTime,
        'status': 'Scheduled',
        'createdAt': DateTime.now().toIso8601String(),
        'appointmentId': appointmentId,
        'tokenNumber': tokenNumber,
        'consultationType': consultationType,
        'doctorName': widget.doctorName,
        'doctorSpecialty': widget.doctorSpecialty,
        'patientName': widget.appointmentData['patientName'],
        'medicalCenterName': widget.medicalCenterName,
      };

      await FirebaseFirestore.instance
          .collection('telemedicine_sessions')
          .doc(appointmentId)
          .set(telemedicineSession);
      // Update/create a "sessions" collection with this scheduleId;
      // Each session document will store the scheduleId and an array of all appointmentIds for this schedule
      final scheduleId = widget.scheduleId;

      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(scheduleId);

      // Use a Firestore transaction to add appointmentId to the appointments array for this session
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final sessionSnapshot = await transaction.get(sessionRef);
        if (!sessionSnapshot.exists) {
          // Create new session doc with this appointmentId in appointments list
          transaction.set(sessionRef, {
            'scheduleId': scheduleId,
            'appointmentIds': [appointmentId],
            'createdAt': DateTime.now().toIso8601String(),
          });
        } else {
          // Update existing session doc by adding appointmentId (avoid duplicates)
          final data = sessionSnapshot.data() as Map<String, dynamic>;
          final List<dynamic> currentAppointments =
              (data['appointmentIds'] ?? []);
          if (!currentAppointments.contains(appointmentId)) {
            transaction.update(sessionRef, {
              'appointmentIds': FieldValue.arrayUnion([appointmentId]),
            });
          }
        }
      });

      print('✅ Telemedicine session created: $telemedicineId');

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
      // Do not fail the whole flow if this fails
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
            Text('Booking Confirmed!',style: TextStyle(fontSize: 12),),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doctor: Dr. ${widget.doctorName}'),
              Text('Schedule: ${widget.selectedTime}'),
              Text('Date: ${widget.selectedDate}'),
              const SizedBox(height: 16),
              
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
                      'Your Schedule Token',
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
                    
                    // Schedule-specific info
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.schedule, size: 24, color: Colors.blue),
                          const SizedBox(height: 4),
                          Text(
                            widget.selectedTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            'Time Slot',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    Text(
                      'You are token #$tokenNumber in the ${widget.selectedTime} schedule',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Important:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '• This token (#$tokenNumber) is for the ${widget.selectedTime} schedule only',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '• Other time slots have their own token sequence starting from 1',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '• Arrive at least 15 minutes before your scheduled time',
                style: const TextStyle(fontSize: 12),
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
        duration: const Duration(seconds: 4),
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
      case 'physical':
        return 'Physical Visit';
      case 'audio':
        return 'Audio Call';
      case 'video':
        return 'Video Call';
      default:
        return 'Physical Visit';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                    _buildDetailRow('Doctor', 'Dr. ${widget.doctorName}'),
                    _buildDetailRow('Specialty', widget.doctorSpecialty),
                    _buildDetailRow('Medical Center', widget.medicalCenterName),
                    _buildDetailRow('Date', widget.selectedDate),
                    _buildDetailRow('Time', widget.selectedTime),
                    _buildDetailRow(
                      'Appointment Type',
                      _formatConsultationType(
                        widget.appointmentData['appointmentType'] ?? 'physical',
                      ),
                    ),
                    _buildDetailRow('Token', 'Will be assigned after payment'),
                    if (widget.appointmentData['patientNotes'] != null &&
                        widget.appointmentData['patientNotes']
                            .toString()
                            .isNotEmpty)
                      _buildDetailRow(
                        'Your Notes',
                        widget.appointmentData['patientNotes'],
                      ),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing Payment...'),
                        ],
                      )
                    : const Text(
                        'Pay Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                    '• No refunds after the payments\n',
                    style: TextStyle(fontSize: 12, color: Color(0xFF18A3B6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
