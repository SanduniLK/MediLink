import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthAnalysisPage extends StatefulWidget {
  final String patientId;
    final Map<String, dynamic> additionalDetails;
  
  const HealthAnalysisPage({super.key, required this.patientId,required this.additionalDetails,});
  
  @override
  State<HealthAnalysisPage> createState() => _HealthAnalysisPageState();

  
}
enum ChartType { labReports, bloodPressure }
class _HealthAnalysisPageState extends State<HealthAnalysisPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedTestType = 'Full Blood Count (FBC)';
  String _selectedParameter = 'Hemoglobin (Hb)';
  ChartType _selectedChartType = ChartType.labReports;
  
  @override
  void initState() {
    super.initState();
    print('🚀 HealthAnalysisPage for patient: ${widget.patientId}');
  }
  
  @override
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Health Trend Analysis'),
      backgroundColor: const Color(0xFF18A3B6),
      elevation: 0,
    ),
    body: SingleChildScrollView(
      child: Column(
        children: [
          // Lab Reports Section
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: const Row(
              children: [
                Icon(Icons.biotech, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Lab Reports Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          // Test Type Selector
          _buildTestTypeSelector(),
          
          // Parameter Selector
          _buildParameterSelector(),
          
          // Lab Chart Section
          Container(
            height: 400, // Fixed height for lab chart
            child: _buildChartSection(),
          ),
          
          const SizedBox(height: 30),
          const Divider(thickness: 2),
          const SizedBox(height: 20),
          
          // Blood Pressure Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red[50],
            child: const Row(
              children: [
                Icon(Icons.monitor_heart, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text(
                  'Blood Pressure Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // BP Charts
          _buildBPCharts(),
          
          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}
  
  Widget _buildTestTypeSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('patient_notes')
          .where('patientId', isEqualTo: widget.patientId)
          .where('noteType', whereIn: ['verified_report_analysis', 'test_report_analysis'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildSelectorLoading('Loading test types...');
        }
        
        final reports = snapshot.data!.docs;
        
        if (reports.isEmpty) {
          return _buildSelectorError('No lab reports found');
        }
        
        final categories = <String>{};
        for (var report in reports) {
          final data = report.data() as Map<String, dynamic>;
          final category = data['testReportCategory']?.toString();
          if (category != null && category.isNotEmpty) {
            categories.add(category);
          }
        }
        
        final categoryList = categories.toList();
        
        if (categoryList.isEmpty) {
          return _buildSelectorError('No test categories found');
        }
        
        // Update selected type if needed
        if (!categoryList.contains(_selectedTestType)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedTestType = categoryList.first;
              });
            }
          });
        }
        
        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              const Icon(Icons.category, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Test Type:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedTestType,
                  isExpanded: true,
                  underline: Container(height: 1, color: Colors.blue),
                  items: categoryList.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category.split('(').first.trim(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTestType = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildParameterSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Parameter:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _getAvailableParameters().length,
              itemBuilder: (context, index) {
                final param = _getAvailableParameters()[index];
                final isSelected = param == _selectedParameter;
                final shortName = param.split('(').first.trim();
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      shortName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF18A3B6),
                    backgroundColor: Colors.grey[200],
                    onSelected: (selected) {
                      setState(() {
                        _selectedParameter = param;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  List<String> _getAvailableParameters() {
    // Based on test type, return available parameters
    if (_selectedTestType == 'Full Blood Count (FBC)') {
      return [
        'Hemoglobin (Hb)',
        'White Blood Cells (WBC)',
        'Platelets',
        'Red Blood Cells (RBC)',
        'Hematocrit (HCT)',
        'MCV',
        'MCH',
        'MCHC',
        'Neutrophils',
        'Lymphocytes',
        'Monocytes',
        'Eosinophils',
        'Basophils',
      ];
    } else if (_selectedTestType == 'Lipid Profile') {
      return [
        'Total Cholesterol',
        'LDL Cholesterol',
        'HDL Cholesterol',
        'Triglycerides',
      ];
    }  else if (_selectedTestType == 'Thyroid (TSH) Test') {
      return [
        'TSH',
        
      ];
    } else if (_selectedTestType == 'Blood Sugar Test') {
      return [
        'Fasting Glucose',
        
      ];
    } else if (_selectedTestType == 'Urine Analysis') {
      return [
        'Specific Gravity',
        'pH',
        'Glucose',
        'Protein',
        'Ketones',
        'Blood',
        'Bilirubin',
      ];
    }
    
    return ['Hemoglobin (Hb)', 'Unknown'];
  }
  
  Widget _buildSelectorLoading(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
Widget _buildTrendChart(List<ChartDataPoint> data) {
  // Get unit for this parameter
  final unit = _getUnitForParameter(_selectedParameter);
  
  // Get normal range for this parameter
  final normalRange = _getNormalRangeForParameter(_selectedParameter);
  final lowRange = normalRange['low'] as double;
  final highRange = normalRange['high'] as double;
  
  // Calculate min and max values for Y-axis
  double minValue = double.infinity;
  double maxValue = double.negativeInfinity;
  
  for (var point in data) {
    if (point.value < minValue) minValue = point.value;
    if (point.value > maxValue) maxValue = point.value;
  }
  
  // Add padding to Y-axis range
  double yAxisPadding = (maxValue - minValue) * 0.2;
  if (yAxisPadding == 0) yAxisPadding = 1; // If all values are same
  final yMin = minValue - yAxisPadding;
  final yMax = maxValue + yAxisPadding;
  
  return Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Normal range text above chart
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Normal Range: $lowRange - $highRange $unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        
        // The Chart (same as before)
        SfCartesianChart(
          title: ChartTitle(
            text: '$_selectedParameter Trend ($unit)',
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          legend: const Legend(isVisible: true),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
              final chartPoint = data as ChartDataPoint;
              final statusText = chartPoint.status == 'normal' ? 'Normal' : 
                              chartPoint.status == 'high' ? 'High' : 'Low';
              final statusColor = _getStatusColor(chartPoint.status);
              
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${chartPoint.date}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Value: ${chartPoint.value.toStringAsFixed(2)} $unit',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: $statusText',
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // ADD NORMAL RANGE TO TOOLTIP
                    const SizedBox(height: 4),
                    Text(
                      'Normal: $lowRange - $highRange $unit',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          primaryXAxis: CategoryAxis(
            title: const AxisTitle(text: 'Test Date'),
            labelRotation: -45,
            labelStyle: const TextStyle(fontSize: 10),
          ),
          primaryYAxis: NumericAxis(
            title: AxisTitle(text: 'Value ($unit)'),
            minimum: yMin > 0 ? yMin : 0,
            maximum: yMax,
          ),
          series: <CartesianSeries>[
            // Line series
            LineSeries<ChartDataPoint, String>(
              name: _selectedParameter,
              dataSource: data,
              xValueMapper: (ChartDataPoint point, _) => point.date,
              yValueMapper: (ChartDataPoint point, _) => point.value,
              pointColorMapper: (ChartDataPoint point, _) => _getStatusColor(point.status),
              markerSettings: const MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                height: 12,
                width: 12,
                borderWidth: 2,
                borderColor: Colors.white,
              ),
              dataLabelSettings: DataLabelSettings(
                isVisible: data.length <= 10,
                labelAlignment: ChartDataLabelAlignment.top,
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                  final chartPoint = data as ChartDataPoint;
                  return Text(
                    chartPoint.value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(chartPoint.status),
                    ),
                  );
                },
              ),
              color: const Color(0xFF18A3B6),
              width: 2,
            ),
          ],
        ),
      ],
    ),
  );
}

// Add this helper method for number formatting
String? _getNumberFormat(String parameter) {
  // Return format based on parameter type
  if (parameter == 'White Blood Cells (WBC)' || 
      parameter == 'Platelets' ||
      parameter.contains('Cholesterol')) {
    return '#,##0';
  }
  return '#,##0.##';
}


  Widget _buildSelectorError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange[50],
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChartSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('patient_notes')
          .where('patientId', isEqualTo: widget.patientId)
          .where('testReportCategory', isEqualTo: _selectedTestType)
          .where('noteType', whereIn: ['verified_report_analysis', 'test_report_analysis'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }
        
        final reports = snapshot.data?.docs ?? [];
        
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.show_chart, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No $_selectedTestType reports found',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        // Extract chart data
        final chartData = <ChartDataPoint>[];
        
        for (var report in reports) {
          final data = report.data() as Map<String, dynamic>;
          final testDate = _fixTestDate(data['testDate']?.toString());
          final verifiedParameters = _extractParameters(data);
          
          print('📋 Processing report: ${report.id}');
          print('📅 Test date: $testDate');
          print('📊 Has parameters: ${verifiedParameters.isNotEmpty}');
          
          for (var paramData in verifiedParameters) {
            if (paramData['parameter'] == _selectedParameter) {
              final value = double.tryParse(paramData['value']?.toString() ?? '0');
              final status = paramData['status']?.toString() ?? 'normal';
              
              if (value != null && value > 0) {
                chartData.add(ChartDataPoint(
                  date: testDate,
                  dateFormatted: _formatDateForSorting(testDate),
                  value: value,
                  status: status,
                  parameter: _selectedParameter,
                ));
                print('✅ Added data point: $testDate - $value');
              }
              break;
            }
          }
        }
        
        if (chartData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.show_chart, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No data for $_selectedParameter',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try selecting a different parameter',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        // Sort by date
        chartData.sort((a, b) => a.dateFormatted.compareTo(b.dateFormatted));
        
        print('📈 Final chart data points: ${chartData.length}');
        for (var point in chartData) {
          print('  - ${point.date}: ${point.value}');
        }
        
        // Build the chart
        return _buildTrendChart(chartData);
      },
    );
  }
  
List<Map<String, dynamic>> _extractParameters(Map<String, dynamic> data) {
  final parameters = <Map<String, dynamic>>[];
  
  print('🔍 Extracting parameters from data...');
  print('📋 Data keys: ${data.keys}');
  
  // 1. Try verifiedParameters first (most reliable)
  if (data['verifiedParameters'] != null) {
    final verifiedParams = data['verifiedParameters'] as List<dynamic>;
    print('📊 Found verifiedParameters: ${verifiedParams.length}');
    
    for (var param in verifiedParams) {
      if (param is Map) {
        final paramMap = Map<String, dynamic>.from(param);
        print('  - ${paramMap['parameter']}: ${paramMap['value']}');
        
        // Ensure status exists
        if (paramMap['status'] == null) {
          paramMap['status'] = 'normal';
        }
        
        parameters.add(paramMap);
      }
    }
  }
  
  // 2. Try results
  if (data['results'] != null && parameters.isEmpty) {
    final results = data['results'] as List<dynamic>;
    print('📊 Found results: ${results.length}');
    
    for (var result in results) {
      if (result is Map) {
        final resultMap = Map<String, dynamic>.from(result);
        print('  - ${resultMap['parameter']}: ${resultMap['value']}');
        
        parameters.add(resultMap);
      }
    }
  }
  
  // 3. Try resultsByLevel
  if (data['resultsByLevel'] != null && parameters.isEmpty) {
    final resultsByLevel = data['resultsByLevel'] as Map<String, dynamic>;
    print('📊 Found resultsByLevel: ${resultsByLevel.keys}');
    
    // Extract from all levels
    if (resultsByLevel['high'] != null) {
      final highResults = resultsByLevel['high'] as List<dynamic>;
      for (var result in highResults) {
        if (result is Map) {
          final resultMap = Map<String, dynamic>.from(result);
          resultMap['status'] = 'high';
          parameters.add(resultMap);
        }
      }
    }
    
    if (resultsByLevel['normal'] != null) {
      final normalResults = resultsByLevel['normal'] as List<dynamic>;
      for (var result in normalResults) {
        if (result is Map) {
          final resultMap = Map<String, dynamic>.from(result);
          resultMap['status'] = 'normal';
          parameters.add(resultMap);
        }
      }
    }
    
    if (resultsByLevel['low'] != null) {
      final lowResults = resultsByLevel['low'] as List<dynamic>;
      for (var result in lowResults) {
        if (result is Map) {
          final resultMap = Map<String, dynamic>.from(result);
          resultMap['status'] = 'low';
          parameters.add(resultMap);
        }
      }
    }
  }
  
  print('✅ Total parameters extracted: ${parameters.length}');
  return parameters;
}
  
  String _fixTestDate(dynamic dateData) {
  print('🕐 Fixing test date data: $dateData (Type: ${dateData.runtimeType})');
  
  if (dateData == null) {
    print('❌ Date data is null');
    return 'Unknown';
  }
  
  // 1. Check if it's already a formatted string (like "28/12/2025")
  if (dateData is String) {
    print('📅 Processing String: $dateData');
    
    // Check if it's a proper date string (contains numbers and slashes)
    if (dateData.contains('/') && dateData.length >= 8) {
      return dateData;
    }
    
    // If it looks like a timestamp string, try to parse it
    if (dateData.contains('December') || dateData.contains('UTC')) {
      try {
        // Try to parse timestamp string
        final dateTime = DateTime.tryParse(dateData);
        if (dateTime != null) {
          return DateFormat('dd/MM/yyyy').format(dateTime);
        }
      } catch (e) {
        print('❌ Error parsing timestamp string: $e');
      }
    }
  }
  
  // 2. Handle Firestore Timestamp
  if (dateData is Timestamp) {
    print('📅 Processing Firestore Timestamp');
    try {
      final dateTime = dateData.toDate();
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      print('❌ Error converting Timestamp: $e');
      return 'Unknown';
    }
  }
  
  // 3. Handle DateTime object
  if (dateData is DateTime) {
    print('📅 Processing DateTime');
    return DateFormat('dd/MM/yyyy').format(dateData);
  }
  
  // 4. Handle Map
  if (dateData is Map<String, dynamic>) {
    print('📅 Processing Map: ${dateData.keys}');
    
    // Try testDateFormatted first (usually a string)
    if (dateData['testDateFormatted'] != null) {
      print('✅ Found testDateFormatted: ${dateData['testDateFormatted']}');
      return _fixTestDate(dateData['testDateFormatted']);
    }
    
    // Try testDate (could be Timestamp or string)
    if (dateData['testDate'] != null) {
      print('✅ Found testDate: ${dateData['testDate']}');
      return _fixTestDate(dateData['testDate']);
    }
  }
  
  print('❌ Unknown date format: ${dateData.runtimeType}');
  return 'Unknown';
}
  
  String _formatDateForSorting(String dateStr) {
    if (dateStr == 'Unknown') return '9999-12-31'; // Put unknown dates at the end
    
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          String day = parts[0].padLeft(2, '0');
          String month = parts[1].padLeft(2, '0');
          String year = parts[2];
          
          // Ensure year has 4 digits
          if (year.length == 2) {
            final yearNum = int.tryParse(year) ?? 0;
            if (yearNum >= 0 && yearNum <= 30) {
              year = '20$year';
            } else {
              year = '19$year';
            }
          }
          
          return '$year-$month-$day';
        }
      }
    } catch (e) {
      print('❌ Error formatting date $dateStr: $e');
    }
    
    return dateStr;
  }
  
Map<String, dynamic> _getNormalRangeForParameter(String parameter) {
  // Normal ranges for CBC/FBC parameters
  final fbcRanges = {
    'Hemoglobin (Hb)': {'low': 13.0, 'high': 17.0, 'unit': 'g/dL'},
    'White Blood Cells (WBC)': {'low': 4000.0, 'high': 11000.0, 'unit': '/cmm'},
    'Platelets': {'low': 150000.0, 'high': 450000.0, 'unit': '/cmm'},
    'Red Blood Cells (RBC)': {'low': 4.5, 'high': 5.9, 'unit': 'million/cmm'},
    'Hematocrit (HCT)': {'low': 40.0, 'high': 54.0, 'unit': '%'},
    'MCV': {'low': 80.0, 'high': 100.0, 'unit': 'fL'},
    'MCH': {'low': 27.0, 'high': 32.0, 'unit': 'pg'},
    'MCHC': {'low': 32.0, 'high': 36.0, 'unit': 'g/dL'},
    'Neutrophils': {'low': 40.0, 'high': 75.0, 'unit': '%'},
    'Lymphocytes': {'low': 20.0, 'high': 45.0, 'unit': '%'},
    'Monocytes': {'low': 2.0, 'high': 10.0, 'unit': '%'},
    'Eosinophils': {'low': 1.0, 'high': 6.0, 'unit': '%'},
    'Basophils': {'low': 0.0, 'high': 2.0, 'unit': '%'},
  };
  
  // Normal ranges for Lipid Profile
  final lipidRanges = {
    'Total Cholesterol': {'low': 0.0, 'high': 200.0, 'unit': 'mg/dL'},
    'LDL Cholesterol': {'low': 0.0, 'high': 100.0, 'unit': 'mg/dL'},
    'HDL Cholesterol': {'low': 40.0, 'high': 60.0, 'unit': 'mg/dL'},
    'Triglycerides': {'low': 0.0, 'high': 150.0, 'unit': 'mg/dL'},
  };
  
  // Normal ranges for Thyroid
  final thyroidRanges = {
    'TSH': {'low': 0.4, 'high': 4.0, 'unit': 'μIU/mL'},
  };
  
  // Normal ranges for Blood Sugar
  final sugarRanges = {
    'Fasting Glucose': {'low': 70.0, 'high': 110.0, 'unit': 'mg/dL'},
  };
  
  // Check all ranges
  if (fbcRanges.containsKey(parameter)) return fbcRanges[parameter]!;
  if (lipidRanges.containsKey(parameter)) return lipidRanges[parameter]!;
  if (thyroidRanges.containsKey(parameter)) return thyroidRanges[parameter]!;
  if (sugarRanges.containsKey(parameter)) return sugarRanges[parameter]!;
  
  // Default range
  return {'low': 0.0, 'high': 100.0, 'unit': ''};
}
  Widget _buildBPCharts() {
     print('🔍 DEBUG: additionalDetails keys: ${widget.additionalDetails.keys}');
  
  // Get the nested additionalDetails
  Map<String, dynamic> actualDetails = {};
  
  if (widget.additionalDetails.containsKey('additionalDetails') && 
      widget.additionalDetails['additionalDetails'] is Map) {
    actualDetails = widget.additionalDetails['additionalDetails'] as Map<String, dynamic>;
    print('✅ Found nested additionalDetails');
    print('📊 Nested keys: ${actualDetails.keys}');
  } else {
    actualDetails = widget.additionalDetails;
    print('⚠️ No nested additionalDetails, using top level');
  }
  
  // Now get bpReadings from the correct location
  final bpReadings = (actualDetails['bpReadings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  
  print('📊 bpReadings count: ${bpReadings.length}');
  for (var i = 0; i < bpReadings.length; i++) {
    print('  📈 Reading $i: ${bpReadings[i]}');
  }
  
  if (bpReadings.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monitor_heart_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Blood Pressure Readings Available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Add BP readings in your profile settings',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  
 
  
  
  if (bpReadings.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monitor_heart_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Blood Pressure Readings Available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'BP readings will appear here when added',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Prepare data for charts
  final systolicData = <BPDataPoint>[];
  final diastolicData = <BPDataPoint>[];
  
  for (var reading in bpReadings) {
    final date = _parseBPDate(reading['date']);
    final systolic = (reading['systolic'] as num?)?.toDouble() ?? 0.0;
    final diastolic = (reading['diastolic'] as num?)?.toDouble() ?? 0.0;
    
    systolicData.add(BPDataPoint(
      date: date,
      dateFormatted: DateFormat('dd/MM').format(date),
      value: systolic,
      type: 'Systolic',
    ));
    
    diastolicData.add(BPDataPoint(
      date: date,
      dateFormatted: DateFormat('dd/MM').format(date),
      value: diastolic,
      type: 'Diastolic',
    ));
  }
  
  // Sort by date
  systolicData.sort((a, b) => a.date.compareTo(b.date));
  diastolicData.sort((a, b) => a.date.compareTo(b.date));

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              const Icon(Icons.monitor_heart, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Blood Pressure Trends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    '${bpReadings.length} readings recorded',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Latest Reading Card
        _buildLatestBPReadingCard(bpReadings),
        
        const SizedBox(height: 24),
        
        // Combined BP Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blood Pressure Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Systolic (Upper) & Diastolic (Lower)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 300,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(
                      title: AxisTitle(text: 'Date'),
                      labelRotation: -45,
                      labelStyle: const TextStyle(fontSize: 10),
                    ),
                    primaryYAxis: NumericAxis(
                      title: AxisTitle(text: 'mmHg'),
                      minimum: 50,
                      maximum: 180,
                      interval: 20,
                    ),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    legend: const Legend(
                      isVisible: true,
                      position: LegendPosition.top,
                    ),
                    series: <CartesianSeries>[
                      // Systolic Line
                      LineSeries<BPDataPoint, String>(
                        name: 'Systolic',
                        dataSource: systolicData,
                        xValueMapper: (BPDataPoint data, _) => data.dateFormatted,
                        yValueMapper: (BPDataPoint data, _) => data.value,
                        color: Colors.red,
                        width: 3,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.circle,
                          height: 6,
                          width: 6,
                          borderWidth: 2,
                          borderColor: Colors.white,
                        ),
                        dataLabelSettings: DataLabelSettings(
                          isVisible: true,
                          builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                            final pointData = data as BPDataPoint;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pointData.value.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Diastolic Line
                      LineSeries<BPDataPoint, String>(
                        name: 'Diastolic',
                        dataSource: diastolicData,
                        xValueMapper: (BPDataPoint data, _) => data.dateFormatted,
                        yValueMapper: (BPDataPoint data, _) => data.value,
                        color: Colors.blue,
                        width: 3,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.circle,
                          height: 6,
                          width: 6,
                          borderWidth: 2,
                          borderColor: Colors.white,
                        ),
                        dataLabelSettings: DataLabelSettings(
                          isVisible: true,
                          builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                            final pointData = data as BPDataPoint;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pointData.value.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Normal systolic range (120)
                      LineSeries<BPDataPoint, String>(
                        name: 'Normal Systolic',
                        dataSource: List.generate(systolicData.length, (index) => BPDataPoint(
                          date: systolicData[index].date,
                          dateFormatted: systolicData[index].dateFormatted,
                          value: 120,
                          type: 'Normal',
                        )),
                        xValueMapper: (BPDataPoint data, _) => data.dateFormatted,
                        yValueMapper: (BPDataPoint data, _) => data.value,
                        color: Colors.green.withOpacity(0.5),
                        width: 2,
                        dashArray: [5, 5],
                      ),
                      // Normal diastolic range (80)
                      LineSeries<BPDataPoint, String>(
                        name: 'Normal Diastolic',
                        dataSource: List.generate(diastolicData.length, (index) => BPDataPoint(
                          date: diastolicData[index].date,
                          dateFormatted: diastolicData[index].dateFormatted,
                          value: 80,
                          type: 'Normal',
                        )),
                        xValueMapper: (BPDataPoint data, _) => data.dateFormatted,
                        yValueMapper: (BPDataPoint data, _) => data.value,
                        color: Colors.green.withOpacity(0.5),
                        width: 2,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // BP Status Table
        _buildBPStatusTable(bpReadings),
        
        const SizedBox(height: 24),
        
        // BP Categories Info
        _buildBPCategoriesInfo(),
      ],
    ),
  );
}
Widget _buildLatestBPReadingCard(List<Map<String, dynamic>> bpReadings) {
  if (bpReadings.isEmpty) return const SizedBox();
  
  // Get latest reading
  final latestReading = bpReadings.reduce((a, b) {
    final dateA = _parseBPDate(a['date']);
    final dateB = _parseBPDate(b['date']);
    return dateA.isAfter(dateB) ? a : b;
  });
  
  final systolic = latestReading['systolic'] as int? ?? 0;
  final diastolic = latestReading['diastolic'] as int? ?? 0;
  final date = _parseBPDate(latestReading['date']);
  final status = _getBPStatus(systolic, diastolic);
  
  Color statusColor;
  IconData statusIcon;
  
  switch (status) {
    case 'Normal':
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      break;
    case 'Elevated':
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      break;
    case 'High (Stage 1)':
    case 'High (Stage 2)':
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      break;
    default:
      statusColor = Colors.grey;
      statusIcon = Icons.help;
  }
  
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Latest Reading',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Systolic',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$systolic',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'mmHg',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Text(
                '/',
                style: TextStyle(fontSize: 32, color: Colors.grey),
              ),
              Column(
                children: [
                  Text(
                    'Diastolic',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$diastolic',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'mmHg',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM yyyy').format(date),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                '$systolic/$diastolic mmHg',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
Widget _buildBPStatusTable(List<Map<String, dynamic>> bpReadings) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blood Pressure History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Date',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Systolic',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Diastolic',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Table Rows
                ...bpReadings.map((reading) {
                  final date = _parseBPDate(reading['date']);
                  final systolic = reading['systolic'] as int? ?? 0;
                  final diastolic = reading['diastolic'] as int? ?? 0;
                  final status = _getBPStatus(systolic, diastolic);
                  
                  Color statusColor;
                  switch (status) {
                    case 'Normal':
                      statusColor = Colors.green;
                      break;
                    case 'Elevated':
                      statusColor = Colors.orange;
                      break;
                    case 'High (Stage 1)':
                    case 'High (Stage 2)':
                      statusColor = Colors.red;
                      break;
                    default:
                      statusColor = Colors.grey;
                  }
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            DateFormat('dd/MM/yy').format(date),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$systolic',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$diastolic',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildBPCategoriesInfo() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blood Pressure Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Understanding your blood pressure readings:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _buildBPCategoryItem('Normal', '≤120', 'and', '≤80', Colors.green),
          _buildBPCategoryItem('Elevated', '120-129', 'and', '<80', Colors.orange),
          _buildBPCategoryItem('High (Stage 1)', '130-139', 'or', '80-89', Colors.red),
          _buildBPCategoryItem('High (Stage 2)', '≥140', 'or', '≥90', Colors.red.shade700),
        ],
      ),
    ),
  );
}
Widget _buildBPCategoryItem(String category, String systolic, String andOr, String diastolic, Color color) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Systolic $systolic $andOr Diastolic $diastolic mmHg',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
DateTime _parseBPDate(dynamic dateData) {
  if (dateData is Timestamp) {
    return dateData.toDate();
  } else if (dateData is String) {
    try {
      return DateTime.parse(dateData);
    } catch (e) {
      return DateTime.now();
    }
  } else if (dateData is DateTime) {
    return dateData;
  }
  return DateTime.now();
}

String _getBPStatus(int systolic, int diastolic) {
  if (systolic < 120 && diastolic < 80) {
    return 'Normal';
  } else if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
    return 'Elevated';
  } else if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
    return 'High (Stage 1)';
  } else if (systolic >= 140 || diastolic >= 90) {
    return 'High (Stage 2)';
  }
  return 'Unknown';
}
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.amber;
      case 'normal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  String _getUnitForParameter(String parameter) {
    // Simple unit mapping
    final unitMap = {
      'Hemoglobin (Hb)': 'g/dL',
      'White Blood Cells (WBC)': '/cmm',
      'Platelets': '/cmm',
      'Red Blood Cells (RBC)': 'million/cmm',
      'Hematocrit (HCT)': '%',
      'MCV': 'fL',
      'MCH': 'pg',
      'MCHC': 'g/dL',
      'Neutrophils': '%',
      'Lymphocytes': '%',
      'Monocytes': '%',
      'Eosinophils': '%',
      'Basophils': '%',
      'Total Cholesterol': 'mg/dL',
      'LDL Cholesterol': 'mg/dL',
      'HDL Cholesterol': 'mg/dL',
      'Triglycerides': 'mg/dL',
      'SGPT (ALT)': 'U/L',
      'SGOT (AST)': 'U/L',
      'Alkaline Phosphatase': 'U/L',
      'Total Bilirubin': 'mg/dL',
      'Direct Bilirubin': 'mg/dL',
      'Albumin': 'g/dL',
      'Total Protein': 'g/dL',
      'Creatinine': 'mg/dL',
      'Urea': 'mg/dL',
      'Uric Acid': 'mg/dL',
      'Sodium': 'mEq/L',
      'Potassium': 'mEq/L',
      'eGFR': 'mL/min',
      'TSH': 'μIU/mL',
      'T3': 'ng/dL',
      'T4': 'μg/dL',
      'Fasting Glucose': 'mg/dL',
      'Postprandial Glucose': 'mg/dL',
      'HbA1c': '%',
      'Specific Gravity': '',
      'pH': '',
      'Glucose': '',
      'Protein': '',
      'Ketones': '',
      'Blood': '',
      'Bilirubin': '',
    };
    
    return unitMap[parameter] ?? '';
  }
}

class ChartDataPoint {
  final String date;
  final String dateFormatted;
  final double value;
  final String status;
  final String parameter;
  
  ChartDataPoint({
    required this.date,
    required this.dateFormatted,
    required this.value,
    required this.status,
    required this.parameter,
  });
}
class BPDataPoint {
  final DateTime date;
  final String dateFormatted;
  final double value;
  final String type;
  
  BPDataPoint({
    required this.date,
    required this.dateFormatted,
    required this.value,
    required this.type,
  });
}