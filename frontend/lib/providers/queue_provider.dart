import 'package:flutter/material.dart';
import '../services/queue_api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

      //  Pass appointments to the API service
      final result = await QueueApiService.startConsultation(
        scheduleId: scheduleId,
        doctorId: doctorId,
        medicalCenterId: medicalCenterId,
        doctorName: doctorName,
        medicalCenterName: medicalCenterName,
        appointments: appointments, 
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
  Future<Map<String, dynamic>?> patientCheckIn(
    String patientId,
    String scheduleId,
  ) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      print('👤 Patient check-in: $patientId, Schedule: $scheduleId');

      final result = await QueueApiService.patientCheckIn(
        patientId,
        scheduleId,
      );

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
        print(
          '✅ Moved to next patient. Current token: ${_currentQueue?['currentToken']}',
        );
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

  Future<Map<String, dynamic>?> getQueueByScheduleId(String scheduleId) async {
    try {
      // 1. Query Firestore for all appointments in this schedule
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('scheduleId', isEqualTo: scheduleId)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      // 2. Process the documents into a List of patient maps
      List<Map<String, dynamic>> patients = [];
      int currentToken = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Ensure we handle basic types correctly
        final Map<String, dynamic> patientData = {
          'patientId': data['patientId'],
          'patientName': data['patientName'] ?? 'Unknown',
          'tokenNumber': data['tokenNumber'] ?? 0,
          'status': data['status'] ?? 'waiting', // confirmed, completed, etc.
          'queueStatus':
              data['queueStatus'] ??
              'waiting', // in_consultation, waiting, etc.
        };

        patients.add(patientData);

        // 3. Find who is currently "in_consultation" to set the current token
        if (data['queueStatus'] == 'in_consultation') {
          currentToken = data['tokenNumber'] ?? 0;
        }
      }

      // 4. If no one is "in_consultation", fallback logic:
      // Find the highest token number that is "completed"
      if (currentToken == 0) {
        final completedPatients = patients
            .where((p) => p['status'] == 'completed')
            .toList();
        if (completedPatients.isNotEmpty) {
          // Sort by token number descending
          completedPatients.sort(
            (a, b) =>
                (b['tokenNumber'] as int).compareTo(a['tokenNumber'] as int),
          );
          // If token 5 is done, the "current" indicator usually stays there or moves to 6
          currentToken = completedPatients.first['tokenNumber'];
        }
      }

      // 5. Return the structure your UI expects
      return {'currentToken': currentToken, 'patients': patients};
    } catch (e) {
      debugPrint("Error fetching queue from Firestore: $e");
      return null;
    }
  }
}
