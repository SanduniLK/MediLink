// lib/config/environment.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Environment {
  // ADD http:// to the beginning
  static String socketUrl = 'http://10.31.163.105:5001';
  
  static Future<void> initialize() async {
    debugPrint('🚀 Connecting to backend at: $socketUrl');
    
    try {
      // Make sure the URL has http://
      final healthUrl = socketUrl.startsWith('http://') 
          ? '$socketUrl/health' 
          : 'http://$socketUrl/health';
          
      final response = await http.get(
        Uri.parse(healthUrl),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        debugPrint('✅ Backend connection successful');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Cannot connect to $socketUrl: $e\n\n'
          'Please check:\n'
          '1. Backend is running: node server.js 5001\n'
          '2. IP address is correct: $socketUrl\n'
          '3. Both devices are on same WiFi');
    }
  }
}