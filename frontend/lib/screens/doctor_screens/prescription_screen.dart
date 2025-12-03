import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/rendering.dart';
import 'package:frontend/model/prescription_model.dart';
import 'package:frontend/screens/doctor_screens/pharmacy_selection_screen.dart';
import 'package:frontend/screens/doctor_screens/prescription_history_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';



class PrescriptionScreen extends StatefulWidget {
  final String? patientId;
  final String? patientName;
  final String? patientAge;
  final Map<String, dynamic>? patientData;
   final bool isFromProfile;
    final String? appointmentId;
  final String? scheduleId;
  final VoidCallback? onPrescriptionComplete;

  const PrescriptionScreen({super.key,
  this.patientId,
    this.patientName,
    this.patientAge,
    this.patientData,
     this.isFromProfile = false,
     this.appointmentId,
    this.scheduleId,
    this.onPrescriptionComplete,
     });

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
  final TextEditingController _medicalCenterController = TextEditingController(text: 'City Medical Center & Hospital');

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
  
  List<Map<String, dynamic>> _patientSuggestions = [];
  List<Map<String, dynamic>> _availablePharmacies = [];
  String? _selectedPatientId;

  // Color Scheme for prescription
  final Color _prescriptionBlue = Color(0xFF1E3A8A);
  final Color _prescriptionGreen = Color(0xFF065F46);
  final Color _prescriptionRed = Color(0xFFDC2626);
  final Color _prescriptionGray = Color(0xFF6B7280);

  // UI Color Scheme
  final Color _backgroundColor = const Color(0xFFDDF0F5);
  final Color _cardColor = const Color(0xFFB2DEE6);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _primaryColor = const Color(0xFF32BACD);
  final Color _darkColor = const Color(0xFF18A3B6);

  final GlobalKey _prescriptionCaptureKey = GlobalKey();

  // FIX: Add these variables for scroll control
  bool _isDrawing = false;
  bool _isSigning = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _addMedicineField();
    _loadPharmacies();
    _loadPatientAppointments();
    _loadDoctorInfo();
    _setPatientData();
  }
void _setPatientData() {
  if (widget.patientName != null && widget.patientName!.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _patientNameController.text = widget.patientName!;
        
        if (widget.patientId != null) {
          _selectedPatientId = widget.patientId;
        }
        
        if (widget.patientAge != null && widget.patientAge!.isNotEmpty) {
          _patientAgeController.text = widget.patientAge!;
        } else if (widget.patientData != null) {
          // Try to extract age from patient data
          final age = widget.patientData!['age'];
          if (age != null) {
            _patientAgeController.text = age.toString();
          } else if (widget.patientData!['dob'] != null) {
            // Calculate age from date of birth
            try {
              final dob = DateTime.parse(widget.patientData!['dob']);
              final now = DateTime.now();
              int calculatedAge = now.year - dob.year;
              if (now.month < dob.month || 
                  (now.month == dob.month && now.day < dob.day)) {
                calculatedAge--;
              }
              _patientAgeController.text = calculatedAge.toString();
            } catch (e) {
              debugPrint('Error calculating age from DOB: $e');
            }
          }
        }
      });
    });
  }
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
            _doctorNameController.text = data?['fullname'] ?? 'Dr. Rajesh Kumar';
            _doctorRegNoController.text = data?['regNumber'] ?? 'MED12345';
            _medicalCenterController.text = data?['hospital'] ?? 'City Medical Center & Hospital';
          });
        } else {
          setState(() {
            _doctorNameController.text = 'Dr. Rajesh Kumar';
            _doctorRegNoController.text = 'MED12345';
            _medicalCenterController.text = 'City Medical Center & Hospital';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading doctor info: $e');
      setState(() {
        _doctorNameController.text = 'Dr. Rajesh Kumar';
        _doctorRegNoController.text = 'MED12345';
        _medicalCenterController.text = 'City Medical Center & Hospital';
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
    _medicalCenterController.dispose();
    _scrollController.dispose();
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

  // FIXED DRAWING METHODS - Prevent scrolling while drawing
  void _handleDrawingStart(DragStartDetails details) {
    setState(() {
      _isDrawing = true;
    });

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
      _isDrawing = false;
    });
  }

  void _clearDrawing() {
    setState(() {
      _drawingPoints.clear();
    });
  }

  // FIXED SIGNATURE METHODS - Prevent scrolling while signing
  void _handleSignatureStart(DragStartDetails details) {
    setState(() {
      _isSigning = true;
    });

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
      _isSigning = false;
    });
  }

  void _clearSignature() {
    setState(() {
      _signaturePoints.clear();
      _hasSignature = false;
    });
  }

  // Generate Prescription Image with Colors and Drawings
 Future<Uint8List?> _generatePrescriptionImage() async {
  try {
    debugPrint('🎨 Generating prescription image with colors and drawings...');
    
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    
    final double width = 600;
    final double height = 1000; // Increased height for drawings
    final Rect bounds = Rect.fromLTWH(0, 0, width, height);
    
    // Draw white background with subtle texture
    final Paint backgroundPaint = Paint()..color = Color(0xFFFEFEFE);
    canvas.drawRect(bounds, backgroundPaint);
    
    // Draw content with colors
    _drawHeader(canvas, width);
    _drawPatientInfo(canvas, width);
    _drawMedicines(canvas, width);
    _drawClinicalDrawing(canvas, width); // This will draw the clinical diagram
    _drawFooter(canvas, width, height);
    
    // Convert to image
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      debugPrint('❌ Failed to generate prescription image bytes');
      return null;
    }
    
    final Uint8List imageBytes = byteData.buffer.asUint8List();
    debugPrint('✅ Prescription image generated: ${imageBytes.length} bytes');
    
    return imageBytes;
    
  } catch (e) {
    debugPrint('❌ Error generating prescription image: $e');
    return null;
  }
}


void _drawHeader(Canvas canvas, double width) {
  // Draw colored header background
  final headerPaint = Paint()
    ..color = _prescriptionBlue
    ..style = PaintingStyle.fill;
  
  canvas.drawRect(Rect.fromLTWH(0, 0, width, 120), headerPaint);
  
  // Medical Center Name - White text
  final centerTextStyle = ui.TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    fontFamily: 'Roboto',
  );
  
  final centerBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.center,
  ))
    ..pushStyle(centerTextStyle)
    ..addText(_medicalCenterController.text.toUpperCase());
  
  final centerParagraph = centerBuilder.build();
  centerParagraph.layout(ui.ParagraphConstraints(width: width - 40));
  canvas.drawParagraph(centerParagraph, const Offset(20, 20));
  
  // Prescription Title
  final titleTextStyle = ui.TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  
  final titleBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.center,
  ))
    ..pushStyle(titleTextStyle)
    ..addText('MEDICAL PRESCRIPTION');
  
  final titleParagraph = titleBuilder.build();
  titleParagraph.layout(ui.ParagraphConstraints(width: width - 40));
  canvas.drawParagraph(titleParagraph, const Offset(20, 50));
  
  // Date with background
  final dateBoxPaint = Paint()
    ..color = Colors.white.withOpacity(0.2)
    ..style = PaintingStyle.fill;
  
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(width - 180, 80, 160, 30), Radius.circular(15)),
    dateBoxPaint
  );
  
  final dateTextStyle = ui.TextStyle(
    color : Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  
  final dateBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
    ..pushStyle(dateTextStyle)
    ..addText('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
  
  final dateParagraph = dateBuilder.build();
  dateParagraph.layout(ui.ParagraphConstraints(width: 150));
  canvas.drawParagraph(dateParagraph, Offset(width - 170, 85));
  
  // Draw decorative line
  final linePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
  
  canvas.drawLine(Offset(20, 115), Offset(width - 20, 115), linePaint);
}


 void _drawPatientInfo(Canvas canvas, double width) {
  double currentY = 140;
  
  // Section title with colored background
  final sectionPaint = Paint()
    ..color = _prescriptionGreen.withOpacity(0.1)
    ..style = PaintingStyle.fill;
  
  canvas.drawRect(Rect.fromLTWH(20, currentY, width - 40, 30), sectionPaint);
  
  final sectionTextStyle = ui.TextStyle(
    color : _prescriptionGreen,
    fontSize: 14,
    fontWeight : FontWeight.bold,
  );
  
  final sectionBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
    ..pushStyle(sectionTextStyle)
    ..addText('PATIENT INFORMATION');
  
  final sectionParagraph = sectionBuilder.build();
  sectionParagraph.layout(ui.ParagraphConstraints(width: width - 40));
  canvas.drawParagraph(sectionParagraph, Offset(30, currentY + 8));
  
  currentY += 40;
  
  // Patient details
  final infoTextStyle = ui.TextStyle(
    color : Colors.black,
    fontSize: 12,
  );
  
  final infoBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
    ..pushStyle(infoTextStyle)
    ..addText('Patient: ${_patientNameController.text}\n')
    ..addText('Age: ${_patientAgeController.text} years\n');
  
  if (_diagnosisController.text.isNotEmpty) {
    infoBuilder.addText('Diagnosis: ${_diagnosisController.text}');
  }
  
  final infoParagraph = infoBuilder.build();
  infoParagraph.layout(ui.ParagraphConstraints(width: width - 40));
  canvas.drawParagraph(infoParagraph, Offset(30, currentY));
  
  currentY += 60;
  
  // Draw line
  final linePaint = Paint()
    ..color = _prescriptionGray.withOpacity(0.3)
    ..strokeWidth = 1;
  canvas.drawLine(Offset(20, currentY), Offset(width - 20, currentY), linePaint);
}


  void _drawMedicines(Canvas canvas, double width) {
  double currentY = 250;
  
  // Section title
  final sectionPaint = Paint()
    ..color = _prescriptionBlue.withOpacity(0.1)
    ..style = PaintingStyle.fill;
  
  canvas.drawRect(Rect.fromLTWH(20, currentY, width - 40, 30), sectionPaint);
  
  final sectionTextStyle = ui.TextStyle(
    color : _prescriptionBlue,
    fontSize: 14,
    fontWeight :FontWeight.bold,
  );
  
  final sectionBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
    ..pushStyle(sectionTextStyle)
    ..addText('PRESCRIBED MEDICATIONS');
  
  final sectionParagraph = sectionBuilder.build();
  sectionParagraph.layout(ui.ParagraphConstraints(width: width - 40));
  canvas.drawParagraph(sectionParagraph, Offset(30, currentY + 8));
  
  currentY += 40;
  
  // Draw medicines
  for (int i = 0; i < _medicineControllers.length; i++) {
    if (_medicineControllers[i].text.isNotEmpty) {
      // Medicine card background
      final medicineCardPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      final medicineStrokePaint = Paint()
        ..color = _prescriptionGreen.withOpacity(0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      
      canvas.drawRect(Rect.fromLTWH(25, currentY, width - 50, 70), medicineCardPaint);
      canvas.drawRect(Rect.fromLTWH(25, currentY, width - 50, 70), medicineStrokePaint);
      
      // Medicine number with circle
      final numberPaint = Paint()
        ..color = _prescriptionGreen
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(45, currentY + 15), 10, numberPaint);
      
      final numberTextStyle = ui.TextStyle(
        color : Colors.white,
        fontSize: 10,
        fontWeight : FontWeight.bold,
      );
      
      final numberBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign :TextAlign.center,
      ))
        ..pushStyle(numberTextStyle)
        ..addText('${i + 1}');
      
      final numberParagraph = numberBuilder.build();
      numberParagraph.layout(ui.ParagraphConstraints(width: 20));
      canvas.drawParagraph(numberParagraph, Offset(35, currentY + 10));
      
      // Medicine details
      // Medicine details
final medicineText = '''
${_medicineControllers[i].text.toUpperCase()}
Dosage: ${_dosageControllers[i].text} | Duration: ${_durationControllers[i].text}
${_frequencyControllers[i].text.isNotEmpty ? 'Frequency: ${_frequencyControllers[i].text}' : ''}
${_instructionControllers[i].text.isNotEmpty ? 'Instructions: ${_instructionControllers[i].text}' : ''}
''';
      
      final medicineStyle = ui.TextStyle(
        color : Colors.black,
        fontSize: 10,
      );
      
      final medicineBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
        ..pushStyle(medicineStyle)
        ..addText(medicineText);
      
      final medicineParagraph = medicineBuilder.build();
      medicineParagraph.layout(ui.ParagraphConstraints(width: width - 80));
      canvas.drawParagraph(medicineParagraph, Offset(60, currentY + 5));
      
      currentY += 80;
    }
  }
  
  // Additional instructions
  if (_descriptionController.text.isNotEmpty) {
    currentY += 10;
    
    final instructionsPaint = Paint()
      ..color = _prescriptionGray.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(20, currentY, width - 40, 50), instructionsPaint);
    
    final instructionsStyle = ui.TextStyle(
      color :_prescriptionGray,
      fontSize: 11,
      fontWeight : FontWeight.w500,
    );
    
    final instructionsBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(instructionsStyle)
      ..addText('Additional Instructions:\n${_descriptionController.text}');
    
    final instructionsParagraph = instructionsBuilder.build();
    instructionsParagraph.layout(ui.ParagraphConstraints(width: width - 50));
    canvas.drawParagraph(instructionsParagraph, Offset(30, currentY + 5));
    
    currentY += 60;
  }
  
  // Draw line
  final linePaint = Paint()
    ..color = _prescriptionGray.withOpacity(0.3)
    ..strokeWidth = 1;
  canvas.drawLine(Offset(20, currentY), Offset(width - 20, currentY), linePaint);
}

 void _drawFooter(Canvas canvas, double width, double height) {
  double currentY = height - 150;
  
  // Draw line
  final linePaint = Paint()
    ..color = _prescriptionGray.withOpacity(0.3)
    ..strokeWidth = 1;
  canvas.drawLine(Offset(20, currentY), Offset(width - 20, currentY), linePaint);
  
  currentY += 20;
  
  // Doctor signature area
  if (_signaturePoints.isNotEmpty) {
    final signatureTextStyle = ui.TextStyle(
      color : Colors.black,
      fontSize: 11,
      fontWeight : FontWeight.w500,
    );
    
    final signatureBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(signatureTextStyle)
      ..addText('Doctor Signature:');
    
    final signatureParagraph = signatureBuilder.build();
    signatureParagraph.layout(ui.ParagraphConstraints(width: 120));
    canvas.drawParagraph(signatureParagraph, Offset(30, currentY));
    
    // Draw the signature
    final signatureBounds = Rect.fromLTWH(150, currentY - 5, 200, 40);
    final borderPaint = Paint()
      ..color = _prescriptionGray.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawRect(signatureBounds, borderPaint);
    
    // Draw signature points
    for (int i = 0; i < _signaturePoints.length - 1; i++) {
      if (_signaturePoints[i].position != null && _signaturePoints[i + 1].position != null) {
        final adjustedStart = Offset(
          _signaturePoints[i].position!.dx * 180 / 300 + 160,
          _signaturePoints[i].position!.dy * 30 / 120 + currentY + 5
        );
        final adjustedEnd = Offset(
          _signaturePoints[i + 1].position!.dx * 180 / 300 + 160,
          _signaturePoints[i + 1].position!.dy * 30 / 120 + currentY + 5
        );
        
        canvas.drawLine(adjustedStart, adjustedEnd, _signaturePoints[i].paint);
      }
    }
    
    currentY += 50;
  }
  
  // Doctor verification
  final doctorBoxPaint = Paint()
    ..color = _prescriptionBlue.withOpacity(0.1)
    ..style = PaintingStyle.fill;
  
  canvas.drawRect(Rect.fromLTWH(20, currentY, width - 40, 60), doctorBoxPaint);
  
  final doctorTextStyle = ui.TextStyle(
    color : Colors.black,
    fontSize: 12,
    fontWeight :FontWeight.w500,
  );
  
  final doctorBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
    ..pushStyle(doctorTextStyle)
    ..addText('Verified by: ${_doctorNameController.text}\n')
    ..addText('Registration No: ${_doctorRegNoController.text}\n')
    ..addText('Medical Center: ${_medicalCenterController.text}\n')
    ..addText('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
  
  final doctorParagraph = doctorBuilder.build();
  doctorParagraph.layout(ui.ParagraphConstraints(width: width - 50));
  canvas.drawParagraph(doctorParagraph, Offset(30, currentY + 5));
}
void _drawClinicalDrawing(Canvas canvas, double width) {
  double currentY = 550;
  
  // Only draw if there are drawings
  if (_drawingPoints.isNotEmpty) {
    // Section title
    final sectionPaint = Paint()
      ..color = _prescriptionRed.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(20, currentY, width - 40, 30), sectionPaint);
    
    final sectionTextStyle = ui.TextStyle(
      color :_prescriptionRed,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );
    
    final sectionBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(sectionTextStyle)
      ..addText('CLINICAL DIAGRAM');
    
    final sectionParagraph = sectionBuilder.build();
    sectionParagraph.layout(ui.ParagraphConstraints(width: width - 40));
    canvas.drawParagraph(sectionParagraph, Offset(30, currentY + 8));
    
    currentY += 40;
    
    // Draw the clinical drawing
    final drawingBounds = Rect.fromLTWH(30, currentY, width - 60, 150);
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(drawingBounds, backgroundPaint);
    
    final borderPaint = Paint()
      ..color = _prescriptionGray.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawRect(drawingBounds, borderPaint);
    
    // Draw the actual drawing points
    for (int i = 0; i < _drawingPoints.length - 1; i++) {
      if (_drawingPoints[i].position != null && _drawingPoints[i + 1].position != null) {
        // Adjust drawing points to fit within the drawing area
        final adjustedStart = Offset(
          _drawingPoints[i].position!.dx * (width - 100) / 300 + 40,
          _drawingPoints[i].position!.dy * 120 / 200 + currentY + 15
        );
        final adjustedEnd = Offset(
          _drawingPoints[i + 1].position!.dx * (width - 100) / 300 + 40,
          _drawingPoints[i + 1].position!.dy * 120 / 200 + currentY + 15
        );
        
        canvas.drawLine(adjustedStart, adjustedEnd, _drawingPoints[i].paint);
      }
    }
    
    currentY += 170;
  }
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
    debugPrint('💾 Prescription saved successfully');

    await _completeAppointmentAndAdvanceQueue();
    
    // Generate prescription image with colors and drawings
    final Uint8List? prescriptionImage = await _generatePrescriptionImage();
    
    Uint8List? drawingImage;
    if (_drawingPoints.isNotEmpty) {
      drawingImage = await _captureDrawing();
    }

    Uint8List? signatureImage;
    if (_signaturePoints.isNotEmpty) {
      signatureImage = await _captureSignature();
    }

    // Upload prescription image to Firebase Storage
    String? prescriptionImageUrl;
    if (prescriptionImage != null) {
      prescriptionImageUrl = await _uploadPrescriptionImageToStorage(
        prescriptionImage, 
        user.uid, 
        widget.patientId ?? _selectedPatientId ?? ''
      );
    }

    // Create prescription data
    final prescriptionData = <String, dynamic>{
      'doctorId': user.uid,
      'doctorName': _doctorNameController.text,
      'patientId': widget.patientId ?? _selectedPatientId ?? '',
      'patientName': _patientNameController.text,
      'patientAge': _patientAgeController.text.isNotEmpty ? int.tryParse(_patientAgeController.text) : null,
      'date': DateTime.now(),
      'medicines': _getMedicines().map((m) => m.toMap()).toList(),
      'description': _descriptionController.text,
      'diagnosis': '', // Will be merged with consultation data if available
      'notes': '',
      'status': shareWithPharmacies ? 'shared' : 'completed',
      'sharedPharmacies': shareWithPharmacies ? _getSelectedPharmacyIds() : [],
      'medicalCenter': _medicalCenterController.text,
      'doctorRegistration': _doctorRegNoController.text,
      'prescriptionImageUrl': prescriptionImageUrl,
      'drawingImage': drawingImage != null ? base64Encode(drawingImage) : null,
      'signatureImage': signatureImage != null ? base64Encode(signatureImage) : null,
      'appointmentId': widget.appointmentId,
      'scheduleId': widget.scheduleId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // If there's an appointment, merge with existing consultation data
    if (widget.appointmentId != null && widget.appointmentId!.isNotEmpty) {
      try {
        final consultationQuery = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: widget.appointmentId)
            .limit(1)
            .get();
        
        if (consultationQuery.docs.isNotEmpty) {
          final consultationData = consultationQuery.docs.first.data();
          prescriptionData['diagnosis'] = consultationData['diagnosis'] ?? '';
          prescriptionData['notes'] = consultationData['notes'] ?? '';
          
          // Update existing document
          await consultationQuery.docs.first.reference.update(prescriptionData);
        } else {
          // Create new document
          final String docId = DateTime.now().millisecondsSinceEpoch.toString();
          prescriptionData['id'] = docId;
          await FirebaseFirestore.instance
              .collection('prescriptions')
              .doc(docId)
              .set(prescriptionData);
        }
      } catch (e) {
        debugPrint('Error merging consultation data: $e');
        // Create new document anyway
        final String docId = DateTime.now().millisecondsSinceEpoch.toString();
        prescriptionData['id'] = docId;
        await FirebaseFirestore.instance
            .collection('prescriptions')
            .doc(docId)
            .set(prescriptionData);
      }
    } else {
      // Create new document without appointment
      final String docId = DateTime.now().millisecondsSinceEpoch.toString();
      prescriptionData['id'] = docId;
      await FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(docId)
          .set(prescriptionData);
    }

    // Update appointment status if applicable
    if (widget.appointmentId != null && widget.appointmentId!.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId!)
          .update({
        'prescriptionStatus': 'completed',
        'prescriptionCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final sharedPharmacyIds = prescriptionData['sharedPharmacies'] as List<dynamic>;
    if (shareWithPharmacies && sharedPharmacyIds.isNotEmpty) {
      await _notifyPharmacies(prescriptionData);
    }

    // Use mounted check before calling setState or Navigator
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shareWithPharmacies 
            ? 'Prescription saved and shared with pharmacies!'
            : 'Prescription saved successfully!',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Call the completion callback
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      debugPrint('🔄 Navigating back to Doctor Unified Search Screen');
      
      // Go back TWICE: 
      // 1. First pop: Close prescription screen
      // 2. Second pop: Close patient profile screen  
      // 3. This will return to DoctorUnifiedSearchScreen
      
      // First pop the prescription screen
      Navigator.pop(context);
      
      // Then call the completion callback if provided
      if (widget.onPrescriptionComplete != null) {
        widget.onPrescriptionComplete!();
      }
    });
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

// Helper method to encode image to base64
String _encodeImageToBase64(Uint8List imageBytes) {
  return base64Encode(imageBytes);
}

  Future<String?> _uploadPrescriptionImageToStorage(
    Uint8List imageBytes, 
    String doctorId, 
    String patientId
  ) async {
    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final fileName = 'prescription_${doctorId}_${patientId}_$timestamp.png';
      
      debugPrint('📤 Uploading prescription image...');
      debugPrint('📁 File name: $fileName');
      debugPrint('📊 Image size: ${imageBytes.length} bytes');
      
      final Reference storageRef = storage
          .ref()
          .child('prescriptions')
          .child(doctorId)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/png',
          customMetadata: {
            'doctorId': doctorId,
            'patientId': patientId,
            'patientName': _patientNameController.text,
            'medicalCenter': _medicalCenterController.text,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Prescription image uploaded to Firebase Storage: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading prescription image to Firebase Storage: $e');
      return null;
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
// ADD THIS METHOD TO PRESCRIPTION SCREEN
Future<void> _completeAppointmentAndAdvanceQueue() async {
  debugPrint('🏁 Completing appointment and advancing queue...');
  debugPrint('📋 Appointment ID: ${widget.appointmentId}');
  debugPrint('📅 Schedule ID: ${widget.scheduleId}');
  
  if (widget.appointmentId == null || widget.appointmentId!.isEmpty) {
    debugPrint('⚠️ No appointment ID provided - skipping queue advancement');
    return;
  }

  try {
    // 1. Mark current appointment as completed
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(widget.appointmentId!)
        .update({
      'status': 'completed',
      'queueStatus': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Appointment ${widget.appointmentId} marked as completed');

    // 2. Find next appointment in queue
    final nextAppointmentsQuery = await FirebaseFirestore.instance
        .collection('appointments')
        .where('scheduleId', isEqualTo: widget.scheduleId)
        .where('status', isEqualTo: 'confirmed')
        .where('queueStatus', isEqualTo: 'waiting')
        .orderBy('tokenNumber')
        .limit(1)
        .get();

    if (nextAppointmentsQuery.docs.isNotEmpty) {
      final nextAppointment = nextAppointmentsQuery.docs.first;
      final nextAppointmentId = nextAppointment.id;
      
      // 3. Update next appointment to "in_consultation"
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(nextAppointmentId)
          .update({
        'queueStatus': 'in_consultation',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('⏭️ Next appointment #${nextAppointment.data()['tokenNumber']} (${nextAppointment.data()['patientName']}) set to in_consultation');
      
      // 4. Show notification about next patient
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Appointment completed. Next patient: ${nextAppointment.data()['patientName']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      debugPrint('🏁 No more patients in queue');
      
      // Show completion message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🏁 All appointments completed for this schedule'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }

  } catch (e) {
    debugPrint('❌ Error completing appointment: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error completing appointment: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
 Future<void> _notifyPharmacies(Map<String, dynamic> prescriptionData) async {
  try {
    final sharedPharmacies = prescriptionData['sharedPharmacies'] as List<dynamic>?;
    if (sharedPharmacies == null || sharedPharmacies.isEmpty) return;
    
    for (var pharmacyId in sharedPharmacies) {
      await FirebaseFirestore.instance
          .collection('pharmacyNotifications')
          .add({
        'pharmacyId': pharmacyId,
        'prescriptionId': prescriptionData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'patientName': prescriptionData['patientName'] ?? 'Unknown',
        'doctorId': prescriptionData['doctorId'] ?? '',
        'doctorName': prescriptionData['doctorName'] ?? 'Dr. Unknown',
        'medicalCenter': prescriptionData['medicalCenter'] ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
        'medicinesCount': (prescriptionData['medicines'] as List<dynamic>?)?.length ?? 0,
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
      body: RepaintBoundary(
        key: _prescriptionCaptureKey,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : NotificationListener<ScrollNotification>(
                // FIX: Prevent scrolling while drawing or signing
                onNotification: (scrollNotification) {
                  if (_isDrawing || _isSigning) {
                    return true; // Prevent scrolling
                  }
                  return false; // Allow scrolling
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                       if (widget.appointmentId != null && widget.appointmentId!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[100] ?? Colors.blue),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Queue Consultation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Finishing prescription will complete this appointment and move to next patient',
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Header Section with Medical Center
                      _buildHeaderSection(),
                      const SizedBox(height: 20),
                      
                      // Medical Center Editor
                      _buildMedicalCenterSection(),
                      const SizedBox(height: 16),
                      
                      // Patient Information
                      _buildPatientInfoSection(),
                      const SizedBox(height: 16),
                      
                      // Diagnosis Section
                      _buildDiagnosisSection(),
                      const SizedBox(height: 16),
                      
                      // Medicines Section
                      _buildMedicinesSection(),
                      const SizedBox(height: 16),
                      
                      // Drawing Section - FIXED
                      _buildFixedDrawingSection(),
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
              ),
      ),
    );
  }

  // FIXED DRAWING SECTION
  Widget _buildFixedDrawingSection() {
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
            const SizedBox(height: 8),
            Text(
              'Draw clinical diagrams that will appear on the prescription',
              style: TextStyle(
                color: _darkColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            
            // Horizontal scroll for color palette
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildColorButton(Colors.black),
                  _buildColorButton(Colors.red),
                  _buildColorButton(Colors.blue),
                  _buildColorButton(Colors.green),
                  _buildColorButton(Colors.orange),
                  _buildColorButton(Colors.purple),
                  _buildColorButton(Colors.brown),
                  _buildColorButton(Colors.pink),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey.shade300,
                  ),
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
            ),
            const SizedBox(height: 16),

            // Drawing Area with better gesture handling
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: _accentColor, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Listener(
                  onPointerDown: (details) {
                    FocusScope.of(context).unfocus();
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _handleDrawingStart,
                    onPanUpdate: _handleDrawingUpdate,
                    onPanEnd: _handleDrawingEnd,
                    child: RepaintBoundary(
                      key: _drawingKey,
                      child: Stack(
                        children: [
                          // Background pattern
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  Colors.grey.shade50,
                                ],
                              ),
                            ),
                            child: CustomPaint(
                              painter: DrawingGridPainter(),
                            ),
                          ),
                          
                          // Drawing canvas
                          CustomPaint(
                            painter: FixedDrawingPainter(points: _drawingPoints),
                            size: Size.infinite,
                          ),
                          
                          // Empty state
                          if (_drawingPoints.isEmpty)
                            const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.draw, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Start drawing clinical diagrams here',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'These will appear on the final prescription',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalCenterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('MEDICAL CENTER', Icons.local_hospital),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _medicalCenterController,
                decoration: InputDecoration(
                  labelText: 'Hospital/Medical Center Name',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.business, color: _primaryColor),
                ),
              ),
            ),
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
          Text(
            _medicalCenterController.text.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'MEDICAL PRESCRIPTION',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
          
          // If coming from profile, show non-editable fields
          if (widget.isFromProfile && widget.patientName != null)
            Column(
              children: [
                // Patient Name (Non-editable)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: _primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patient Name',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _patientNameController.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _darkColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'FROM PROFILE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Patient Age (Non-editable)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: _primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patient Age',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _patientAgeController.text.isNotEmpty
                                    ? '${_patientAgeController.text} years'
                                    : 'Not specified',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _darkColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            // Original dropdown for selecting patients
            _buildPatientDropdownSection(),
        ],
      ),
    ),
  );
}

// Original dropdown section (moved to separate method)
Widget _buildPatientDropdownSection() {
  if (_patientSuggestions.isEmpty) {
    return _buildEmptyState('No patients available', 'Confirmed appointments will appear here');
  }
  
  return Column(
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
  // Predefined options
  final List<String> dosageOptions = [
    '1 capsule',
    '2 capsules', 
    '1 tablet',
    '2 tablets',
    '5ml syrup',
    '10ml syrup',
    '1 teaspoon',
    '2 teaspoons',
    '1 injection',
    '2 injections',
    '1 drop',
    '2 drops',
    '1 spray',
    '2 sprays',
    '1 patch',
    'Other'
  ];

  final List<String> frequencyOptions = [
    'Once daily',
    'Twice daily', 
    'Three times daily',
    'Four times daily',
    'Every 6 hours',
    'Every 8 hours',
    'Every 12 hours',
    'Once weekly',
    'Twice weekly',
    'As needed',
    'Before meals',
    'After meals',
    'At bedtime',
    'Other'
  ];

  final List<String> durationOptions = [
    '1 day',
    '3 days',
    '5 days',
    '7 days',
    '10 days',
    '14 days',
    '21 days',
    '30 days',
    '45 days',
    '60 days',
    '90 days',
    'Until finished',
    'As directed',
    'Other'
  ];

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
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
        
        // Medicine Name (Text Input)
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
        
        // Dosage Dropdown
        Container(
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            value: _dosageControllers[index].text.isEmpty ? null : _dosageControllers[index].text,
            decoration: InputDecoration(
              labelText: 'Dosage',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              prefixIcon: Icon(Icons.medical_services, color: _primaryColor),
            ),
            items: dosageOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _dosageControllers[index].text = newValue ?? '';
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        
        // Frequency Dropdown
        Container(
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            value: _frequencyControllers[index].text.isEmpty ? null : _frequencyControllers[index].text,
            decoration: InputDecoration(
              labelText: 'Frequency',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              prefixIcon: Icon(Icons.repeat, color: _primaryColor),
            ),
            items: frequencyOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _frequencyControllers[index].text = newValue ?? '';
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        
        // Duration Dropdown
        Container(
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            value: _durationControllers[index].text.isEmpty ? null : _durationControllers[index].text,
            decoration: InputDecoration(
              labelText: 'Duration',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
            ),
            items: durationOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _durationControllers[index].text = newValue ?? '';
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        
        // Special Instructions (Text Input)
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
            color: _selectedColor == color ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
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
              height: 140,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Listener(
                  onPointerDown: (details) {
                    FocusScope.of(context).unfocus();
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _handleSignatureStart,
                    onPanUpdate: _handleSignatureUpdate,
                    onPanEnd: _handleSignatureEnd,
                    child: RepaintBoundary(
                      key: _signatureKey,
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
                              painter: FixedSignatureGuidePainter(),
                            ),
                          ),

                          // Signature Canvas
                          CustomPaint(
                            painter: FixedDrawingPainter(points: _signaturePoints),
                            size: Size.infinite,
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
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
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
                          'Medical Center: ${_medicalCenterController.text}',
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
        const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _savePrescription(),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('finish Prescription', style: TextStyle(color: Colors.white)),
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
            
          ],
        ),
        const SizedBox(height: 12),

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
                    ? 'Your signature and drawings will be included in the prescription.'
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
void debugPrintQueueInfo(String message) {
  final timestamp = DateTime.now().toIso8601String();
  debugPrint('🕒 [$timestamp] $message');
}
void setupDebugLogging() {
  debugPrint('🚀 === MEDICAL QUEUE SYSTEM STARTED ===');
  debugPrint('📱 Platform: ${Platform.operatingSystem}');
  debugPrint('📅 Date: ${DateTime.now()}');
}
// FIXED CUSTOM PAINTERS - Add these at the bottom of the file
class FixedDrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  FixedDrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].position != null && points[i + 1].position != null) {
        canvas.drawLine(points[i].position!, points[i + 1].position!, points[i].paint);
      } else if (points[i].position != null && points[i + 1].position == null) {
        // Draw points for better performance with single taps
        canvas.drawCircle(points[i].position!, points[i].paint.strokeWidth / 2, points[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(FixedDrawingPainter oldDelegate) => true;
  
  @override
  bool shouldRebuildSemantics(FixedDrawingPainter oldDelegate) => false;
}

class DrawingGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 0.5;

    // Draw grid lines
    const gridSize = 20.0;
    
    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(DrawingGridPainter oldDelegate) => false;
  
  @override
  bool shouldRebuildSemantics(DrawingGridPainter oldDelegate) => false;
}

class FixedSignatureGuidePainter extends CustomPainter {
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
  bool shouldRepaint(FixedSignatureGuidePainter oldDelegate) => false;
  
  @override
  bool shouldRebuildSemantics(FixedSignatureGuidePainter oldDelegate) => false;
}

class DrawingPoint {
  final Offset? position;
  final Paint paint;

  DrawingPoint({required this.position, required this.paint});
}