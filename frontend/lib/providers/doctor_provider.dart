import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:frontend/model/doctor.dart';
import 'package:http/http.dart' as http;
import '../config/network_config.dart'; 


class DoctorProvider with ChangeNotifier {
  List<dynamic>? _allDoctorsData;
  List<Doctor>? _allDoctors;
  bool _isLoading = false;
  String _error = '';

  List<dynamic>? get allDoctorsData => _allDoctorsData;
  List<Doctor>? get allDoctors => _allDoctors;
  bool get isLoading => _isLoading;
  String get error => _error;

  void clearError() {
    _error = '';
    notifyListeners();
  }

Future<void> loadAllDoctorsQueueDashboard() async {
  _isLoading = true;
  _error = '';
  notifyListeners();

  try {
    print('🔄 Loading doctors data...');
    
    // Use the URL that works in your mobile browser
    final response = await http.get(
      Uri.parse('http://10.222.212.133:5001/api/doctors/dashboard'),
    ).timeout(const Duration(seconds: 30));

    print('📊 Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print('✅ REAL Data received! ${data.length} doctors');
      
      // Process real Firebase data
      _processRealFirebaseData(data);
    } else {
      _error = 'Server error: ${response.statusCode}';
      print('❌ Server error: ${response.statusCode}');
    }
  } on TimeoutException {
    _error = 'Connection timeout. Please check:\n• Backend is running\n• Correct IP: 10.159.139.145:5001\n• Same WiFi network';
    print('⏰ Timeout loading real data');
  } catch (e) {
    print('❌ Error loading real data: $e');
    _error = 'Network error: $e';
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
// Add this method to your DoctorProvider class
void debugAppointmentsData() {
  if (_allDoctorsData == null) {
    print('❌ No doctors data available');
    return;
  }

  print('=== APPOINTMENTS DEBUG ===');
  
  for (var doctorData in _allDoctorsData!) {
    final doctorId = doctorData['id'];
    final doctorName = doctorData['fullname'];
    final schedules = List<Map<String, dynamic>>.from(doctorData['schedules'] ?? []);
    
    print('👨‍⚕️ Doctor: $doctorName ($doctorId)');
    print('   Schedules: ${schedules.length}');
    
    for (var schedule in schedules) {
      final medicalCenter = schedule['medicalCenterName'];
      final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);
      
      print('   📅 Schedule: $medicalCenter');
      print('      Appointments: ${appointments.length}');
      
      for (var appointment in appointments) {
        print('      👤 Patient: ${appointment['patientName']}');
        print('         Token: ${appointment['tokenNumber']}');
        print('         Status: ${appointment['status']}');
        print('         Time: ${appointment['time']}');
        print('         Date: ${appointment['date']}');
      }
    }
  }
  print('=== END DEBUG ===');
}
  void _processRealFirebaseData(List<dynamic> data) {
  try {
    print('🔄 Processing ${data.length} REAL Firebase doctors...');
    
    List<Doctor> processedDoctors = [];
    
    for (var doctorData in data) {
      final doctor = _mapFirebaseDataToDoctor(doctorData);
      if (doctor != null) {
        processedDoctors.add(doctor);
      }
    }
    
    _allDoctors = processedDoctors;
    _allDoctorsData = data; // Store raw data for schedules
    
    print('✅ Successfully processed ${processedDoctors.length} doctors from Firebase');
    
    // Debug: Print doctor details
    for (var doctor in processedDoctors) {
      print('👨‍⚕️ Doctor: ${doctor.name}');
      print('   Available Times: ${doctor.availableTimes.length}');
      print('   Available Times: ${doctor.availableTimes}');
    }
    
  } catch (e) {
    print('❌ Error processing Firebase data: $e');
    _error = 'Error processing data: $e';
    throw e;
  }
}
Doctor? _mapFirebaseDataToDoctor(Map<String, dynamic> doctorData) {
  try {
    final doctorId = doctorData['id'] ?? '';
    final doctorName = doctorData['fullname'] ?? 'Unknown Doctor';
    final schedules = List<Map<String, dynamic>>.from(doctorData['schedules'] ?? []);
    
    
    print('📋 Mapping doctor: $doctorName');
    print('   Schedules count: ${schedules.length}');
    
    // Extract available times from weekly schedules
    List<String> availableTimes = [];
    
    for (var schedule in schedules) {
      final weeklySchedule = schedule['weeklySchedule'] ?? [];
      final medicalCenter = schedule['medicalCenterName'] ?? 'Medical Center';
      final appointments = List<Map<String, dynamic>>.from(schedule['appointments'] ?? []);
      
      print('   Processing schedule: $medicalCenter');
      print('   Weekly schedule days: ${weeklySchedule.length}');
      print('   Appointments count: ${appointments.length}'); // DEBUG
      
      for (var daySchedule in weeklySchedule) {
        if (daySchedule['available'] == true) {
          final day = daySchedule['day'] ?? 'unknown';
          final timeSlots = daySchedule['timeSlots'] as List? ?? [];
          
          print('     Available day: $day, Time slots: ${timeSlots.length}');
          
          for (var slot in timeSlots) {
            final startTime = slot['startTime'] ?? '';
            final endTime = slot['endTime'] ?? '';
            if (startTime.isNotEmpty && endTime.isNotEmpty) {
              final timeSlot = '$day: $startTime - $endTime at $medicalCenter';
              availableTimes.add(timeSlot);
              print('       Time slot: $timeSlot');
            }
          }
        }
      }
    }
    
    // If no specific times found, create some default availability
    if (availableTimes.isEmpty && schedules.isNotEmpty) {
      for (var schedule in schedules) {
        final medicalCenter = schedule['medicalCenterName'] ?? 'Medical Center';
        final booked = schedule['bookedAppointments'] ?? 0;
        availableTimes.add('$medicalCenter - $booked appointments booked');
      }
    }
    
    // Create Doctor object
    return Doctor(
      id: doctorId,
      name: doctorName,
      specialty: doctorData['specialization'] ?? 'General Practitioner',
      imageUrl: doctorData['imageUrl'] ?? '',
      rating: 4.5, // Default rating
      bio: _generateBioFromFirebaseData(doctorData),
      experience: '${doctorData['experience'] ?? 5} years',
      availableTimes: availableTimes,
    );
    
  } catch (e) {
    print('❌ Error mapping doctor data: $e');
    return null;
  }
}
String _generateBioFromFirebaseData(Map<String, dynamic> doctorData) {
  final specialization = doctorData['specialization'] ?? 'Doctor';
  final hospital = doctorData['hospital'] ?? 'Medical Center';
  final experience = doctorData['experience'] ?? 5;
  final schedules = List<Map<String, dynamic>>.from(doctorData['schedules'] ?? []);
  
  String bio = '$specialization at $hospital with $experience years experience';
  
  if (schedules.isNotEmpty) {
    final scheduleCount = schedules.length;
    bio += '. $scheduleCount active schedule${scheduleCount > 1 ? 's' : ''}.';
  }
  
  return bio;
}
List<Map<String, dynamic>> getCurrentDoctorSchedules(String doctorId) {
  if (_allDoctorsData == null) return [];
  
  for (var doctorData in _allDoctorsData!) {
    if (doctorData['id'] == doctorId) {
      final schedules = List<Map<String, dynamic>>.from(doctorData['schedules'] ?? []);
      return schedules;
    }
  }
  
  return [];
}

  String _generateBio(Map<String, dynamic> doctorData) {
    return '${doctorData['specialization'] ?? 'Doctor'} at ${doctorData['hospital'] ?? 'Medical Center'} with ${doctorData['experience'] ?? 5} years experience';
  }

  List<String> _extractAvailableTimes(Map<String, dynamic> doctorData) {
    List<String> availableTimes = [];
    final schedules = List<Map<String, dynamic>>.from(doctorData['schedules'] ?? []);
    
    for (var schedule in schedules) {
      final weeklySchedule = schedule['weeklySchedule'] ?? [];
      final medicalCenter = schedule['medicalCenterName'] ?? 'Clinic';
      
      for (var daySchedule in weeklySchedule) {
        if (daySchedule['available'] == true) {
          final day = daySchedule['day'];
          final timeSlots = daySchedule['timeSlots'] as List?;
          
          if (timeSlots != null && timeSlots.isNotEmpty) {
            for (var slot in timeSlots) {
              final startTime = slot['startTime'] ?? '';
              final endTime = slot['endTime'] ?? '';
              if (startTime.isNotEmpty && endTime.isNotEmpty) {
                availableTimes.add('$day: $startTime - $endTime at $medicalCenter');
              }
            }
          }
        }
      }
    }
    
    if (availableTimes.isEmpty) {
      availableTimes.add('Check schedule for availability');
    }
    
    return availableTimes;
  }

  // Your existing methods...
  void _handleDoctorData(List<dynamic> data) {
    try {
      _allDoctorsData = data;
    } catch (e) {
      _error = 'Error processing data: $e';
    }
  }

  Future<List<dynamic>?> loadSingleDoctorFullSchedule(String doctorId) async {
    try {
      final String apiUrl = '${NetworkConfig.baseUrl}/api/doctors/$doctorId/full-schedule';
      
      final response = await http.get(
        Uri.parse(apiUrl),
      ).timeout(const Duration(seconds: 40)); 

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        }
      }
      
      throw Exception('Server error: ${response.statusCode}');
    } on TimeoutException {
      return null; 
    } catch (e) {
      return null;
    }
  }

  Future<void> debugBackendConnection() async {
    final baseUrl = NetworkConfig.baseUrl;
    
    // Test 1: Basic connectivity
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/test'))
        .timeout(const Duration(seconds: 5));
    } catch (e) {
      return;
    }
    
    // Test 2: Database status
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/db-status'))
        .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Handle error
    }
    
    // Test 3: Lightweight doctors endpoint
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/doctors/basic'))
        .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
    } catch (e) {
      // Handle error
    }
    
    // Test 4: Full dashboard endpoint
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/doctors/dashboard'))
        .timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      
      // Count schedules
      int totalSchedules = 0;
      for (var doctor in data) {
        totalSchedules += (doctor['schedules'] as List).length;
      }
    } catch (e) {
      // Handle error
    }
  }
}