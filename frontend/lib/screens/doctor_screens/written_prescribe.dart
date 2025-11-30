
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/services/prescription_storage_service.dart';
import 'package:intl/intl.dart';


class AllPrescriptionsScreen extends StatefulWidget {
  const AllPrescriptionsScreen({super.key});

  @override
  State<AllPrescriptionsScreen> createState() => _AllPrescriptionsScreenState();
}

class _AllPrescriptionsScreenState extends State<AllPrescriptionsScreen> {
  final PrescriptionFirestoreService _prescriptionService = PrescriptionFirestoreService();
  List<DoctorPrescription> _doctorsPrescriptions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final prescriptions = await _prescriptionService.fetchAllDoctorsPrescriptions();
      
      setState(() {
        _doctorsPrescriptions = prescriptions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showPrescriptionDetails(PrescriptionData prescription) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18A3B6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medical_services, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Prescription Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prescription Image
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: prescription.prescriptionImageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF18A3B6),
                            ),
                          ),
                          errorWidget: (context, url, error) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 50),
                              const SizedBox(height: 10),
                              const Text('Failed to load image'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Patient Information
                    _buildInfoSection('PATIENT INFORMATION', [
                      _buildInfoRow('Name', prescription.patientName),
                      if (prescription.patientAge != null)
                        _buildInfoRow('Age', '${prescription.patientAge} years'),
                      _buildInfoRow('Date', DateFormat('dd/MM/yyyy').format(prescription.date)),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Diagnosis
                    if (prescription.diagnosis.isNotEmpty)
                      _buildInfoSection('DIAGNOSIS', [
                        Text(prescription.diagnosis),
                      ]),
                    
                    // Medicines
                    if (prescription.medicines.isNotEmpty)
                      _buildInfoSection('PRESCRIBED MEDICINES', [
                        ...prescription.medicines.map((medicine) => 
                          _buildMedicineItem(medicine)
                        ).toList(),
                      ]),
                    
                    // Notes
                    if (prescription.notes.isNotEmpty)
                      _buildInfoSection('NOTES', [
                        Text(prescription.notes),
                      ]),
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Download functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Download feature coming soon!')),
                              );
                            },
                            icon: const Icon(Icons.download, size: 20),
                            label: const Text('Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF18A3B6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF18A3B6),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildMedicineItem(Medicine medicine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medicine.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (medicine.dosage.isNotEmpty) Text('Dosage: ${medicine.dosage}'),
          if (medicine.duration.isNotEmpty) Text('Duration: ${medicine.duration}'),
          if (medicine.frequency.isNotEmpty) Text('Frequency: ${medicine.frequency}'),
          if (medicine.instructions.isNotEmpty) Text('Instructions: ${medicine.instructions}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Prescriptions'),
        backgroundColor: const Color(0xFF18A3B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrescriptions,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _errorMessage.isNotEmpty
              ? _buildError()
              : _doctorsPrescriptions.isEmpty
                  ? _buildEmpty()
                  : _buildPrescriptionGrid(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: const Color(0xFF18A3B6)),
          const SizedBox(height: 16),
          const Text('Loading prescriptions...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text('Error loading prescriptions'),
          const SizedBox(height: 8),
          Text(_errorMessage, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadPrescriptions,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No prescriptions found'),
        ],
      ),
    );
  }

  Widget _buildPrescriptionGrid() {
    return RefreshIndicator(
      onRefresh: _loadPrescriptions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _doctorsPrescriptions.length,
        itemBuilder: (context, doctorIndex) {
          final doctor = _doctorsPrescriptions[doctorIndex];
          return _buildDoctorSection(doctor);
        },
      ),
    );
  }

  Widget _buildDoctorSection(DoctorPrescription doctor) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Header with Profile Image
            Row(
              children: [
                // Doctor Profile Image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF18A3B6)),
                  ),
                  child: ClipOval(
                    child: doctor.profileImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: doctor.profileImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF18A3B6).withOpacity(0.1),
                              child: Icon(Icons.person, color: const Color(0xFF18A3B6)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF18A3B6).withOpacity(0.1),
                              child: Icon(Icons.person, color: const Color(0xFF18A3B6)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF18A3B6).withOpacity(0.1),
                            child: Icon(Icons.person, color: const Color(0xFF18A3B6)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.doctorName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        doctor.doctorSpecialization,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Text(
                        '${doctor.prescriptionCount} prescription(s)',
                        style: const TextStyle(
                          color: Color(0xFF18A3B6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Prescription Images Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: doctor.prescriptions.length,
              itemBuilder: (context, prescriptionIndex) {
                final prescription = doctor.prescriptions[prescriptionIndex];
                return _buildPrescriptionCard(prescription);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(PrescriptionData prescription) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPrescriptionDetails(prescription),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Image Preview
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: prescription.prescriptionImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: const Color(0xFF18A3B6)),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red.shade400),
                          const SizedBox(height: 4),
                          const Text('Load Error', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Patient Info
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prescription.patientName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(prescription.date),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}