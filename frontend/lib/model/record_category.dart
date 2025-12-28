// lib/model/record_category.dart
import 'package:flutter/material.dart';

enum RecordCategory {
  labResults('Lab Results', Icons.assignment),
  prescriptions('Prescriptions', Icons.medication),
 
 
  other('Other', Icons.folder);

  final String displayName;
  final IconData icon;

  const RecordCategory(this.displayName, this.icon);

  static RecordCategory fromString(String value) {
    return RecordCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecordCategory.other,
    );
  }
}