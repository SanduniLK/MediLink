import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/firestore_service.dart';
import 'package:frontend/telemedicine/consultation_screen.dart';

class DoctorNotificationPage extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorNotificationPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorNotificationPage> createState() => _DoctorNotificationPageState();
}

class _DoctorNotificationPageState extends State<DoctorNotificationPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _notificationSubscription;

  // Color scheme
  final Color _primaryColor = const Color(0xFF18A3B6);
  final Color _secondaryColor = const Color(0xFF32BACD);
  final Color _accentColor = const Color(0xFF85CEDA);
  final Color _lightColor = const Color(0xFFB2DEE6);
  final Color _veryLightColor = const Color(0xFFDDF0F5);

  @override
  void initState() {
    super.initState();
    _loadDoctorNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDoctorNotifications() async {
    try {
      debugPrint('🔔 Loading doctor notifications for: ${widget.doctorId}');
      
      _notificationSubscription?.cancel();
      
      _notificationSubscription = FirestoreService.getDoctorNotificationsStream(widget.doctorId)
          .listen((notifications) {
        if (mounted) {
          setState(() {
            _notifications = notifications;
            _isLoading = false;
          });
        }
      }, onError: (error) {
        debugPrint('❌ Error loading notifications: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });

    } catch (e) {
      debugPrint('❌ Error setting up notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _markAsRead(String notificationId) async {
    try {
      await FirestoreService.markNotificationAsRead(notificationId);
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  void _clearAllNotifications() async {
    try {
      await FirestoreService.clearDoctorNotifications(widget.doctorId);
      if (mounted) {
        setState(() {
          _notifications = [];
        });
      }
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
    }
  }

  // In DoctorNotificationPage - update _buildNotificationCard method
Widget _buildNotificationCard(Map<String, dynamic> notification) {
  final bool isRead = notification['isRead'] ?? false;
  final String type = notification['type'] ?? 'info';
  final DateTime timestamp = (notification['timestamp'] as Timestamp).toDate();
  final bool hasAction = notification['hasAction'] ?? false;
  final String actionText = notification['actionText'] ?? 'Action';
  final String appointmentId = notification['appointmentId'] ?? '';
  final String patientName = notification['patientName'] ?? 'Patient';
  
  Color borderColor;
  IconData icon;
  
  switch (type) {
    case 'patient_joined':
      borderColor = Colors.green;
      icon = Icons.person_add;
      break;
    case 'consultation_started':
      borderColor = _primaryColor;
      icon = Icons.video_call;
      break;
    default:
      borderColor = _accentColor;
      icon = Icons.notifications;
  }

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    elevation: isRead ? 1 : 3,
    color: isRead ? _veryLightColor : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: borderColor, width: 2),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Icon(icon, color: borderColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: isRead ? Colors.grey[600] : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['message'] ?? '',
                      style: TextStyle(
                        color: isRead ? Colors.grey[500] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              !isRead
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    )
                  : const SizedBox(),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Time and action button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTimeAgo(timestamp),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              
              // ACTION BUTTON - Only show for patient_joined notifications
              if (hasAction && type == 'patient_joined')
                ElevatedButton(
                  onPressed: () => _handleJoinMeeting(appointmentId, patientName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_call, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        actionText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
// In DoctorNotificationPage - add this method
void _handleJoinMeeting(String appointmentId, String patientName) async {
  try {
    debugPrint('🎯 Doctor tapping JOIN MEETING for appointment: $appointmentId');
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _veryLightColor,
        content: Row(
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
            const SizedBox(width: 16),
            Text(
              'Joining consultation...',
              style: TextStyle(color: _primaryColor),
            ),
          ],
        ),
      ),
    );

    // Get session details
    final sessionData = await FirestoreService.getSessionByAppointmentId(appointmentId);
    
    if (sessionData != null && mounted) {
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      // Complete step 3: Doctor joins
      await FirestoreService.completeDoctorJoinFlow(
        appointmentId: appointmentId,
        doctorId: widget.doctorId,
      );
      
      // Navigate to consultation screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ConsultationScreen(
            appointmentId: appointmentId,
            userId: widget.doctorId,
            userName: widget.doctorName,
            userType: 'doctor',
            consultationType: sessionData['consultationType'] ?? 'video',
            patientId: sessionData['patientId'],
            doctorId: widget.doctorId,
            patientName: patientName,
            doctorName: widget.doctorName,
          ),
        ),
      );
    } else {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError('Could not find consultation details');
      }
    }
    
  } catch (e) {
    debugPrint('❌ Error joining meeting: $e');
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showError('Failed to join consultation: $e');
    }
  }
}

void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}
  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear All',
            ),
        ],
      ),
      backgroundColor: _veryLightColor,
      body: _isLoading
          ? _buildLoading()
          : _notifications.isEmpty
              ? _buildEmpty()
              : _buildNotificationList(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 64, color: _accentColor),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 18,
              color: _primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(color: _secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    final unreadCount = _notifications.where((n) => !(n['isRead'] ?? false)).length;
    
    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.all(16),
          color: _lightColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Notifications list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDoctorNotifications,
            backgroundColor: _veryLightColor,
            color: _primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(_notifications[index]);
              },
            ),
          ),
        ),
      ],
    );
  }
}