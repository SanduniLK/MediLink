import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'schedule_appointments_screen.dart';

// Color Scheme
const Color primaryColor = Color(0xFF18A3B6); // Deep teal
const Color secondaryColor = Color(0xFF32BACD); // Bright cyan
const Color accentColor1 = Color(0xFF85CEDA); // Teal-blue
const Color accentColor2 = Color(0xFFB2DEE6); // Soft aqua
const Color backgroundColor = Color(0xFFDDF0F5); // Very light blue
const Color textColorDark = Color(0xFF1A3A3F);
const Color textColorLight = Color(0xFF5A6D70);

// Schedule Model
class DoctorSchedule {
  final String id;
  final bool adminApproved;
  final String appointmentType;
  final DateTime? approvedAt;
  final String availableDate;
  final DateTime createdAt;
  final bool doctorConfirmed;
  final String doctorId;
  final String doctorName;
  final int maxAppointments;
  final String medicalCenterAdminId;
  final String medicalCenterId;
  final String medicalCenterName;
  final DateTime scheduleDate;
  final String status;
  final DateTime submittedAt;
  final List<String> telemedicineTypes;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> weeklySchedule;

  DoctorSchedule({
    required this.id,
    required this.adminApproved,
    required this.appointmentType,
    this.approvedAt,
    required this.availableDate,
    required this.createdAt,
    required this.doctorConfirmed,
    required this.doctorId,
    required this.doctorName,
    required this.maxAppointments,
    required this.medicalCenterAdminId,
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.scheduleDate,
    required this.status,
    required this.submittedAt,
    required this.telemedicineTypes,
    required this.updatedAt,
    required this.weeklySchedule,
  });

  factory DoctorSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DoctorSchedule(
      id: doc.id,
      adminApproved: data['adminApproved'] ?? false,
      appointmentType: data['appointmentType'] ?? '',
      approvedAt: data['approvedAt']?.toDate(),
      availableDate: data['availableDate'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      doctorConfirmed: data['doctorConfirmed'] ?? false,
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      maxAppointments: data['maxAppointments'] ?? 0,
      medicalCenterAdminId: data['medicalCenterAdminId'] ?? '',
      medicalCenterId: data['medicalCenterId'] ?? '',
      medicalCenterName: data['medicalCenterName'] ?? '',
      scheduleDate: data['scheduleDate']?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      submittedAt: data['submittedAt']?.toDate() ?? DateTime.now(),
      telemedicineTypes: List<String>.from(data['telemedicineTypes'] ?? []),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      weeklySchedule: List<Map<String, dynamic>>.from(data['weeklySchedule'] ?? []),
    );
  }

  List<String> get availableDays {
    return weeklySchedule
        .where((day) => day['available'] == true)
        .map((day) => day['day'].toString())
        .toList();
  }

  List<Map<String, dynamic>> getTimeSlotsForDay(String day) {
    for (var schedule in weeklySchedule) {
      if (schedule['day'] == day.toLowerCase()) {
        return List<Map<String, dynamic>>.from(schedule['timeSlots'] ?? []);
      }
    }
    return [];
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class Allschedule extends StatefulWidget {
  const Allschedule({super.key});

  @override
  State<Allschedule> createState() => _AllscheduleState();
}

class _AllscheduleState extends State<Allschedule> {
  late Stream<QuerySnapshot> _schedulesStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    _schedulesStream = FirebaseFirestore.instance
        .collection('doctorSchedules')
        .snapshots();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _onScheduleTap(DoctorSchedule schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleAppointmentsScreen(
          schedule: schedule,
        ),
      ),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: accentColor2,
                        child: Icon(
                          Icons.schedule,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor Schedules',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColorDark,
                              ),
                            ),
                            Text(
                              'Manage your appointments',
                              style: TextStyle(
                                fontSize: 14,
                                color: textColorLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _initializeStream,
                        icon: Icon(
                          Icons.refresh,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tabs
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabButton('Telemedicine', 0),
                        ),
                        Expanded(
                          child: _buildTabButton('Physical', 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: _schedulesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildErrorState();
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        final schedules = snapshot.data!.docs
                            .map((doc) => DoctorSchedule.fromFirestore(doc))
                            .toList();

                        final telemedicineSchedules = schedules
                            .where((schedule) =>
                                schedule.appointmentType.toLowerCase() == 'telemedicine')
                            .toList();

                        final physicalSchedules = schedules
                            .where((schedule) =>
                                schedule.appointmentType.toLowerCase() == 'physical')
                            .toList();

                        return DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              TabBar(
                                indicator: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                ),
                                labelColor: primaryColor,
                                unselectedLabelColor: textColorLight,
                                indicatorSize: TabBarIndicatorSize.tab,
                                tabs: const [
                                  Tab(text: 'Telemedicine'),
                                  Tab(text: 'Physical'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildScheduleList(telemedicineSchedules, isTelemedicine: true),
                                    _buildScheduleList(physicalSchedules, isTelemedicine: false),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load schedules',
            style: TextStyle(
              fontSize: 18,
              color: textColorDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection',
            style: TextStyle(
              fontSize: 14,
              color: textColorLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: accentColor2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_outlined,
              size: 64,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No schedules found',
            style: TextStyle(
              fontSize: 20,
              color: textColorDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Create a new schedule to start accepting appointments',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textColorLight,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Add create schedule functionality
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Create New Schedule'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(List<DoctorSchedule> schedules, {required bool isTelemedicine}) {
    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTelemedicine ? Icons.videocam_off : Icons.local_hospital_outlined,
              size: 64,
              color: accentColor1,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isTelemedicine ? 'Telemedicine' : 'Physical'} Schedules',
              style: TextStyle(
                fontSize: 18,
                color: textColorDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a ${isTelemedicine ? 'telemedicine' : 'physical'} schedule to get started',
              style: TextStyle(
                fontSize: 14,
                color: textColorLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        return _buildScheduleCard(schedules[index], isTelemedicine: isTelemedicine);
      },
    );
  }

  Widget _buildScheduleCard(DoctorSchedule schedule, {required bool isTelemedicine}) {
    return GestureDetector(
      onTap: () => _onScheduleTap(schedule),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Pattern
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accentColor2,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isTelemedicine ? accentColor1 : secondaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isTelemedicine ? Icons.video_call : Icons.local_hospital,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.doctorName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColorDark,
                                ),
                              ),
                              Text(
                                schedule.medicalCenterName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColorLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _buildStatusBadge(schedule.status),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Details Grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildDetailItem(
                              icon: Icons.calendar_today,
                              label: 'Date',
                              value: schedule.formatDate(schedule.scheduleDate),
                            ),
                            const SizedBox(width: 12),
                            _buildDetailItem(
                              icon: Icons.people,
                              label: 'Max Appointments',
                              value: schedule.maxAppointments.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildDetailItem(
                              icon: Icons.date_range,
                              label: 'Available Date',
                              value: schedule.availableDate,
                            ),
                            const SizedBox(width: 12),
                            _buildDetailItem(
                              icon: schedule.adminApproved ? Icons.check_circle : Icons.pending,
                              label: 'Admin Status',
                              value: schedule.adminApproved ? 'Approved' : 'Pending',
                              color: schedule.adminApproved ? Colors.green : Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Available Days
                  if (schedule.availableDays.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Days',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColorDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: schedule.availableDays.map((day) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentColor2,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                day.capitalize(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Action Button
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [secondaryColor, primaryColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Appointments',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 16,
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
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'confirmed':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'pending':
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        icon = Icons.pending;
        break;
      case 'cancelled':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            status.capitalize(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
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
                      fontSize: 10,
                      color: textColorLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColorDark,
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
}

extension StringExt on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}