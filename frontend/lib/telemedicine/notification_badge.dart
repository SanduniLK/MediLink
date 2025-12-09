import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final bool showZero;
  final String? customText;
  
  const NotificationBadge({
    super.key,
    required this.count,
    this.size = 20.0,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
    this.showZero = false,
    this.customText,
  });
  
  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !showZero) return const SizedBox.shrink();
    
    final displayText = customText ?? (count > 99 ? '99+' : count.toString());
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: textColor,
            fontSize: count > 9 ? size * 0.4 : size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// Simple red dot version
class NotificationDot extends StatelessWidget {
  final bool show;
  final double size;
  final Color color;
  
  const NotificationDot({
    super.key,
    required this.show,
    this.size = 8.0,
    this.color = Colors.red,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}