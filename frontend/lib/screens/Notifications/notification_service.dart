import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:frontend/telemedicine/consultation_screen.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Initialize local notifications
  static Future<void> initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    
    await _localNotifications.initialize(settings);
  }

  // Send notification when doctor starts consultation
  static Future<void> sendConsultationStartedNotification({
    required String patientId,
    required String doctorName,
    required String appointmentId,
    required String consultationType,
  }) async {
    try {
      debugPrint('🔔 Sending consultation started notification to patient: $patientId');
      
      // 1. Store in Firestore
      await _storeNotificationInFirestore(
        patientId: patientId,
        doctorName: doctorName,
        appointmentId: appointmentId,
        consultationType: consultationType,
      );

      // 2. Send local notification
      await _showLocalNotification(
        doctorName: doctorName,
        appointmentId: appointmentId,
        consultationType: consultationType,
      );

      debugPrint('✅ Consultation notification sent successfully');

    } catch (e) {
      debugPrint('❌ Error sending consultation notification: $e');
    }
  }

  // Store notification in Firestore
  static Future<void> _storeNotificationInFirestore({
    required String patientId,
    required String doctorName,
    required String appointmentId,
    required String consultationType,
  }) async {
    try {
      final notificationData = {
        'patientId': patientId,
        'doctorName': doctorName,
        'appointmentId': appointmentId,
        'consultationType': consultationType,
        'type': 'consultation_started',
        'title': 'Consultation Started 🔔',
        'message': 'Dr. $doctorName has started your $consultationType consultation',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'action': 'join_consultation',
        'priority': 'high',
      };

      await _firestore.collection('notifications').add(notificationData);
      debugPrint('✅ Notification stored in Firestore');
      
    } catch (e) {
      debugPrint('❌ Error storing notification: $e');
    }
  }

  // Show local notification with action buttons
  static Future<void> _showLocalNotification({
    required String doctorName,
    required String appointmentId,
    required String consultationType,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'consultation_channel', // channelId
        'Consultation Notifications', // channelName
        channelDescription: 'Notifications for telemedicine consultations',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        timeoutAfter: 30000, // 30 seconds timeout
        styleInformation: BigTextStyleInformation(''),
        actions: [
          AndroidNotificationAction(
            'join_action',
            'Join Now',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss_action',
            'Dismiss',
          ),
        ],
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Dr. $doctorName is Calling You 📞',
        'Tap to join $consultationType consultation',
        details,
        payload: json.encode({
          'type': 'consultation_started',
          'appointmentId': appointmentId,
          'doctorName': doctorName,
          'consultationType': consultationType,
          'action': 'join_consultation',
        }),
      );

      debugPrint('✅ Local notification shown');
      
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  // Handle notification tap and actions
  static void configureNotificationActions(BuildContext context) {
    // Handle notification tap
    _localNotifications.getNotificationAppLaunchDetails().then((details) {
      if (details?.didNotificationLaunchApp ?? false) {
        final payload = details?.notificationResponse?.payload;
        if (payload != null) {
          _handleNotificationPayload(payload, context);
        }
      }
    });

    // Handle notification actions
    _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationResponse(response, context);
      },
    );
  }

  static void _handleNotificationResponse(
      NotificationResponse response, BuildContext context) {
    final String? payload = response.payload;
    if (payload != null) {
      _handleNotificationPayload(payload, context);
    }
  }

  static void _handleNotificationPayload(String payload, BuildContext context) {
    try {
      final data = json.decode(payload) as Map<String, dynamic>;
      
      if (data['action'] == 'join_consultation') {
        _navigateToConsultation(data, context);
      }
    } catch (e) {
      debugPrint('❌ Error handling notification payload: $e');
    }
  }

  static void _navigateToConsultation(Map<String, dynamic> data, BuildContext context) {
    // You'll need to get patient info from your app state
    // This is a simplified version - adjust based on your app structure
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    
    // Navigate to consultation screen
    // You'll need to pass the actual patient data here
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConsultationScreen(
          appointmentId: data['appointmentId'],
          userId: 'patient_id_here', // Get from your app state
          userName: 'Patient Name', // Get from your app state
          userType: 'patient',
          consultationType: data['consultationType'] ?? 'video',
          patientId: 'patient_id_here', // Get from your app state
          doctorId: 'doctor_id_here', // Get from notification data or lookup
          patientName: 'Patient Name', // Get from your app state
          doctorName: data['doctorName'] ?? 'Doctor',
        ),
      ),
    );
  }

  // ADD THESE MISSING METHODS:

  // Get all unread notifications for a patient
  static Stream<List<Map<String, dynamic>>> getPatientNotifications(String patientId) {
    return _firestore
        .collection('notifications')
        .where('patientId', isEqualTo: patientId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for a patient
  static Future<void> markAllAsRead(String patientId) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('patientId', isEqualTo: patientId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ All notifications marked as read for patient: $patientId');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  // Get notification count for badge
  static Stream<int> getNotificationCount(String patientId) {
    return _firestore
        .collection('notifications')
        .where('patientId', isEqualTo: patientId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}