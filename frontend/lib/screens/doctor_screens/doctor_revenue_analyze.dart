import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/model/revenue_model.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class DoctorRevenueAnalysisPage extends StatefulWidget {
  const DoctorRevenueAnalysisPage({Key? key}) : super(key: key);

  @override
  _DoctorRevenueAnalysisPageState createState() => _DoctorRevenueAnalysisPageState();
}

class _DoctorRevenueAnalysisPageState extends State<DoctorRevenueAnalysisPage> {
  String _selectedTimeFrame = 'week';
  String? _selectedMedicalCenter;
  List<Appointment> _appointments = [];
  List<MedicalCenter> _medicalCenters = [];
  Map<String, dynamic>? _doctorData;
  bool _isLoading = true;
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _bgColor = const Color(0xFFDDF0F5);

  // Appointment type counters
  int _physicalAppointments = 0;
  int _telemedicineAppointments = 0;
  double _physicalRevenue = 0;
  double _telemedicineRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Fetch doctor data
    final doctorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (doctorDoc.exists) {
      _doctorData = doctorDoc.data() as Map<String, dynamic>;
      
      // Get doctor's medical centers
      final centersData = _doctorData?['medicalCenters'] as List<dynamic>? ?? [];
      _medicalCenters = centersData.map((center) {
        final Map<String, dynamic> centerMap = center as Map<String, dynamic>;
        return MedicalCenter(
          id: centerMap['id']?.toString() ?? '',
          name: centerMap['name']?.toString() ?? 'Unknown Center',
        );
      }).toList();
      
      await _fetchAppointments();
      _calculateAppointmentTypes();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAppointments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    Query query = FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .where('paymentStatus', isEqualTo: 'paid');
    
    if (_selectedMedicalCenter != null) {
      query = query.where('medicalCenterId', isEqualTo: _selectedMedicalCenter);
    }
    
    final querySnapshot = await query.get();
    
    _appointments = querySnapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Appointment(
        id: doc.id,
        fees: _getDoctorFees(data),
        paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
        date: (data['date'] as String?) ?? '',
        medicalCenterId: data['medicalCenterId'] as String?,
        medicalCenterName: data['medicalCenterName'] as String?,
        patientName: data['patientName'] as String?,
        patientId: data['patientId'] as String?,
        consultationType: data['consultationType'] as String?,
      );
    }).toList();
    
    // Sort by date
    _appointments.sort((a, b) => (b.paidAt ?? DateTime.now()).compareTo(a.paidAt ?? DateTime.now()));
  }

  double _getDoctorFees(Map<String, dynamic> appointmentData) {
    // If doctor has fixed fees in their profile, use that
    if (_doctorData != null && _doctorData?['fees'] != null) {
      final doctorFees = _doctorData!['fees'];
      if (doctorFees is int) {
        return doctorFees.toDouble();
      } else if (doctorFees is double) {
        return doctorFees;
      } else if (doctorFees is String) {
        return double.tryParse(doctorFees) ?? 0;
      }
    }
    
    // Otherwise, use the appointment fees (which should be doctor fees only)
    final fees = appointmentData['fees'];
    if (fees is int) {
      return fees.toDouble();
    } else if (fees is double) {
      return fees;
    } else if (fees is String) {
      return double.tryParse(fees) ?? 0;
    }
    
    return 0;
  }

  void _calculateAppointmentTypes() {
    _physicalAppointments = 0;
    _telemedicineAppointments = 0;
    _physicalRevenue = 0;
    _telemedicineRevenue = 0;
    
    for (var appointment in _appointments) {
      if (appointment.consultationType == 'video' || 
          appointment.consultationType == 'chat' ||
          appointment.consultationType == 'telemedicine') {
        _telemedicineAppointments++;
        _telemedicineRevenue += appointment.fees;
      } else {
        _physicalAppointments++;
        _physicalRevenue += appointment.fees;
      }
    }
  }

  List<RevenueData> _getChartData() {
    final now = DateTime.now();
    List<RevenueData> data = [];

    if (_selectedTimeFrame == 'day') {
      // Group by hour for today
      final todayAppointments = _appointments.where((app) {
        final paidAt = app.paidAt;
        if (paidAt == null) return false;
        return paidAt.year == now.year &&
               paidAt.month == now.month &&
               paidAt.day == now.day;
      }).toList();

      final Map<int, List<Appointment>> groupedByHour = {};
      for (var appointment in todayAppointments) {
        final hour = appointment.paidAt?.hour ?? 0;
        groupedByHour.putIfAbsent(hour, () => []).add(appointment);
      }
      
      for (int hour = 0; hour < 24; hour++) {
        final hourAppointments = groupedByHour[hour] ?? [];
        final total = hourAppointments.fold(0.0, (double sum, app) => sum + app.fees);
        data.add(RevenueData(
          label: '${hour.toString().padLeft(2, '0')}:00',
          value: total,
          date: DateTime(now.year, now.month, now.day, hour),
        ));
      }
    } else if (_selectedTimeFrame == 'week') {
      // Group by day for current week
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dayAppointments = _appointments.where((app) {
          final paidAt = app.paidAt;
          if (paidAt == null) return false;
          return paidAt.year == date.year &&
                 paidAt.month == date.month &&
                 paidAt.day == date.day;
        }).toList();
        
        final total = dayAppointments.fold(0.0, (double sum, app) => sum + app.fees);
        data.add(RevenueData(
          label: DateFormat('EEE').format(date),
          value: total,
          date: date,
        ));
      }
    } else if (_selectedTimeFrame == 'month') {
      // Group by day for current month
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(now.year, now.month, day);
        final dayAppointments = _appointments.where((app) {
          final paidAt = app.paidAt;
          if (paidAt == null) return false;
          return paidAt.year == date.year &&
                 paidAt.month == date.month &&
                 paidAt.day == date.day;
        }).toList();
        
        final total = dayAppointments.fold(0.0, (double sum, app) => sum + app.fees);
        data.add(RevenueData(
          label: DateFormat('MMM dd').format(date),
          value: total,
          date: date,
        ));
      }
    }

    return data;
  }

  Map<String, dynamic> _getRevenueStats() {
    final filteredAppointments = _selectedMedicalCenter == null 
      ? _appointments
      : _appointments.where((app) => app.medicalCenterId == _selectedMedicalCenter).toList();

    final totalRevenue = filteredAppointments.fold(0.0, (double sum, app) => sum + app.fees);
    final totalAppointments = filteredAppointments.length;
    final avgRevenuePerAppointment = totalAppointments > 0 ? totalRevenue / totalAppointments : 0;

    // Today's revenue
    final today = DateTime.now();
    final todayRevenue = filteredAppointments.where((app) {
      final paidAt = app.paidAt;
      if (paidAt == null) return false;
      return paidAt.year == today.year &&
             paidAt.month == today.month &&
             paidAt.day == today.day;
    }).fold(0.0, (double sum, app) => sum + app.fees);

    // This week's revenue
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final thisWeekRevenue = filteredAppointments.where((app) {
      final paidAt = app.paidAt;
      if (paidAt == null) return false;
      return paidAt.isAfter(startOfWeek) || paidAt.isAtSameMomentAs(startOfWeek);
    }).fold(0.0, (double sum, app) => sum + app.fees);

    return {
      'totalRevenue': totalRevenue,
      'totalAppointments': totalAppointments,
      'avgRevenue': avgRevenuePerAppointment,
      'todayRevenue': todayRevenue,
      'weekRevenue': thisWeekRevenue,
    };
  }

  @override
Widget build(BuildContext context) {
  final stats = _getRevenueStats();
  final chartData = _getChartData();

  return Scaffold(
    backgroundColor: _bgColor,
    body: _isLoading
        ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _lightColor.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: _primaryColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Revenue Analysis',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.refresh, color: _primaryColor),
                            onPressed: _loadDoctorData,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dr. ${_doctorData?['fullname'] ?? 'Doctor'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${_doctorData?['specialization'] ?? 'Specialist'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _secondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Filters
                Card(
                  margin: const EdgeInsets.all(15),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter Revenue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _selectedMedicalCenter,
                                decoration: InputDecoration(
                                  labelText: 'Medical Center',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: Icon(Icons.medical_services, color: _accentColor),
                                ),
                                hint: const Text('All Medical Centers'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Medical Centers'),
                                  ),
                                  ..._medicalCenters.map((center) {
                                    return DropdownMenuItem<String?>(
                                      value: center.id,
                                      child: Text(center.name),
                                    );
                                  }),
                                ],
                                onChanged: (String? value) {
                                  setState(() {
                                    _selectedMedicalCenter = value;
                                  });
                                  _fetchAppointments();
                                  _calculateAppointmentTypes();
                                },
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _lightColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedTimeFrame,
                                dropdownColor: _bgColor,
                                underline: const SizedBox(),
                                items: [
                                  DropdownMenuItem(
                                    value: 'day',
                                    child: Row(
                                      children: [
                                        Icon(Icons.today, color: _primaryColor, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Day'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'week',
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_view_week, color: _primaryColor, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Week'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'month',
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_view_month, color: _primaryColor, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Month'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (String? value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedTimeFrame = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
               // In the build method, where you use the appointment type cards:
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 15),
  child: SizedBox(
    height: 140, // Match this with the card height
    child: Row(
      children: [
        Expanded(
          child: _buildAppointmentTypeCard(
            'Physical',
            _physicalAppointments.toString(),
            'Rs ${_physicalRevenue.toStringAsFixed(2)}',
            Icons.person,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAppointmentTypeCard(
            'Telemedicine',
            _telemedicineAppointments.toString(),
            'Rs ${_telemedicineRevenue.toStringAsFixed(2)}',
            Icons.videocam,
            const Color(0xFF2196F3),
          ),
        ),
      ],
    ),
  ),
),
                
                const SizedBox(height: 15),
                
                // Statistics Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
                      _buildStatCard(
                        'Total Revenue',
                        'Rs ${stats['totalRevenue'].toStringAsFixed(2)}',
                        Icons.currency_rupee,
                        _primaryColor,
                      ),
                      _buildStatCard(
                        'Total Appointments',
                        stats['totalAppointments'].toString(),
                        Icons.people_alt,
                        _secondaryColor,
                      ),
                      _buildStatCard(
                        'Avg/Appointment',
                        'Rs ${stats['avgRevenue'].toStringAsFixed(2)}',
                        Icons.trending_up,
                        _accentColor,
                      ),
                      _buildStatCard(
                        "Today's Revenue",
                        'Rs ${stats['todayRevenue'].toStringAsFixed(2)}',
                        Icons.today,
                        const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ),
                
                // Chart
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revenue Trend (Doctor Fees Only)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 250,
                            child: SfCartesianChart(
                              palette: [_primaryColor],
                              primaryXAxis: CategoryAxis(
                                title: AxisTitle(
                                  text: _selectedTimeFrame == 'day' 
                                    ? 'Hour of Day'
                                    : _selectedTimeFrame == 'week'
                                      ? 'Day of Week'
                                      : 'Date',
                                ),
                                labelRotation: _selectedTimeFrame == 'month' ? 45 : 0,
                              ),
                              primaryYAxis: NumericAxis(
                                title: const AxisTitle(text: 'Revenue (Rs)'),
                                numberFormat: NumberFormat.currency(symbol: 'Rs '),
                              ),
                              series: <CartesianSeries>[
                                ColumnSeries<RevenueData, String>(
                                  dataSource: chartData,
                                  xValueMapper: (RevenueData data, _) => data.label,
                                  yValueMapper: (RevenueData data, _) => data.value,
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                    labelAlignment: ChartDataLabelAlignment.top,
                                    textStyle: TextStyle(fontSize: 10),
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ],
                              tooltipBehavior: TooltipBehavior(
                                enable: true,
                                format: 'Revenue: Rs ${'point.y'}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Recent Transactions - FILTERED: Only shows doctor's own patients
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent Transactions',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Your patients only',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs ${stats['weekRevenue'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _secondaryColor,
                                    ),
                                  ),
                                  Text(
                                    'this week',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Showing Doctor Fees Only',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // This already shows only doctor's appointments due to query filter
                          ..._appointments.take(5).map((appointment) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: _bgColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: appointment.consultationType == 'video' 
                                    ? _lightColor 
                                    : const Color(0xFFC8E6C9),
                                  child: Icon(
                                    appointment.consultationType == 'video' 
                                      ? Icons.videocam 
                                      : Icons.person,
                                    color: appointment.consultationType == 'video' 
                                      ? _primaryColor 
                                      : const Color(0xFF4CAF50),
                                  ),
                                ),
                                title: Text(
                                  _getMaskedPatientName(appointment.patientName),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appointment.medicalCenterName ?? 'Medical Center',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      '${appointment.consultationType == 'video' ? 'Telemedicine' : 'Physical'} • ${DateFormat('MMM dd, hh:mm a').format(appointment.paidAt ?? DateTime.now())}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs ${appointment.fees.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: appointment.consultationType == 'video' 
                                          ? _lightColor 
                                          : const Color(0xFFC8E6C9).withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        appointment.consultationType == 'video' ? 'Video' : 'Physical',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: appointment.consultationType == 'video' 
                                            ? _primaryColor 
                                            : const Color(0xFF4CAF50),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          if (_appointments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No transactions found',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
  );
}

  // Helper function to mask patient name for privacy
  String _getMaskedPatientName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Patient';
    
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      final firstName = parts[0];
      final lastName = parts[parts.length - 1];
      final maskedLastName = lastName.length > 1 
        ? '${lastName[0]}${'*' * (lastName.length - 1)}'
        : '*';
      return '$firstName $maskedLastName';
    } else if (fullName.length > 2) {
      return '${fullName.substring(0, 2)}${'*' * (fullName.length - 2)}';
    }
    return 'Patient';
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _lightColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'LKR',
                    style: TextStyle(
                      fontSize: 10,
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildAppointmentTypeCard(String title, String count, String revenue, IconData icon, Color color) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    child: Container(
      height: 140, // Fixed height
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18), // Smaller icon
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11, // Smaller font
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 18, // Reduced from 20
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'Appointments',
            style: const TextStyle(
              fontSize: 9, // Smaller font
              color: Colors.grey,
              height: 1.0, // Reduce line height
            ),
          ),
          const SizedBox(height: 4),
          Text(
            revenue,
            style: TextStyle(
              fontSize: 12, // Reduced from 14
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'Revenue',
            style: const TextStyle(
              fontSize: 9, // Smaller font
              color: Colors.grey,
              height: 1.0, // Reduce line height
            ),
          ),
        ],
      ),
    ),
  );
}
}