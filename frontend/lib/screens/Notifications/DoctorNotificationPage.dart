import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/firestore_service.dart';

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

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isRead = notification['isRead'] ?? false;
    final String type = notification['type'] ?? 'info';
    final DateTime timestamp = (notification['timestamp'] as Timestamp).toDate();
    
    Color borderColor;
    IconData icon;
    
    switch (type) {
      case 'patient_joined':
        borderColor = Colors.green;
        icon = Icons.person_add;
        break;
      case 'call_started':
        borderColor = _primaryColor;
        icon = Icons.video_call;
        break;
      case 'call_ended':
        borderColor = Colors.grey;
        icon = Icons.call_end;
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
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: borderColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Icon(icon, color: borderColor, size: 20),
        ),
        title: Text(
          notification['title'] ?? 'Notification',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[600] : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'] ?? '',
              style: TextStyle(
                color: isRead ? Colors.grey[500] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(timestamp),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          if (!isRead) {
            _markAsRead(notification['id']);
          }
        },
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