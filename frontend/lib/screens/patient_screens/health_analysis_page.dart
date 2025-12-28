import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthAnalysisPage extends StatefulWidget {
  final String patientId;
  
  const HealthAnalysisPage({super.key, required this.patientId});
  
  @override
  State<HealthAnalysisPage> createState() => _HealthAnalysisPageState();
}

class _HealthAnalysisPageState extends State<HealthAnalysisPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedTestType = 'Full Blood Count (FBC)';
  String _selectedParameter = 'Hemoglobin (Hb)';
  
  @override
  void initState() {
    super.initState();
    print('🚀 HealthAnalysisPage for patient: ${widget.patientId}');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Trend Analysis'),
        backgroundColor: const Color(0xFF18A3B6),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Test Type Selector
          _buildTestTypeSelector(),
          
          // Parameter Selector
          _buildParameterSelector(),
          
          // Chart Section
          Expanded(
            child: _buildChartSection(),
          ),
        ],
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
  
  print('📈 Chart parameters:');
  print('  - Data points: ${data.length}');
  print('  - Min value: $minValue');
  print('  - Max value: $maxValue');
  print('  - Y-axis range: $yMin to $yMax');
  
  return Container(
    padding: const EdgeInsets.all(16),
    child: SfCartesianChart(
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
        // Remove the numberFormat parameter or use correct type
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
            isVisible: data.length <= 10, // Show labels if few points
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
  
  String _fixTestDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    
    // Fix dates like "4.0-11" (which is actually a range, not a date)
    if (dateStr.contains('.') && dateStr.contains('-')) {
      return 'Unknown';
    }
    
    // Fix 2-digit years
    if (dateStr.contains('/') && dateStr.length <= 8) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        if (parts[2].length == 2) {
          // Convert YY to YYYY
          final year = int.tryParse(parts[2]) ?? 0;
          if (year >= 0 && year <= 30) {
            return '${parts[0]}/${parts[1]}/20${parts[2]}';
          } else {
            return '${parts[0]}/${parts[1]}/19${parts[2]}';
          }
        }
      }
    }
    
    return dateStr;
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