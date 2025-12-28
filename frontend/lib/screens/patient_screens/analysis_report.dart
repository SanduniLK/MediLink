import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

// Models for different test types
class TestParameter {
  final String name;
  final dynamic value;
  final dynamic refLow;
  final dynamic refHigh;
  final String unit;
  final String status; // normal, high, low
  final String level; // normal, warning, critical
  
  TestParameter({
    required this.name,
    required this.value,
    required this.refLow,
    required this.refHigh,
    required this.unit,
    required this.status,
    required this.level,
  });
}

class MedicalTestReport {
  final String testType;
  final DateTime testDate;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final String labName;
  final String referenceNo;
  final Map<String, dynamic> rawData;
  final List<TestParameter> parameters;
  final Map<String, dynamic> extractedInfo;
  
  MedicalTestReport({
    required this.testType,
    required this.testDate,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.labName,
    required this.referenceNo,
    required this.rawData,
    required this.parameters,
    required this.extractedInfo,
  });
}

// Chart Data Models
class ChartData {
  final String parameter;
  final double value;
  final double refLow;
  final double refHigh;
  final Color color;
  final String status;
  
  ChartData({
    required this.parameter,
    required this.value,
    required this.refLow,
    required this.refHigh,
    required this.color,
    required this.status,
  });
}

class CategoryChartData {
  final String category;
  final double value;
  final Color color;
  
  CategoryChartData({
    required this.category,
    required this.value,
    required this.color,
  });
}

// Main Analysis System
class MedicalReportAnalyzer {
  static Map<String, dynamic> analyzeReport(String text) {
    final testType = _detectTestType(text);
    
    switch (testType) {
      case 'CBC':
        return _analyzeCBC(text);
      case 'Lipid Profile':
        return _analyzeLipidProfile(text);
      
      case 'Thyroid Profile':
        return _analyzeThyroid(text);
      case 'Blood Sugar':
        return _analyzeBloodSugar(text);
      case 'Urine Analysis':
        return _analyzeUrine(text);
      case 'HbA1c':
        return _analyzeHbA1c(text);
      default:
        return _analyzeGeneric(text);
    }
  }
  
  static String _detectTestType(String text) {
    final textLower = text.toLowerCase();
    
    if (textLower.contains('complete blood count') || 
        textLower.contains('cbc') ||
        textLower.contains('haemogram')) {
      return 'CBC';
    } else if (textLower.contains('lipid') || 
               textLower.contains('cholesterol') ||
               textLower.contains('hdl') || 
               textLower.contains('ldl')) {
      return 'Lipid Profile';
    } else if (textLower.contains('liver') || 
               textLower.contains('sgpt') || 
               textLower.contains('sgot') ||
               textLower.contains('alt') || 
               textLower.contains('ast') ||
               textLower.contains('alkaline')) {
      return 'Liver Function Test';
    } else if (textLower.contains('kidney') || 
               textLower.contains('creatinine') ||
               textLower.contains('urea') || 
               textLower.contains('bun')) {
      return 'Kidney Function Test';
    } else if (textLower.contains('thyroid') || 
               textLower.contains('tsh') ||
               textLower.contains('t3') || 
               textLower.contains('t4')) {
      return 'Thyroid Profile';
    } else if (textLower.contains('blood sugar') || 
               textLower.contains('glucose') ||
               textLower.contains('fasting sugar')) {
      return 'Blood Sugar';
    } else if (textLower.contains('urine') || 
               textLower.contains('urinalysis')) {
      return 'Urine Analysis';
    } else if (textLower.contains('hba1c') || 
               textLower.contains('glycated')) {
      return 'HbA1c';
    }
    
    return 'Generic';
  }
  
  static Map<String, dynamic> _analyzeCBC(String text) {
    final parameters = <TestParameter>[];
    final extractedInfo = <String, dynamic>{};
    
    // Extract patient info
    final ageMatch = RegExp(r'AGE[:\s]+(\d+)\s*Y/E?').firstMatch(text);
    final genderMatch = RegExp(r'(Miss\.|Mr\.|Mrs\.|Ms\.)\s+([A-Z\s]+)').firstMatch(text);
    final dateMatch = RegExp(r'(\d{2}/\d{2}/\d{4})').allMatches(text);
    
    // Extract parameters
    _extractParameter(text, r'WHITE CELL COUNT[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'White Blood Cells (WBC)', '10^9/L', parameters);
    _extractParameter(text, r'NEUTROPHILS[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Neutrophils', '%', parameters);
    _extractParameter(text, r'LYMPHOCYTES[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Lymphocytes', '%', parameters);
    _extractParameter(text, r'MONOCYTES[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Monocytes', '%', parameters);
    _extractParameter(text, r'EOSINOPHILS[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Eosinophils', '%', parameters);
    _extractParameter(text, r'BASOPHILS[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Basophils', '%', parameters);
    _extractParameter(text, r'HAEMOGLOBIN[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Hemoglobin', 'g/dL', parameters);
    _extractParameter(text, r'RED BLOOD CELLS[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Red Blood Cells (RBC)', '10^12/L', parameters);
    _extractParameter(text, r'MEAN CELL VOLUME[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Mean Cell Volume (MCV)', 'fL', parameters);
    _extractParameter(text, r'HAEMATOCRIT[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Hematocrit', '%', parameters);
    _extractParameter(text, r'MEAN CELL HAEMOGLOBIN[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Mean Cell Hemoglobin (MCH)', 'pg', parameters);
    _extractParameter(text, r'M\.C\.H\. CONCENTRATION[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'MCH Concentration (MCHC)', 'g/dL', parameters);
    _extractParameter(text, r'RED CELLS DISTRIBUTION WIDTH[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Red Cell Distribution Width (RDW)', '%', parameters);
    _extractParameter(text, r'PLATELET COUNT[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Platelets', '10^9/L', parameters);
    
    // Analyze patterns
    final abnormalParams = parameters.where((p) => p.status != 'normal').toList();
    final criticalParams = parameters.where((p) => p.level == 'critical').toList();
    
    // Determine possible conditions
    final possibleConditions = <String>[];
    final hemoglobin = parameters.firstWhereOrNull((p) => p.name.contains('Hemoglobin'));
    final mcv = parameters.firstWhereOrNull((p) => p.name.contains('MCV'));
    final mch = parameters.firstWhereOrNull((p) => p.name.contains('MCH'));
    
    if (hemoglobin != null && double.tryParse(hemoglobin.value.toString()) != null) {
      final hbValue = double.parse(hemoglobin.value.toString());
      if (hbValue < 11) {
        possibleConditions.add('Anemia');
        if (mcv != null && mch != null) {
          final mcvValue = double.tryParse(mcv.value.toString());
          final mchValue = double.tryParse(mch.value.toString());
          if (mcvValue != null && mcvValue < 80 && mchValue != null && mchValue < 27) {
            possibleConditions.add('Iron Deficiency Anemia');
          }
        }
      }
    }
    
    return {
      'testType': 'CBC',
      'parameters': parameters,
      'analysis': {
        'abnormalCount': abnormalParams.length,
        'criticalCount': criticalParams.length,
        'possibleConditions': possibleConditions,
        'summary': _generateCBSSummary(parameters),
        'charts': _generateCBCCharts(parameters),
      },
      'extractedInfo': extractedInfo,
    };
  }
  
  static Map<String, dynamic> _analyzeLipidProfile(String text) {
    final parameters = <TestParameter>[];
    
    // Extract lipid profile parameters
    _extractParameter(text, r'TOTAL CHOLESTEROL[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Total Cholesterol', 'mg/dL', parameters);
    _extractParameter(text, r'HDL[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'HDL Cholesterol', 'mg/dL', parameters);
    _extractParameter(text, r'LDL[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'LDL Cholesterol', 'mg/dL', parameters);
    _extractParameter(text, r'TRIGLYCERIDES[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Triglycerides', 'mg/dL', parameters);
    _extractParameter(text, r'VLDL[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'VLDL Cholesterol', 'mg/dL', parameters);
    
    // Calculate ratios
    final totalChol = parameters.firstWhereOrNull((p) => p.name.contains('Total Cholesterol'));
    final hdl = parameters.firstWhereOrNull((p) => p.name.contains('HDL'));
    
    if (totalChol != null && hdl != null) {
      try {
        final total = double.parse(totalChol.value.toString());
        final hdlVal = double.parse(hdl.value.toString());
        final ratio = hdlVal > 0 ? total / hdlVal : 0;
        
        parameters.add(TestParameter(
          name: 'Cholesterol/HDL Ratio',
          value: ratio.toStringAsFixed(2),
          refLow: '0',
          refHigh: '5',
          unit: 'ratio',
          status: ratio > 5 ? 'high' : 'normal',
          level: ratio > 5 ? 'warning' : 'normal',
        ));
      } catch (e) {
        // Ignore calculation errors
      }
    }
    
    // Risk assessment
    final riskLevel = _assessLipidRisk(parameters);
    
    return {
      'testType': 'Lipid Profile',
      'parameters': parameters,
      'analysis': {
        'riskLevel': riskLevel,
        'cardiovascularRisk': _getCardiovascularRisk(parameters),
        'recommendations': _getLipidRecommendations(parameters),
        'charts': _generateLipidCharts(parameters),
      },
    };
  }
  
  static Map<String, dynamic> _analyzeLFT(String text) {
    final parameters = <TestParameter>[];
    
    _extractParameter(text, r'SGPT[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'SGPT (ALT)', 'U/L', parameters);
    _extractParameter(text, r'SGOT[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'SGOT (AST)', 'U/L', parameters);
    _extractParameter(text, r'ALKALINE PHOSPHATASE[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Alkaline Phosphatase', 'U/L', parameters);
    _extractParameter(text, r'TOTAL BILIRUBIN[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Total Bilirubin', 'mg/dL', parameters);
    _extractParameter(text, r'DIRECT BILIRUBIN[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Direct Bilirubin', 'mg/dL', parameters);
    _extractParameter(text, r'ALBUMIN[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Albumin', 'g/dL', parameters);
    _extractParameter(text, r'TOTAL PROTEIN[^0-9]*([\d.]+)[^0-9]*([\d.]+)[^0-9]*([\d.]+)', 
        'Total Protein', 'g/dL', parameters);
    
    return {
      'testType': 'Liver Function Test',
      'parameters': parameters,
      'analysis': {
        'liverStatus': _assessLiverFunction(parameters),
        'possibleConditions': _getLiverConditions(parameters),
        'charts': _generateLFTCharts(parameters),
      },
    };
  }
  

  // Helper methods for parameter extraction
  static void _extractParameter(
    String text, 
    String pattern, 
    String name, 
    String unit,
    List<TestParameter> parameters,
  ) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
    if (match != null) {
      try {
        final value = double.tryParse(match.group(1)?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '');
        final refLow = double.tryParse(match.group(2)?.replaceAll(RegExp(r'[^0-9.-]'), '') ?? '');
        final refHigh = double.tryParse(match.group(3)?.replaceAll(RegExp(r'[^0-9.-]'), '') ?? '');
        
        if (value != null && refLow != null && refHigh != null) {
          final status = value < refLow ? 'low' : (value > refHigh ? 'high' : 'normal');
          final level = (value < refLow * 0.7 || value > refHigh * 1.3) ? 'critical' : 
                       (status != 'normal') ? 'warning' : 'normal';
          
          parameters.add(TestParameter(
            name: name,
            value: value,
            refLow: refLow,
            refHigh: refHigh,
            unit: unit,
            status: status,
            level: level,
          ));
        }
      } catch (e) {
        // Skip parameter if parsing fails
      }
    }
  }
  
  // Chart generation methods
  static Map<String, Widget> _generateCBCCharts(List<TestParameter> parameters) {
    final charts = <String, Widget>{};
    
    // 1. Blood Cell Distribution Chart
    final cellTypes = ['Neutrophils', 'Lymphocytes', 'Monocytes', 'Eosinophils', 'Basophils'];
    final cellData = <CategoryChartData>[];
    
    for (final type in cellTypes) {
      final param = parameters.firstWhereOrNull((p) => p.name.contains(type));
      if (param != null) {
        cellData.add(CategoryChartData(
          category: type,
          value: double.parse(param.value.toString()),
          color: _getParameterColor(param.status),
        ));
      }
    }
    
    if (cellData.isNotEmpty) {
      charts['cellDistribution'] = SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        series: <CartesianSeries>[
          BarSeries<CategoryChartData, String>(
            dataSource: cellData,
            xValueMapper: (data, _) => data.category,
            yValueMapper: (data, _) => data.value,
            pointColorMapper: (data, _) => data.color,
            dataLabelSettings: DataLabelSettings(isVisible: true),
          ),
        ],
      );
    }
    
    // 2. RBC Parameters Radar Chart
    final rbcParams = ['Hemoglobin', 'RBC Count', 'MCV', 'MCH', 'MCHC'];
    final rbcData = <ChartData>[];
    
    for (final paramName in rbcParams) {
      final param = parameters.firstWhereOrNull((p) => p.name.contains(paramName));
      if (param != null) {
        rbcData.add(ChartData(
          parameter: paramName,
          value: double.parse(param.value.toString()),
          refLow: double.parse(param.refLow.toString()),
          refHigh: double.parse(param.refHigh.toString()),
          color: _getParameterColor(param.status),
          status: param.status,
        ));
      }
    }
    
    if (rbcData.isNotEmpty) {
      charts['rbcAnalysis'] = SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        series: <CartesianSeries>[
          LineSeries<ChartData, String>(
            dataSource: rbcData,
            xValueMapper: (data, _) => data.parameter,
            yValueMapper: (data, _) => data.value,
            markerSettings: MarkerSettings(isVisible: true),
          ),
        ],
      );
    }
    
    return charts;
  }
  
  static Map<String, Widget> _generateLipidCharts(List<TestParameter> parameters) {
    final charts = <String, Widget>{};
    
    final lipidParams = ['Total Cholesterol', 'HDL', 'LDL', 'Triglycerides'];
    final lipidData = <ChartData>[];
    
    for (final paramName in lipidParams) {
      final param = parameters.firstWhereOrNull((p) => p.name.contains(paramName));
      if (param != null) {
        lipidData.add(ChartData(
          parameter: paramName,
          value: double.parse(param.value.toString()),
          refLow: double.parse(param.refLow.toString()),
          refHigh: double.parse(param.refHigh.toString()),
          color: _getParameterColor(param.status),
          status: param.status,
        ));
      }
    }
    
    if (lipidData.isNotEmpty) {
      charts['lipidProfile'] = SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: 'mg/dL'),
        ),
        series: <CartesianSeries>[
          ColumnSeries<ChartData, String>(
            dataSource: lipidData,
            xValueMapper: (data, _) => data.parameter,
            yValueMapper: (data, _) => data.value,
            pointColorMapper: (data, _) => data.color,
            dataLabelSettings: DataLabelSettings(isVisible: true),
          ),
        ],
      );
      
      // Pie chart for cholesterol composition
      final compositionData = <CategoryChartData>[];
      final ldl = parameters.firstWhereOrNull((p) => p.name.contains('LDL'));
      final hdl = parameters.firstWhereOrNull((p) => p.name.contains('HDL'));
      final trig = parameters.firstWhereOrNull((p) => p.name.contains('Triglycerides'));
      
      if (ldl != null && hdl != null && trig != null) {
        compositionData.addAll([
          CategoryChartData(category: 'LDL', value: double.parse(ldl.value.toString()), color: Colors.orange),
          CategoryChartData(category: 'HDL', value: double.parse(hdl.value.toString()), color: Colors.green),
          CategoryChartData(category: 'Triglycerides', value: double.parse(trig.value.toString()), color: Colors.blue),
        ]);
        
        charts['cholesterolComposition'] = SfCircularChart(
          series: <CircularSeries>[
            PieSeries<CategoryChartData, String>(
              dataSource: compositionData,
              xValueMapper: (data, _) => data.category,
              yValueMapper: (data, _) => data.value,
              pointColorMapper: (data, _) => data.color,
              dataLabelSettings: DataLabelSettings(isVisible: true),
            ),
          ],
        );
      }
    }
    
    return charts;
  }
  
  static Map<String, Widget> _generateLFTCharts(List<TestParameter> parameters) {
    final charts = <String, Widget>{};
    
    final liverEnzymes = ['SGPT (ALT)', 'SGOT (AST)', 'Alkaline Phosphatase'];
    final enzymeData = <ChartData>[];
    
    for (final enzyme in liverEnzymes) {
      final param = parameters.firstWhereOrNull((p) => p.name.contains(enzyme));
      if (param != null) {
        enzymeData.add(ChartData(
          parameter: enzyme,
          value: double.parse(param.value.toString()),
          refLow: double.parse(param.refLow.toString()),
          refHigh: double.parse(param.refHigh.toString()),
          color: _getParameterColor(param.status),
          status: param.status,
        ));
      }
    }
    
    if (enzymeData.isNotEmpty) {
      charts['liverEnzymes'] = SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        primaryYAxis: NumericAxis(title: AxisTitle(text: 'U/L')),
        series: <CartesianSeries>[
          ColumnSeries<ChartData, String>(
            dataSource: enzymeData,
            xValueMapper: (data, _) => data.parameter,
            yValueMapper: (data, _) => data.value,
            pointColorMapper: (data, _) => data.color,
            dataLabelSettings: DataLabelSettings(isVisible: true),
          ),
        ],
      );
    }
    
    return charts;
  }
  
  static Map<String, Widget> _generateKFTCharts(List<TestParameter> parameters) {
    final charts = <String, Widget>{};
    
    final kidneyParams = ['Creatinine', 'Urea', 'Uric Acid'];
    final kidneyData = <ChartData>[];
    
    for (final paramName in kidneyParams) {
      final param = parameters.firstWhereOrNull((p) => p.name.contains(paramName));
      if (param != null) {
        kidneyData.add(ChartData(
          parameter: paramName,
          value: double.parse(param.value.toString()),
          refLow: double.parse(param.refLow.toString()),
          refHigh: double.parse(param.refHigh.toString()),
          color: _getParameterColor(param.status),
          status: param.status,
        ));
      }
    }
    
    if (kidneyData.isNotEmpty) {
      charts['kidneyFunction'] = SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        series: <CartesianSeries>[
          LineSeries<ChartData, String>(
            dataSource: kidneyData,
            xValueMapper: (data, _) => data.parameter,
            yValueMapper: (data, _) => data.value,
            markerSettings: MarkerSettings(isVisible: true),
            color: Colors.blue,
          ),
        ],
      );
    }
    
    return charts;
  }
  
  // Helper methods
  static Color _getParameterColor(String status) {
    switch (status) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
  
  static String _generateCBSSummary(List<TestParameter> parameters) {
    final abnormal = parameters.where((p) => p.status != 'normal').length;
    if (abnormal == 0) return 'All CBC parameters within normal range.';
    
    final critical = parameters.where((p) => p.level == 'critical');
    if (critical.isNotEmpty) {
      return '${critical.length} critical abnormalities found. Immediate attention required.';
    }
    
    return '$abnormal parameter(s) outside normal range. Further evaluation recommended.';
  }
  
  static String _assessLipidRisk(List<TestParameter> parameters) {
    final ldl = parameters.firstWhereOrNull((p) => p.name.contains('LDL'));
    final hdl = parameters.firstWhereOrNull((p) => p.name.contains('HDL'));
    final trig = parameters.firstWhereOrNull((p) => p.name.contains('Triglycerides'));
    
    int riskScore = 0;
    
    if (ldl != null && ldl.status == 'high') riskScore += 2;
    if (hdl != null && hdl.status == 'low') riskScore += 2;
    if (trig != null && trig.status == 'high') riskScore += 1;
    
    if (riskScore >= 3) return 'High Risk';
    if (riskScore >= 1) return 'Moderate Risk';
    return 'Low Risk';
  }
  
  static List<String> _getCardiovascularRisk(List<TestParameter> parameters) {
    final risks = <String>[];
    final ldl = parameters.firstWhereOrNull((p) => p.name.contains('LDL'));
    final hdl = parameters.firstWhereOrNull((p) => p.name.contains('HDL'));
    
    if (ldl != null && ldl.status == 'high') {
      risks.add('Elevated LDL increases cardiovascular risk');
    }
    
    if (hdl != null && hdl.status == 'low') {
      risks.add('Low HDL is a risk factor for heart disease');
    }
    
    return risks;
  }
  
  static List<String> _getLipidRecommendations(List<TestParameter> parameters) {
    final recommendations = <String>[];
    final ldl = parameters.firstWhereOrNull((p) => p.name.contains('LDL'));
    final trig = parameters.firstWhereOrNull((p) => p.name.contains('Triglycerides'));
    
    if (ldl != null && ldl.status == 'high') {
      recommendations.add('Reduce saturated fat intake');
      recommendations.add('Increase physical activity');
      recommendations.add('Consider cholesterol-lowering medication');
    }
    
    if (trig != null && trig.status == 'high') {
      recommendations.add('Reduce sugar and refined carbohydrate intake');
      recommendations.add('Limit alcohol consumption');
      recommendations.add('Increase omega-3 fatty acids');
    }
    
    return recommendations;
  }
  
  static String _assessLiverFunction(List<TestParameter> parameters) {
    final alt = parameters.firstWhereOrNull((p) => p.name.contains('ALT'));
    final ast = parameters.firstWhereOrNull((p) => p.name.contains('AST'));
    final alp = parameters.firstWhereOrNull((p) => p.name.contains('Alkaline'));
    
    if (alt != null && alt.status == 'high' && ast != null && ast.status == 'high') {
      return 'Elevated liver enzymes suggest liver inflammation';
    }
    
    if (alp != null && alp.status == 'high') {
      return 'Possible bile duct obstruction or bone disease';
    }
    
    return 'Liver function appears normal';
  }
  
  static List<String> _getLiverConditions(List<TestParameter> parameters) {
    final conditions = <String>[];
    final alt = parameters.firstWhereOrNull((p) => p.name.contains('ALT'));
    final ast = parameters.firstWhereOrNull((p) => p.name.contains('AST'));
    final bilirubin = parameters.firstWhereOrNull((p) => p.name.contains('Bilirubin'));
    
    if (alt != null && alt.status == 'high' && ast != null && ast.status == 'high') {
      conditions.add('Hepatitis');
      conditions.add('Fatty liver disease');
    }
    
    if (bilirubin != null && bilirubin.status == 'high') {
      conditions.add('Jaundice');
      conditions.add('Liver dysfunction');
    }
    
    return conditions;
  }
  
  static String _assessKidneyFunction(List<TestParameter> parameters) {
    final creatinine = parameters.firstWhereOrNull((p) => p.name.contains('Creatinine'));
    final urea = parameters.firstWhereOrNull((p) => p.name.contains('Urea'));
    final egfr = parameters.firstWhereOrNull((p) => p.name.contains('GFR'));
    
    if (creatinine != null && creatinine.status == 'high') {
      return 'Reduced kidney function';
    }
    
    if (egfr != null && egfr.status == 'low') {
      return 'Impaired kidney filtration';
    }
    
    if (urea != null && urea.status == 'high') {
      return 'Possible dehydration or kidney issues';
    }
    
    return 'Kidney function appears normal';
  }
  
  static String _getKidneyStage(List<TestParameter> parameters) {
    final egfr = parameters.firstWhereOrNull((p) => p.name.contains('GFR'));
    if (egfr != null) {
      try {
        final gfr = double.parse(egfr.value.toString());
        if (gfr >= 90) return 'Stage 1: Normal';
        if (gfr >= 60) return 'Stage 2: Mildly reduced';
        if (gfr >= 30) return 'Stage 3: Moderately reduced';
        if (gfr >= 15) return 'Stage 4: Severely reduced';
        return 'Stage 5: Kidney failure';
      } catch (e) {
        return 'Unknown stage';
      }
    }
    return 'Stage not determined';
  }
  
  // Other analysis methods for different test types...
  static Map<String, dynamic> _analyzeThyroid(String text) => {'testType': 'Thyroid'};
  static Map<String, dynamic> _analyzeBloodSugar(String text) => {'testType': 'Blood Sugar'};
  static Map<String, dynamic> _analyzeUrine(String text) => {'testType': 'Urine Analysis'};
  static Map<String, dynamic> _analyzeHbA1c(String text) => {'testType': 'HbA1c'};
  static Map<String, dynamic> _analyzeGeneric(String text) => {'testType': 'Generic'};
}

// Main Widget
class MedicalReportDashboard extends StatefulWidget {
  final String reportText;
  
  const MedicalReportDashboard({Key? key, required this.reportText}) : super(key: key);
  
  @override
  _MedicalReportDashboardState createState() => _MedicalReportDashboardState();
}

class _MedicalReportDashboardState extends State<MedicalReportDashboard> {
  late Map<String, dynamic> analysis;
  
  @override
  void initState() {
    super.initState();
    analysis = MedicalReportAnalyzer.analyzeReport(widget.reportText);
  }
  
  @override
  Widget build(BuildContext context) {
    final testType = analysis['testType'];
    final parameters = analysis['parameters'] as List<TestParameter>;
    final charts = analysis['analysis']['charts'] as Map<String, Widget>;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('$testType Analysis'),
        backgroundColor: Color(0xFF18A3B6),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test Summary Card
            _buildSummaryCard(analysis),
            SizedBox(height: 20),
            
            // Charts Section
            if (charts.isNotEmpty) ...[
              Text(
                '📈 Visual Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ...charts.entries.map((entry) {
                return Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _getChartTitle(entry.key),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Container(
                            height: 250,
                            child: entry.value,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ],
            
            // Parameters Table
            Text(
              '📊 Test Parameters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...parameters.map((param) => _buildParameterCard(param)).toList(),
            
            // Analysis Section
            if (analysis['analysis']['possibleConditions'] != null) ...[
              SizedBox(height: 20),
              _buildPossibleConditions(analysis['analysis']['possibleConditions'] as List<String>),
            ],
            
            if (analysis['analysis']['recommendations'] != null) ...[
              SizedBox(height: 20),
              _buildRecommendations(analysis['analysis']['recommendations'] as List<String>),
            ],
            
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryCard(Map<String, dynamic> analysis) {
    final testType = analysis['testType'];
    final analysisData = analysis['analysis'];
    final abnormalCount = analysisData['abnormalCount'] ?? 0;
    final criticalCount = analysisData['criticalCount'] ?? 0;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (criticalCount > 0) {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'Critical';
    } else if (abnormalCount > 0) {
      statusColor = Colors.orange;
      statusIcon = Icons.info;
      statusText = 'Abnormal';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Normal';
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testType,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        analysisData['summary'] ?? 'Analysis complete',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Parameters', '${analysis['parameters']?.length ?? 0}', Colors.blue),
                _buildStatItem('Abnormal', '$abnormalCount', Colors.orange),
                _buildStatItem('Critical', '$criticalCount', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
  
  Widget _buildParameterCard(TestParameter param) {
    Color statusColor = _getStatusColor(param.status);
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              param.status == 'high' ? Icons.arrow_upward : 
              param.status == 'low' ? Icons.arrow_downward : Icons.check,
              color: statusColor,
              size: 20,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                param.name,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                param.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Value: ',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '${param.value} ${param.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              'Reference: ${param.refLow} - ${param.refHigh} ${param.unit}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPossibleConditions(List<String> conditions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🩺 Possible Conditions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        SizedBox(height: 8),
        ...conditions.map((condition) {
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: Colors.blue[50],
            child: ListTile(
              leading: Icon(Icons.medical_services, color: Colors.blue, size: 20),
              title: Text(condition),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildRecommendations(List<String> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💡 Recommendations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        SizedBox(height: 8),
        ...recommendations.map((rec) {
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: Colors.green[50],
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green, size: 20),
              title: Text(rec),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
  
  String _getChartTitle(String key) {
    switch (key) {
      case 'cellDistribution':
        return 'Blood Cell Distribution';
      case 'rbcAnalysis':
        return 'RBC Parameters Analysis';
      case 'lipidProfile':
        return 'Lipid Profile Overview';
      case 'cholesterolComposition':
        return 'Cholesterol Composition';
      case 'liverEnzymes':
        return 'Liver Enzymes Comparison';
      case 'kidneyFunction':
        return 'Kidney Function Parameters';
      default:
        return 'Analysis Chart';
    }
  }
}

// Integration with your existing MedicalRecordsScreen
class EnhancedMedicalRecordsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medical Reports with Charts'),
      ),
      body: ListView(
        children: [
          // Example usage
          ListTile(
            title: Text('CBC Report Analysis'),
            subtitle: Text('Complete Blood Count with Charts'),
            onTap: () {
              final sampleReport = """...""" ; // Your report text here
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MedicalReportDashboard(reportText: sampleReport),
                ),
              );
            },
          ),
          // Add more report types...
        ],
      ),
    );
  }
}