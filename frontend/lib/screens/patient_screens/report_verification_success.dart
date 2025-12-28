// lib/screens/patient_screens/report_verification_success.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/patient_screens/enhanced_medical_dashboard.dart';

class ReportVerificationSuccessScreen extends StatelessWidget {
  final String fileName;
  final int parameterCount;
  final int abnormalCount;
  final String category;
  
  const ReportVerificationSuccessScreen({
    super.key,
    required this.fileName,
    required this.parameterCount,
    required this.abnormalCount,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verification Complete'),
        backgroundColor: Color(0xFF18A3B6),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green,
                ),
              ),
              
              SizedBox(height: 32),
              
              Text(
                'Lab Report Verified!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 16),
              
              Text(
                'Your lab results have been successfully verified and saved.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 32),
              
              // Success Details Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDetailRow('File Name', fileName),
                      _buildDetailRow('Category', category),
                      _buildDetailRow('Parameters Verified', '$parameterCount parameters'),
                      _buildDetailRow('Status', abnormalCount > 0 ? '⚠️ $abnormalCount abnormalities found' : '✅ All normal'),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 32),
              
              // Action Buttons
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EnhancedMedicalDashboard(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF18A3B6),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('View Health Dashboard'),
                  ),
                  
                  SizedBox(height: 12),
                  
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // Go back to records screen
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Back to Medical Records'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}