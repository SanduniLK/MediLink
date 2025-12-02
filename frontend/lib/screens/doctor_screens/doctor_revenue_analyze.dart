import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class DoctorRevenueAnalysisPage extends StatefulWidget {
  const DoctorRevenueAnalysisPage({super.key});

  @override
  State<DoctorRevenueAnalysisPage> createState() => _DoctorRevenueAnalysisPageState();
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
  double _doctorFees = 0; // Will be 2600 from doctor's data

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
  setState(() => _isLoading = true);
  
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  print('=== LOADING DOCTOR DATA ===');
  print('Doctor UID: ${user.uid}');
  
  try {
    // Try doctors collection first
    final doctorDoc = await FirebaseFirestore.instance
      .collection('doctors')
      .doc(user.uid)
      .get();
    
    if (doctorDoc.exists) {
      _doctorData = doctorDoc.data() as Map<String, dynamic>;
      print('✅ Doctor data found in doctors collection');
    } else {
      // Try users collection as fallback
      print('❌ Not found in doctors collection, trying users...');
      final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
      
      if (userDoc.exists) {
        _doctorData = userDoc.data() as Map<String, dynamic>;
        print('✅ Doctor data found in users collection');
      }
    }
    
    if (_doctorData != null) {
      // DEBUG: Print all doctor data
      print('=== FULL DOCTOR DATA ===');
      _doctorData!.forEach((key, value) {
        print('$key: $value');
      });
      print('========================');
      
      // Get doctor's fees - SIMPLE DIRECT METHOD
      _doctorFees = _extractDoctorFeesSimple(_doctorData!);
      print('💰 Doctor fees: $_doctorFees');
      
      // Get doctor's registered medical centers
      _parseMedicalCenters(_doctorData!);
      
      await _fetchAppointments();
      _calculateAppointmentTypes();
      
      // DEBUG: Show calculation
      print('📊 CALCULATION: $_doctorFees × ${_appointments.length} = ${_doctorFees * _appointments.length}');
    } else {
      print('❌ Doctor data is null');
    }
  } catch (e) {
    print('❌ Error loading doctor data: $e');
  }
  
  setState(() => _isLoading = false);
}

// SIMPLE fee extraction - just find the number field
double _extractDoctorFeesSimple(Map<String, dynamic> data) {
  print('🔍 Looking for doctor fees...');
  
  // First priority: 'fees' field
  if (data['fees'] != null) {
    final value = data['fees'];
    print('Found "fees" field: $value');
    
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      // Try to parse string
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  
  // Second: Look for any field that contains 'fee'
  print('Searching for fee fields...');
  for (var key in data.keys) {
    if (key.toString().toLowerCase().contains('fee')) {
      final value = data[key];
      print('Found fee field "$key": $value');
      
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
  }
  
  // Third: Look for numeric fields between 1000-10000 (typical fee range)
  for (var key in data.keys) {
    final value = data[key];
    if (value is int && value >= 1000 && value <= 10000) {
      print('Found numeric fee "$key": $value');
      return value.toDouble();
    }
  }
  
  print('⚠️ No doctor fees found! Available fields:');
  data.forEach((key, value) {
    print('  $key: $value (${value.runtimeType})');
  });
  
  return 0; // Return 0, not 3000
}

  double _getDoctorFeesFromData(Map<String, dynamic> data) {
    print('=== GETTING DOCTOR FEES ===');
    print('Available fields: ${data.keys}');
    
    // Check fees field
    if (data['fees'] != null) {
      final fees = data['fees'];
      print('Fees field found: $fees (type: ${fees.runtimeType})');
      
      if (fees is int) {
        return fees.toDouble();
      } else if (fees is double) {
        return fees;
      } else if (fees is String) {
        return double.tryParse(fees) ?? 0;
      }
    }
    
    print('No valid fees found, checking other fields...');
    
    // Try other possible field names
    final possibleFields = ['fee', 'consultation_fee', 'consultationFee', 'price', 'amount'];
    for (var field in possibleFields) {
      if (data[field] != null) {
        print('Found field "$field": ${data[field]}');
        final value = data[field];
        if (value is int) return value.toDouble();
        if (value is double) return value;
        if (value is String) return double.tryParse(value) ?? 0;
      }
    }
    
    print('⚠️ NO FEES FOUND - Check your database structure');
    return 0;
  }

  void _parseMedicalCenters(Map<String, dynamic> data) {
    print('=== PARSING MEDICAL CENTERS ===');
    
    _medicalCenters.clear();
    
    // Check if medicalCenters field exists
    if (data['medicalCenters'] == null) {
      print('medicalCenters field is null');
      return;
    }
    
    final centersData = data['medicalCenters'];
    print('medicalCenters type: ${centersData.runtimeType}');
    print('medicalCenters value: $centersData');
    
    if (centersData is List) {
      print('Processing as List with ${centersData.length} items');
      
      for (var item in centersData) {
        print('Item: $item (type: ${item.runtimeType})');
        
        if (item is Map) {
          try {
            // Convert to String keys
            final map = item.cast<String, dynamic>();
            final id = map['id']?.toString();
            final name = map['name']?.toString();
            
            if (id != null && name != null) {
              print('Adding medical center: $name ($id)');
              _medicalCenters.add(MedicalCenter(id: id, name: name));
            } else {
              print('Missing id or name in map');
            }
          } catch (e) {
            print('Error converting map: $e');
          }
        }
      }
    }
    
    print('Total medical centers parsed: ${_medicalCenters.length}');
  }

  Future<void> _fetchAppointments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    print('=== FETCHING APPOINTMENTS ===');
    print('Using doctor fees: $_doctorFees');
    
    Query query = FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: user.uid)
        .where('paymentStatus', isEqualTo: 'paid');
    
    if (_selectedMedicalCenter != null) {
      query = query.where('medicalCenterId', isEqualTo: _selectedMedicalCenter);
      print('Filtering by medical center: $_selectedMedicalCenter');
    }
    
    final querySnapshot = await query.get();
    print('Found ${querySnapshot.docs.length} appointments');
    
    _appointments = querySnapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Appointment(
        id: doc.id,
        doctorFees: _doctorFees, // Always use doctor's fee (2600)
        paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
        date: (data['date'] as String?) ?? '',
        medicalCenterId: data['medicalCenterId'] as String?,
        medicalCenterName: data['medicalCenterName'] as String?,
        patientName: data['patientName'] as String?,
        patientId: data['patientId'] as String?,
        consultationType: data['consultationType'] as String?,
      );
    }).toList();
    
    // Sort by date (newest first)
    _appointments.sort((a, b) => (b.paidAt ?? DateTime.now()).compareTo(a.paidAt ?? DateTime.now()));
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
        _telemedicineRevenue += _doctorFees; // Use doctor's fee
      } else {
        _physicalAppointments++;
        _physicalRevenue += _doctorFees; // Use doctor's fee
      }
    }
    
    print('Physical: $_physicalAppointments appointments, Rs $_physicalRevenue');
    print('Telemedicine: $_telemedicineAppointments appointments, Rs $_telemedicineRevenue');
  }

  List<RevenueData> _getChartData() {
    final now = DateTime.now();
    List<RevenueData> data = [];

    if (_selectedTimeFrame == 'day') {
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
        final total = hourAppointments.length * _doctorFees;
        data.add(RevenueData(
          label: '${hour.toString().padLeft(2, '0')}:00',
          value: total,
          date: DateTime(now.year, now.month, now.day, hour),
        ));
      }
    } else if (_selectedTimeFrame == 'week') {
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
        
        final total = dayAppointments.length * _doctorFees;
        data.add(RevenueData(
          label: DateFormat('EEE').format(date),
          value: total,
          date: date,
        ));
      }
    } else if (_selectedTimeFrame == 'month') {
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
        
        final total = dayAppointments.length * _doctorFees;
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

    final totalAppointments = filteredAppointments.length;
    final totalRevenue = _doctorFees * totalAppointments;
    final avgRevenuePerAppointment = totalAppointments > 0 ? _doctorFees : 0;

    final today = DateTime.now();
    final todayAppointments = filteredAppointments.where((app) {
      final paidAt = app.paidAt;
      if (paidAt == null) return false;
      return paidAt.year == today.year &&
             paidAt.month == today.month &&
             paidAt.day == today.day;
    }).length;
    
    final todayRevenue = _doctorFees * todayAppointments;

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final weekAppointments = filteredAppointments.where((app) {
      final paidAt = app.paidAt;
      if (paidAt == null) return false;
      return paidAt.isAfter(startOfWeek) || paidAt.isAtSameMomentAs(startOfWeek);
    }).length;
    
    final weekRevenue = _doctorFees * weekAppointments;

    return {
      'totalRevenue': totalRevenue,
      'totalAppointments': totalAppointments,
      'avgRevenue': avgRevenuePerAppointment,
      'todayRevenue': todayRevenue,
      'weekRevenue': weekRevenue,
      'doctorFees': _doctorFees,
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
                      // Show doctor's fee
                      Text(
                        'Fee per appointment: Rs ${_doctorFees.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
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
                                  if (_medicalCenters.isNotEmpty) ...[
                                    const DropdownMenuItem<String?>(
                                      value: 'divider',
                                      enabled: false,
                                      child: Divider(),
                                    ),
                                    DropdownMenuItem<String?>(
                                      value: 'label',
                                      enabled: false,
                                      child: Text(
                                        'Your Registered Centers:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                    ..._medicalCenters.map((center) {
                                      return DropdownMenuItem<String?>(
                                        value: center.id,
                                        child: Text(center.name),
                                      );
                                    }),
                                  ],
                                ],
                                onChanged: (String? value) {
                                  if (value != null && value != 'divider' && value != 'label') {
                                    setState(() {
                                      _selectedMedicalCenter = value;
                                    });
                                    _fetchAppointments();
                                    _calculateAppointmentTypes();
                                  }
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
                        if (_selectedMedicalCenter != null && _medicalCenters.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(Icons.business, color: _accentColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Showing: ${_medicalCenters.firstWhere((center) => center.id == _selectedMedicalCenter, orElse: () => MedicalCenter(id: '', name: 'Selected')).name}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _secondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedMedicalCenter = null;
                                    });
                                    _fetchAppointments();
                                    _calculateAppointmentTypes();
                                  },
                                  child: Icon(Icons.clear, color: Colors.grey, size: 18),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Appointment Type Cards - FIXED OVERFLOW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCompactAppointmentCard(
                          'Physical',
                          _physicalAppointments.toString(),
                          'Rs ${_physicalRevenue.toStringAsFixed(0)}',
                          Icons.person,
                          const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactAppointmentCard(
                          'Telemedicine',
                          _telemedicineAppointments.toString(),
                          'Rs ${_telemedicineRevenue.toStringAsFixed(0)}',
                          Icons.videocam,
                          const Color(0xFF2196F3),
                        ),
                      ),
                    ],
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
                        'Rs ${stats['totalRevenue'].toStringAsFixed(0)}',
                        Icons.money_sharp,
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
                        'Rs ${stats['avgRevenue'].toStringAsFixed(0)}',
                        Icons.trending_up,
                        _accentColor,
                      ),
                      _buildStatCard(
                        "Today's Revenue",
                        'Rs ${stats['todayRevenue'].toStringAsFixed(0)}',
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
                            'Revenue Trend',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          Text(
                            'Based on Rs $_doctorFees per appointment',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
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
                                LineSeries<RevenueData, String>(
                                  dataSource: chartData,
                                  xValueMapper: (RevenueData data, _) => data.label,
                                  yValueMapper: (RevenueData data, _) => data.value,
                                  name: 'Revenue',
                                  markerSettings: const MarkerSettings(
                                    isVisible: true,
                                    height: 6,
                                    width: 6,
                                  ),
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: false,
                                  ),
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
                
                // Recent Transactions
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
                              Text(
                                'Recent Transactions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs ${stats['weekRevenue'].toStringAsFixed(0)}',
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
                                      'Rs ${appointment.doctorFees.toStringAsFixed(0)}',
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

  // Helper methods
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

  // New compact appointment card to prevent overflow
  Widget _buildCompactAppointmentCard(String title, String count, String revenue, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Text(
              'Appointments',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              revenue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Text(
              'Revenue',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data Models
class Appointment {
  final String id;
  final double doctorFees;
  final DateTime? paidAt;
  final String date;
  final String? medicalCenterId;
  final String? medicalCenterName;
  final String? patientName;
  final String? patientId;
  final String? consultationType;

  Appointment({
    required this.id,
    required this.doctorFees,
    required this.paidAt,
    required this.date,
    this.medicalCenterId,
    this.medicalCenterName,
    this.patientName,
    this.patientId,
    this.consultationType,
  });
}

class MedicalCenter {
  final String id;
  final String name;

  MedicalCenter({
    required this.id,
    required this.name,
  });
}

class RevenueData {
  final String label;
  final double value;
  final DateTime date;

  RevenueData({
    required this.label,
    required this.value,
    required this.date,
  });
}