import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/Cancellation_Service.dart';
import 'package:intl/intl.dart';


class TokenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> assignTokenNumber(String doctorId, String date) async {
    try {
      final queueDocRef = _firestore
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date');

      return await _firestore.runTransaction<int>((transaction) async {
        final queueDoc = await transaction.get(queueDocRef);
        
        int newTokenNumber;
        
        if (queueDoc.exists) {
          newTokenNumber = (queueDoc.data()!['lastTokenNumber'] ?? 0) + 1;
          transaction.update(queueDocRef, {
            'lastTokenNumber': newTokenNumber,
            'totalAppointments': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          newTokenNumber = 1;
          transaction.set(queueDocRef, {
            'doctorId': doctorId,
            'date': date,
            'lastTokenNumber': newTokenNumber,
            'currentServingToken': 0,
            'totalAppointments': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        print('🎫 Token assigned: $newTokenNumber for Dr. $doctorId on $date');
        return newTokenNumber;
      });
    } catch (e) {
      print('Error assigning token number: $e');
      rethrow;
    }
  }

  // FIXED: Token adjustment for cancellations with robust error handling
  Future<void> adjustTokensAfterCancellation(String doctorId, String date, int cancelledTokenNumber) async {
    try {
      print('🔄 Adjusting tokens after cancellation...');
      print('   Doctor: $doctorId, Date: $date, Cancelled Token: $cancelledTokenNumber');

      final queueDocRef = _firestore
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date');

      // First check if queue document exists
      final queueDoc = await queueDocRef.get();
      if (!queueDoc.exists) {
        print('⚠️ Queue document not found, no tokens to adjust');
        return;
      }

      final queueData = queueDoc.data()!;
      final lastTokenNumber = queueData['lastTokenNumber'] ?? 0;
      
      print('   Current last token: $lastTokenNumber');
      print('   Cancelled token: $cancelledTokenNumber');

      // If no tokens exist or cancelled token is invalid, just return
      if (lastTokenNumber == 0 || cancelledTokenNumber <= 0) {
        print('⚠️ No valid tokens to adjust');
        return;
      }

      // If cancelled token is the last one, simple decrement
      if (cancelledTokenNumber == lastTokenNumber) {
        await queueDocRef.update({
          'lastTokenNumber': lastTokenNumber - 1,
          'totalAppointments': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Cancelled last token, simple decrement');
        return;
      }

      // Get all appointments for this doctor-date to adjust tokens
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: ['confirmed', 'pending'])
          .where('tokenNumber', isGreaterThan: cancelledTokenNumber)
          .orderBy('tokenNumber')
          .get();

      print('   Found ${appointmentsQuery.docs.length} appointments to adjust');

      // Use batch write instead of transaction for better reliability
      final batch = _firestore.batch();

      // Adjust tokens for all appointments after the cancelled one
      for (var doc in appointmentsQuery.docs) {
        final appointmentData = doc.data();
        final currentToken = appointmentData['tokenNumber'] as int?;
        
        if (currentToken != null && currentToken > cancelledTokenNumber) {
          final newToken = currentToken - 1;
          batch.update(doc.reference, {
            'tokenNumber': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('   Adjusted token $currentToken → $newToken for ${appointmentData['patientName']}');
        }
      }

      // Update queue counters
      batch.update(queueDocRef, {
        'lastTokenNumber': lastTokenNumber - 1,
        'totalAppointments': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();

      print('✅ Token adjustment completed');
      print('   New last token: ${lastTokenNumber - 1}');

    } catch (e) {
      print('❌ Error adjusting tokens after cancellation: $e');
      // Don't rethrow - allow cancellation to proceed even if token adjustment fails
      print('⚠️ Continuing with cancellation without token adjustment');
    }
  }
}

class MyAppointmentsPage extends StatefulWidget {
  final String patientId;
  
  const MyAppointmentsPage({Key? key, required this.patientId}) : super(key: key);

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;
  String errorMessage = '';
  final TokenService _tokenService = TokenService();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          errorMessage = 'Please log in to view appointments';
          isLoading = false;
        });
        return;
      }

      print('🔍 Loading appointments for patient: ${widget.patientId}');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('createdAt', descending: true)
          .get();

      print('✅ Found ${querySnapshot.docs.length} appointments');

      List<Map<String, dynamic>> appointmentsList = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        appointmentsList.add({
          'id': doc.id,
          'patientId': data['patientId'],
          'patientName': data['patientName'] ?? 'Patient',
          'doctorId': data['doctorId'],
          'doctorName': data['doctorName'] ?? 'Doctor',
          'doctorSpecialty': data['doctorSpecialty'] ?? 'General Practitioner',
          'medicalCenterName': data['medicalCenterName'] ?? 'Medical Center',
          'date': data['date'] ?? 'Not specified',
          'time': data['time'] ?? 'Not specified',
          'appointmentType': data['appointmentType'] ?? 'physical',
          'patientNotes': data['patientNotes'] ?? '',
          'fees': data['fees'] ?? '0',
          'status': data['status'] ?? 'requested',
          'paymentStatus': data['paymentStatus'] ?? 'pending',
          'paymentMethod': data['paymentMethod'] ?? 'Not specified',
          'createdAt': data['createdAt'] ?? Timestamp.now(),
          'tokenNumber': data['tokenNumber'] ?? 0,
          'queueStatus': data['queueStatus'] ?? 'waiting',
          'qrCodeData': data['qrCodeData'] ?? '',
          'currentQueueNumber': data['currentQueueNumber'] ?? 0,
          'scheduleId': data['scheduleId'] ?? '',
        });
      }

      setState(() {
        appointments = appointmentsList;
      });

      // Debug: Print all appointments and their categories
      print('📊 ALL APPOINTMENTS:');
      for (var apt in appointments) {
        print(' - ${apt['doctorName']} | Date: ${apt['date']} | Status: ${apt['status']} | Token: ${apt['tokenNumber']}');
      }
      
      print('📈 UPCOMING: ${_getUpcomingAppointments().length}');
      print('📈 PAST: ${_getPastAppointments().length}');
      print('📈 CANCELLED: ${_getCancelledAppointments().length}');

    } catch (e) {
      print('❌ Error loading appointments: $e');
      setState(() {
        errorMessage = 'Failed to load appointments. Please check your internet connection.';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }
  // ✅ ADD THIS METHOD: Refresh token numbers for all appointments
// ✅ FIXED: Better token refresh with real-time updates
Future<void> _refreshTokenNumbers() async {
  try {
    print('🔄 Refreshing ALL token numbers...');
    
    // Get fresh data from Firestore
    final querySnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: widget.patientId)
        .orderBy('createdAt', descending: true)
        .get();

    // Create a map of fresh data
    final freshAppointments = <String, Map<String, dynamic>>{};
    for (var doc in querySnapshot.docs) {
      freshAppointments[doc.id] = {...doc.data(), 'id': doc.id};
    }

    // Update local appointments with fresh data
    bool hasChanges = false;
    for (int i = 0; i < appointments.length; i++) {
      final localAppt = appointments[i];
      final freshAppt = freshAppointments[localAppt['id']];
      
      if (freshAppt != null) {
        // Check for token number changes
        final freshToken = freshAppt['tokenNumber'] ?? 0;
        final localToken = localAppt['tokenNumber'] ?? 0;
        
        if (freshToken != localToken) {
          appointments[i]['tokenNumber'] = freshToken;
          hasChanges = true;
          print('   🔄 Token updated: $localToken → $freshToken for ${localAppt['doctorName']}');
        }

        // Check for status changes
        final freshStatus = freshAppt['status'] ?? '';
        final localStatus = localAppt['status'] ?? '';
        if (freshStatus != localStatus) {
          appointments[i]['status'] = freshStatus;
          hasChanges = true;
        }
      }
    }

    if (hasChanges && mounted) {
      setState(() {});
      print('✅ Token refresh completed with changes');
    }

  } catch (e) {
    print('❌ Error refreshing tokens: $e');
  }
}

// ✅ UPDATED: Cancel appointment with token refresh
// ✅ FIXED: Complete cancel appointment method
// ✅ ENHANCED: Complete cancel appointment method with dynamic token management
// ✅ FIXED: Complete cancellation with dynamic token renumbering
Future<void> _cancelAppointment(String appointmentId, Map<String, dynamic> appointment) async {
  try {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final tokenNumber = appointment['tokenNumber'] ?? 0;
        return AlertDialog(
          title: const Text('Cancel Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cancel appointment with Dr. ${appointment['doctorName']}?'),
              const SizedBox(height: 8),
              Text('Date: ${appointment['date']} | Time: ${appointment['time']}'),
              if (tokenNumber > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Token #$tokenNumber will be cancelled',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Other patients tokens will be automatically renumbered',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Appointment'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Appointment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    final tokenNumber = appointment['tokenNumber'] as int?;
    final doctorId = appointment['doctorId'];
    final date = appointment['date'];
    final scheduleId = appointment['scheduleId'];

    print('🔄 STARTING CANCELLATION PROCESS...');
    print('   Appointment: $appointmentId');
    print('   Token: $tokenNumber, Doctor: $doctorId, Date: $date');

    // ✅ STEP 1: Update appointment status first
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'queueStatus': 'cancelled',
    });
    print('✅ Appointment status updated to cancelled');

    // ✅ STEP 2: Decrease slot count in doctorSchedules
    final scheduleDoc = await FirebaseFirestore.instance
        .collection('doctorSchedules')
        .doc(scheduleId)
        .get();

    if (scheduleDoc.exists) {
      final currentBooked = (scheduleDoc.data()!['bookedAppointments'] as int? ?? 0);
      final newBookedCount = currentBooked > 0 ? currentBooked - 1 : 0;
      
      await FirebaseFirestore.instance
          .collection('doctorSchedules')
          .doc(scheduleId)
          .update({
        'bookedAppointments': newBookedCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('📊 Slot count updated: $currentBooked → $newBookedCount');
    }

    // ✅ STEP 3: DYNAMIC TOKEN RENUMBERING (THE MAIN FIX)
    if (tokenNumber != null && tokenNumber > 0) {
      print('🔄 Starting dynamic token renumbering...');
      
      // Get all appointments with higher token numbers
      final appointmentsToUpdate = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: ['confirmed', 'pending'])
          .where('tokenNumber', isGreaterThan: tokenNumber)
          .orderBy('tokenNumber')
          .get();

      print('📝 Found ${appointmentsToUpdate.docs.length} appointments to renumber');

      // Update each appointment's token number (shift down by 1)
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in appointmentsToUpdate.docs) {
        final currentToken = doc.data()['tokenNumber'] as int?;
        if (currentToken != null && currentToken > tokenNumber) {
          final newTokenNumber = currentToken - 1;
          batch.update(doc.reference, {
            'tokenNumber': newTokenNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('   🔄 Token $currentToken → $newTokenNumber for ${doc.data()['patientName']}');
        }
      }

      // Update queue document
      final queueDocRef = FirebaseFirestore.instance
          .collection('doctorDailyQueue')
          .doc('${doctorId}_$date');

      final queueDoc = await queueDocRef.get();
      if (queueDoc.exists) {
        batch.update(queueDocRef, {
          'lastTokenNumber': FieldValue.increment(-1),
          'totalAppointments': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Dynamic token renumbering completed');
    }

    // ✅ STEP 4: Refresh data
    await _loadAppointments();
    await _refreshTokenNumbers();

    // ✅ STEP 5: Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Appointment cancelled successfully!'),
              if (tokenNumber != null && tokenNumber > 0)
                const Text(
                  'Token has been freed and other tokens renumbered',
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Switch to cancelled tab
      _tabController.animateTo(2);
    }

  } catch (e) {
    print('❌ Error cancelling appointment: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}

  // FIXED: Simplified appointment filtering logic
  List<Map<String, dynamic>> _getUpcomingAppointments() {
    return appointments.where((apt) {
      final status = apt['status']?.toString() ?? '';
      // Upcoming appointments are confirmed/pending and not completed/cancelled
      return (status == 'confirmed' || status == 'pending') && status != 'completed' && status != 'cancelled';
    }).toList();
  }

  List<Map<String, dynamic>> _getPastAppointments() {
    return appointments.where((apt) {
      final status = apt['status']?.toString() ?? '';
      return status == 'completed';
    }).toList();
  }

  List<Map<String, dynamic>> _getCancelledAppointments() {
    return appointments.where((apt) {
      return apt['status']?.toString() == 'cancelled';
    }).toList();
  }

  // FIXED: Removed complex date parsing that was causing issues
  DateTime? _extractDateFromString(String dateString) {
    try {
      // Try to extract date from formats like "Tomorrow (10/10/2025)"
      final regex = RegExp(r'(\d{1,2}/\d{1,2}/\d{4})');
      final match = regex.firstMatch(dateString);
      if (match != null) {
        final datePart = match.group(1);
        return DateFormat('dd/MM/yyyy').parse(datePart!);
      }
      
      // Try standard date format
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _getUpcomingAppointments();
    final past = _getPastAppointments();
    final cancelled = _getCancelledAppointments();
    
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: _buildTabWithBadge('Upcoming', upcoming.length),
            ),
            Tab(
              child: _buildTabWithBadge('Past', past.length),
            ),
            Tab(
              child: _buildTabWithBadge('Cancelled', cancelled.length),
            ),
          ],
        ),
      ),
      body: errorMessage.isNotEmpty
          ? _buildErrorState()
          : _buildTabContent(upcoming, past, cancelled),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Navigate to Book Appointment Screen'),
              backgroundColor: Color(0xFF18A3B6),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Book New'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTabContent(List<Map<String, dynamic>> upcoming, List<Map<String, dynamic>> past, List<Map<String, dynamic>> cancelled) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAppointmentsList(upcoming, 'upcoming'),
        _buildAppointmentsList(past, 'past'),
        _buildAppointmentsList(cancelled, 'cancelled'),
      ],
    );
  }

  Widget _buildTabWithBadge(String title, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFF18A3B6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: const Color(0xFF85CEDA).withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connection Issue',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadAppointments,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(List<Map<String, dynamic>> appointmentList, String type) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF18A3B6)),
        ),
      );
    }
    
    if (appointmentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(type),
              size: 64,
              color: const Color(0xFFB2DEE6),
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(type),
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF18A3B6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptySubMessage(type),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF85CEDA),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      backgroundColor: const Color(0xFFDDF0F5),
      color: const Color(0xFF18A3B6),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointmentList.length,
        itemBuilder: (context, index) {
          final appointment = appointmentList[index];
          return _buildAppointmentCard(appointment, type);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, String type) {
    final statusColor = _getStatusColor(appointment['status']);
    final dateStr = appointment['date']?.toString() ?? '';
    final isTomorrow = dateStr.toLowerCase().contains('tomorrow');
    final tokenNumber = appointment['tokenNumber'] ?? 0;
    final queueStatus = appointment['queueStatus'] ?? 'waiting';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFDDF0F5).withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Info and Status
              Row(
                children: [
                  // Token number badge for upcoming appointments
                  if (tokenNumber > 0 && type == 'upcoming')
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18A3B6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#$tokenNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Token',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    CircleAvatar(
                      backgroundColor: const Color(0xFF32BACD),
                      child: Text(
                        _getDoctorInitials(appointment['doctorName']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment['doctorName'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18A3B6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          appointment['doctorSpecialty'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF85CEDA),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      appointment['status'].toString().toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Queue status for upcoming appointments
              if (tokenNumber > 0 && type == 'upcoming')
                _buildQueueStatusRow(queueStatus, tokenNumber, appointment['currentQueueNumber'] ?? 0),
              
              // Medical Center
              _buildDetailRow(Icons.location_on, appointment['medicalCenterName']),
              const SizedBox(height: 8),
              
              // Date with Tomorrow indicator
              Row(
                children: [
                  Icon(
                    Icons.calendar_today, 
                    size: 16, 
                    color: isTomorrow ? const Color(0xFF32BACD) : const Color(0xFF85CEDA),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment['date'],
                      style: TextStyle(
                        fontSize: 14,
                        color: isTomorrow ? const Color(0xFF32BACD) : const Color(0xFF18A3B6),
                        fontWeight: isTomorrow ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isTomorrow) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF32BACD).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'TOMORROW',
                        style: TextStyle(
                          color: const Color(0xFF32BACD),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              // Time and Appointment Type
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 360;
                  
                  return Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: const Color(0xFF85CEDA)),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(appointment['time']),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        _getConsultationIcon(appointment['appointmentType']), 
                        size: 16, 
                        color: const Color(0xFF85CEDA),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatConsultationType(appointment['appointmentType']),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF18A3B6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              // Fees
              const SizedBox(height: 8),
              _buildDetailRow(Icons.attach_money, 'Fees: Rs. ${appointment['fees']}'),
              
              // Payment Status
              const SizedBox(height: 8),
              _buildDetailRow(Icons.payment, 'Payment: ${appointment['paymentStatus']}'),
              
              // QR Code Info for upcoming appointments
              if (tokenNumber > 0 && type == 'upcoming' && appointment['qrCodeData'] != null)
                _buildQRCodeInfo(),
              
              const SizedBox(height: 12),
              
              // Footer with booking date and action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booked: ${_formatDateTime(appointment['createdAt'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF85CEDA),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Action buttons for upcoming appointments
                  if (type == 'upcoming') 
                    _buildActionButtons(appointment),
                  
                  // View Details button for past appointments
                  if (type == 'past') 
                    _buildPastAppointmentButton(appointment),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Queue status row
  Widget _buildQueueStatusRow(String queueStatus, int tokenNumber, int currentQueue) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (queueStatus) {
      case 'in-consultation':
        statusColor = Colors.orange;
        statusText = 'Currently Consulting';
        statusIcon = Icons.medical_services;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Consultation Completed';
        statusIcon = Icons.check_circle;
        break;
      default: // waiting
        statusColor = const Color(0xFF32BACD);
        if (currentQueue > 0 && tokenNumber > currentQueue) {
          final patientsAhead = tokenNumber - currentQueue - 1;
          statusText = '$patientsAhead patient${patientsAhead == 1 ? '' : 's'} ahead';
          statusIcon = Icons.timer;
        } else {
          statusText = 'Waiting for your turn';
          statusIcon = Icons.schedule;
        }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // QR Code info row
  Widget _buildQRCodeInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF18A3B6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF18A3B6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code, size: 16, color: const Color(0xFF18A3B6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Show QR code at clinic for token verification',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF18A3B6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> appointment) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Cancel Button
        Container(
          constraints: const BoxConstraints(minWidth: 100),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red),
          ),
          child: TextButton.icon(
            onPressed: () => _cancelAppointment(appointment['id'], appointment),
            icon: const Icon(
              Icons.cancel,
              size: 16,
              color: Colors.red,
            ),
            label: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        // Join/Get Directions Button
        Container(
          constraints: const BoxConstraints(minWidth: 120),
          decoration: BoxDecoration(
            color: const Color(0xFF32BACD).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF32BACD)),
          ),
          child: TextButton.icon(
            onPressed: () {
              _handleAppointmentAction(appointment);
            },
            icon: Icon(
              _getActionIcon(appointment['appointmentType']),
              size: 16,
              color: const Color(0xFF32BACD),
            ),
            label: Text(
              _getActionText(appointment['appointmentType']),
              style: const TextStyle(
                color: Color(0xFF32BACD),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPastAppointmentButton(Map<String, dynamic> appointment) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      decoration: BoxDecoration(
        color: const Color(0xFF85CEDA).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF85CEDA)),
      ),
      child: TextButton.icon(
        onPressed: () {
          _showAppointmentDetails(appointment);
        },
        icon: const Icon(
          Icons.info,
          size: 16,
          color: Color(0xFF85CEDA),
        ),
        label: const Text(
          'Details',
          style: TextStyle(
            color: Color(0xFF85CEDA),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final tokenNumber = appointment['tokenNumber'] ?? 0;
    final queueStatus = appointment['queueStatus'] ?? 'waiting';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Doctor', 'Dr. ${appointment['doctorName']}'),
              _buildDetailItem('Specialty', appointment['doctorSpecialty']),
              _buildDetailItem('Medical Center', appointment['medicalCenterName']),
              _buildDetailItem('Date', appointment['date']),
              _buildDetailItem('Time', _formatTime(appointment['time'])),
              _buildDetailItem('Type', _formatConsultationType(appointment['appointmentType'])),
              _buildDetailItem('Status', appointment['status']),
              // Token and queue info
              if (tokenNumber > 0) _buildDetailItem('Token Number', '#$tokenNumber'),
              if (tokenNumber > 0) _buildDetailItem('Queue Status', _formatQueueStatus(queueStatus)),
              _buildDetailItem('Fees', 'Rs. ${appointment['fees']}'),
              _buildDetailItem('Payment Status', appointment['paymentStatus']),
              _buildDetailItem('Booked On', _formatDateTime(appointment['createdAt'])),
              if (appointment['patientNotes']?.isNotEmpty == true)
                _buildDetailItem('Your Notes', appointment['patientNotes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF85CEDA)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF85CEDA)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF18A3B6),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _handleAppointmentAction(Map<String, dynamic> appointment) {
    final type = appointment['appointmentType'];
    if (type == 'physical') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Get directions to ${appointment['medicalCenterName']}'),
          backgroundColor: const Color(0xFF18A3B6),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join consultation feature coming soon!'),
          backgroundColor: Color(0xFF32BACD),
        ),
      );
    }
  }

  // Helper methods
  String _formatTime(String time) {
    try {
      if (time.contains(' - ')) {
        final parts = time.split(' - ');
        if (parts.isNotEmpty) {
          return '${parts[0]}';
        }
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _getDoctorInitials(String doctorName) {
    if (doctorName.isEmpty) return 'DR';
    final names = doctorName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return doctorName.length >= 2 ? doctorName.substring(0, 2).toUpperCase() : 'DR';
  }

  IconData _getEmptyIcon(String type) {
    switch (type) {
      case 'upcoming':
        return Icons.event_available;
      case 'past':
        return Icons.history;
      case 'cancelled':
        return Icons.event_busy;
      default:
        return Icons.event;
    }
  }

  String _getEmptyMessage(String type) {
    switch (type) {
      case 'upcoming':
        return 'No upcoming appointments';
      case 'past':
        return 'No past appointments';
      case 'cancelled':
        return 'No cancelled appointments';
      default:
        return 'No appointments';
    }
  }

  String _getEmptySubMessage(String type) {
    switch (type) {
      case 'upcoming':
        return 'Book a new appointment to get started';
      case 'past':
        return 'Your completed appointments will appear here';
      case 'cancelled':
        return 'Your cancelled appointments will appear here';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF32BACD);
      case 'requested':
        return const Color(0xFF85CEDA);
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getConsultationIcon(String type) {
    switch (type) {
      case 'physical':
        return Icons.local_hospital;
      case 'audio':
        return Icons.phone;
      case 'video':
        return Icons.video_call;
      default:
        return Icons.help;
    }
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
        return type;
    }
  }

  IconData _getActionIcon(String type) {
    switch (type) {
      case 'physical':
        return Icons.directions;
      case 'audio':
      case 'video':
        return Icons.video_call;
      default:
        return Icons.info;
    }
  }

  String _getActionText(String type) {
    switch (type) {
      case 'physical':
        return 'Get Directions';
      case 'audio':
      case 'video':
        return 'Join Call';
      default:
        return 'View Details';
    }
  }

  String _formatQueueStatus(String queueStatus) {
    switch (queueStatus) {
      case 'waiting': return 'Waiting for your turn';
      case 'in-consultation': return 'Currently in consultation';
      case 'completed': return 'Consultation completed';
      default: return queueStatus;
    }
  }
}