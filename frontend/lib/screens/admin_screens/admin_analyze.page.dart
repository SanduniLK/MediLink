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
  String _selectedTimeFrame = 'month';
  String? _selectedMedicalCenter;
  List<MedicalCenter> _medicalCenters = [];
  List<DoctorRevenue> _doctorRevenues = [];
  List<MonthlyRevenue> _monthlyRevenues = [];
  Map<String, dynamic>? _adminData;
  bool _isLoading = true;
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
  Map<String, int> _centerAppointmentCounts = {};

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }
      
      print('=== LOADING ADMIN DATA ===');
      
      // Load all medical centers first
      await _loadMedicalCenters();
      
      // Load revenue data
      await _loadRevenueData();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading admin data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMedicalCenters() async {
  print('Loading medical centers...');
  
  try {
    final centersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'medical_center')
        .get();
    
    _medicalCenters = centersSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Extract name
      String name = data['name']?.toString() ?? 'Unknown Center';
      
      // Extract address
      String address = data['address']?.toString() ?? '';
      
      // Extract specialization
      String specialization = data['specialization']?.toString() ?? '';
      
      // Extract test fees
      double testFees = 0;
      if (data['testFees'] != null) {
        final fees = data['testFees'];
        if (fees is int) {
          testFees = fees.toDouble();
        } else if (fees is double) {
          testFees = fees;
        } else if (fees is String) {
          testFees = double.tryParse(fees) ?? 0;
        }
      }
      
      return MedicalCenter(
        id: doc.id,
        name: name,
        address: address,
        specialization: specialization,
        testFees: testFees,
      );
    }).toList();
    
    print('Loaded ${_medicalCenters.length} medical centers');
    
    // Debug print
    for (var center in _medicalCenters.take(3)) {
      print('Center: ${center.name}, ID: ${center.id}');
    }
    
  } catch (e) {
    print('Error loading medical centers: $e');
  }
}

  Future<void> _loadRevenueData() async {
    print('Loading revenue data...');
    
    try {
      // Fetch all paid appointments
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('paymentStatus', isEqualTo: 'paid')
          .get();
      
      print('Found ${appointmentsSnapshot.docs.length} paid appointments');
      
      // Reset data
      _doctorRevenues.clear();
      _monthlyRevenues.clear();
      _totalRevenue = 0;
      _totalAppointments = appointmentsSnapshot.docs.length;
      _centerAppointmentCounts.clear();
      _thisMonthRevenue = 0;
      
      // Map to store doctor revenues
      final Map<String, DoctorRevenue> doctorRevenueMap = {};
      final Map<String, Map<int, double>> monthlyRevenueMap = {};
      final Map<String, int> centerAppointmentCounts = {};
      
      // Current date for calculations
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Debug print first few appointments
        if (appointmentsSnapshot.docs.indexOf(doc) < 3) {
          print('Appointment data: $data');
        }
        
        // Get appointment details
        final appointmentFees = _parseFees(data['fees']);
        final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
        final doctorId = data['doctorId'] as String?;
        final doctorName = data['doctorName'] as String?;
        final medicalCenterId = data['medicalCenterId'] as String?;
        
        if (doctorId == null || medicalCenterId == null) {
          print('Skipping appointment: missing doctorId or medicalCenterId');
          continue;
        }
        
        // Add to total revenue
        _totalRevenue += appointmentFees;
        
        // Count appointments per medical center
        centerAppointmentCounts[medicalCenterId] = (centerAppointmentCounts[medicalCenterId] ?? 0) + 1;
        
        // Add to doctor revenue
        if (!doctorRevenueMap.containsKey(doctorId)) {
          doctorRevenueMap[doctorId] = DoctorRevenue(
            doctorId: doctorId,
            doctorName: doctorName ?? 'Unknown Doctor',
            totalRevenue: 0,
            appointmentCount: 0,
            medicalCenters: {},
          );
        }
        
        final doctorRev = doctorRevenueMap[doctorId]!;
        doctorRev.totalRevenue += appointmentFees;
        doctorRev.appointmentCount++;
        doctorRev.medicalCenters[medicalCenterId] = 
            (doctorRev.medicalCenters[medicalCenterId] ?? 0) + appointmentFees;
        
        // Add to monthly revenue by medical center
        if (paidAt != null) {
          final monthKey = DateTime(paidAt.year, paidAt.month);
          
          if (!monthlyRevenueMap.containsKey(medicalCenterId)) {
            monthlyRevenueMap[medicalCenterId] = {};
          }
          
          final monthIndex = paidAt.month;
          monthlyRevenueMap[medicalCenterId]![monthIndex] = 
              (monthlyRevenueMap[medicalCenterId]![monthIndex] ?? 0) + appointmentFees;
          
          // Calculate this month's revenue
          if (monthKey.year == currentMonth.year && monthKey.month == currentMonth.month) {
            _thisMonthRevenue += appointmentFees;
          }
        }
      }
      
      // Store center appointment counts
      _centerAppointmentCounts = centerAppointmentCounts;
      
      // Convert doctor revenue map to list and sort
      _doctorRevenues = doctorRevenueMap.values.toList();
      _doctorRevenues.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
      _totalDoctors = _doctorRevenues.length;
      _avgRevenuePerDoctor = _totalDoctors > 0 ? _totalRevenue / _totalDoctors : 0;
      
      // Prepare monthly revenue data for chart
      _prepareMonthlyRevenueData(monthlyRevenueMap);
      
      print('Revenue data loaded:');
      print('Total Revenue: Rs $_totalRevenue');
      print('Total Appointments: $_totalAppointments');
      print('Total Doctors: $_totalDoctors');
      print('This Month Revenue: Rs $_thisMonthRevenue');
      print('Center Appointment Counts: $_centerAppointmentCounts');
      
    } catch (e) {
      print('Error loading revenue data: $e');
    }
  }

  void _prepareMonthlyRevenueData(Map<String, Map<int, double>> monthlyRevenueMap) {
    // Get last 6 months
    final now = DateTime.now();
    final months = <DateTime>[];
    
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i);
      months.add(date);
    }
    
    // Prepare data for each medical center
    _monthlyRevenues.clear();
    for (var center in _medicalCenters) {
      final monthlyData = <MonthlyRevenueData>[];
      
      for (var month in months) {
        final monthIndex = month.month;
        final revenue = monthlyRevenueMap[center.id]?[monthIndex] ?? 0;
        
        monthlyData.add(MonthlyRevenueData(
          month: DateFormat('MMM').format(month),
          revenue: revenue,
          date: month,
        ));
      }
      
      _monthlyRevenues.add(MonthlyRevenue(
        medicalCenterId: center.id,
        medicalCenterName: center.name,
        monthlyData: monthlyData,
        totalRevenue: monthlyData.fold(0.0, (sum, data) => sum + data.revenue),
      ));
    }
    
    // Sort by total revenue
    _monthlyRevenues.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    
    print('Monthly revenue data prepared for ${_monthlyRevenues.length} centers');
  }

  double _parseFees(dynamic fees) {
    if (fees is int) return fees.toDouble();
    if (fees is double) return fees;
    if (fees is String) return double.tryParse(fees) ?? 0;
    return 0;
  }

  int _getAppointmentsCountForCenter(String centerId) {
    return _centerAppointmentCounts[centerId] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            )
          : Column(
              children: [
                // Fixed Header
                Container(
                  padding: const EdgeInsets.only(top: 50, left: 15, right: 15, bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Revenue Dashboard',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: _primaryColor),
                            onPressed: _loadAdminData,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Medical Center Revenue Analysis',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
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
                                  'Filter Data',
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
                                      child: _medicalCenters.isEmpty
                                          ? Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey[300]!),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'No medical centers found',
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                              ),
                                            )
                                          : DropdownButtonFormField<String?>(
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
                                                    child: Text(
                                                      center.name,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }),
                                              ],
                                              onChanged: (String? value) {
                                                setState(() {
                                                  _selectedMedicalCenter = value;
                                                });
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
                                            value: 'month',
                                            child: Row(
                                              children: [
                                                Icon(Icons.calendar_view_month, color: _primaryColor, size: 18),
                                                const SizedBox(width: 8),
                                                const Text('Monthly'),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'quarter',
                                            child: Row(
                                              children: [
                                                Icon(Icons.timeline, color: _primaryColor, size: 18),
                                                const SizedBox(width: 8),
                                                const Text('Quarterly'),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'year',
                                            child: Row(
                                              children: [
                                                Icon(Icons.calendar_today, color: _primaryColor, size: 18),
                                                const SizedBox(width: 8),
                                                const Text('Yearly'),
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
                                'Rs ${_totalRevenue.toStringAsFixed(0)}',
                                Icons.attach_money,
                                _primaryColor,
                              ),
                              _buildStatCard(
                                'Total Appointments',
                                _totalAppointments.toString(),
                                Icons.people_alt,
                                _secondaryColor,
                              ),
                              _buildStatCard(
                                'Active Doctors',
                                _totalDoctors.toString(),
                                Icons.person,
                                _accentColor,
                              ),
                              _buildStatCard(
                                "This Month",
                                'Rs ${_thisMonthRevenue.toStringAsFixed(0)}',
                                Icons.trending_up,
                                const Color(0xFF9C27B0),
                              ),
                            ],
                          ),
                        ),
                        
                        // Medical Center Monthly Revenue Chart
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
                                    'Medical Center Revenue (Last 6 Months)',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _monthlyRevenues.isEmpty
                                      ? Container(
                                          height: 200,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'No revenue data available',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      : SizedBox(
                                          height: 300,
                                          child: SfCartesianChart(
                                            primaryXAxis: CategoryAxis(
                                              title: AxisTitle(text: 'Month'),
                                            ),
                                            primaryYAxis: NumericAxis(
                                              title: AxisTitle(text: 'Revenue (Rs)'),
                                              numberFormat: NumberFormat.currency(symbol: 'Rs '),
                                            ),
                                            legend: Legend(
                                              isVisible: true,
                                              position: LegendPosition.bottom,
                                            ),
                                            tooltipBehavior: TooltipBehavior(
                                              enable: true,
                                              format: 'Revenue: Rs ${'point.y'}',
                                            ),
                                            series: _getMedicalCenterBarSeries(),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Top Doctors Revenue Chart
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
                                    'Top Doctors Revenue',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Top 5 performing doctors',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _doctorRevenues.isEmpty
                                      ? Container(
                                          height: 200,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'No doctor revenue data',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      : SizedBox(
                                          height: 300,
                                          child: SfCartesianChart(
                                            primaryXAxis: CategoryAxis(
                                              title: AxisTitle(text: 'Doctor'),
                                            ),
                                            primaryYAxis: NumericAxis(
                                              title: AxisTitle(text: 'Revenue (Rs)'),
                                              numberFormat: NumberFormat.currency(symbol: 'Rs '),
                                            ),
                                            series: <CartesianSeries>[
                                              ColumnSeries<DoctorRevenue, String>(
                                                dataSource: _doctorRevenues.take(5).toList(),
                                                xValueMapper: (DoctorRevenue data, _) => 
                                                    data.doctorName.split(' ').first,
                                                yValueMapper: (DoctorRevenue data, _) => data.totalRevenue,
                                                name: 'Revenue',
                                                color: _primaryColor,
                                                dataLabelSettings: DataLabelSettings(
                                                  isVisible: true,
                                                  labelAlignment: ChartDataLabelAlignment.top,
                                                  textStyle: const TextStyle(fontSize: 10),
                                                ),
                                              ),
                                            ],
                                            tooltipBehavior: TooltipBehavior(
                                              enable: true,
                                              format: 'Doctor: ${'point.x'}\nRevenue: Rs ${'point.y'}',
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Medical Centers List
                        const SizedBox(height: 15),
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
                                        'Medical Centers Revenue',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryColor,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Rs ${_totalRevenue.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _medicalCenters.isEmpty
                                      ? Container(
                                          height: 100,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'No medical centers found',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      : SizedBox(
                                          height: 300,
                                          child: ListView.builder(
                                            itemCount: _medicalCenters.length,
                                            itemBuilder: (context, index) {
                                              final center = _medicalCenters[index];
                                              final monthlyData = _monthlyRevenues
                                                  .firstWhere((mr) => mr.medicalCenterId == center.id, 
                                                      orElse: () => MonthlyRevenue(
                                                        medicalCenterId: center.id,
                                                        medicalCenterName: center.name,
                                                        monthlyData: [],
                                                        totalRevenue: 0,
                                                      ));
                                              final appointmentCount = _getAppointmentsCountForCenter(center.id);
                                              
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                decoration: BoxDecoration(
                                                  color: _bgColor,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundColor: _lightColor,
                                                    child: Icon(
                                                      Icons.business,
                                                      color: _primaryColor,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    center.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        center.specialization,
                                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        'Test Fees: Rs ${center.testFees.toStringAsFixed(0)}',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                                      ),
                                                    ],
                                                  ),
                                                  trailing: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Rs ${monthlyData.totalRevenue.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: _primaryColor,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: _lightColor,
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Text(
                                                          '$appointmentCount appts',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: _primaryColor,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Top Doctors List
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
                                        'Top Performing Doctors',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryColor,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Avg: Rs ${_avgRevenuePerDoctor.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _doctorRevenues.isEmpty
                                      ? Container(
                                          height: 100,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'No doctor data available',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: _doctorRevenues.take(5).map((doctor) {
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: _bgColor,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor: _lightColor,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: _primaryColor,
                                                  ),
                                                ),
                                                title: Text(
                                                  doctor.doctorName,
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                subtitle: Text(
                                                  '${doctor.appointmentCount} appointments',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                                                      ),
                                                    ),
                                                    Text(
                                                      '${doctor.medicalCenters.length} centers',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey[500],
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
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<BarSeries<MonthlyRevenueData, String>> _getMedicalCenterBarSeries() {
    // Get top 3-5 medical centers for the chart (for better visibility)
    final topCenters = _monthlyRevenues.take(3).toList();
    
    if (topCenters.isEmpty) {
      return [];
    }
    
    return topCenters.map((center) {
      return BarSeries<MonthlyRevenueData, String>(
        dataSource: center.monthlyData,
        xValueMapper: (MonthlyRevenueData data, _) => data.month,
        yValueMapper: (MonthlyRevenueData data, _) => data.revenue,
        name: center.medicalCenterName.length > 15 
            ? '${center.medicalCenterName.substring(0, 15)}...'
            : center.medicalCenterName,
        color: _getColorForIndex(_monthlyRevenues.indexOf(center)),
        dataLabelSettings: const DataLabelSettings(
          isVisible: false,
        ),
      );
    }).toList();
  }

  Color _getColorForIndex(int index) {
    final colors = [
      _primaryColor,
      _secondaryColor,
      _accentColor,
      const Color(0xFF9C27B0),
      const Color(0xFF4CAF50),
    ];
    return index < colors.length ? colors[index] : _primaryColor;
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
}

// Data Models
class MedicalCenter {
  final String id;
  final String name;
  final String address;
  final String specialization;
  final double testFees;

  MedicalCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.specialization,
    required this.testFees,
  });
}

class DoctorRevenue {
  final String doctorId;
  final String doctorName;
  double totalRevenue;
  int appointmentCount;
  Map<String, double> medicalCenters;

  DoctorRevenue({
    required this.doctorId,
    required this.doctorName,
    required this.totalRevenue,
    required this.appointmentCount,
    required this.medicalCenters,
  });
}

class MonthlyRevenue {
  final String medicalCenterId;
  final String medicalCenterName;
  final List<MonthlyRevenueData> monthlyData;
  final double totalRevenue;

  MonthlyRevenue({
    required this.medicalCenterId,
    required this.medicalCenterName,
    required this.monthlyData,
    required this.totalRevenue,
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