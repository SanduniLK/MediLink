import 'package:flutter/material.dart';

class LabReportsManagementScreen extends StatefulWidget {
  const LabReportsManagementScreen({super.key});

  @override
  State<LabReportsManagementScreen> createState() =>
      _LabReportsManagementScreenState();
}

class _LabReportsManagementScreenState extends State<LabReportsManagementScreen> {
  // Mock data for lab reports
  final List<Map<String, String>> _labReports = [
    {
      'id': 'L-001',
      'patientName': 'Sarah Johnson',
      'reportName': 'Blood Test Report',
      'uploadDate': '2025-10-27',
    },
    {
      'id': 'L-002',
      'patientName': 'Michael Brown',
      'reportName': 'Urine Analysis',
      'uploadDate': '2025-10-25',
    },
    {
      'id': 'L-003',
      'patientName': 'Emily Davis',
      'reportName': 'X-Ray Report',
      'uploadDate': '2025-10-20',
    },
  ];

  // Variables for the upload form
  final TextEditingController _patientNameController = TextEditingController();
  String? _selectedFile;

  @override
  void dispose() {
    _patientNameController.dispose();
    super.dispose();
  }

  // Method to handle the file upload process
  void _uploadReport() {
    if (_patientNameController.text.isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient and a file to upload.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Here you would implement the logic to upload the file to your backend
    // and store the report details in the database.
    setState(() {
      _labReports.add({
        'id': 'L-${_labReports.length + 1}',
        'patientName': _patientNameController.text,
        'reportName': _selectedFile!.split('/').last, // Get the filename from the path
        'uploadDate': DateTime.now().toString().substring(0, 10),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lab report uploaded successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    _patientNameController.clear();
    setState(() {
      _selectedFile = null;
    });
  }

  void _viewReport(String reportId) {
    // Implement logic to view the report (e.g., open a PDF viewer)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing report with ID: $reportId'),
      ),
    );
  }

  void _deleteReport(String reportId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: const Text('Are you sure you want to delete this report?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() {
                  _labReports.removeWhere((report) => report['id'] == reportId);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Lab Reports Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
          ),
          _buildUploadForm(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _labReports.length,
              itemBuilder: (context, index) {
                final report = _labReports[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ListTile(
                    leading: const Icon(Icons.file_copy, color: Color(0xFF18A3B6)),
                    title: Text(
                      '${report['patientName']!} - ${report['reportName']!}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Uploaded: ${report['uploadDate']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.blue),
                          onPressed: () => _viewReport(report['id']!),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteReport(report['id']!),
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
    );
  }

  Widget _buildUploadForm() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Upload New Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _patientNameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedFile ?? 'No file selected',
                    style: TextStyle(color: _selectedFile == null ? Colors.grey : Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Simulate file browsing
                    setState(() {
                      _selectedFile = '/path/to/report.pdf'; // Placeholder file path
                    });
                  },
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _uploadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32BACD),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Upload Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
