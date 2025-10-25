import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:frontend/model/doctor.dart';
import 'package:frontend/providers/queue_provider.dart';
import 'package:frontend/screens/doctor_screens/doctor_live_queue_screen.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/doctor_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DoctorQueueDashboard extends StatefulWidget {
  const DoctorQueueDashboard({super.key});

  @override
  State<DoctorQueueDashboard> createState() => _DoctorQueueDashboardState();
}

class _DoctorQueueDashboardState extends State<DoctorQueueDashboard> {
  String? currentDoctorId;
  Map<String, dynamic>? _selectedSchedule;
  bool _showPatientList = false;
  bool _isInitialized = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
    currentDoctorId = FirebaseAuth.instance.currentUser?.uid;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentDoctorId != null && mounted) {
        Provider.of<DoctorProvider>(context, listen: false)
            .loadAllDoctorsQueueDashboard();
        _isInitialized = true;
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAppointmentsPage(Map<String, dynamic> schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleAppointmentsPage(schedule: schedule),
      ),
    );
  }

  Doctor? _findCurrentDoctor(List<Doctor> doctors) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return doctors.firstWhere((doctor) => doctor.id == currentUserId);
  }

  // Enhanced Stat Card with better design
  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countTotalAppointments(Doctor doctor) {
    final doctorProvider = Provider.of<DoctorProvider>(context, listen: false);
    final schedules = doctorProvider.getCurrentDoctorSchedules(doctor.id);
    
    int totalAppointments = 0;
    for (var schedule in schedules) {
      final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);
      totalAppointments += appointments.length;
    }
    
    return totalAppointments;
  }

  int _countTodayAppointments(Doctor doctor) {
    final today = DateTime.now();
    final todayFormatted = "Today (${today.day}/${today.month}/${today.year})";
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowFormatted = "Tomorrow (${tomorrow.day}/${tomorrow.month}/${tomorrow.year})";
    
    final doctorProvider = Provider.of<DoctorProvider>(context, listen: false);
    final schedules = doctorProvider.getCurrentDoctorSchedules(doctor.id);
    
    int todayCount = 0;
    for (var schedule in schedules) {
      final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);
      for (var appointment in appointments) {
        final appointmentDate = appointment['date']?.toString() ?? '';
        if (appointmentDate == todayFormatted || appointmentDate == 'Today') {
          todayCount++;
        }
      }
    }
    
    return todayCount;
  }

  int _countWaitingPatients(Doctor doctor) {
    final doctorProvider = Provider.of<DoctorProvider>(context, listen: false);
    final schedules = doctorProvider.getCurrentDoctorSchedules(doctor.id);
    
    int waitingCount = 0;
    for (var schedule in schedules) {
      final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);
      for (var appointment in appointments) {
        final status = appointment['status']?.toString().toLowerCase() ?? '';
        if (status == 'waiting' || status == 'confirmed') {
          waitingCount++;
        }
      }
    }
    
    return waitingCount;
  }

  // Enhanced Schedule Card
  Widget _buildScheduleCardFromFirebase(Map<String, dynamic> schedule) {
    final medicalCenterName = schedule['medicalCenterName'] ?? 'Unknown Center';
    final status = schedule['status'] ?? 'pending';
    final bookedAppointments = schedule['bookedAppointments'] ?? 0;
    final weeklySchedule = schedule['weeklySchedule'] ?? [];
    final date = schedule['date'] ?? '';
    final adminApproved = schedule['adminApproved'] ?? false;
    final doctorConfirmed = schedule['doctorConfirmed'] ?? false;
    final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);

    // Get available days and times
    List<String> availableDays = [];
    String scheduleTime = '';
    
    for (var daySchedule in weeklySchedule) {
      if (daySchedule['available'] == true) {
        final day = daySchedule['day'] ?? '';
        final timeSlots = daySchedule['timeSlots'] as List? ?? [];
        
        if (timeSlots.isNotEmpty) {
          final firstSlot = timeSlots.first;
          final startTime = firstSlot['startTime'] ?? '';
          final endTime = firstSlot['endTime'] ?? '';
          
          availableDays.add(day);
          if (scheduleTime.isEmpty) {
            scheduleTime = '$startTime - $endTime';
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF18A3B6).withOpacity(0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAppointmentsPage(schedule),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with clinic name and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicalCenterName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18A3B6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (date.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: const Color(0xFF18A3B6).withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF18A3B6).withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Schedule details
                Row(
                  children: [
                    _buildDetailItem(Icons.access_time, scheduleTime.isNotEmpty ? scheduleTime : 'No time set'),
                    const Spacer(),
                    _buildDetailItem(Icons.people, '$bookedAppointments patients'),
                  ],
                ),

                const SizedBox(height: 12),

                // Available days
                if (availableDays.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: availableDays.map((day) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18A3B6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF18A3B6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),

                const SizedBox(height: 16),

                // Quick patient preview
                if (appointments.isNotEmpty) ...[
                  const Text(
                    'Upcoming Patients:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildPatientPreview(appointments),
                  const SizedBox(height: 16),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showAppointmentsPage(schedule),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF18A3B6),
                          side: const BorderSide(color: Color(0xFF18A3B6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('View All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _startConsultation(schedule),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18A3B6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text('Start Queue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF18A3B6).withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF18A3B6).withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPatientPreview(List<Map<String, dynamic>> appointments) {
    final previewAppointments = appointments.take(2).toList();
    final remainingCount = appointments.length - previewAppointments.length;

    return [
      ...previewAppointments.map((appointment) {
        final patientName = appointment['patientName'] ?? 'Unknown Patient';
        final tokenNumber = appointment['tokenNumber'] ?? 1;
        final status = appointment['status'] ?? 'waiting';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF18A3B6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#$tokenNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
      if (remainingCount > 0)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF18A3B6).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '+ $remainingCount more patients',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF18A3B6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildDashboard() {
    return Consumer<DoctorProvider>(
      builder: (context, doctorProvider, child) {
        if (!_isInitialized && doctorProvider.isLoading) {
          return _buildLoadingState();
        }

        if (doctorProvider.error.isNotEmpty) {
          return _buildErrorState(doctorProvider);
        }

        final doctors = doctorProvider.allDoctors;
        
        if (doctors == null || doctors.isEmpty) {
          return _buildEmptyState();
        }

        final currentDoctor = _findCurrentDoctor(doctors);
        
        if (currentDoctor == null) {
          return _buildDoctorNotFoundState();
        }

        return _buildDoctorCard(currentDoctor);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF18A3B6)),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your schedule...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(DoctorProvider doctorProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 64),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              doctorProvider.error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                doctorProvider.clearError();
                doctorProvider.loadAllDoctorsQueueDashboard();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Schedule Found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your schedule will appear here once appointments are booked',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorNotFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            Text(
              'Profile Not Found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check if your doctor profile is properly set up',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    final totalAppointments = _countTotalAppointments(doctor);
    final todayAppointments = _countTodayAppointments(doctor);
    final waitingPatients = _countWaitingPatients(doctor);

    final doctorProvider = Provider.of<DoctorProvider>(context, listen: false);
    final realSchedules = doctorProvider.getCurrentDoctorSchedules(doctor.id);

    return RefreshIndicator(
      onRefresh: () async {
        await Provider.of<DoctorProvider>(context, listen: false)
            .loadAllDoctorsQueueDashboard();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF18A3B6),
                    Color(0xFF32BACD),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF18A3B6).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withAlpha(230),
                        child: doctor.imageUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  doctor.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(Icons.person, size: 30, color: const Color(0xFF18A3B6)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dr. ${doctor.name}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doctor.specialty,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.yellow.shade300, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${doctor.rating}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back! Ready for your consultations?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Stats
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              children: [
                _buildStatCard(
                  'Total',
                  totalAppointments.toString(),
                  Icons.calendar_today,
                  const Color(0xFF18A3B6),
                  'Appointments',
                ),
                _buildStatCard(
                  "Today's",
                  todayAppointments.toString(),
                  Icons.today,
                  const Color(0xFF32BACD),
                  'Patients',
                ),
                _buildStatCard(
                  'Waiting',
                  waitingPatients.toString(),
                  Icons.people,
                  const Color(0xFF85CEDA),
                  'In Queue',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // My Schedules Section
            if (realSchedules.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    'My Schedules',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18A3B6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${realSchedules.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF18A3B6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...realSchedules.map((schedule) => _buildScheduleCardFromFirebase(schedule)),
            ] else
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.schedule_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Schedules',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your schedules will appear here when patients book appointments',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF32BACD);
      case 'waiting':
        return const Color(0xFF85CEDA);
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic dateInput) {
    try {
      if (dateInput is Timestamp) {
        DateTime date = dateInput.toDate();
        return DateFormat('MMM dd, yyyy').format(date);
      }
      
      if (dateInput is DateTime) {
        return DateFormat('MMM dd, yyyy').format(dateInput);
      }
      
      if (dateInput is String && dateInput.isNotEmpty) {
        DateTime date = DateTime.parse(dateInput);
        return DateFormat('MMM dd, yyyy').format(date);
      }
      
      return 'Date not set';
    } catch (e) {
      return dateInput?.toString() ?? 'Invalid date';
    }
  }

void _startConsultation(Map<String, dynamic> schedule) async {
  if (!mounted) return;
  
  // Store context in a local variable before async operations
  final currentContext = context;
  
  final success = await showDialog<bool>(
    context: currentContext,
    builder: (context) => AlertDialog(
      title: const Text('Start Consultation'),
      content: Text('Begin patient queue for ${schedule['medicalCenterName']}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final queueProvider = Provider.of<QueueProvider>(context, listen: false);
            final doctorProvider = Provider.of<DoctorProvider>(context, listen: false);
            
            final doctors = doctorProvider.allDoctors;
            final currentDoctor = _findCurrentDoctor(doctors ?? []);
            
            final appointments = (schedule['appointments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            
            try {
              final success = await queueProvider.startConsultation(
                scheduleId: schedule['_id'] ?? schedule['id'] ?? '',
                doctorId: FirebaseAuth.instance.currentUser!.uid,
                medicalCenterId: schedule['medicalCenterId'] ?? '',
                doctorName: 'Dr. ${currentDoctor?.name ?? 'Unknown'}',
                medicalCenterName: schedule['medicalCenterName'] ?? 'Unknown Center',
                appointments: appointments,
              );
              
              Navigator.pop(context, success);
            } catch (e) {
              Navigator.pop(context, false);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18A3B6),
          ),
          child: const Text('Start Queue'),
        ),
      ],
    ),
  ) ?? false;

  // Use WidgetsBinding for safe navigation
  if (success && mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final doctorProvider = Provider.of<DoctorProvider>(context, listen: false);
        final doctors = doctorProvider.allDoctors;
        final currentDoctor = _findCurrentDoctor(doctors ?? []);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorLiveQueueScreen(
              doctorId: FirebaseAuth.instance.currentUser!.uid,
              doctorName: currentDoctor?.name ?? 'Doctor',
              schedule: schedule,
            ),
          ),
        );
      }
    });
  } else if (!success && mounted) {
    final queueProvider = Provider.of<QueueProvider>(context, listen: false);
    _showSnackBar('Failed to start consultation: ${queueProvider.error}');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Queue',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (mounted) {
                Provider.of<DoctorProvider>(context, listen: false)
                    .loadAllDoctorsQueueDashboard();
              }
            },
          ),
        ],
      ),
      body: _buildDashboard(),
    );
  }
}

// Enhanced Schedule Appointments Page
class ScheduleAppointmentsPage extends StatelessWidget {
  final Map<String, dynamic> schedule;

  const ScheduleAppointmentsPage({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);
    final medicalCenterName = schedule['medicalCenterName'] ?? 'Unknown Center';
    final bookedAppointments = schedule['bookedAppointments'] ?? 0;
    
    // Sort appointments by token number
    appointments.sort((a, b) {
      final aToken = a['tokenNumber'] ?? a['token'] ?? 999;
      final bToken = b['tokenNumber'] ?? b['token'] ?? 999;
      return (aToken as int).compareTo(bToken as int);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          medicalCenterName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF18A3B6),
                  Color(0xFF32BACD),
                ],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Patient Queue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$bookedAppointments Appointments',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getScheduleDays(schedule),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Appointments List
          Expanded(
            child: appointments.isEmpty
                ? _buildEmptyAppointments()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      return _buildAppointmentCard(appointments[index], index + 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAppointments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Appointments',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No patients scheduled for this session',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, int index) {
    final patientName = appointment['patientName'] ?? 'Unknown Patient';
    final tokenNumber = appointment['tokenNumber'] ?? index;
    final appointmentTime = appointment['time'] ?? 'Not specified';
    final status = appointment['status']?.toString() ?? 'waiting';
    final patientPhone = appointment['patientPhone'] ?? 'Not provided';
    final appointmentDate = appointment['date'] ?? 'Today';
    final patientAge = appointment['patientAge'] ?? _generateRandomAge();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Token Number
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF18A3B6),
                    Color(0xFF32BACD),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '#$tokenNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Patient Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF0F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$patientAge yrs',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF18A3B6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Date and Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(appointmentDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        appointmentTime,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Phone Number
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        patientPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
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

  String _getScheduleDays(Map<String, dynamic> schedule) {
    final weeklySchedule = schedule['weeklySchedule'] ?? [];
    List<String> availableDays = [];
    
    for (var daySchedule in weeklySchedule) {
      if (daySchedule['available'] == true) {
        final day = daySchedule['day'] ?? '';
        availableDays.add(day);
      }
    }
    
    return availableDays.isNotEmpty 
        ? 'Available: ${availableDays.join(', ')}'
        : 'No scheduled days';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF32BACD);
      case 'waiting':
        return const Color(0xFF85CEDA);
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic dateInput) {
    try {
      if (dateInput is Timestamp) {
        DateTime date = dateInput.toDate();
        return DateFormat('MMM dd, yyyy').format(date);
      }
      
      if (dateInput is DateTime) {
        return DateFormat('MMM dd, yyyy').format(dateInput);
      }
      
      if (dateInput is String && dateInput.isNotEmpty) {
        DateTime date = DateTime.parse(dateInput);
        return DateFormat('MMM dd, yyyy').format(date);
      }
      
      return 'Date not set';
    } catch (e) {
      return dateInput?.toString() ?? 'Invalid date';
    }
  }

  int _generateRandomAge() {
    return 18 + (DateTime.now().millisecondsSinceEpoch % 53);
  }
}