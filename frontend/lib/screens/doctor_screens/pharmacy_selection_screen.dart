// screens/doctor_screens/pharmacy_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PharmacySelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> pharmacies;

  const PharmacySelectionScreen({super.key, required this.pharmacies});

  @override
  State<PharmacySelectionScreen> createState() => _PharmacySelectionScreenState();
}

class _PharmacySelectionScreenState extends State<PharmacySelectionScreen> {
  final Set<String> _selectedPharmacyIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text('Select Pharmacies'),
        backgroundColor: const Color(0xFF18A3B6),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select pharmacies to share prescription with',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: widget.pharmacies.isEmpty
                ? const Center(
                    child: Text(
                      'No registered pharmacies available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.pharmacies.length,
                    itemBuilder: (context, index) {
                      final pharmacy = widget.pharmacies[index];
                      final isSelected = _selectedPharmacyIds.contains(pharmacy['id']);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF18A3B6).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_pharmacy,
                              color: const Color(0xFF18A3B6),
                            ),
                          ),
                          title: Text(
                            pharmacy['name'] ?? 'Unknown Pharmacy',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pharmacy['address'] ?? ''),
                              Text(pharmacy['phone'] ?? ''),
                            ],
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedPharmacyIds.add(pharmacy['id']);
                                } else {
                                  _selectedPharmacyIds.remove(pharmacy['id']);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPharmacyIds.remove(pharmacy['id']);
                              } else {
                                _selectedPharmacyIds.add(pharmacy['id']);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selectedPharmacyIds.isNotEmpty
                  ? () => Navigator.pop(context, _selectedPharmacyIds.toList())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A3B6),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Share with Selected Pharmacies',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}