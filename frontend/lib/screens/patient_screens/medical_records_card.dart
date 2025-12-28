import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/patient_screens/medical_records_screen.dart';
import 'package:frontend/screens/patient_screens/enhanced_medical_dashboard.dart';

class MedicalRecordsHomeCard extends StatefulWidget {
  final String patientId;
  final VoidCallback? onPressed;
  
  const MedicalRecordsHomeCard({
    super.key,
    required this.patientId,
    this.onPressed,
  });

  @override
  State<MedicalRecordsHomeCard> createState() => _MedicalRecordsHomeCardState();
}

class _MedicalRecordsHomeCardState extends State<MedicalRecordsHomeCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic> _stats = {
    'labResults': 0,
    'prescriptions': 0,
    'testNotes': 0,
    'total': 0,
    'latestDate': null,
    'hasAbnormal': false,
  };
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      setState(() => _isLoading = true);
      
      // Get counts from medical_records collection
      final labSnapshot = await _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: widget.patientId)
          .where('category', isEqualTo: 'labResults')
          .count()
          .get();
      
      final prescriptionSnapshot = await _firestore
          .collection('medical_records')
          .where('patientId', isEqualTo: widget.patientId)
          .where('category', isEqualTo: 'prescriptions')
          .count()
          .get();
      
      // Get analyzed reports count
      final notesSnapshot = await _firestore
          .collection('patient_notes')
          .where('patientId', isEqualTo: widget.patientId)
          .where('noteType', whereIn: ['verified_report_analysis', 'test_report_analysis'])
          .count()
          .get();
      
      // Get latest analysis with abnormal results
      final latestAnalysis = await _firestore
          .collection('patient_notes')
          .where('patientId', isEqualTo: widget.patientId)
          .where('noteType', whereIn: ['verified_report_analysis', 'test_report_analysis'])
          .orderBy('analysisDate', descending: true)
          .limit(1)
          .get();
      
      bool hasAbnormal = false;
      String? latestDate;
      
      if (latestAnalysis.docs.isNotEmpty) {
        final data = latestAnalysis.docs.first.data();
        final abnormalCount = data['abnormalCount'] ?? 0;
        hasAbnormal = abnormalCount > 0;
        
        if (data['analysisDate'] is Timestamp) {
          latestDate = DateFormat('dd MMM').format((data['analysisDate'] as Timestamp).toDate());
        }
      }
      
      setState(() {
        _stats = {
          'labResults': labSnapshot.count,
          'prescriptions': prescriptionSnapshot.count,
          'testNotes': notesSnapshot.count,
          'total': (labSnapshot.count ?? 0) + (prescriptionSnapshot.count ?? 0),
          'latestDate': latestDate,
          'hasAbnormal': hasAbnormal,
        };
        _isLoading = false;
      });
      
    } catch (e) {
      debugPrint('❌ Error loading medical records summary: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicalRecordsScreen(),
          ),
        );
      },
      child: Card(
        elevation: 2,
        margin: EdgeInsets.all(8),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF18A3B6).withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF18A3B6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.medical_services, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Medical Records',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                ],
              ),
              
              SizedBox(height: 16),
              
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Lab Results', _stats['labResults'] ?? 0, Icons.science),
                    _buildStatItem('Prescriptions', _stats['prescriptions'] ?? 0, Icons.medication),
                    _buildStatItem('Analyzed', _stats['testNotes'] ?? 0, Icons.analytics),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Status Indicator
                if (_stats['hasAbnormal'] == true)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Abnormal results found',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_stats['latestDate'] != null)
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Latest: ${_stats['latestDate']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                
                SizedBox(height: 8),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MedicalRecordsScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.folder_open, size: 16),
                        label: Text('View All'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EnhancedMedicalDashboard(),
                            ),
                          );
                        },
                        icon: Icon(Icons.analytics, size: 16),
                        label: Text('Dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF18A3B6),
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Color(0xFF18A3B6)),
            SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}