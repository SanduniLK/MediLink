import 'package:flutter/material.dart';

class UploadPrescriptionScreen extends StatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  State<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends State<UploadPrescriptionScreen> {
  // These controllers would manage the text field input
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // This is a placeholder for the uploaded image. In a real app, this would
  // store the file path or a File object.
  bool _isImageUploaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text(
          'Upload Prescription',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prescription Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18A3B6),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField('Prescription Title', _titleController, Icons.medical_services_outlined),
            const SizedBox(height: 16),
            _buildTextField('Prescribing Doctor', _doctorController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField('Date', _dateController, Icons.calendar_today_outlined),
            const SizedBox(height: 20),
            _buildImageUploadSection(),
            const SizedBox(height: 40),
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hintText, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF32BACD)),
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return GestureDetector(
      onTap: () {
        // Placeholder for image selection logic
        setState(() {
          _isImageUploaded = !_isImageUploaded;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isImageUploaded ? 'Image selected!' : 'Upload image...'),
            backgroundColor: const Color(0xFF32BACD),
          ),
        );
      },
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFDDF0F5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFB2DEE6),
            width: 2,
          ),
        ),
        child: _isImageUploaded
            ? const Center(
                child: Text(
                  'Image Preview Here', // Replace with an actual Image.file or Image.network
                  style: TextStyle(color: Color(0xFF18A3B6)),
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 50, color: Color(0xFF18A3B6)),
                    SizedBox(height: 8),
                    Text(
                      'Tap to Upload Prescription Image',
                      style: TextStyle(color: Color(0xFF18A3B6)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Placeholder for uploading prescription logic
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prescription uploaded successfully!'),
              backgroundColor: Color(0xFF32BACD),
            ),
          );
          Navigator.pop(context); // Go back to the previous screen
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF18A3B6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        child: const Text(
          'Upload',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}