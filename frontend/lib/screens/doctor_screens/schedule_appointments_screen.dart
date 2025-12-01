import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'allschedule.dart';
import 'doctor_unified_search_screen.dart'; // Add this import

// Color Scheme (same as main file)
const Color primaryColor = Color(0xFF18A3B6);
const Color secondaryColor = Color(0xFF32BACD);
const Color accentColor1 = Color(0xFF85CEDA);
const Color accentColor2 = Color(0xFFB2DEE6);
const Color backgroundColor = Color(0xFFDDF0F5);
const Color textColorDark = Color(0xFF1A3A3F);
const Color textColorLight = Color(0xFF5A6D70);

// Appointment Model
class ScheduleAppointment {
  final String id;
  final String appointmentType;
  final String consultationType;
  final String? chatRoomId;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final int currentQueueNumber;
  final String date;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String fees;
  final String medicalCenterId;
  final String medicalCenterName;
  final DateTime? paidAt;
  final String patientId;
  final String patientName;
  final String patientNotes;
  final String paymentStatus;
  final String qrCodeData;
  final String queueStatus;
  final String scheduleId;
  final String selectedDate;
  final String selectedTime;
  final String status;
  final String? telemedicineId;
  final String time;
  final int tokenNumber;
  final String? videoLink;
  final DateTime updatedAt;

  ScheduleAppointment({
    required this.id,
    required this.appointmentType,
    required this.consultationType,
    this.chatRoomId,
    this.cancelledAt,
    required this.createdAt,
    required this.currentQueueNumber,
    required this.date,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.fees,
    required this.medicalCenterId,
    required this.medicalCenterName,
    this.paidAt,
    required this.patientId,
    required this.patientName,
    required this.patientNotes,
    required this.paymentStatus,
    required this.qrCodeData,
    required this.queueStatus,
    required this.scheduleId,
    required this.selectedDate,
    required this.selectedTime,
    required this.status,
    this.telemedicineId,
    required this.time,
    required this.tokenNumber,
    this.videoLink,
    required this.updatedAt,
  });

  factory ScheduleAppointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ScheduleAppointment(
      id: doc.id,
      appointmentType: data['appointmentType'] ?? '',
      consultationType: data['consultationType'] ?? '',
      chatRoomId: data['chatRoomId'],
      cancelledAt: data['cancelledAt']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      currentQueueNumber: data['currentQueueNumber'] ?? 0,
      date: data['date'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      doctorSpecialty: data['doctorSpecialty'] ?? '',
      fees: data['fees'] ?? '',
      medicalCenterId: data['medicalCenterId'] ?? '',
      medicalCenterName: data['medicalCenterName'] ?? '',
      paidAt: data['paidAt']?.toDate(),
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      patientNotes: data['patientNotes'] ?? '',
      paymentStatus: data['paymentStatus'] ?? '',
      qrCodeData: data['qrCodeData'] ?? '',
      queueStatus: data['queueStatus'] ?? '',
      scheduleId: data['scheduleId'] ?? '',
      selectedDate: data['selectedDate'] ?? '',
      selectedTime: data['selectedTime'] ?? '',
      status: data['status'] ?? '',
      telemedicineId: data['telemedicineId'],
      time: data['time'] ?? '',
      tokenNumber: data['tokenNumber'] ?? 0,
      videoLink: data['videoLink'],
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  bool get isActive => status.toLowerCase() != 'cancelled';
  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class ScheduleAppointmentsScreen extends StatefulWidget {
  final DoctorSchedule schedule;

  const ScheduleAppointmentsScreen({
    super.key,
    required this.schedule,
  });

  @override
  State<ScheduleAppointmentsScreen> createState() => _ScheduleAppointmentsScreenState();
}

class _ScheduleAppointmentsScreenState extends State<ScheduleAppointmentsScreen> {
  late Stream<QuerySnapshot> _appointmentsStream;
  List<ScheduleAppointment> _appointments = [];
  bool _isLoading = true;
  int _totalAppointments = 0;
  int _activeAppointments = 0;
  int _cancelledAppointments = 0;
  double _totalRevenue = 0;
  int _currentQueueNumber = 0;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

 void _loadAppointments() {
  _appointmentsStream = FirebaseFirestore.instance
      .collection('appointments')
      .where('scheduleId', isEqualTo: widget.schedule.id)
      .snapshots();

  _appointmentsStream.listen((snapshot) {
    final appointments = snapshot.docs
        .map((doc) => ScheduleAppointment.fromFirestore(doc))
        .toList()
      ..sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));

    final total = appointments.length;
    final active = appointments.where((a) => a.isActive).length;
    final cancelled = appointments.where((a) => !a.isActive).length;
    final revenue = appointments
        .where((a) => a.isPaid)
        .fold(0.0, (sum, a) => sum + (double.tryParse(a.fees) ?? 0));
    
    final current = appointments
        .where((a) => a.isActive && a.status.toLowerCase() == 'confirmed')
        .firstOrNull
        ?.tokenNumber ?? 0;

    setState(() {
      _appointments = appointments;
      _totalAppointments = total;
      _activeAppointments = active;
      _cancelledAppointments = cancelled;
      _totalRevenue = revenue;
      _currentQueueNumber = current;
      _isLoading = false;
    });
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(primaryColor.value).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Back button and title
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.schedule.doctorName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColorDark,
                              ),
                            ),
                            Text(
                              widget.schedule.medicalCenterName,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColorLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Statistics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.people,
                          label: 'Total',
                          value: _totalAppointments.toString(),
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.check_circle,
                          label: 'Active',
                          value: _activeAppointments.toString(),
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.monetization_on,
                          label: 'Revenue',
                          value: '₹${_totalRevenue.toStringAsFixed(0)}',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Current Queue Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [secondaryColor, primaryColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.queue,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Queue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              Text(
                                '#${_currentQueueNumber}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.schedule.appointmentType.capitalize(),
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // SINGLE Start Consultation Button
            if (_activeAppointments > 0 && _currentQueueNumber > 0)
              Container(
                padding: const EdgeInsets.all(16),
                color: accentColor2,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DoctorUnifiedSearchScreen(
        doctorId: widget.schedule.doctorId,
        doctorName: widget.schedule.doctorName,
        scheduleId: widget.schedule.id,
        appointmentType: widget.schedule.appointmentType,
      ),
    ),
  );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    icon: Icon(
                      widget.schedule.appointmentType == 'telemedicine' ? 
                      Icons.video_call : Icons.local_hospital,
                      size: 24,
                    ),
                    label: const Text(
                      'Start Consultation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // Appointments List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    )
                  : _appointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: accentColor2,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  size: 48,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Appointments',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: textColorDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No appointments booked for this schedule yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColorLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            return _buildAppointmentCard(_appointments[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(color.value).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(color.value).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColorLight,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColorDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(ScheduleAppointment appointment) {
    final isCurrent = appointment.tokenNumber == _currentQueueNumber;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(primaryColor.value).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: isCurrent ? Border.all(
          color: primaryColor,
          width: 2,
        ) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCurrent ? primaryColor : accentColor2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${appointment.tokenNumber}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColorDark,
                          ),
                        ),
                        Text(
                          appointment.selectedTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColorLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(appointment.statusColor.value).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        appointment.isActive ? Icons.check_circle : Icons.cancel,
                        size: 14,
                        color: appointment.statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        appointment.status.capitalize(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: appointment.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Details Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3,
              children: [
                _buildAppointmentDetailItem(
                  icon: Icons.medical_services,
                  label: 'Specialty',
                  value: appointment.doctorSpecialty,
                ),
                _buildAppointmentDetailItem(
                  icon: Icons.payment,
                  label: 'Fees',
                  value: '₹${appointment.fees}',
                ),
                _buildAppointmentDetailItem(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: appointment.selectedDate,
                ),
                _buildAppointmentDetailItem(
                  icon: Icons.payment,
                  label: 'Payment',
                  value: appointment.paymentStatus.capitalize(),
                  color: appointment.isPaid ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentDetailItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: textColorLight,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColorDark,
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}