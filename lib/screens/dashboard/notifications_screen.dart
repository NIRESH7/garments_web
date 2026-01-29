import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [TextButton(onPressed: () {}, child: const Text('Clear All'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildNotificationItem(
            context,
            title: 'Critical Stock Alert',
            message:
                'Lot #4028 is running low on weight. Immediate inward required.',
            time: '2 mins ago',
            type: 'alert',
            isUnread: true,
          ),
          _buildNotificationItem(
            context,
            title: 'QC Report Ready',
            message:
                'Lab test results for Cotton Twill (Dia 32) are now available.',
            time: '1 hour ago',
            type: 'info',
            isUnread: true,
          ),
          _buildNotificationItem(
            context,
            title: 'New Dispatch Created',
            message:
                'DC-20260129-1545 has been generated for Party: Global Textiles.',
            time: '3 hours ago',
            type: 'success',
            isUnread: false,
          ),
          _buildNotificationItem(
            context,
            title: 'System Maintenance',
            message:
                'The server will be down for scheduled maintenance at 11:00 PM.',
            time: '5 hours ago',
            type: 'warning',
            isUnread: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required String title,
    required String message,
    required String time,
    required String type,
    required bool isUnread,
  }) {
    Color iconColor;
    IconData icon;

    switch (type) {
      case 'alert':
        iconColor = ColorPalette.error;
        icon = LucideIcons.alertTriangle;
        break;
      case 'success':
        iconColor = ColorPalette.success;
        icon = LucideIcons.checkCircle2;
        break;
      case 'warning':
        iconColor = Colors.orange;
        icon = LucideIcons.info;
        break;
      default:
        iconColor = ColorPalette.primary;
        icon = LucideIcons.bell;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? iconColor.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread ? iconColor.withOpacity(0.1) : Colors.grey.shade100,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 15,
                        color: ColorPalette.textPrimary,
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: iconColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ColorPalette.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ColorPalette.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
