import 'package:flutter/material.dart';
import '../services/queue_api_service.dart';

class QueueProvider with ChangeNotifier {
  Map<String, dynamic>? _currentQueue;
  String _error = '';
  bool _isLoading = false;

  Map<String, dynamic>? get currentQueue => _currentQueue;
  String get error => _error;
  bool get isLoading => _isLoading;

 Future<bool> startConsultation({
  required String scheduleId,
  required String doctorId,
  required String medicalCenterId,
  required String doctorName,
  required String medicalCenterName,
  required List<Map<String, dynamic>> appointments,
}) async {
  try {
    _isLoading = true;
    _error = '';
    notifyListeners();

    print('🎯 Starting consultation in QueueProvider...');
    print('   Schedule ID: $scheduleId');
    print('   Doctor ID: $doctorId');
    print('   Medical Center: $medicalCenterName');
    print('   Appointments: ${appointments.length}');
    
    // ✅ FIX: Pass appointments to the API service
    final result = await QueueApiService.startConsultation(
      scheduleId: scheduleId,
      doctorId: doctorId,
      medicalCenterId: medicalCenterId,
      doctorName: doctorName,
      medicalCenterName: medicalCenterName,
      appointments: appointments, // Pass appointments here
    );

    _isLoading = false;

    if (result['success'] == true) {
      _currentQueue = result['data'];
      print('✅ Queue started successfully!');
      print('   Queue ID: ${_currentQueue?['queueId']}');
      print('   Patients: ${_currentQueue?['patients']?.length}');
      notifyListeners();
      return true;
    } else {
      _error = result['error'] ?? 'Failed to start queue';
      print('❌ Queue start failed: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _isLoading = false;
    _error = e.toString();
    print('❌ Exception in startConsultation: $e');
    notifyListeners();
    return false;
  }
}

  // Get queue by schedule
  Future<void> getQueueBySchedule(String scheduleId) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      final result = await QueueApiService.getQueueBySchedule(scheduleId);
      
      _isLoading = false;
      
      if (result['success'] == true) {
        _currentQueue = result['data'];
        print('✅ Queue loaded: ${_currentQueue?['queueId']}');
      } else {
        _error = result['error'] ?? 'Failed to get queue';
        print('❌ Queue load failed: $_error');
      }
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('❌ Exception in getQueueBySchedule: $_error');
      notifyListeners();
    }
  }

  // Get queue for patient
  Future<Map<String, dynamic>?> getQueueForPatient(String patientId) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      print('📋 Getting queue for patient: $patientId');

      final result = await QueueApiService.getQueueForPatient(patientId);

      _isLoading = false;

      if (result['success'] == true) {
        _currentQueue = result['data'];
        print('✅ Patient queue loaded successfully');
        print('   Queue ID: ${_currentQueue?['queueId']}');
        print('   Current Token: ${_currentQueue?['currentToken']}');
        notifyListeners();
        return result['data'];
      } else {
        _error = result['error'] ?? 'Failed to get patient queue';
        print('❌ Patient queue load failed: $_error');
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('❌ Exception in getQueueForPatient: $_error');
      notifyListeners();
      return null;
    }
  }

  // Patient check-in
  Future<Map<String, dynamic>?> patientCheckIn(String patientId, String scheduleId) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      print('👤 Patient check-in: $patientId, Schedule: $scheduleId');

      final result = await QueueApiService.patientCheckIn(patientId, scheduleId);

      _isLoading = false;

      if (result['success'] == true) {
        print('✅ Patient checked in successfully');
        print('   Token: ${result['data']['patient']['tokenNumber']}');
        print('   Current Token: ${result['data']['currentToken']}');
        notifyListeners();
        return result['data'];
      } else {
        _error = result['error'] ?? 'Failed to check in patient';
        print('❌ Check-in failed: $_error');
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('❌ Exception in patientCheckIn: $_error');
      notifyListeners();
      return null;
    }
  }

  // Move to next patient
  Future<bool> nextPatient(String queueId) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      final result = await QueueApiService.nextPatient(queueId);
      
      _isLoading = false;
      
      if (result['success'] == true) {
        _currentQueue = result['data'];
        print('✅ Moved to next patient. Current token: ${_currentQueue?['currentToken']}');
        notifyListeners();
        return true;
      } else {
        _error = result['error'] ?? 'Failed to move to next patient';
        print('❌ Next patient failed: $_error');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('❌ Exception in nextPatient: $_error');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void disposeListeners() {
    _currentQueue = null;
    _error = '';
    _isLoading = false;
  }
}