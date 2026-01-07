import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdditionalDetailsScreen extends StatefulWidget {
  final String uid;
  const AdditionalDetailsScreen({super.key, required this.uid});

  @override
  State<AdditionalDetailsScreen> createState() => _AdditionalDetailsScreenState();
}

class BPReading {
  final int systolic;
  final int diastolic;
  final DateTime date;
  final String? note;
  
  BPReading({
    required this.systolic,
    required this.diastolic,
    required this.date,
    this.note,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'systolic': systolic,
      'diastolic': diastolic,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
  
  factory BPReading.fromMap(Map<String, dynamic> map) {
    return BPReading(
      systolic: map['systolic'],
      diastolic: map['diastolic'],
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
    );
  }
}

class _AdditionalDetailsScreenState extends State<AdditionalDetailsScreen> {
  // Controllers
  final childrenCtrl = TextEditingController();
  final pastSurgeriesCtrl = TextEditingController();
  
  // Dropdown values
  String maritalStatus = "Unmarried";
  String pregnancyStatus = "No";
  String physicalActivity = "Sedentary";
  String dietType = "Vegetarian";
  
  // Family History
  String familyKidney = "No";
  String familyDiabetes = "No";
  String familyBloodPressure = "No";
  
  // Current BP Values (for new entry)
  final systolicBPCtrl = TextEditingController();
  final diastolicBPCtrl = TextEditingController();
  final bpNoteCtrl = TextEditingController();
  DateTime? bpDate;
  
  // Children dropdown
  String childrenStatus = "No Children";
  
  // Additional fields
  bool isFemale = false;
  bool isLoading = false;
  bool isSaving = false;
  
  // Pregnancy related
  String currentPregnancy = "Not Pregnant";
  final pregnancyWeeksCtrl = TextEditingController();
  
  // BP Readings list
  List<BPReading> bpReadings = [];
  
  // Color Scheme
  final Color primaryColor = const Color(0xFF18A3B6);
  final Color secondaryColor = const Color(0xFF32BACD);
  final Color accentColor = const Color(0xFF85CEDA);
  final Color lightColor = const Color(0xFFB2DEE6);
  final Color veryLightColor = const Color(0xFFDDF0F5);
  
  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }
  
  Future<void> _loadPatientData() async {
    setState(() => isLoading = true);
    try {
      var snap = await FirebaseFirestore.instance
          .collection("patients")
          .doc(widget.uid)
          .get();
      
      if (snap.exists) {
        var data = snap.data()!;
        
        // Check gender for pregnancy options
        isFemale = (data["gender"] == "Female");
        
        // Load additional details if they exist
        if (data.containsKey("additionalDetails")) {
          var details = data["additionalDetails"];
          
          // Helper function to safely get dropdown values
          String getPhysicalActivity(String? storedValue) {
            if (storedValue == null) return "Sedentary";
            
            // Map old values to new ones
            switch (storedValue) {
              case "Low":
              case "Sedentary (Little to no exercise)":
                return "Sedentary";
              case "Light (Light exercise 1-3 days/week)":
                return "Light";
              case "Moderate (Moderate exercise 3-5 days/week)":
                return "Moderate";
              case "Active (Hard exercise 6-7 days/week)":
                return "Active";
              case "Very Active (Very hard exercise & physical job)":
                return "Very Active";
              default:
                return storedValue;
            }
          }
          
          setState(() {
            maritalStatus = details["maritalStatus"] ?? "Unmarried";
            familyKidney = details["familyKidney"] ?? "No";
            familyDiabetes = details["familyDiabetes"] ?? "No";
            familyBloodPressure = details["familyBloodPressure"] ?? "No";
            pregnancyStatus = details["pregnancyStatus"] ?? "No";
            currentPregnancy = details["currentPregnancy"] ?? "Not Pregnant";
            pregnancyWeeksCtrl.text = details["pregnancyWeeks"]?.toString() ?? "";
            childrenStatus = details["childrenStatus"] ?? "No Children";
            childrenCtrl.text = details["childrenCount"]?.toString() ?? "";
            dietType = details["dietType"] ?? "Vegetarian";
            pastSurgeriesCtrl.text = details["pastSurgeries"] ?? "";
            physicalActivity = getPhysicalActivity(details["physicalActivity"]);
            
            // Load BP readings
            if (details["bpReadings"] != null) {
              List<dynamic> readingsData = details["bpReadings"];
              bpReadings = readingsData.map((data) => BPReading.fromMap(data)).toList();
              bpReadings.sort((a, b) => b.date.compareTo(a.date)); // Sort by latest first
            }
            
            // Load latest BP for quick entry
            if (bpReadings.isNotEmpty) {
              systolicBPCtrl.text = bpReadings.first.systolic.toString();
              diastolicBPCtrl.text = bpReadings.first.diastolic.toString();
              bpDate = bpReadings.first.date;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading patient data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: bpDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        bpDate = picked;
      });
    }
  }
  
  void _addBPReading() {
    final systolic = int.tryParse(systolicBPCtrl.text);
    final diastolic = int.tryParse(diastolicBPCtrl.text);
    
    if (systolic == null || diastolic == null) {
      _showErrorSnackBar('Please enter valid BP numbers');
      return;
    }
    
    if (systolic < 70 || systolic > 250) {
      _showErrorSnackBar('Systolic BP should be between 70-250');
      return;
    }
    
    if (diastolic < 40 || diastolic > 150) {
      _showErrorSnackBar('Diastolic BP should be between 40-150');
      return;
    }
    
    if (bpDate == null) {
      _showErrorSnackBar('Please select BP date');
      return;
    }
    
    final newReading = BPReading(
      systolic: systolic,
      diastolic: diastolic,
      date: bpDate!,
      note: bpNoteCtrl.text.isNotEmpty ? bpNoteCtrl.text : null,
    );
    
    setState(() {
      bpReadings.insert(0, newReading); // Add at beginning for latest first
    });
    
    // Clear form for next entry
    systolicBPCtrl.clear();
    diastolicBPCtrl.clear();
    bpNoteCtrl.clear();
    bpDate = null;
    
    _showSuccessSnackBar('BP reading added!');
  }
  
  void _removeBPReading(int index) {
    setState(() {
      bpReadings.removeAt(index);
    });
    _showSuccessSnackBar('BP reading removed');
  }
  
  Future<void> _saveDetails() async {
    if (isSaving) return;
    
    setState(() => isSaving = true);
    
    try {
      final updateData = {
        "additionalDetails": {
          "maritalStatus": maritalStatus,
          "familyKidney": familyKidney,
          "familyDiabetes": familyDiabetes,
          "familyBloodPressure": familyBloodPressure,
          "pregnancyStatus": pregnancyStatus,
          "currentPregnancy": currentPregnancy,
          
          "childrenStatus": childrenStatus,
          "childrenCount": childrenCtrl.text.isNotEmpty 
              ? int.tryParse(childrenCtrl.text) 
              : null,
          "dietType": dietType,
          "pastSurgeries": pastSurgeriesCtrl.text,
          "physicalActivity": physicalActivity,
          "bpReadings": bpReadings.map((reading) => reading.toMap()).toList(),
          "lastUpdated": FieldValue.serverTimestamp(),
        }
      };
      
      // Save to patients collection
      await FirebaseFirestore.instance
          .collection("patients")
          .doc(widget.uid)
          .set(updateData, SetOptions(merge: true));
      
      _showSuccessSnackBar("Additional details saved successfully!");
      
    } catch (e) {
      print('Error saving details: $e');
      _showErrorSnackBar('Error saving details: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: veryLightColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
    );
  }
  
  // Helper method to build dropdowns with proper width constraints
  Widget _buildDropdownFormField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool isExpanded = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: lightColor, width: 1),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: isExpanded,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          labelText: label,
          labelStyle: TextStyle(color: primaryColor),
        ),
        items: items,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Additional Patient Details"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Marital Status
                  _buildSectionHeader("Marital Status"),
                  const SizedBox(height: 8),
                  _buildDropdownFormField<String>(
                    label: "Select marital status",
                    value: maritalStatus,
                    items: const [
                      DropdownMenuItem(value: "Unmarried", child: Text("Unmarried",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Married", child: Text("Married",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Divorced", child: Text("Divorced",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Widowed", child: Text("Widowed",style: TextStyle(color: Colors.black))),
                    ],
                    onChanged: (val) => setState(() => maritalStatus = val!),
                  ),
                  const SizedBox(height: 20),
                  
                  // Family Background Section
                  _buildSectionHeader("Family Medical History"),
                  const SizedBox(height: 12),
                  
                  // Family Kidney History
                  const Text("Family History of Kidney Disease"),
                  _buildDropdownFormField<String>(
                    label: "Select option",
                    value: familyKidney,
                    items: const [
                      DropdownMenuItem(value: "No", child: Text("No",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Yes", child: Text("Yes",style: TextStyle(color: Colors.black))),
                     
                    ],
                    onChanged: (val) => setState(() => familyKidney = val!),
                  ),
                  const SizedBox(height: 12),
                  
                  // Family Diabetes History
                  const Text("Family History of Diabetes"),
                  _buildDropdownFormField<String>(
                    label: "Select option",
                    value: familyDiabetes,
                    items: const [
                      DropdownMenuItem(value: "No", child: Text("No",style: TextStyle(color: Colors.black),)),
                      DropdownMenuItem(value: "Yes", child: Text("Yes",style: TextStyle(color: Colors.black),)),
                      
                    ],
                    onChanged: (val) => setState(() => familyDiabetes = val!),
                  ),
                  const SizedBox(height: 12),
                  
                  // Family Blood Pressure History
                  const Text("Family History of High Blood Pressure"),
                  _buildDropdownFormField<String>(
                    label: "Select option",
                    value: familyBloodPressure,
                    items: const [
                      DropdownMenuItem(value: "No", child: Text("No",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Yes", child: Text("Yes",style: TextStyle(color: Colors.black))),
                      
                    ],
                    onChanged: (val) => setState(() => familyBloodPressure = val!),
                  ),
                  const SizedBox(height: 20),
                  
                  // Blood Pressure Section
                  _buildSectionHeader("Blood Pressure Readings"),
                  const SizedBox(height: 12),
                  
                  // Current BP Entry Form
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: accentColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            "Add New BP Reading",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: systolicBPCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    labelText: "Systolic",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(Icons.arrow_upward, color: primaryColor),
                                    suffixText: "mmHg",
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: diastolicBPCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    labelText: "Diastolic",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(Icons.arrow_downward, color: primaryColor),
                                    suffixText: "mmHg",
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // BP Note
                          TextFormField(
                            controller: bpNoteCtrl,
                            maxLines: 1,
                            decoration: InputDecoration(
                              labelText: "Note (optional)",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(Icons.note, color: primaryColor),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // BP Date Selection - FIXED WITH CONSTRAINED WIDTH
                          SizedBox(
                            width: double.infinity,
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: primaryColor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        bpDate != null 
                                            ? DateFormat('dd-MMM-yyyy').format(bpDate!)
                                            : "Select Date",
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          ElevatedButton.icon(
                            onPressed: _addBPReading,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: secondaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text("Add Reading"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Past BP Readings
                  if (bpReadings.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader("Past Blood Pressure Readings"),
                    const SizedBox(height: 12),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bpReadings.length,
                      itemBuilder: (context, index) {
                        final reading = bpReadings[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: lightColor, width: 1),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getBPCardColor(reading.systolic, reading.diastolic),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${reading.systolic}/${reading.diastolic}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Text(
                              DateFormat('dd MMM yyyy').format(reading.date),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: reading.note != null ? Text(reading.note!) : null,
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red.shade300),
                              onPressed: () => _removeBPReading(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Pregnancy Section (only for females)
                  if (isFemale) ...[
                    _buildSectionHeader("Pregnancy Information"),
                    const SizedBox(height: 12),
                    
                    const Text("Pregnancy Status"),
                    _buildDropdownFormField<String>(
                      label: "Select pregnancy status",
                      value: pregnancyStatus,
                      items: const [
                        DropdownMenuItem(value: "No", child: Text("No",style: TextStyle(color: Colors.black))),
                        DropdownMenuItem(value: "Yes", child: Text("Yes",style: TextStyle(color: Colors.black))),
                      ],
                      onChanged: (val) {
                        setState(() {
                          pregnancyStatus = val!;
                          if (val == "No") {
                            currentPregnancy = "Not Pregnant";
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    if (pregnancyStatus == "Yes") ...[
                      const Text("Current Pregnancy Status"),
                      _buildDropdownFormField<String>(
                        label: "Select trimester",
                        value: currentPregnancy,
                        items: const [
                          DropdownMenuItem(value: "Not Pregnant", child: Text("Not Pregnant",style: TextStyle(color: Colors.black))),
                          DropdownMenuItem(value: "First Trimester", child: Text("First Trimester",style: TextStyle(color: Colors.black))),
                          DropdownMenuItem(value: "Second Trimester", child: Text("Second Trimester",style: TextStyle(color: Colors.black))),
                          DropdownMenuItem(value: "Third Trimester", child: Text("Third Trimester",style: TextStyle(color: Colors.black))),
                          DropdownMenuItem(value: "Postpartum", child: Text("Postpartum",style: TextStyle(color: Colors.black))),
                        ],
                        onChanged: (val) => setState(() => currentPregnancy = val!),
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: childrenCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: "Number of Children",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.child_care, color: primaryColor),
                        ),
                      ),
                    ],
                    
                    
                    SizedBox(height: 20),
                    
                  ],
                  
                  // Diet Type
                  _buildSectionHeader("Diet Type"),
                  const SizedBox(height: 8),
                  _buildDropdownFormField<String>(
                    label: "Select diet type",
                    value: dietType,
                    items: const [
                      DropdownMenuItem(value: "Vegetarian", child: Text("Vegetarian",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Non-Vegetarian", child: Text("Non-Vegetarian",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Vegan", child: Text("Vegan",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Pescatarian", child: Text("Pescatarian",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Gluten-Free", child: Text("Gluten-Free",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Diabetic Diet", child: Text("Diabetic Diet",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Low Sodium", child: Text("Low Sodium",style: TextStyle(color: Colors.black))),
                      DropdownMenuItem(value: "Other", child: Text("Other",style: TextStyle(color: Colors.black))),
                    ],
                    onChanged: (val) => setState(() => dietType = val!),
                  ),
                  const SizedBox(height: 20),
                  
                  // Past Surgeries
                  _buildSectionHeader("Past Surgeries/Procedures"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: pastSurgeriesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "List any past surgeries or medical procedures",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.medical_services, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Physical Activity - FIXED WITH SHORTER LABELS
                  _buildSectionHeader("Physical Activity Level"),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: lightColor, width: 1),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: physicalActivity,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        labelText: "Select activity level",
                        labelStyle: TextStyle(color: primaryColor),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Sedentary",
                          child: Text("Sedentary", style: TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: "Light",
                          child: Text("Light", style: TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: "Moderate",
                          child: Text("Moderate", style: TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: "Active",
                          child: Text("Active", style: TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: "Very Active",
                          child: Text("Very Active", style: TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) => setState(() => physicalActivity = val!),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save),
                                SizedBox(width: 8),
                                Text("Save Additional Details"),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
  
  Color _getBPCardColor(int systolic, int diastolic) {
    if (systolic > 180 || diastolic > 120) {
      return Colors.red; // Hypertensive Crisis
    } else if (systolic >= 140 || diastolic >= 90) {
      return Colors.orange; // Hypertension Stage 2
    } else if (systolic >= 130 || diastolic >= 80) {
      return Colors.yellow.shade700; // Hypertension Stage 1
    } else if (systolic >= 120) {
      return Colors.blue; // Elevated
    } else {
      return Colors.green; // Normal
    }
  }
  
  @override
  void dispose() {
    childrenCtrl.dispose();
    pastSurgeriesCtrl.dispose();
    systolicBPCtrl.dispose();
    diastolicBPCtrl.dispose();
    bpNoteCtrl.dispose();
    pregnancyWeeksCtrl.dispose();
    super.dispose();
  }
}