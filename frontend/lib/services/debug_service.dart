import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/network_config.dart';

class DebugService {
  static Future<void> debugBackendConnection() async {
    final baseUrl = NetworkConfig.baseUrl;
    print('🐛 STARTING DEBUG SEQUENCE');
    
    // Test 1: Basic connectivity
    try {
      print('1️⃣ Testing basic connectivity...');
      final response = await http.get(Uri.parse('$baseUrl/api/test'))
        .timeout(Duration(seconds: 5));
      print('   ✅ Basic connectivity: OK (${response.statusCode})');
      print('   📦 Response: ${response.body}');
    } catch (e) {
      print('   ❌ Basic connectivity failed: $e');
      return;
    }
    
    // Test 2: Database status
    try {
      print('2️⃣ Testing database connection...');
      final response = await http.get(Uri.parse('$baseUrl/api/db-status'))
        .timeout(Duration(seconds: 5));
      print('   ✅ Database status: OK (${response.statusCode})');
      print('   📦 Response: ${response.body}');
    } catch (e) {
      print('   ❌ Database status check failed: $e');
    }
    
    // Test 3: Lightweight doctors endpoint
    try {
      print('3️⃣ Testing lightweight doctors endpoint...');
      final response = await http.get(Uri.parse('$baseUrl/api/doctors/basic'))
        .timeout(Duration(seconds: 10));
      print('   ✅ Lightweight endpoint: OK (${response.statusCode})');
      final data = json.decode(response.body);
      print('   📊 Doctors count: ${data.length}');
    } catch (e) {
      print('   ❌ Lightweight endpoint failed: $e');
    }
    
    // Test 4: Full dashboard endpoint (with longer timeout)
    try {
      print('4️⃣ Testing full dashboard endpoint...');
      final response = await http.get(Uri.parse('$baseUrl/api/doctors/dashboard'))
        .timeout(Duration(seconds: 30));
      print('   ✅ Dashboard endpoint: OK (${response.statusCode})');
      final data = json.decode(response.body);
      print('   📊 Total doctors: ${data.length}');
      
      // Count schedules
      int totalSchedules = 0;
      for (var doctor in data) {
        totalSchedules += (doctor['schedules'] as List).length;
      }
      print('   📅 Total schedules: $totalSchedules');
    } catch (e) {
      print('   ❌ Dashboard endpoint failed: $e');
    }
    
    print('🐛 DEBUG SEQUENCE COMPLETE');
  }
}