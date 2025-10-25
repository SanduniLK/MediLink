import 'package:flutter/foundation.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _doctor;
  Map<String, dynamic>? _user;

  Map<String, dynamic>? get doctor => _doctor;
  Map<String, dynamic>? get user => _user;

  void setDoctor(Map<String, dynamic> doctorData) {
    _doctor = doctorData;
    notifyListeners();
  }

  void setUser(Map<String, dynamic> userData) {
    _user = userData;
    notifyListeners();
  }

  void clear() {
    _doctor = null;
    _user = null;
    notifyListeners();
  }
}