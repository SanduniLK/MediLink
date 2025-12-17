import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/model/test_report_model.dart';
import 'package:frontend/services/file_download_service.dart';

class TestReportViewScreen extends StatelessWidget {
  final TestReportModel testReport;
  final String? encodedReport;
  final String downloadUrl;

  const TestReportViewScreen({
    super.key,
    required this.testReport, 
    this.encodedReport,
    required this.downloadUrl,
  });

  // Build PDF/Image preview section
  Widget _buildReportPreview(BuildContext context) {
    // If we have encoded report (Base64), show it
    if (encodedReport != null && encodedReport!.isNotEmpty) {
      try {
        // Try to decode as Base64 image
        if (encodedReport!.length > 1000) {
          return _buildBase64ImagePreview(encodedReport!,context);
        }
      } catch (e) {
        debugPrint('Error decoding base64: $e');
      }
    }

    // Otherwise, show a preview card with download option
    return _buildDownloadPreviewCard(context);
  }

  Widget _buildBase64ImagePreview(String base64String, BuildContext context) {
  try {
    final bytes = base64Decode(base64String);
    return Container(
      constraints: BoxConstraints(
        maxHeight: 400,  // LIMIT HEIGHT
        minHeight: 100,
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildDownloadPreviewCard(context);
          },
        ),
      ),
    );
  } catch (e) {
    return _buildDownloadPreviewCard(context);
  }
}

  Widget _buildDownloadPreviewCard(BuildContext context) {
  return Container(
    constraints: BoxConstraints(
      minHeight: 200,  // Minimum height
      maxHeight: 300,  // Maximum height
    ),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: SingleChildScrollView(  // ADD THIS - Makes content scrollable
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,  // ADD THIS
        children: [
          Icon(
            testReport.fileName.toLowerCase().endsWith('.pdf') 
                ? Icons.picture_as_pdf 
                : Icons.insert_drive_file,
            size: 60,
            color: const Color(0xFF18A3B6),
          ),
          const SizedBox(height: 16),
          Text(
            testReport.fileName.isNotEmpty 
                ? testReport.fileName 
                : 'Test Report.pdf',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,  // LIMIT LINES
            overflow: TextOverflow.ellipsis,  // ADD ELLIPSIS
          ),
          if (testReport.fileSize.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              testReport.fileSize,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _downloadAndOpenFile(context),
            icon: const Icon(Icons.download),
            label: const Text('Open Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF18A3B6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _downloadAndOpenFile(BuildContext context) async {
  bool isDownloading = false;
  
  // Show download dialog with progress
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Downloading'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDownloading)
                  const CircularProgressIndicator()
                else
                  const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 16),
                Text(isDownloading 
                  ? 'Download Complete!' 
                  : 'Downloading ${testReport.fileName}...'),
              ],
            ),
            actions: isDownloading
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ]
                : [],
          );
        },
      );
    },
  );

  try {
    // Start download
    final savePath = await FileDownloadService.downloadFile(
      url: downloadUrl,
      fileName: testReport.fileName,
      onProgress: (received, total) {
        if (total != -1) {
          print('Progress: ${(received / total * 100).toStringAsFixed(0)}%');
        }
      },
    );

    if (savePath != null) {
      // Update dialog to show success
      isDownloading = true;
      
      // Close dialog after 1 second
      await Future.delayed(const Duration(seconds: 1));
      if (context.mounted) Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded to: Downloads/${testReport.fileName}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Try to open the file
      _openDownloadedFile(context, savePath);
    } else {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
void _openDownloadedFile(BuildContext context, String filePath) async {
  try {
    // For Android, use file_editor or similar package
    // For now, show where the file is saved
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File has been downloaded to:'),
            const SizedBox(height: 8),
            Text(
              filePath,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cannot open file: $e'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

  void _copyDownloadUrlToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: downloadUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download URL copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Report Details'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed:()=>_downloadAndOpenFile(context),
            tooltip: 'Download Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: testReport.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(testReport.statusIcon, color: testReport.statusColor, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                testReport.testName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                testReport.patientName,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      _buildInfoChip('Date: ${testReport.formattedTestDate}', Icons.calendar_today),
      const SizedBox(width: 8),
      _buildInfoChip(testReport.testType, Icons.medical_services),
      const SizedBox(width: 8),
      _buildStatusChip(testReport.status, testReport.statusColor),
    ],
  ),
),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // REPORT PREVIEW SECTION - ADD THIS
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Report Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (encodedReport != null && encodedReport!.isNotEmpty)
                          Chip(
                            label: const Text('IMAGE'),
                            backgroundColor: Colors.blue.shade50,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildReportPreview(context),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Medical Center Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medical Center',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      testReport.medicalCenterName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            if (testReport.description.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        testReport.description,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Lab Findings
            if (testReport.labFindings.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lab Findings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...testReport.labFindings.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 8, right: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF18A3B6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.value.toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            if (testReport.notes.isNotEmpty) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Additional Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18A3B6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        testReport.notes,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // File Information (with URL)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report File Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.insert_drive_file, color: Color(0xFF18A3B6)),
                      title: Text(
                        testReport.fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (testReport.fileSize.isNotEmpty)
                            Text(
                              testReport.fileSize,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Download URL available',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed:()=> _copyDownloadUrlToClipboard(context),
                          icon: const Icon(Icons.link, size: 16),
                          label: const Text('Copy URL'),
                        ),
                        ElevatedButton.icon(
                          onPressed:()=> _downloadAndOpenFile(context),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF18A3B6),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
  return Chip(
    label: Text(
      text.length > 20 ? '${text.substring(0, 20)}...' : text, // Limit text
      overflow: TextOverflow.ellipsis,
    ),
    labelStyle: const TextStyle(fontSize: 12),
    avatar: Icon(icon, size: 16),
    backgroundColor: Colors.grey.shade100,
  );
}

Widget _buildStatusChip(String status, Color color) {
  return Chip(
    label: Text(
      status.length > 15 ? '${status.substring(0, 15)}...' : status.toUpperCase(),
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10, // Smaller font
        fontWeight: FontWeight.bold,
        color: color,
      ),
    ),
    backgroundColor: color.withValues(alpha: 0.1),
    side: BorderSide(color: color),
    visualDensity: VisualDensity.compact, // Make chip more compact
  );
}
}