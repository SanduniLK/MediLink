import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AdminRevenueAnalysisPage extends StatefulWidget {
  const AdminRevenueAnalysisPage({super.key});

  @override
  State<AdminRevenueAnalysisPage> createState() => _AdminRevenueAnalysisPageState();
}

class _AdminRevenueAnalysisPageState extends State<AdminRevenueAnalysisPage> {
  bool _isLoading = true;
  bool _hasData = false;
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _bgColor = const Color(0xFFDDF0F5);

  // Statistics
  double _totalRevenue = 0;
  int _totalAppointments = 0;
  int _totalDoctors = 0;
  double _avgRevenuePerDoctor = 0;
  double _thisMonthRevenue = 0;
  double _lastMonthRevenue = 0;
  double _revenueChangePercentage = 0;
  String _medicalCenterName = '';
  String _medicalCenterId = '';
  double _testFees = 0;
  final List<MonthlyRevenueData> _lineChartData = [];
  final List<DoctorRevenue> _doctorRevenues = [];
  final List<MonthlyRevenueData> _monthlyRevenueData = [];

  @override
  void initState() {
    super.initState();
    _loadMedicalCenterData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMedicalCenterData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasData = false;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          _showNoDataUI('Please login as medical center');
        }
        return;
      }

      // Get medical center data
      final centerDoc = await FirebaseFirestore.instance
          .collection('medical_centers')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (centerDoc.docs.isEmpty) {
        if (mounted) {
          _showNoDataUI('Medical center not found');
        }
        return;
      }

      final centerData = centerDoc.docs.first.data();
      _medicalCenterId = centerDoc.docs.first.id;
      _medicalCenterName = (centerData['name']?.toString() ?? 'Medical Center').trim();
      _testFees = _parseFees(centerData['testFees']);

      print('=== LOADING DATA FOR: "$_medicalCenterName" ===');
      print('Medical Center Test Fees: Rs $_testFees');

      // Load payment data
      await _loadPaymentData();
      
    } catch (e) {
      print('Error loading medical center data: $e');
      if (mounted) {
        _showNoDataUI('Error loading data');
      }
    }
  }

  Future<void> _loadPaymentData() async {
  print('Loading appointment data for medical center: "$_medicalCenterName"');
  
  try {
    // Get ALL payments from database
    final allPayments = await FirebaseFirestore.instance
        .collection('payments')
        .get();
    
    print('Total payments in database: ${allPayments.docs.length}');
    
    // Filter payments for this medical center
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> relevantPayments = [];
    final Map<String, int> doctorAppointmentCount = {};
    final Map<String, double> monthlyAppointmentCount = {};
    final Set<String> uniqueDoctorIds = {}; // Track unique doctors
    
    for (var doc in allPayments.docs) {
      final data = doc.data();
      
      // Get medical center name from payment
      final paymentMedicalCenter = (data['medicalCenterName']?.toString() ?? '').trim();
      
      // Compare with our medical center name
      bool isOurMedicalCenter = paymentMedicalCenter.toLowerCase() == _medicalCenterName.toLowerCase();
      
      if (!isOurMedicalCenter) {
        continue;
      }
      
      // Check payment status
      final status = data['paymentStatus']?.toString().toLowerCase() ?? '';
      final isCompleted = status == 'completed' || status == 'paid' || status == 'success';
      
      if (!isCompleted) {
        continue;
      }
      
      print('✅ Found relevant appointment for $_medicalCenterName');
      relevantPayments.add(doc);
      
      // Count appointments per doctor
      final doctorId = data['doctorId'] as String?;
      final doctorName = data['doctorName'] as String?;
      
      if (doctorId != null && doctorName != null) {
        doctorAppointmentCount[doctorId] = (doctorAppointmentCount[doctorId] ?? 0) + 1;
        uniqueDoctorIds.add(doctorId);
        print('  - Dr. $doctorName (ID: $doctorId)');
      }
      
      // Count appointments per month
      final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
      if (paidAt != null) {
        final monthKey = '${paidAt.year}-${paidAt.month.toString().padLeft(2, '0')}';
        monthlyAppointmentCount[monthKey] = (monthlyAppointmentCount[monthKey] ?? 0) + 1;
      }
    }
    
    print('Relevant appointments found: ${relevantPayments.length}');
    print('Unique doctors found: ${uniqueDoctorIds.length}');
    
    // Get doctor information (for display purposes)
    final List<String> doctorIdsList = uniqueDoctorIds.toList();
    _totalDoctors = doctorIdsList.length; // Set here for immediate use
    
    if (relevantPayments.isEmpty) {
      print('No relevant appointments found. Showing empty state.');
      if (mounted) {
        setState(() {
          _hasData = false;
          _isLoading = false;
        });
      }
      return;
    }
    
    // Process the appointments
    _processAppointments(relevantPayments, doctorIdsList, doctorAppointmentCount, monthlyAppointmentCount);
    
    if (mounted) {
      setState(() {
        _hasData = true;
        _isLoading = false;
      });
    }
    
  } catch (e) {
    print('Error loading payment data: $e');
    if (mounted) {
      setState(() {
        _hasData = false;
        _isLoading = false;
      });
    }
  }
}

void _processAppointments(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> appointments,
  List<String> doctorIds, // List of doctor IDs from appointments
  Map<String, int> doctorAppointmentCount,
  Map<String, double> monthlyAppointmentCount
) {
  // Clear existing data
  _doctorRevenues.clear();
  _lineChartData.clear();
  _monthlyRevenueData.clear();
  
  _totalAppointments = appointments.length;
  
  // Calculate total revenue: test fees × number of appointments
  _totalRevenue = _testFees * _totalAppointments;
  
  _thisMonthRevenue = 0;
  _lastMonthRevenue = 0;
  
  // Current and last month
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);
  
  // Calculate monthly revenue
  final Map<String, double> monthlyRevenue = {};
  
  for (var monthKey in monthlyAppointmentCount.keys) {
    final appointmentCount = monthlyAppointmentCount[monthKey] ?? 0;
    monthlyRevenue[monthKey] = _testFees * appointmentCount;
    
    // Parse month from key (format: YYYY-MM)
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      
      if (year != null && month != null) {
        final monthDate = DateTime(year, month);
        
        // This month vs last month
        if (monthDate.year == currentMonth.year && monthDate.month == currentMonth.month) {
          _thisMonthRevenue = monthlyRevenue[monthKey]!;
        }
        if (monthDate.year == lastMonth.year && monthDate.month == lastMonth.month) {
          _lastMonthRevenue = monthlyRevenue[monthKey]!;
        }
      }
    }
  }
  
  // Calculate revenue per doctor
  final Map<String, DoctorRevenue> doctorRevenueMap = {};
  
  for (var doctorId in doctorAppointmentCount.keys) {
    final appointmentCount = doctorAppointmentCount[doctorId] ?? 0;
    final doctorRevenue = _testFees * appointmentCount;
    
    // Find doctor name from appointments
    String doctorName = 'Unknown Doctor';
    for (var appointment in appointments) {
      final data = appointment.data();
      if (data['doctorId'] == doctorId && data['doctorName'] != null) {
        doctorName = data['doctorName'] as String;
        break;
      }
    }
    
    doctorRevenueMap[doctorId] = DoctorRevenue(
      doctorId: doctorId,
      doctorName: doctorName,
      medicalCenterName: _medicalCenterName,
      totalRevenue: doctorRevenue,
      appointmentCount: appointmentCount,
    );
  }
  
  // Convert and sort doctor revenues
  _doctorRevenues.addAll(doctorRevenueMap.values);
  _doctorRevenues.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
  
  // Set total doctors from the doctorAppointmentCount map
  _totalDoctors = doctorAppointmentCount.length;
  _avgRevenuePerDoctor = _totalDoctors > 0 ? _totalRevenue / _totalDoctors : 0;
  
  // Calculate percentage change
  if (_lastMonthRevenue > 0) {
    _revenueChangePercentage = ((_thisMonthRevenue - _lastMonthRevenue) / _lastMonthRevenue) * 100;
  } else if (_thisMonthRevenue > 0) {
    _revenueChangePercentage = 100;
  }
  
  // Prepare chart data
  _prepareChartData(monthlyRevenue);
  
  print('=== PROCESSING COMPLETE ===');
  print('Medical Center Test Fees: Rs $_testFees');
  print('Total Appointments: $_totalAppointments');
  print('Total Revenue: Rs $_totalRevenue (Test Fees × Appointments)');
  print('Total Doctors: $_totalDoctors');
  print('This Month Revenue: Rs $_thisMonthRevenue');
  print('Last Month Revenue: Rs $_lastMonthRevenue');
  print('Revenue Change: ${_revenueChangePercentage.toStringAsFixed(1)}%');
  print('Doctor Revenues: ${_doctorRevenues.length} doctors');
  if (_doctorRevenues.isNotEmpty) {
    for (var doctor in _doctorRevenues) {
      print('  - ${doctor.doctorName}: Rs ${doctor.totalRevenue} (${doctor.appointmentCount} appointments × Rs $_testFees)');
    }
  }
}

Future<List<String>> _getCenterDoctors() async {
  final List<String> doctorIds = [];
  
  try {
    // First, get all appointments for this medical center
    final allPayments = await FirebaseFirestore.instance
        .collection('payments')
        .where('medicalCenterName', isEqualTo: _medicalCenterName)
        .get();
    
    print('=== FINDING DOCTORS WITH APPOINTMENTS AT "$_medicalCenterName" ===');
    
    // Get unique doctor IDs from appointments
    final Set<String> doctorIdsFromAppointments = {};
    final Map<String, String> doctorIdToName = {};
    
    for (var doc in allPayments.docs) {
      final data = doc.data();
      final doctorId = data['doctorId'] as String?;
      final doctorName = data['doctorName'] as String?;
      
      if (doctorId != null && doctorName != null) {
        doctorIdsFromAppointments.add(doctorId);
        doctorIdToName[doctorId] = doctorName;
        print('Found appointment: Dr. $doctorName (ID: $doctorId)');
      }
    }
    
    print('Doctors with appointments: ${doctorIdsFromAppointments.length}');
    
    // Now check which of these doctors are registered with this medical center
    final doctorsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();
    
    for (var doc in doctorsSnapshot.docs) {
      final data = doc.data();
      final doctorId = doc.id;
      final doctorName = data['fullname']?.toString() ?? data['name']?.toString() ?? 'Unknown';
      final medicalCenters = data['medicalCenters'] as List<dynamic>?;
      
      // Check if this doctor has appointments at our medical center
      if (!doctorIdsFromAppointments.contains(doctorId)) {
        print('Doctor $doctorName has no appointments at $_medicalCenterName');
        continue;
      }
      
      print('\nChecking registration for: $doctorName (ID: $doctorId)');
      
      bool isRegistered = false;
      
      if (medicalCenters != null) {
        for (var center in medicalCenters) {
          if (center is Map<String, dynamic>) {
            final centerId = center['id']?.toString();
            final centerName = center['name']?.toString();
            
            print('  - Registered at: $centerName (ID: $centerId)');
            
            if (centerId == _medicalCenterId || centerName == _medicalCenterName) {
              isRegistered = true;
              print('  ✅ REGISTERED with $_medicalCenterName');
              break;
            }
          }
        }
      } else {
        print('  - No medical centers registered in profile');
      }
      
      if (isRegistered) {
        doctorIds.add(doctorId);
        print('  ✅ Adding to registered doctors list');
      } else {
        print('  ❌ NOT registered with $_medicalCenterName');
      }
    }
    
    print('\n=== SUMMARY ===');
    print('Total appointments found: ${allPayments.docs.length}');
    print('Doctors with appointments: ${doctorIdsFromAppointments.length}');
    print('Registered doctors with appointments: ${doctorIds.length}');
    
    // If no registered doctors found, at least show doctors with appointments
    if (doctorIds.isEmpty && doctorIdsFromAppointments.isNotEmpty) {
      print('\n⚠️ No registered doctors found, but showing doctors with appointments:');
      for (var doctorId in doctorIdsFromAppointments) {
        final doctorName = doctorIdToName[doctorId] ?? 'Unknown';
        print('  - Dr. $doctorName (has appointments but not registered)');
      }
      
      // Optional: Add unregistered doctors to list for display
      // doctorIds.addAll(doctorIdsFromAppointments.toList());
    }
    
  } catch (e) {
    print('Error getting center doctors: $e');
  }
  
  return doctorIds;
}

  void _prepareChartData(Map<String, double> monthlyRevenue) {
    // Line chart - last 12 months
    final now = DateTime.now();
    
    _lineChartData.clear();
    for (int i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final revenue = monthlyRevenue[monthKey] ?? 0;
      
      _lineChartData.add(MonthlyRevenueData(
        month: DateFormat('MMM yyyy').format(date),
        revenue: revenue,
        date: date,
      ));
    }
    
    // Bar chart - last 6 months
    _monthlyRevenueData.clear();
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final revenue = monthlyRevenue[monthKey] ?? 0;
      
      _monthlyRevenueData.add(MonthlyRevenueData(
        month: DateFormat('MMM').format(date),
        revenue: revenue,
        date: date,
      ));
    }
  }

  double _parseFees(dynamic fees) {
    if (fees is int) return fees.toDouble();
    if (fees is double) return fees;
    if (fees is String) return double.tryParse(fees) ?? 0;
    return 0;
  }

  void _showNoDataUI(String message) {
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
      _hasData = false;
      _medicalCenterName = _medicalCenterName.isEmpty ? message : _medicalCenterName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _isLoading
          ? _buildLoading()
          : !_hasData
              ? _buildNoDataUI()
              : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Revenue Data...',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataUI() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            Icon(
              Icons.analytics_outlined,
              color: Colors.grey[400],
              size: 100,
            ),
            const SizedBox(height: 20),
            Text(
              'No Revenue Data Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _medicalCenterName,
              style: TextStyle(
                fontSize: 18,
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Medical Center Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildSummaryRow('Medical Center', _medicalCenterName),
                    _buildSummaryRow('Test Fees', 'Rs ${_testFees.toStringAsFixed(0)}'),
                    _buildSummaryRow('Registered Doctors', _totalDoctors.toString()),
                    const SizedBox(height: 15),
                    Text(
                      'No completed appointment records found.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Revenue will be calculated as: Test Fees × Number of Appointments',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Formula: Rs $_testFees × Appointment Count',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  _loadMedicalCenterData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'Refresh Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? _primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      )
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Fixed Header
        Container(
          padding: const EdgeInsets.only(top: 50, left: 15, right: 15, bottom: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: _lightColor.withOpacity(0.3),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _medicalCenterName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Test Fees: Rs ${_testFees.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: _primaryColor),
                    onPressed: () {
                      if (mounted) {
                        _loadMedicalCenterData();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Revenue Analysis Dashboard',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                // Revenue Formula Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.calculate, color: _primaryColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Revenue Calculation',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                    children: [
                                      const TextSpan(text: 'Total Revenue = '),
                                      TextSpan(
                                        text: 'Test Fees',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const TextSpan(text: ' × '),
                                      TextSpan(
                                        text: 'Appointment Count',
                                        style: TextStyle(
                                          color: _secondaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '\n= Rs ${_testFees.toStringAsFixed(0)} × $_totalAppointments',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _lightColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Rs ${_totalRevenue.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Statistics Cards
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildStatCardWidget(
                        'Total Revenue',
                        'Rs ${_totalRevenue.toStringAsFixed(0)}',
                        Icons.attach_money,
                        _primaryColor,
                        subtitle: '$_totalAppointments appointments',
                      ),
                      _buildStatCardWidget(
                        'Total Appointments',
                        _totalAppointments.toString(),
                        Icons.people_alt,
                        _secondaryColor,
                        subtitle: '× Rs ${_testFees.toStringAsFixed(0)} each',
                      ),
                      _buildStatCardWidget(
                        'This Month',
                        'Rs ${_thisMonthRevenue.toStringAsFixed(0)}',
                        Icons.trending_up,
                        _revenueChangePercentage >= 0 ? Colors.green : Colors.red,
                        subtitle: _revenueChangePercentage >= 0 
                            ? '+${_revenueChangePercentage.toStringAsFixed(1)}%'
                            : '${_revenueChangePercentage.toStringAsFixed(1)}%',
                      ),
                      _buildStatCardWidget(
                        'Registered Doctors',
                        _totalDoctors.toString(),
                        Icons.person,
                        _accentColor,
                        subtitle: 'Avg: Rs ${_avgRevenuePerDoctor.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
                
                // Revenue Trend Line Chart - FIXED TOOLTIP
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
                          Row(
                            children: [
                              Icon(Icons.timeline, color: _primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Revenue Trend (Last 12 Months)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_medicalCenterName • Test Fees: Rs ${_testFees.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _lineChartData.isEmpty
                              ? Container(
                                  height: 200,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No revenue data available',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 250,
                                  child: SfCartesianChart(
                                    primaryXAxis: CategoryAxis(
                                      labelRotation: 45,
                                      labelStyle: const TextStyle(fontSize: 10),
                                    ),
                                    primaryYAxis: NumericAxis(
                                      numberFormat: NumberFormat.currency(symbol: ''),
                                      labelStyle: const TextStyle(fontSize: 10),
                                    ),
                                    legend: const Legend(isVisible: false),
                                    tooltipBehavior: TooltipBehavior(
                                      enable: true,
                                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                                        final monthlyData = data as MonthlyRevenueData;
                                        final revenueText = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0).format(monthlyData.revenue);
                                        final appointments = monthlyData.revenue / _testFees;
                                        return Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.3),
                                                blurRadius: 5,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Month: ${monthlyData.month}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Revenue: $revenueText',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _primaryColor,
                                                ),
                                              ),
                                              Text(
                                                'Appointments: ${appointments.toInt()}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _secondaryColor,
                                                ),
                                              ),
                                              Text(
                                                'Formula: Rs ${_testFees.toStringAsFixed(0)} × ${appointments.toInt()}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    series: <CartesianSeries>[
                                      LineSeries<MonthlyRevenueData, String>(
                                        dataSource: _lineChartData,
                                        xValueMapper: (MonthlyRevenueData data, _) => data.month,
                                        yValueMapper: (MonthlyRevenueData data, _) => data.revenue,
                                        name: 'Revenue',
                                        color: _primaryColor,
                                        width: 3,
                                        markerSettings: const MarkerSettings(
                                          isVisible: true,
                                          shape: DataMarkerType.circle,
                                          borderWidth: 2,
                                          borderColor: Color(0xFF18A3B6),
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Monthly Revenue Bar Chart - FIXED TOOLTIP
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
                          Row(
                            children: [
                              Icon(Icons.bar_chart, color: _primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Monthly Revenue (Last 6 Months)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _monthlyRevenueData.isEmpty
                              ? Container(
                                  height: 200,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No monthly revenue data',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 250,
                                  child: SfCartesianChart(
                                    primaryXAxis: const CategoryAxis(
                                      labelStyle: TextStyle(fontSize: 11),
                                    ),
                                    primaryYAxis: NumericAxis(
                                      numberFormat: NumberFormat.currency(symbol: ''),
                                      labelStyle: const TextStyle(fontSize: 10),
                                    ),
                                    tooltipBehavior: TooltipBehavior(
                                      enable: true,
                                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                                        final monthlyData = data as MonthlyRevenueData;
                                        final revenueText = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0).format(monthlyData.revenue);
                                        final appointments = monthlyData.revenue / _testFees;
                                        return Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.3),
                                                blurRadius: 5,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Month: ${monthlyData.month}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Revenue: $revenueText',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _primaryColor,
                                                ),
                                              ),
                                              Text(
                                                'Appointments: ${appointments.toInt()}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _secondaryColor,
                                                ),
                                              ),
                                              Text(
                                                'Formula: Rs ${_testFees.toStringAsFixed(0)} × ${appointments.toInt()}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    series: <CartesianSeries>[
                                      ColumnSeries<MonthlyRevenueData, String>(
                                        dataSource: _monthlyRevenueData,
                                        xValueMapper: (MonthlyRevenueData data, _) => data.month,
                                        yValueMapper: (MonthlyRevenueData data, _) => data.revenue,
                                        name: 'Revenue',
                                        color: _primaryColor,
                                        dataLabelSettings: const DataLabelSettings(
                                          isVisible: true,
                                          labelAlignment: ChartDataLabelAlignment.top,
                                          textStyle: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Doctor Performance
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
                          Row(
                            children: [
                              Icon(Icons.medical_services, color: _primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Doctor Performance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_doctorRevenues.length} doctors',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Revenue generated per doctor (Rs ${_testFees.toStringAsFixed(0)} × appointments)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _doctorRevenues.isEmpty
                              ? Container(
                                  height: 100,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_off,
                                        color: Colors.grey[400],
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No doctor appointment data',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: _doctorRevenues.map((doctor) {
                                    final rank = _doctorRevenues.indexOf(doctor) + 1;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: _bgColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: _lightColor,
                                          child: Text(
                                            rank.toString(),
                                            style: TextStyle(
                                              color: _primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          doctor.doctorName,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${doctor.appointmentCount} appointments × Rs ${_testFees.toStringAsFixed(0)}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              width: double.infinity,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: _lightColor,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                              child: FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: _totalRevenue > 0 
                                                    ? doctor.totalRevenue / _totalRevenue 
                                                    : 0,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: _primaryColor,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Rs ${doctor.totalRevenue.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _primaryColor,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${((doctor.totalRevenue / _totalRevenue) * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Summary Card
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
                          Row(
                            children: [
                              Icon(Icons.summarize_outlined, color: _primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Revenue Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryRow('Medical Center', _medicalCenterName),
                          _buildSummaryRow('Test Fees', 'Rs ${_testFees.toStringAsFixed(0)}'),
                          _buildSummaryRow('Total Appointments', _totalAppointments.toString()),
                          _buildSummaryRow('Total Revenue', 'Rs ${_totalRevenue.toStringAsFixed(0)}'),
                          _buildSummaryRow('Calculation', 'Rs ${_testFees.toStringAsFixed(0)} × $_totalAppointments'),
                          _buildSummaryRow('Registered Doctors', _totalDoctors.toString()),
                          _buildSummaryRow('Avg per Doctor', 'Rs ${_avgRevenuePerDoctor.toStringAsFixed(0)}'),
                          _buildSummaryRow('This Month', 'Rs ${_thisMonthRevenue.toStringAsFixed(0)}'),
                          if (_revenueChangePercentage != 0)
                            _buildSummaryRow(
                              'Month Change',
                              _revenueChangePercentage >= 0 
                                  ? '+${_revenueChangePercentage.toStringAsFixed(1)}%'
                                  : '${_revenueChangePercentage.toStringAsFixed(1)}%',
                              color: _revenueChangePercentage >= 0 ? Colors.green : Colors.red,
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
        ),
      ],
    );
  }

  Widget _buildStatCardWidget(String title, String value, IconData icon, Color color, {String? subtitle}) {
    final colorValue = color.value;
    final opacityColor = Color(colorValue).withOpacity(0.1);
    
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: opacityColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (title.contains('Revenue') || title.contains('Month'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _lightColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LKR',
                      style: TextStyle(
                        fontSize: 8,
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Data Models
class DoctorRevenue {
  final String doctorId;
  final String doctorName;
  final String medicalCenterName;
  double totalRevenue;
  int appointmentCount;

  DoctorRevenue({
    required this.doctorId,
    required this.doctorName,
    required this.medicalCenterName,
    required this.totalRevenue,
    required this.appointmentCount,
  });
}

class MonthlyRevenueData {
  final String month;
  final double revenue;
  final DateTime date;

  MonthlyRevenueData({
    required this.month,
    required this.revenue,
    required this.date,
  });
}