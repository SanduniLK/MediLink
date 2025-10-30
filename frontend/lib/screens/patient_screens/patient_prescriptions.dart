import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class PatientPrescriptionsScreen extends StatefulWidget {
  final String patientId;

  const PatientPrescriptionsScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  State<PatientPrescriptionsScreen> createState() => _PatientPrescriptionsScreenState();
}

class _PatientPrescriptionsScreenState extends State<PatientPrescriptionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    try {
      print('Loading prescriptions for patient: ${widget.patientId}');
      
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final querySnapshot = await _firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: widget.patientId)
          .get();

      print('Query returned ${querySnapshot.docs.length} documents');

      final prescriptions = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Check if it has prescriptionImageUrl
        if (data['prescriptionImageUrl'] != null && 
            data['prescriptionImageUrl'].toString().isNotEmpty) {
          final imageUrl = data['prescriptionImageUrl'].toString();
          print('Found image URL: $imageUrl');
          
          // Test if URL is accessible
          try {
            // Just add the prescription, we'll handle image loading in the UI
            prescriptions.add({
              'id': doc.id,
              ...data,
              'createdAt': _parseTimestamp(data['createdAt']),
            });
          } catch (e) {
            print('Error with image URL $imageUrl: $e');
          }
        } else {
          print('No prescriptionImageUrl found in document ${doc.id}');
        }
      }

      print('Total prescriptions with images: ${prescriptions.length}');

      setState(() {
        _prescriptions = prescriptions;
        _isLoading = false;
      });

    } catch (e) {
      print('Error: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('My Prescriptions'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading prescriptions...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPrescriptions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_prescriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Prescriptions Found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text('Patient ID: ${widget.patientId}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPrescriptions,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _prescriptions[index];
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    final imageUrl = prescription['prescriptionImageUrl']?.toString() ?? '';
    final diagnosis = prescription['diagnosis']?.toString() ?? 'No diagnosis';
    final description = prescription['description']?.toString() ?? '';
    final patientName = prescription['patientName']?.toString() ?? 'Unknown';
    final createdAt = prescription['createdAt'] as DateTime;
    final status = prescription['status']?.toString() ?? 'unknown';
    final medicalCenter = prescription['medicalCenter']?.toString() ?? '';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF18A3B6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${status.toUpperCase()}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (medicalCenter.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          medicalCenter,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(createdAt),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Image Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prescription Image:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF18A3B6),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Image with better error handling
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _buildImageWidget(imageUrl),
                ),
                
                const SizedBox(height: 8),
                
                // URL for debugging
                GestureDetector(
                  onTap: () {
                    print('Tapped image URL: $imageUrl');
                  },
                  child: Text(
                    'Image URL: ${imageUrl.length > 50 ? '${imageUrl.substring(0, 50)}...' : imageUrl}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          // Prescription Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Diagnosis
                if (diagnosis.isNotEmpty && diagnosis != 'No diagnosis') ...[
                  _buildDetailRow('Diagnosis:', diagnosis),
                  const SizedBox(height: 12),
                ],

                // Description
                if (description.isNotEmpty) ...[
                  _buildDetailRow('Description:', description),
                  const SizedBox(height: 12),
                ],

                // Medicines
                if (prescription['medicines'] != null && (prescription['medicines'] as List).isNotEmpty) ...[
                  const Text(
                    'Medicines:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
                  ),
                  const SizedBox(height: 8),
                  ..._buildMedicinesList(prescription['medicines']),
                  const SizedBox(height: 12),
                ],

                // Notes
                if (prescription['notes'] != null && prescription['notes'].toString().isNotEmpty) ...[
                  _buildDetailRow('Notes:', prescription['notes'].toString()),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const Center(child: Text('No image available'));
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      progressIndicatorBuilder: (context, url, downloadProgress) => Center(
        child: CircularProgressIndicator(value: downloadProgress.progress),
      ),
      errorWidget: (context, url, error) {
        print('Image load error for $url: $error');
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            const Text('Failed to load image'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Try to reload the image
                setState(() {});
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF18A3B6)),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }

  List<Widget> _buildMedicinesList(dynamic medicines) {
    if (medicines is List) {
      return medicines.map<Widget>((medicine) {
        final med = medicine as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💊 ${med['name'] ?? 'Unknown Medicine'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              if (med['dosage'] != null) Text('Dosage: ${med['dosage']}'),
              if (med['frequency'] != null) Text('Frequency: ${med['frequency']}'),
              if (med['duration'] != null) Text('Duration: ${med['duration']}'),
              if (med['instructions'] != null) Text('Instructions: ${med['instructions']}'),
            ],
          ),
        );
      }).toList();
    }
    return [const Text('No medicines listed')];
  }
}