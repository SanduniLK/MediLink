// screens/patient_screens/enhanced_medical_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/patient_screens/fbc_trend_charts.dart';
import 'package:intl/intl.dart';

// Add ChartData class
class ChartData {
  final String parameter;
  final double value;
  final double refLow;
  final double refHigh;
  final Color color;
  final String status;

  ChartData({
    required this.parameter,
    required this.value,
    required this.refLow,
    required this.refHigh,
    required this.color,
    required this.status,
  });
}

// Simplified EnhancedMedicalDashboard - No syncfusion charts
// In EnhancedMedicalDashboard
class EnhancedMedicalDashboard extends StatefulWidget {
  @override
  _EnhancedMedicalDashboardState createState() => _EnhancedMedicalDashboardState();
}

class _EnhancedMedicalDashboardState extends State<EnhancedMedicalDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentPatientId; // Get this from your auth system
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medical Dashboard'),
        backgroundColor: Color(0xFF18A3B6),
        actions: [
          IconButton(
            icon: Icon(Icons.insights),
            onPressed: () {
              if (_currentPatientId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FBCTrendCharts(patientId: _currentPatientId!),
                  ),
                );
              }
            },
            tooltip: 'View Trend Charts',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Recent FBC Reports
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('patient_notes')
                .where('patientId', isEqualTo: _currentPatientId)
                .where('testReportCategory', isEqualTo: 'Full Blood Count (FBC)')
                .orderBy('analysisDate', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return CircularProgressIndicator();
              }
              
              final reports = snapshot.data!.docs;
              
              return Card(
                margin: EdgeInsets.all(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '📊 Recent FBC Reports',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FBCTrendCharts(patientId: _currentPatientId!),
                                ),
                              );
                            },
                            icon: Icon(Icons.timeline),
                            label: Text('View Trends'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      
                      // Quick summary of each report
                      ...reports.map((reportDoc) {
                        final data = reportDoc.data() as Map<String, dynamic>;
                        final testDate = data['testDate'] ?? 'Unknown Date';
                        final abnormalCount = data['abnormalCount'] ?? 0;
                        final overallStatus = data['overallStatus'] ?? 'Unknown';
                        
                        Color statusColor = overallStatus == 'Normal' 
                            ? Colors.green 
                            : Colors.orange;
                        
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                overallStatus == 'Normal' ? Icons.check : Icons.warning,
                                color: statusColor,
                              ),
                            ),
                          ),
                          title: Text('FBC Report - $testDate'),
                          subtitle: Text(
                            abnormalCount > 0 
                                ? '$abnormalCount abnormal findings' 
                                : 'All normal',
                          ),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () {
                            _showReportDetails(data);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Key Parameter Summary
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔑 Key Parameters Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('patient_notes')
                        .where('patientId', isEqualTo: _currentPatientId)
                        .where('testReportCategory', isEqualTo: 'Full Blood Count (FBC)')
                        .orderBy('analysisDate', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text('No FBC reports available'));
                      }
                      
                      final latestReport = snapshot.data!.docs.first;
                      final data = latestReport.data() as Map<String, dynamic>;
                      final verifiedParameters = data['verifiedParameters'] as List<dynamic>?;
                      
                      if (verifiedParameters == null) {
                        return Center(child: Text('No parameters available'));
                      }
                      
                      // Get only important parameters
                      final importantParams = [
                        'Hemoglobin (Hb)',
                        'White Blood Cells (WBC)',
                        'Platelets',
                        'Red Blood Cells (RBC)',
                        'Hematocrit (HCT)',
                      ];
                      
                      final importantData = verifiedParameters.where((param) {
                        final paramName = param['parameter']?.toString() ?? '';
                        return importantParams.contains(paramName);
                      }).toList();
                      
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: importantData.length,
                        itemBuilder: (context, index) {
                          final param = importantData[index];
                          final paramName = param['parameter']?.toString() ?? '';
                          final value = param['value']?.toString() ?? '';
                          final unit = param['unit']?.toString() ?? '';
                          final status = param['status']?.toString() ?? 'normal';
                          
                          Color bgColor;
                          Color textColor;
                          
                          switch (status) {
                            case 'high':
                              bgColor = Colors.red[50]!;
                              textColor = Colors.red;
                              break;
                            case 'low':
                              bgColor = Colors.yellow[50]!;
                              textColor = Colors.yellow[800]!;
                              break;
                            default:
                              bgColor = Colors.blue[50]!;
                              textColor = Colors.blue;
                          }
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: textColor.withOpacity(0.3)),
                            ),
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  paramName.split('(').first.trim(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$value $unit',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: textColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showReportDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Details'),
        content: Container(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Date: ${data['testDate']}'),
              Text('Status: ${data['overallStatus']}'),
              Text('Abnormal Parameters: ${data['abnormalCount']}'),
              SizedBox(height: 16),
              Text('Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(data['analysisSummary'] ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}