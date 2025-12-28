import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FBCTrendCharts extends StatefulWidget {
  final String patientId;
  
  const FBCTrendCharts({Key? key, required this.patientId}) : super(key: key);
  
  @override
  _FBCTrendChartsState createState() => _FBCTrendChartsState();
}

class _FBCTrendChartsState extends State<FBCTrendCharts> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedParameter = 'Hemoglobin (Hb)';
  List<String> _availableParameters = [
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
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FBC Trend Analysis'),
        backgroundColor: Color(0xFF18A3B6),
      ),
      body: Column(
        children: [
          // Parameter Selector
          _buildParameterSelector(),
          
          // Chart
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('patient_notes')
                  .where('patientId', isEqualTo: widget.patientId)
                  .where('testReportCategory', isEqualTo: 'Full Blood Count (FBC)')
                  .orderBy('testDateFormatted', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                
                final reports = snapshot.data!.docs;
                
                if (reports.isEmpty) {
                  return Center(
                    child: Text('No FBC reports found for this patient'),
                  );
                }
                
                // Extract chart data
                final chartData = _extractChartData(reports, _selectedParameter);
                
                if (chartData.isEmpty) {
                  return Center(
                    child: Text('No data available for $_selectedParameter'),
                  );
                }
                
                return _buildChart(chartData, _selectedParameter);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildParameterSelector() {
    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Parameter to View:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableParameters.map((param) {
              final isSelected = param == _selectedParameter;
              return ChoiceChip(
                label: Text(param.split('(').first.trim()),
                selected: isSelected,
                selectedColor: Color(0xFF18A3B6),
                onSelected: (selected) {
                  setState(() {
                    _selectedParameter = param;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  List<ParameterData> _extractChartData(List<QueryDocumentSnapshot> reports, String parameter) {
    final chartData = <ParameterData>[];
    
    for (var report in reports) {
      final data = report.data() as Map<String, dynamic>;
      final testDate = data['testDate']?.toString() ?? '';
      final testDateFormatted = data['testDateFormatted']?.toString() ?? '';
      final verifiedParameters = data['verifiedParameters'] as List<dynamic>?;
      
      if (verifiedParameters != null) {
        // Find the parameter in verified parameters
        for (var param in verifiedParameters) {
          if (param is Map && param['parameter'] == parameter) {
            final value = double.tryParse(param['value']?.toString() ?? '0');
            final status = param['status']?.toString() ?? 'normal';
            
            if (value != null && value > 0) {
              chartData.add(ParameterData(
                date: testDate,
                dateFormatted: testDateFormatted,
                value: value,
                status: status,
                parameter: parameter,
              ));
            }
            break;
          }
        }
      }
    }
    
    // Sort by date
    chartData.sort((a, b) => a.dateFormatted.compareTo(b.dateFormatted));
    
    return chartData;
  }
  
  Widget _buildChart(List<ParameterData> data, String parameter) {
    // Get normal range for this parameter
    final normalRange = _getNormalRange(parameter);
    final refLow = normalRange['low'] ?? 0;
    final refHigh = normalRange['high'] ?? 0;
    final unit = normalRange['unit'] ?? '';
    
    return SfCartesianChart(
      title: ChartTitle(
        text: '$parameter Trend ($unit)',
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      legend: Legend(isVisible: true),
      tooltipBehavior: TooltipBehavior(enable: true),
      primaryXAxis: CategoryAxis(
        title: AxisTitle(text: 'Test Date'),
        labelRotation: -45,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Value ($unit)'),
      ),
      series: <CartesianSeries>[
        // Main line series
        LineSeries<ParameterData, String>(
          name: parameter,
          dataSource: data,
          xValueMapper: (data, _) => data.date,
          yValueMapper: (data, _) => data.value,
          pointColorMapper: (data, _) => _getStatusColor(data.status),
          markerSettings: MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            height: 8,
            width: 8,
            borderWidth: 2,
            borderColor: Colors.white,
          ),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: TextStyle(fontSize: 10),
          ),
        ),
        // Reference low line
        LineSeries<ReferenceLine, String>(
          name: 'Low Normal',
          dataSource: [
            ReferenceLine(x: data.isNotEmpty ? data.first.date : '', y: refLow),
            ReferenceLine(x: data.isNotEmpty ? data.last.date : '', y: refLow),
          ],
          xValueMapper: (line, _) => line.x,
          yValueMapper: (line, _) => line.y,
          color: Colors.yellow[700],
          width: 2,
          dashArray: [5, 5],
          markerSettings: MarkerSettings(isVisible: false),
        ),
        // Reference high line
        LineSeries<ReferenceLine, String>(
          name: 'High Normal',
          dataSource: [
            ReferenceLine(x: data.isNotEmpty ? data.first.date : '', y: refHigh),
            ReferenceLine(x: data.isNotEmpty ? data.last.date : '', y: refHigh),
          ],
          xValueMapper: (line, _) => line.x,
          yValueMapper: (line, _) => line.y,
          color: Colors.red,
          width: 2,
          dashArray: [5, 5],
          markerSettings: MarkerSettings(isVisible: false),
        ),
        // Target range (shaded area)
        RangeAreaSeries<RangeData, String>(
          name: 'Normal Range',
          dataSource: data.map((d) {
            return RangeData(
              x: d.date,
              low: refLow,
              high: refHigh,
            );
          }).toList(),
          xValueMapper: (data, _) => data.x,
          lowValueMapper: (data, _) => data.low,
          highValueMapper: (data, _) => data.high,
          color: Colors.blue.withOpacity(0.1),
        ),
      ],
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.yellow[700]!;
      default:
        return Colors.blue;
    }
  }
  
  Map<String, dynamic> _getNormalRange(String parameter) {
    final Map<String, Map<String, dynamic>> normalRanges = {
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
    };
    
    return normalRanges[parameter] ?? {'low': 0, 'high': 0, 'unit': ''};
  }
}

// Data models
class ParameterData {
  final String date;
  final String dateFormatted;
  final double value;
  final String status;
  final String parameter;
  
  ParameterData({
    required this.date,
    required this.dateFormatted,
    required this.value,
    required this.status,
    required this.parameter,
  });
}

class ReferenceLine {
  final String x;
  final double y;
  
  ReferenceLine({required this.x, required this.y});
}

class RangeData {
  final String x;
  final double low;
  final double high;
  
  RangeData({required this.x, required this.low, required this.high});
}