import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:frontend/model/prescription_model.dart';
import 'package:frontend/screens/doctor_screens/pharmacy_selection_screen.dart';
import 'package:frontend/screens/doctor_screens/prescription_history_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final List<TextEditingController> _medicineControllers = [];
  final List<TextEditingController> _dosageControllers = [];
  final List<TextEditingController> _durationControllers = [];
  final List<TextEditingController> _frequencyControllers = [];
  final List<TextEditingController> _instructionControllers = [];

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _doctorRegNoController = TextEditingController();

  // Drawing variables
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isErasing = false;
  final List<DrawingPoint> _drawingPoints = [];
  final GlobalKey _drawingKey = GlobalKey();

  // Signature variables
  final GlobalKey _signatureKey = GlobalKey();
  final List<DrawingPoint> _signaturePoints = [];
  bool _hasSignature = false;

  bool _isLoading = false;
  List<Map<String, dynamic>> _availablePharmacies = [];
  List<Map<String, dynamic>> _patientSuggestions = [];
  String? _selectedPatientId;

  // Color Scheme
  final Color _backgroundColor = const Color(0xFFDDF0F5); // Very light blue
  final Color _cardColor = const Color(0xFFB2DEE6); // Soft aqua
  final Color _accentColor = const Color(0xFF85CEDA); // Teal-blue
  final Color _primaryColor = const Color(0xFF32BACD); // Bright cyan
  final Color _darkColor = const Color(0xFF18A3B6); // Deep teal

  @override
  void initState() {
    super.initState();
    _addMedicineField();
    _loadPharmacies();
    _loadPatientAppointments();
    _loadDoctorInfo();
  }

  Future<void> _loadDoctorInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(user.uid)
            .get();
        
        if (doctorDoc.exists) {
          final data = doctorDoc.data();
          setState(() {
            _doctorNameController.text = data?['fullname'] ?? 'Dr. Umapathy';
            _doctorRegNoController.text = data?['registrationNumber'] ?? 'MED12345';
          });
        } else {
          setState(() {
            _doctorNameController.text = 'Dr. Umapathy';
            _doctorRegNoController.text = 'MED12345';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading doctor info: $e');
      setState(() {
        _doctorNameController.text = 'Dr. Umapathy';
        _doctorRegNoController.text = 'MED12345';
      });
    }
  }

  Future<void> _loadPharmacies() async {
    try {
      final pharmaciesSnapshot = await FirebaseFirestore.instance
          .collection('pharmacies')
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        _availablePharmacies = pharmaciesSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading pharmacies: $e');
    }
  }

  Future<void> _loadPatientAppointments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .get();

      final patientMap = <String, Map<String, dynamic>>{};
      
      for (final doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'confirmed') {
          final patientId = data['patientId'] as String?;
          final patientName = data['patientName'] as String?;
          
          if (patientId != null && patientName != null && !patientMap.containsKey(patientId)) {
            patientMap[patientId] = {
              'patientId': patientId,
              'patientName': patientName,
            };
          }
        }
      }

      setState(() {
        _patientSuggestions = patientMap.values.toList();
        _patientSuggestions.sort((a, b) => (a['patientName'] as String)
            .compareTo(b['patientName'] as String));
      });
    } catch (e) {
      debugPrint('Error loading patient appointments: $e');
    }
  }

  Future<void> _fetchPatientAge(String patientId) async {
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        final patientData = patientDoc.data();
        int? calculatedAge;
        
        if (patientData != null && patientData.containsKey('age')) {
          calculatedAge = patientData['age'] as int?;
        } else {
          final dob = patientData?['dob'];
          if (dob != null && dob is String) {
            final birthDate = DateTime.parse(dob);
            final now = DateTime.now();
            int ageCalculation = now.year - birthDate.year;
            if (now.month < birthDate.month || 
                (now.month == birthDate.month && now.day < birthDate.day)) {
              ageCalculation--;
            }
            calculatedAge = ageCalculation;
          }
        }
        
        setState(() {
          _patientAgeController.text = calculatedAge?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching patient age: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _medicineControllers) {
      controller.dispose();
    }
    for (var controller in _dosageControllers) {
      controller.dispose();
    }
    for (var controller in _durationControllers) {
      controller.dispose();
    }
    for (var controller in _frequencyControllers) {
      controller.dispose();
    }
    for (var controller in _instructionControllers) {
      controller.dispose();
    }
    _descriptionController.dispose();
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    _doctorNameController.dispose();
    _doctorRegNoController.dispose();
    super.dispose();
  }

  void _addMedicineField() {
    setState(() {
      _medicineControllers.add(TextEditingController());
      _dosageControllers.add(TextEditingController());
      _durationControllers.add(TextEditingController());
      _frequencyControllers.add(TextEditingController());
      _instructionControllers.add(TextEditingController());
    });
  }

  void _removeMedicineField(int index) {
    if (_medicineControllers.length > 1) {
      setState(() {
        _medicineControllers.removeAt(index).dispose();
        _dosageControllers.removeAt(index).dispose();
        _durationControllers.removeAt(index).dispose();
        _frequencyControllers.removeAt(index).dispose();
        _instructionControllers.removeAt(index).dispose();
      });
    }
  }

  // Drawing Methods
  void _handleDrawingStart(DragStartDetails details) {
    final RenderBox renderBox = _drawingKey.currentContext!.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _drawingPoints.add(DrawingPoint(
        position: localPosition,
        paint: Paint()
          ..color = _isErasing ? Colors.white : _selectedColor
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round
          ..blendMode = _isErasing ? BlendMode.clear : BlendMode.srcOver,
      ));
    });
  }

  void _handleDrawingUpdate(DragUpdateDetails details) {
    final RenderBox renderBox = _drawingKey.currentContext!.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _drawingPoints.add(DrawingPoint(
        position: localPosition,
        paint: Paint()
          ..color = _isErasing ? Colors.white : _selectedColor
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round
          ..blendMode = _isErasing ? BlendMode.clear : BlendMode.srcOver,
      ));
    });
  }

  void _handleDrawingEnd(DragEndDetails details) {
    setState(() {
      _drawingPoints.add(DrawingPoint(position: null, paint: Paint()));
    });
  }

  void _clearDrawing() {
    setState(() {
      _drawingPoints.clear();
    });
  }

  // Signature Methods
  void _handleSignatureStart(DragStartDetails details) {
    final RenderBox renderBox = _signatureKey.currentContext!.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
    
    setState(() {
      _signaturePoints.add(DrawingPoint(
        position: localPosition,
        paint: Paint()
          ..color = Colors.black
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      ));
      _hasSignature = true;
    });
  }

  void _handleSignatureUpdate(DragUpdateDetails details) {
    final RenderBox renderBox = _signatureKey.currentContext!.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
    
    setState(() {
      _signaturePoints.add(DrawingPoint(
        position: localPosition,
        paint: Paint()
          ..color = Colors.black
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      ));
    });
  }

  void _handleSignatureEnd(DragEndDetails details) {
    setState(() {
      _signaturePoints.add(DrawingPoint(position: null, paint: Paint()));
    });
  }

  void _clearSignature() {
    setState(() {
      _signaturePoints.clear();
      _hasSignature = false;
    });
  }

  Future<void> _savePrescription({bool shareWithPharmacies = false}) async {
    if (_patientNameController.text.isEmpty) {
      _showError('Please select a patient');
      return;
    }

    if (!_hasSignature) {
      _showError('Please provide your signature before saving');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Uint8List? drawingImage;
      if (_drawingPoints.isNotEmpty) {
        drawingImage = await _captureDrawing();
      }

      Uint8List? signatureImage;
      if (_signaturePoints.isNotEmpty) {
        signatureImage = await _captureSignature();
      }

      final prescription = Prescription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        doctorId: user.uid,
        patientName: _patientNameController.text,
        patientId: _selectedPatientId!,
        patientAge: _patientAgeController.text.isNotEmpty ? int.tryParse(_patientAgeController.text) : null,
        date: DateTime.now(),
        medicines: _getMedicines(),
        description: _descriptionController.text,
        diagnosis: _diagnosisController.text,
        notes: _notesController.text,
        status: shareWithPharmacies ? 'shared' : 'completed',
        sharedPharmacies: shareWithPharmacies ? _getSelectedPharmacyIds() : [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        drawingImage: drawingImage,
        signatureImage: signatureImage,
      );

      await FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(prescription.id)
          .set(prescription.toMap());

      if (shareWithPharmacies && prescription.sharedPharmacies.isNotEmpty) {
        await _notifyPharmacies(prescription);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shareWithPharmacies 
                ? 'Prescription saved and shared with pharmacies!'
                : 'Prescription saved successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (!shareWithPharmacies && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save prescription: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Uint8List?> _captureDrawing() async {
    try {
      final boundary = _drawingKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing drawing: $e');
      return null;
    }
  }

  Future<Uint8List?> _captureSignature() async {
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing signature: $e');
      return null;
    }
  }

  List<Medicine> _getMedicines() {
    List<Medicine> medicines = [];
    for (int i = 0; i < _medicineControllers.length; i++) {
      if (_medicineControllers[i].text.isNotEmpty) {
        medicines.add(Medicine(
          name: _medicineControllers[i].text,
          dosage: _dosageControllers[i].text,
          duration: _durationControllers[i].text,
          frequency: _frequencyControllers[i].text,
          instructions: _instructionControllers[i].text,
        ));
      }
    }
    return medicines;
  }

  List<String> _getSelectedPharmacyIds() {
    return _availablePharmacies.map((pharmacy) => pharmacy['id'] as String).toList();
  }

  Future<void> _notifyPharmacies(Prescription prescription) async {
    try {
      for (String pharmacyId in prescription.sharedPharmacies) {
        await FirebaseFirestore.instance
            .collection('pharmacyNotifications')
            .add({
          'pharmacyId': pharmacyId,
          'prescriptionId': prescription.id,
          'patientName': prescription.patientName,
          'doctorId': prescription.doctorId,
          'doctorName': _doctorNameController.text,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
          'medicinesCount': prescription.medicines.length,
        });
      }
    } catch (e) {
      debugPrint('Error notifying pharmacies: $e');
    }
  }

  Future<void> _shareWithPharmacies() async {
    final selectedPharmacies = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PharmacySelectionScreen(
          pharmacies: _availablePharmacies,
        ),
      ),
    );

    if (selectedPharmacies != null && selectedPharmacies.isNotEmpty) {
      await _savePrescription(shareWithPharmacies: true);
    }
  }

  Future<void> _generateAndSharePDF() async {
    setState(() => _isLoading = true);
    
    try {
      final prescriptionText = _generatePrescriptionText();
      await Share.share(
        prescriptionText,
        subject: 'Prescription for ${_patientNameController.text} - ${_doctorNameController.text}',
      );
    } catch (e) {
      _showError('Failed to share prescription: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _generatePrescriptionText() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('           ${_doctorNameController.text.toUpperCase()}\'S CLINIC          ');
    buffer.writeln('              MEDICAL PRESCRIPTION         ');
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Patient: ${_patientNameController.text}');
    if (_patientAgeController.text.isNotEmpty) {
      buffer.writeln('Age: ${_patientAgeController.text} years');
    }
    buffer.writeln('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    buffer.writeln();
    
    if (_diagnosisController.text.isNotEmpty) {
      buffer.writeln('Diagnosis: ${_diagnosisController.text}');
      buffer.writeln();
    }
    
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('PRESCRIBED MEDICATIONS:');
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln();
    
    for (int i = 0; i < _medicineControllers.length; i++) {
      if (_medicineControllers[i].text.isNotEmpty) {
        buffer.writeln('${i + 1}. ${_medicineControllers[i].text.toUpperCase()}');
        buffer.writeln('   ▸ Dosage: ${_dosageControllers[i].text}');
        buffer.writeln('   ▸ Duration: ${_durationControllers[i].text}');
        if (_frequencyControllers[i].text.isNotEmpty) {
          buffer.writeln('   ▸ Frequency: ${_frequencyControllers[i].text}');
        }
        if (_instructionControllers[i].text.isNotEmpty) {
          buffer.writeln('   ▸ Instructions: ${_instructionControllers[i].text}');
        }
        buffer.writeln();
      }
    }
    
    if (_descriptionController.text.isNotEmpty) {
      buffer.writeln('Additional Instructions:');
      buffer.writeln(_descriptionController.text);
      buffer.writeln();
    }
    
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('Verified by: ${_doctorNameController.text}');
    buffer.writeln('Registration No: ${_doctorRegNoController.text}');
    buffer.writeln('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    buffer.writeln('═══════════════════════════════════════════');
    
    return buffer.toString();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Digital Prescription',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: _darkColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPatientAppointments,
            tooltip: 'Refresh Patients',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header Section
                  _buildHeaderSection(),
                  const SizedBox(height: 20),
                  
                  // Patient Information
                  _buildPatientInfoSection(),
                  const SizedBox(height: 16),
                  
                  // Diagnosis Section
                  _buildDiagnosisSection(),
                  const SizedBox(height: 16),
                  
                  // Medicines Section
                  _buildMedicinesSection(),
                  const SizedBox(height: 16),
                  
                  // Drawing Section
                  _buildDrawingSection(),
                  const SizedBox(height: 16),
                  
                  // Additional Instructions
                  _buildAdditionalInstructions(),
                  const SizedBox(height: 16),
                  
                  // Signature Section
                  _buildSignatureSection(),
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _darkColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _darkColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.medical_services, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          const Text(
            'MEDICAL PRESCRIPTION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('PATIENT INFORMATION', Icons.person_outline),
            const SizedBox(height: 16),
            
            if (_patientSuggestions.isEmpty)
              _buildEmptyState('No patients available', 'Confirmed appointments will appear here')
            else
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _patientNameController.text.isEmpty ? null : _patientNameController.text,
                      decoration: InputDecoration(
                        labelText: 'Select Patient',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        prefixIcon: Icon(Icons.search, color: _primaryColor),
                      ),
                      items: _patientSuggestions.map((patient) {
                        return DropdownMenuItem<String>(
                          value: patient['patientName'] as String,
                          child: Text(patient['patientName'] as String),
                        );
                      }).toList(),
                      onChanged: (String? selectedValue) {
                        if (selectedValue != null) {
                          setState(() {
                            _patientNameController.text = selectedValue;
                            final selectedPatient = _patientSuggestions.firstWhere(
                              (patient) => patient['patientName'] == selectedValue,
                            );
                            _selectedPatientId = selectedPatient['patientId'] as String;
                            _fetchPatientAge(_selectedPatientId!);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _patientAgeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Patient Age',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('DIAGNOSIS & CLINICAL NOTES', Icons.medical_information),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _diagnosisController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Diagnosis',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.health_and_safety, color: _primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Clinical Notes',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.note, color: _primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicinesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSectionHeader('PRESCRIBED MEDICATIONS', Icons.medication),
                const Spacer(),
                FloatingActionButton.small(
                  onPressed: _addMedicineField,
                  backgroundColor: _primaryColor,
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_medicineControllers.length, (index) {
              return _buildMedicineCard(index);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Medicine ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_medicineControllers.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                  onPressed: () => _removeMedicineField(index),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: _medicineControllers[index],
              decoration: InputDecoration(
                labelText: 'Medicine Name',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(Icons.medication_outlined, color: _primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _dosageControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Dosage',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _durationControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: _frequencyControllers[index],
              decoration: InputDecoration(
                labelText: 'Frequency',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(Icons.repeat, color: _primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: _instructionControllers[index],
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Special Instructions',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(Icons.info_outline, color: _primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('CLINICAL DRAWING PAD', Icons.edit),
            const SizedBox(height: 16),
            
            // Toolbar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildColorButton(Colors.black),
                _buildColorButton(Colors.red),
                _buildColorButton(Colors.blue),
                _buildColorButton(Colors.green),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.brush, color: _isErasing ? Colors.grey : _selectedColor),
                  tooltip: 'Pencil',
                  onPressed: () {
                    setState(() {
                      _isErasing = false;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.auto_fix_normal, color: _isErasing ? Colors.orange : Colors.grey),
                  tooltip: 'Eraser',
                  onPressed: () {
                    setState(() {
                      _isErasing = !_isErasing;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                  tooltip: 'Clear All',
                  onPressed: _clearDrawing,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Drawing Area
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: _accentColor),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _handleDrawingStart,
                onPanUpdate: _handleDrawingUpdate,
                onPanEnd: _handleDrawingEnd,
                child: RepaintBoundary(
                  key: _drawingKey,
                  child: CustomPaint(
                    painter: DrawingPainter(points: _drawingPoints),
                    size: Size.infinite,
                    child: _drawingPoints.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.draw, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'Draw clinical diagrams or notes here',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _isErasing = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedColor == color ? Colors.white : Colors.grey,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInstructions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('ADDITIONAL INSTRUCTIONS', Icons.note_add),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'General Instructions & Advice',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.assignment, color: _primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                _buildSectionHeader('DOCTOR SIGNATURE', Icons.assignment_ind),
                const Spacer(),
                if (_hasSignature)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: _clearSignature,
                    tooltip: 'Clear Signature',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Signature Area
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background with guide lines
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.grey.shade50,
                        ],
                        stops: const [0.7, 1.0],
                      ),
                    ),
                    child: CustomPaint(
                      painter: SignatureGuidePainter(),
                    ),
                  ),

                  // Signature Canvas
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _handleSignatureStart,
                    onPanUpdate: _handleSignatureUpdate,
                    onPanEnd: _handleSignatureEnd,
                    child: RepaintBoundary(
                      key: _signatureKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          painter: DrawingPainter(points: _signaturePoints),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),

                  // Instruction Text (only shown when no signature)
                  if (!_hasSignature)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 32,
                            color: _darkColor.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign above this line',
                            style: TextStyle(
                              color: _darkColor.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Draw your signature in the box above',
                            style: TextStyle(
                              color: _darkColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Doctor Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    color: _darkColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _doctorNameController.text,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _darkColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Registration No: ${_doctorRegNoController.text}',
                          style: TextStyle(
                            color: _darkColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                          style: TextStyle(
                            color: _darkColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasSignature)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                ],
              ),
            ),

            // Signature Status
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasSignature ? Icons.check_circle : Icons.info,
                  color: _hasSignature ? Colors.green : _darkColor.withOpacity(0.6),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _hasSignature ? 'Signature provided' : 'Signature required',
                  style: TextStyle(
                    color: _hasSignature ? Colors.green : _darkColor.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _savePrescription(),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Save Prescription', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _shareWithPharmacies,
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('Share to Pharmacy', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateAndSharePDF,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('Export as PDF', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // Signature Requirement Note
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hasSignature ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasSignature ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _hasSignature ? Icons.check_circle : Icons.warning,
                color: _hasSignature ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hasSignature 
                    ? 'Your signature has been added to the prescription.'
                    : 'Please provide your signature above to complete the prescription.',
                  style: TextStyle(
                    color: _hasSignature ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _darkColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _darkColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Column(
      children: [
        Icon(Icons.people_outline, size: 40, color: _darkColor.withOpacity(0.5)),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(color: _darkColor.withOpacity(0.7)),
        ),
        Text(
          subtitle,
          style: TextStyle(color: _darkColor.withOpacity(0.5), fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Custom painter for signature guide lines
class SignatureGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw horizontal guide line in the middle
    final middleY = size.height * 0.6;
    canvas.drawLine(
      Offset(0, middleY),
      Offset(size.width, middleY),
      paint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(SignatureGuidePainter oldDelegate) => false;
}

class DrawingPoint {
  final Offset? position;
  final Paint paint;

  DrawingPoint({required this.position, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].position != null && points[i + 1].position != null) {
        canvas.drawLine(points[i].position!, points[i + 1].position!, points[i].paint);
      } else if (points[i].position != null && points[i + 1].position == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i].position!], points[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}