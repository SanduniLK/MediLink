// lib/model/test_report.dart
import 'dart:convert';

class TestResult {
  final String parameter;
  final double value;
  final String unit;
  final String level; // high, normal, low
  final String normalRange;
  final String? note;

  TestResult({
    required this.parameter,
    required this.value,
    required this.unit,
    required this.level,
    required this.normalRange,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'parameter': parameter,
      'value': value,
      'unit': unit,
      'level': level,
      'normalRange': normalRange,
      'note': note,
    };
  }

  factory TestResult.fromMap(Map<String, dynamic> map) {
    return TestResult(
      parameter: map['parameter'] ?? '',
      value: (map['value'] is int) ? (map['value'] as int).toDouble() : (map['value'] as num).toDouble(),
      unit: map['unit'] ?? '',
      level: map['level'] ?? '',
      normalRange: map['normalRange'] ?? '',
      note: map['note'],
    );
  }

  String toJson() => json.encode(toMap());
  factory TestResult.fromJson(String source) => TestResult.fromMap(json.decode(source));
}

class TestReportAnalysis {
  final String testType;
  final String fileName;
  final DateTime analysisDate;
  final List<TestResult> results;
  final List<String> abnormalities;
  final String? notes;

  TestReportAnalysis({
    required this.testType,
    required this.fileName,
    required this.analysisDate,
    List<TestResult>? results,
    List<String>? abnormalities,
    this.notes,
  }) : results = results ?? [],
       abnormalities = abnormalities ?? [];

  Map<String, dynamic> toMap() {
    return {
      'testType': testType,
      'fileName': fileName,
      'analysisDate': analysisDate.toIso8601String(),
      'results': results.map((x) => x.toMap()).toList(),
      'abnormalities': abnormalities,
      'notes': notes,
    };
  }

  factory TestReportAnalysis.fromMap(Map<String, dynamic> map) {
    return TestReportAnalysis(
      testType: map['testType'] ?? '',
      fileName: map['fileName'] ?? '',
      analysisDate: DateTime.parse(map['analysisDate']),
      results: List<TestResult>.from(map['results']?.map((x) => TestResult.fromMap(x)) ?? []),
      abnormalities: List<String>.from(map['abnormalities'] ?? []),
      notes: map['notes'],
    );
  }

  String toJson() => json.encode(toMap());
  factory TestReportAnalysis.fromJson(String source) => TestReportAnalysis.fromMap(json.decode(source));
}