import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_screen.dart';

class BookAppointmentPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String selectedDate;
  final String selectedTime;
  final String medicalCenterId;
  final String medicalCenterName;
  final double doctorFees;
  final String scheduleId;
  
  const BookAppointmentPage({Key? key, 
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.selectedDate,
    required this.selectedTime,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.doctorFees,
    required this.scheduleId,
  }) : super(key: key);

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  final TextEditingController notesController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  
  String selectedConsultationType = 'physical';
  bool _checkingAvailability = false;
  bool _isSlotAvailable = false;
  int _bookedAppointments = 0;
  int _maxAppointments = 0;
  bool _processingBooking = false;
    double _medicalCenterFees = 0.0;
  double get _totalAmount => widget.doctorFees + _medicalCenterFees;
  bool _loadingMedicalCenterFees = false;
  
  
  List<String> availableConsultationTypes = ['physical']; 
  String scheduleAppointmentType = 'physical'; 
  List<String> scheduleTelemedicineTypes = []; 
  String _searchQuery = '';
  List<String> _filteredConsultationTypes = [];
  bool _showSearchBar = false;


  @override
  void initState() {
    super.initState();
    _checkAppointmentAvailability();
    _loadMedicalCenterFees();
    searchController.addListener(_onSearchChanged);
  }
@override
void dispose() {
  searchController.dispose(); // Add this line
  super.dispose();
}
void _onSearchChanged() {
  setState(() {
    _searchQuery = searchController.text.toLowerCase();
    _filterConsultationTypes();
  });
}
Future<void> _loadMedicalCenterFees() async {
  try {
    print('🔄 START: Loading medical center fees...');
    
    if (isMounted) {
      setState(() {
        _loadingMedicalCenterFees = true;
      });
    }

    // ADD THESE DEBUG PRINTS
    print('📋 Medical Center Details from Widget:');
    print('   - ID: ${widget.medicalCenterId}');
    print('   - Name: ${widget.medicalCenterName}');
    print('   - Expected Document ID: Pm7dsLwhLda5NHaBcIRKEq7QpSV2');

    // Check if medicalCenterId is valid
    if (widget.medicalCenterId.isEmpty) {
      print('❌ ERROR: Medical Center ID is empty!');
      if (isMounted) {
        setState(() {
          _medicalCenterFees = 0.0;
        });
      }
      return;
    }

    print('🔍 Querying Firestore for medical center...');
    print('   - Collection: medicalCenters');
    print('   - Document ID: ${widget.medicalCenterId}');

    final medicalCenterDoc = await FirebaseFirestore.instance
        .collection('medical_centers')
        .doc(widget.medicalCenterId)
        .get();

    print('📄 Firestore Response:');
    print('   - Document exists: ${medicalCenterDoc.exists}');
    
    if (medicalCenterDoc.exists) {
      final data = medicalCenterDoc.data()!;
      print('   - Document ID in Firestore: ${medicalCenterDoc.id}');
      print('   - All fields: ${data.keys.join(', ')}');
      print('   - testFees value: ${data['testFees']}');
      print('   - testFees type: ${data['testFees']?.runtimeType}');
      print('   - name value: ${data['name']}');
      
      final testFees = (data['testFees'] as num?)?.toDouble() ?? 0.0;
      
      print('💰 Fee Calculation:');
      print('   - Raw testFees from Firestore: ${data['testFees']}');
      print('   - Converted to double: $testFees');
      
      if (isMounted) {
        setState(() {
          _medicalCenterFees = testFees;
        });
      }
      
      print('✅ SUCCESS: Medical Center Fees = Rs. $_medicalCenterFees');
      print('✅ SUCCESS: Doctor Fees = Rs. ${widget.doctorFees}');
      print('✅ SUCCESS: Total Amount = Rs. $_totalAmount');
    } else {
      print('❌ ERROR: No document found with ID: ${widget.medicalCenterId}');
      print('❌ Expected document ID: Pm7dsLwhLda5NHaBcIRKEq7QpSV2');
      print('❌ But received: ${widget.medicalCenterId}');
      print('❌ IDs do not match!');
    }
  } catch (e) {
    print('❌ EXCEPTION: Error loading medical center fees: $e');
  } finally {
    if (isMounted) {
      setState(() {
        _loadingMedicalCenterFees = false;
      });
    }
    print('🏁 FINISHED: Loading medical center fees completed');
  }
}
void _filterConsultationTypes() {
  if (_searchQuery.isEmpty) {
    _filteredConsultationTypes = availableConsultationTypes;
  } else {
    _filteredConsultationTypes = availableConsultationTypes.where((type) {
      final formattedType = _formatConsultationType(type).toLowerCase();
      return formattedType.contains(_searchQuery);
    }).toList();
  }
}

void _toggleSearchBar() {
  setState(() {
    _showSearchBar = !_showSearchBar;
    if (!_showSearchBar) {
      searchController.clear();
      _searchQuery = '';
      _filterConsultationTypes();
    }
  });
}
  
  bool get isMounted => mounted;

  Future<void> _checkAppointmentAvailability() async {
    try {
     if (isMounted) {
  setState(() {
    _isSlotAvailable = _bookedAppointments < _maxAppointments;
    _checkingAvailability = false;
    if (availableConsultationTypes.isNotEmpty) {
      selectedConsultationType = availableConsultationTypes.first;
    }
    _filterConsultationTypes(); 
  });
}


      print('🔍 Checking appointment availability...');
      print('📅 Schedule ID: ${widget.scheduleId}');
      print('📅 Selected Date: ${widget.selectedDate}');

      if (widget.scheduleId.isEmpty) {
        if (isMounted) {
          setState(() {
            _isSlotAvailable = false;
            _checkingAvailability = false;
          });
        }
        return;
      }

      final scheduleDoc = await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .doc(widget.scheduleId)
          .get();

      if (!scheduleDoc.exists) {
        if (isMounted) {
          setState(() {
            _isSlotAvailable = false;
            _checkingAvailability = false;
          });
        }
        return;
      }

      final scheduleData = scheduleDoc.data()!;
      _maxAppointments = (scheduleData['maxAppointments'] as int? ?? 10);
      _bookedAppointments = (scheduleData['bookedAppointments'] as int? ?? 0);
      
      // MARK: Get appointment type and telemedicine types from schedule
      scheduleAppointmentType = scheduleData['appointmentType'] as String? ?? 'physical';
      scheduleTelemedicineTypes = List<String>.from(scheduleData['telemedicineTypes'] ?? []);
      
      // MARK: Determine available consultation types based on schedule
      _updateAvailableConsultationTypes();

      print('📊 Schedule Details:');
      print('   Max Appointments: $_maxAppointments');
      print('   Booked Appointments: $_bookedAppointments');
      print('   Available: ${_bookedAppointments < _maxAppointments}');
      print('   Appointment Type: $scheduleAppointmentType');
      print('   Telemedicine Types: $scheduleTelemedicineTypes');
      print('   Available Consultation Types: $availableConsultationTypes');

      if (isMounted) {
        setState(() {
          _isSlotAvailable = _bookedAppointments < _maxAppointments;
          _checkingAvailability = false;
          // Set default selection to first available type
          if (availableConsultationTypes.isNotEmpty) {
            selectedConsultationType = availableConsultationTypes.first;
          }
        });
      }

    } catch (e) {
      print('❌ Error checking availability: $e');
      if (isMounted) {
        setState(() {
          _isSlotAvailable = false;
          _checkingAvailability = false;
        });
      }
    }
  }

  // MARK: New method to determine available consultation types
  void _updateAvailableConsultationTypes() {
    if (scheduleAppointmentType == 'physical') {
      // If doctor scheduled physical, only show physical
      availableConsultationTypes = ['physical'];
    } else if (scheduleAppointmentType == 'telemedicine') {
      // If doctor scheduled telemedicine, show only the telemedicine types they selected
      availableConsultationTypes = scheduleTelemedicineTypes;
      
      // If doctor didn't select any telemedicine types (fallback), show both
      if (availableConsultationTypes.isEmpty) {
        availableConsultationTypes = ['audio', 'video'];
      }
    } else {
      // Fallback to physical
      availableConsultationTypes = ['physical'];
    }
  }

  // Main booking method - NO TOKEN ASSIGNMENT BEFORE PAYMENT
  Future<void> _confirmBooking() async {
    if (!_isSlotAvailable) {
      _showErrorSnackBar('This appointment slot is no longer available.');
      return;
    }

    if (_checkingAvailability || _processingBooking) {
      _showErrorSnackBar('Please wait while we process your request...');
      return;
    }

    if (widget.scheduleId.isEmpty) {
      _showErrorSnackBar('Schedule information not found.');
      return;
    }

    // MARK: Validate selected consultation type is allowed
    if (!availableConsultationTypes.contains(selectedConsultationType)) {
      _showErrorSnackBar('Selected consultation type is not available for this schedule.');
      return;
    }

    if (isMounted) {
      setState(() {
        _processingBooking = true;
      });
    }

    try {
      print('🔍 Double-checking availability before booking...');
      
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
      
      print('   Current Booked: $currentBooked');
      print('   Max Appointments: $maxAppointments');
      
      if (currentBooked >= maxAppointments) {
        _showErrorSnackBar('Sorry, this slot has just been booked by someone else. Please choose another time.');
        return;
      }

      // Generate QR data
      final qrData = _generateQRData();

    
      final appointmentData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorName,
        'doctorSpecialty': widget.doctorSpecialty,
        'medicalCenterId': widget.medicalCenterId,
        'medicalCenterName': widget.medicalCenterName,
        'date': widget.selectedDate,
        'time': widget.selectedTime,
        'appointmentType': selectedConsultationType,
        'patientNotes': notesController.text.trim(),
        'fees': _totalAmount.toString(),
        'doctorFees': widget.doctorFees.toString(),
        'medicalCenterFees': _medicalCenterFees.toString(), 
        'status': 'pending',
        'paymentStatus': 'pending',
        'scheduleId': widget.scheduleId,
        'createdAt': FieldValue.serverTimestamp(),
        'queueStatus': 'waiting',
        'qrCodeData': qrData,
        'currentQueueNumber': 0,
      };

      print('✅ Proceeding to payment');
      print('   Schedule ID: ${widget.scheduleId}');
      print('   Current Booked: $currentBooked');
      print('   Will update to: ${currentBooked + 1}');
      print('   Selected Consultation Type: $selectedConsultationType');
      print('   Token: Will be assigned after payment');

      // Navigate to payment screen and wait for result
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            appointmentData: appointmentData,
            
            amount: _totalAmount,
            doctorName: widget.doctorName,
            doctorSpecialty: widget.doctorSpecialty,
            selectedDate: widget.selectedDate,
            selectedTime: widget.selectedTime,
            medicalCenterName: widget.medicalCenterName,
            scheduleId: widget.scheduleId,
            doctorId: widget.doctorId,
          ),
        ),
      );

      
      if (isMounted) {
        await _checkAppointmentAvailability();
      }

    } catch (e) {
      print('❌ Error during booking process: $e');
      _showErrorSnackBar('An error occurred during booking. Please try again.');
    } finally {
      
      if (isMounted) {
        setState(() {
          _processingBooking = false;
        });
      }
    }
  }

  // QR data generation
  String _generateQRData() {
    return 'appointment_${widget.patientId}_${widget.doctorId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _showErrorSnackBar(String message) {
    if (isMounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Appointment'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show booking process indicator
            if (_processingBooking)
              _buildBookingInProgressIndicator(),

            // Availability Status
            if (_checkingAvailability)
              _buildLoadingIndicator(),
            
            if (!_checkingAvailability && !_isSlotAvailable)
              _buildSlotUnavailableWarning(),

            if (!_checkingAvailability && _isSlotAvailable)
              _buildSlotAvailableInfo(),

            // Appointment Summary
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointment Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryItem('Doctor', 'Dr. ${widget.doctorName}'),
                    _buildSummaryItem('Specialty', widget.doctorSpecialty),
                    _buildSummaryItem('Medical Center', widget.medicalCenterName),
                    _buildSummaryItem('Date', widget.selectedDate),
                    _buildSummaryItem('Time', widget.selectedTime),
                    _buildSummaryItem('Schedule Type', _formatScheduleType()),
                    _buildSummaryItem('Token Number', 'Will be assigned after payment'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // MARK: Updated Consultation Type Section
            if (availableConsultationTypes.length > 1) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Consultation Type',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getConsultationTypeDescription(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: availableConsultationTypes.map((type) {
                          return Expanded(
                            child: RadioListTile<String>(
                              title: Text(
                                _formatConsultationType(type),
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: type,
                              groupValue: selectedConsultationType,
                              onChanged: (_isSlotAvailable && !_processingBooking) ? (value) {
                                setState(() {
                                  selectedConsultationType = value!;
                                });
                              } : null,
                              contentPadding: EdgeInsets.zero,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (availableConsultationTypes.length == 1) ...[
              
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Consultation Type',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18A3B6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getConsultationTypeIcon(availableConsultationTypes.first),
                              color: const Color(0xFF18A3B6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatConsultationType(availableConsultationTypes.first),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF18A3B6),
                                    ),
                                  ),
                                  Text(
                                    _getConsultationTypeDescription(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Notes
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Notes (Optional)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      enabled: _isSlotAvailable && !_processingBooking,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Any specific concerns or symptoms...',
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSlotAvailable && !_checkingAvailability && !_processingBooking) 
                    ? _confirmBooking 
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isSlotAvailable && !_processingBooking) 
                      ? const Color(0xFF18A3B6)
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _processingBooking
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
                          Text('Processing...'),
                        ],
                      )
                    : const Text(
                        'Confirm & Proceed to Payment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            // Price
            if (_isSlotAvailable)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Doctor Fees
                    _buildFeeRow('Doctor Consultation Fee', widget.doctorFees),
                    
                    // Medical Center Fees
                    if (_loadingMedicalCenterFees)
                      _buildLoadingFeeRow()
                    else
                      _buildFeeRow('Medical Center Facility Fee', _medicalCenterFees),
                    
                    const Divider(height: 20, color: Colors.green),
                    
                    // Total Amount
                    _buildTotalRow(_totalAmount),
                    
                    const SizedBox(height: 8),
                    const Text(
                      'Token number will be assigned after successful payment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // Important Information
            if (_isSlotAvailable)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
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
                        Icon(Icons.info, size: 16, color: Color(0xFF18A3B6)),
                        SizedBox(width: 8),
                        Text(
                          'Important Information',
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
                      '• Token number will be assigned after payment\n'
                      '• Show your token at the clinic for queue management\n'
                      '• Arrive 15 minutes before your appointment time\n'
                      '• Cancel at least 2 hours before for refund',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                  ],
                ),
              ),
          ], 
        ), 
      ), 
    ); 
  }


  String _formatScheduleType() {
    if (scheduleAppointmentType == 'physical') {
      return 'Physical Consultation';
    } else if (scheduleAppointmentType == 'telemedicine') {
      if (scheduleTelemedicineTypes.length == 1) {
        return 'Telemedicine (${_formatConsultationType(scheduleTelemedicineTypes.first)})';
      } else if (scheduleTelemedicineTypes.length == 2) {
        return 'Telemedicine (Audio/Video)';
      } else {
        return 'Telemedicine Consultation';
      }
    } else {
      return 'Consultation';
    }
  }

  String _getConsultationTypeDescription() {
    if (scheduleAppointmentType == 'physical') {
      return 'In-person consultation at the medical center';
    } else if (scheduleAppointmentType == 'telemedicine') {
      if (availableConsultationTypes.length == 1) {
        return 'Remote ${_formatConsultationType(availableConsultationTypes.first)} consultation';
      } else {
        return 'Choose your preferred telemedicine type';
      }
    } else {
      return 'Consultation';
    }
  }
Widget _buildFeeRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.green,
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingFeeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Medical Center Facility Fee',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green,
            ),
          ),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(double totalAmount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        Text(
          'Rs. ${totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
  IconData _getConsultationTypeIcon(String type) {
    switch (type) {
      case 'physical': return Icons.local_hospital;
      case 'audio': return Icons.audiotrack;
      case 'video': return Icons.videocam;
      default: return Icons.medical_services;
    }
  }

  // Booking in progress indicator
  Widget _buildBookingInProgressIndicator() {
    return Card(
      color: const Color(0xFFFFF9C4),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: Colors.orange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Processing Your Booking',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'Available slots: ${_maxAppointments - _bookedAppointments}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Loading indicator
  Widget _buildLoadingIndicator() {
    return Card(
      color: Colors.blue[50],
      elevation: 4,
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF18A3B6)),
            ),
            SizedBox(width: 16),
            Text('Checking availability...'),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotUnavailableWarning() {
    return Card(
      color: Colors.red[50],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appointment Not Available',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    'No slots available ($_bookedAppointments/$_maxAppointments booked)',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please select a different date or time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotAvailableInfo() {
    return Card(
      color: Colors.green[50],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Slot Available ✓',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '${_maxAppointments - _bookedAppointments} slots available ($_bookedAppointments/$_maxAppointments booked)',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule Type: ${_formatScheduleType()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF18A3B6),
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
      default: return type;
    }
  }
}
