import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:frontend/providers/queue_provider.dart';

class MedicalCenterQRScanner extends StatefulWidget {
  final String medicalCenterId;

  const MedicalCenterQRScanner({super.key, required this.medicalCenterId});

  @override
  State<MedicalCenterQRScanner> createState() => _MedicalCenterQRScannerState();
}

class _MedicalCenterQRScannerState extends State<MedicalCenterQRScanner> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = false;
  List<Map<String, dynamic>> _activeQueues = [];

  @override
  void initState() {
    super.initState();
    _loadActiveQueues();
  }

  void _loadActiveQueues() async {
  try {
    print('🔄 Loading active queues for medical center: ${widget.medicalCenterId}');
    
    // In a real app, you'd call an API to get active queues
    // For now, we'll simulate with a debug endpoint
    final response = await http.get(
      Uri.parse('http://10.222.212.133:5001/api/debug-queues'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final queues = List<Map<String, dynamic>>.from(data['queues'] ?? []);
      
      // Filter queues for this medical center
      final filteredQueues = queues.where((queue) {
        return queue['medicalCenterId'] == widget.medicalCenterId && 
               queue['isActive'] == true;
      }).toList();
      
      setState(() {
        _activeQueues = filteredQueues;
      });
      
      print('✅ Found ${_activeQueues.length} active queues');
    }
  } catch (e) {
    print('❌ Error loading active queues: $e');
    // Fallback to empty list
    setState(() {
      _activeQueues = [];
    });
  }
}
  

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onQRCodeDetect(BarcodeCapture capture) {
    if (_isScanning) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String qrCode = barcodes.first.rawValue ?? '';
      _processQRCode(qrCode);
    }
  }

  void _processQRCode(String qrCode) async {
    setState(() {
      _isScanning = true;
    });

    // QR code format: "patient:patient123" or just "patient123"
    final patientId = qrCode.replaceAll('patient:', '').trim();
    
    if (patientId.isEmpty) {
      _showError('Invalid QR code');
      setState(() { _isScanning = false; });
      return;
    }

    // If multiple active queues, show selection dialog
    if (_activeQueues.length > 1) {
      _showQueueSelectionDialog(patientId);
    } else if (_activeQueues.isNotEmpty) {
      // Auto-select the only queue
      await _performCheckIn(patientId, _activeQueues.first['scheduleId']);
    } else {
      _showError('No active queues found for this medical center');
      setState(() { _isScanning = false; });
    }
  }

  Future<void> _performCheckIn(String patientId, String scheduleId) async {
    final queueProvider = Provider.of<QueueProvider>(context, listen: false);
    
    try {
      final response = await queueProvider.patientCheckIn(patientId, scheduleId);
      
      if (response != null) {
        _showSuccess(
          'Patient checked in successfully!\n'
          'Token: #${response['patient']['tokenNumber']}\n'
          'Current Token: #${response['currentToken']}\n'
          'Position in queue: ${response['queuePosition']}'
        );
      } else {
        _showError('Failed to check in patient: ${queueProvider.error}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _showQueueSelectionDialog(String patientId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Queue'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _activeQueues.length,
            itemBuilder: (context, index) {
              final queue = _activeQueues[index];
              return ListTile(
                leading: const Icon(Icons.medical_services, color: Color(0xFF18A3B6)),
                title: Text(queue['doctorName']),
                subtitle: Text('Current Token: #${queue['currentToken']}'),
                onTap: () {
                  Navigator.pop(context);
                  _performCheckIn(patientId, queue['scheduleId']);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Check-in Successful',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Check-in Failed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Patient QR Code'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Active Queues Info
          if (_activeQueues.isNotEmpty) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Color(0xFF18A3B6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_activeQueues.length} active queue${_activeQueues.length > 1 ? 's' : ''} found',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF18A3B6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Scanner View
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: _onQRCodeDetect,
                ),
                
                // Scanner Overlay
                Container(
                  decoration: ShapeDecoration(
                    shape: _ScannerOverlayShape(
                      borderColor: const Color(0xFF18A3B6),
                    ),
                  ),
                ),
                
                // Loading Indicator
                if (_isScanning)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF18A3B6)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing QR Code...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Instructions
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _isScanning ? 'Processing...' : 'Scan Patient QR Code',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Position the QR code within the frame',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// Custom scanner overlay shape
class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;

  const _ScannerOverlayShape({
    required this.borderColor,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    const width = 240.0;
    const height = 240.0;
    const borderLength = 30.0;
    const borderWidth = 4.0;

    final backgroundPaint = Paint()..color = Colors.black54;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final center = rect.center;
    final scannerRect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    // Draw background
    canvas.drawRect(rect, backgroundPaint);

    // Draw transparent scanner area
    final scannerAreaPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRect(scannerRect, scannerAreaPaint);

    // Draw scanner border
    canvas.drawRect(scannerRect, borderPaint);

    // Draw corner borders
    // Top left
    canvas.drawLine(
      scannerRect.topLeft,
      scannerRect.topLeft + const Offset(borderLength, 0),
      borderPaint,
    );
    canvas.drawLine(
      scannerRect.topLeft,
      scannerRect.topLeft + const Offset(0, borderLength),
      borderPaint,
    );

    // Top right
    canvas.drawLine(
      scannerRect.topRight,
      scannerRect.topRight - const Offset(borderLength, 0),
      borderPaint,
    );
    canvas.drawLine(
      scannerRect.topRight,
      scannerRect.topRight + const Offset(0, borderLength),
      borderPaint,
    );

    // Bottom left
    canvas.drawLine(
      scannerRect.bottomLeft,
      scannerRect.bottomLeft + const Offset(borderLength, 0),
      borderPaint,
    );
    canvas.drawLine(
      scannerRect.bottomLeft,
      scannerRect.bottomLeft - const Offset(0, borderLength),
      borderPaint,
    );

    // Bottom right
    canvas.drawLine(
      scannerRect.bottomRight,
      scannerRect.bottomRight - const Offset(borderLength, 0),
      borderPaint,
    );
    canvas.drawLine(
      scannerRect.bottomRight,
      scannerRect.bottomRight - const Offset(0, borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}