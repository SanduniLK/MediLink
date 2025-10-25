import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/model/doctor.dart';
import 'package:http/http.dart' as http;


class NetworkConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5001";
    } else {
      return "http://10.0.2.2:5001";
    }
  }
  
  static String get doctorsDashboard => "$baseUrl/api/doctors/dashboard";
}

Future<List<Doctor>> fetchDoctors() async {
  // FORCE Android emulator URL
  String baseUrl = "http://10.0.2.2:5001";
  String apiUrl = "$baseUrl/api/doctors/dashboard";
  
  print('🚨 FORCE TESTING WITH: $apiUrl');
  
  try {
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
    );
    
    print('📊 Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final doctors = parseDoctors(response.body);
      print('✅ Successfully loaded ${doctors.length} doctors');
      return doctors;
    } else {
      throw Exception('Failed to load doctors: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ API Error: $e');
    throw Exception('Failed to load data: $e');
  }
}
List<Doctor> parseDoctors(String responseBody) {
  try {
    final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
    return parsed.map<Doctor>((json) {
      // Use fromMap instead of fromJson
      String id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
      return Doctor.fromMap(id, json);
    }).toList();
  } catch (e) {
    print('❌ Error parsing doctors: $e');
    return [];
  }
}