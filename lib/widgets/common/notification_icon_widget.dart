import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/provider/notification_provider.dart';
import 'package:knocksense/screens/utils/notifications_screen.dart';

/// Reusable notification icon with unread count badge
/// Can be used in AppBars, navigation bars, or as standalone buttons
class NotificationIconWidget extends ConsumerWidget {
  final Color? iconColor;
  final double iconSize;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final IconData iconData;

  const NotificationIconWidget({
    Key? key,
    this.iconColor,
    this.iconSize = 29,
    this.badgeColor,
    this.badgeTextColor,
    this.iconData = Icons.notifications_off_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            iconData,
            size: iconSize,
            color: iconColor ?? const Color(0xFF6B4423),
          ),
          // Unread count badge
          unreadCountAsync.when(
            data: (count) {
              if (count == 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFFF4C21A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor ?? Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
          ),
        );
      },
      tooltip: 'Notifications',
    );
  }
}

/// Simplified version for use in BottomNavigationBar
class NotificationNavigationIcon extends ConsumerWidget {
  final bool isActive;

  const NotificationNavigationIcon({
    Key? key,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        if (count == 0) {
          return Icon(
            isActive
                ? Icons.notifications
                : Icons.notifications_outlined,
          );
        }

        return Badge(
          label: Text('$count'),
          child: Icon(
            isActive
                ? Icons.notifications
                : Icons.notifications_outlined,
          ),
        );
      },
      loading: () => Icon(
        isActive ? Icons.notifications : Icons.notifications_outlined,
      ),
      error: (_, __) => Icon(
        isActive ? Icons.notifications : Icons.notifications_outlined,
      ),
    );
  }
}
