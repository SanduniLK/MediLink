import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/model/telemedicine_session.dart';
import 'package:frontend/screens/Notifications/notification_service.dart';
import 'package:frontend/services/firestore_service.dart';

import 'package:frontend/telemedicine/consultation_screen.dart';


class PatientNotificationPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientNotificationPage({
    super.key, 
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientNotificationPage> createState() => _PatientNotificationPageState();
}

class _PatientNotificationPageState extends State<PatientNotificationPage> {
  @override
  void initState() {
    super.initState();
    // Configure notification actions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.configureNotificationActions(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Notifications'),
        backgroundColor: const Color(0xFF18A3B6),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              } else if (value == 'clear_all') {
                _clearAllNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Text('Mark All as Read'),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear All'),
              ),
            ],
          ),
        ],
      ),
      body: _buildNotificationList(),
    );
  }

  Widget _buildNotificationList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getPatientNotifications(widget.patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF18A3B6)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Failed to load notifications',
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No New Notifications',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see consultation notifications here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final String doctorName = notification['doctorName'] ?? 'Doctor';
    final String consultationType = notification['consultationType'] ?? 'video';
    final bool isVideoCall = consultationType == 'video';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with doctor info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF18A3B6),
                  child: Icon(
                    isVideoCall ? Icons.videocam : Icons.phone,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. $doctorName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${consultationType.toUpperCase()} CONSULTATION',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF18A3B6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildNotificationTime(notification['timestamp']),
              ],
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              notification['message'] ?? 'Consultation has started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _joinConsultation(notification),
                    icon: const Icon(Icons.video_call, size: 20),
                    label: const Text('JOIN CONSULTATION'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18A3B6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => _dismissNotification(notification),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTime(Timestamp? timestamp) {
    if (timestamp == null) return const SizedBox();

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    String timeText;
    if (difference.inMinutes < 1) {
      timeText = 'Just now';
    } else if (difference.inMinutes < 60) {
      timeText = '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      timeText = '${difference.inHours}h ago';
    } else {
      timeText = '${date.day}/${date.month}/${date.year}';
    }

    return Text(
      timeText,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[500],
      ),
    );
  }

 // In PatientTelemedicinePage - update join method
Future<void> _joinConsultation(Map<String, dynamic> notification) async {
  try {
    final appointmentId = notification['appointmentId'];
    final consultationType = notification['consultationType'] ?? 'video';
    final doctorId = notification['doctorId'];
    final doctorName = notification['doctorName'] ?? 'Doctor';

    if (appointmentId == null || doctorId == null) {
      _showError('Invalid notification data: missing appointment ID or doctor ID');
      return;
    }

    debugPrint('🎬 PATIENT JOINING: $appointmentId');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: Row(
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
            const SizedBox(width: 16),
            const Text('Joining consultation...', style: TextStyle(color: Colors.blueAccent)),
          ],
        ),
      ),
    );

    // STEP 1: Ensure join status fields exist
    debugPrint('🔄 Ensuring join status fields exist...');
    await FirestoreService.addJoinStatusFields(appointmentId);

    // STEP 2: Update patient join status to TRUE
    debugPrint('🔄 Updating patient join status to TRUE...');
    await FirestoreService.updateSessionJoinStatus(
      appointmentId: appointmentId,
      userType: 'patient',
      hasJoined: true,
    );

    // STEP 3: Send notification to doctor
    debugPrint('🔄 Sending notification to doctor...');
    await FirestoreService.createPatientJoinedNotification(
      doctorId: doctorId,
      patientName: widget.patientName,
      appointmentId: appointmentId,
      consultationType: consultationType,
    );

    // STEP 4: Verify the update worked
    final updatedStatus = await FirestoreService.getSessionJoinStatus(appointmentId);
    debugPrint('✅ VERIFICATION - Patient joined: ${updatedStatus?['patientJoined']}');

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    debugPrint('🎉 PATIENT JOINED SUCCESSFULLY');

    // Navigate to consultation
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ConsultationScreen(
            appointmentId: appointmentId,
            userId: widget.patientId,
            userName: widget.patientName,
            userType: 'patient',
            consultationType: consultationType,
            patientId: widget.patientId,
            doctorId: doctorId,
            patientName: widget.patientName,
            doctorName: doctorName,
          ),
        ),
      );
    }

  } catch (e) {
    debugPrint('❌ PATIENT JOIN ERROR: $e');
    if (mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
    _showError('Failed to join consultation: $e');
  }
}

  void _dismissNotification(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss Notification'),
        content: const Text('Are you sure you want to dismiss this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              NotificationService.markAsRead(notification['id']);
              Navigator.pop(context);
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _markAllAsRead() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: const Text('Mark all notifications as read?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              NotificationService.markAllAsRead(widget.patientId);
              Navigator.pop(context);
            },
            child: const Text('Mark All'),
          ),
        ],
      ),
    );
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will mark all notifications as read. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              NotificationService.markAllAsRead(widget.patientId);
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
  void _showError(String message) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
}