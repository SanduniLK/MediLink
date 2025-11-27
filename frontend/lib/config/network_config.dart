import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class NetworkConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    } else if (Platform.isAndroid) {
      // Use 10.0.2.2 for USB tethering and Android
      return "http://10.109.195.138:5001";
    } else if (Platform.isIOS) {
      return "http://localhost:3000";
    } else {
      return "http://localhost:3000";
    }
  }
  
  static String get doctorsDashboard => "$baseUrl/api/doctors/dashboard";
}