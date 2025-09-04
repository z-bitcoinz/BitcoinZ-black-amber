import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

/// A badge widget that shows unread notification count
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final bool showZero;
  final Color? badgeColor;
  final Color? textColor;
  final double? fontSize;
  final EdgeInsets? padding;
  final bool showOnlyNotifications; // If true, only show notification count, not memo count
  final bool showOnlyMemos; // If true, only show memo count, not notification count

  const NotificationBadge({
    Key? key,
    required this.child,
    this.showZero = false,
    this.badgeColor,
    this.textColor,
    this.fontSize,
    this.padding,
    this.showOnlyNotifications = false,
    this.showOnlyMemos = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        int count;
        
        if (showOnlyNotifications) {
          count = notificationProvider.unreadCount;
        } else if (showOnlyMemos) {
          count = notificationProvider.unreadMemoCount;
        } else {
          count = notificationProvider.totalUnreadCount;
        }

        if (count == 0 && !showZero) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0 || showZero)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: fontSize ?? 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A simple dot badge for indicating unread items without showing count
class NotificationDot extends StatelessWidget {
  final Widget child;
  final Color? dotColor;
  final double? size;
  final bool showOnlyNotifications;
  final bool showOnlyMemos;

  const NotificationDot({
    Key? key,
    required this.child,
    this.dotColor,
    this.size,
    this.showOnlyNotifications = false,
    this.showOnlyMemos = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        bool hasUnread;
        
        if (showOnlyNotifications) {
          hasUnread = notificationProvider.hasUnreadNotifications;
        } else if (showOnlyMemos) {
          hasUnread = notificationProvider.hasUnreadMemos;
        } else {
          hasUnread = notificationProvider.hasAnyUnread;
        }

        if (!hasUnread) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: size ?? 8,
                height: size ?? 8,
                decoration: BoxDecoration(
                  color: dotColor ?? Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A text widget that shows unread count
class NotificationCountText extends StatelessWidget {
  final TextStyle? style;
  final bool showOnlyNotifications;
  final bool showOnlyMemos;
  final String prefix;
  final String suffix;

  const NotificationCountText({
    Key? key,
    this.style,
    this.showOnlyNotifications = false,
    this.showOnlyMemos = false,
    this.prefix = '',
    this.suffix = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        int count;
        
        if (showOnlyNotifications) {
          count = notificationProvider.unreadCount;
        } else if (showOnlyMemos) {
          count = notificationProvider.unreadMemoCount;
        } else {
          count = notificationProvider.totalUnreadCount;
        }

        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Text(
          '$prefix$count$suffix',
          style: style ?? Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
}

/// A widget that shows different content based on unread status
class NotificationStatusBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool hasUnread, int count) builder;
  final bool showOnlyNotifications;
  final bool showOnlyMemos;

  const NotificationStatusBuilder({
    Key? key,
    required this.builder,
    this.showOnlyNotifications = false,
    this.showOnlyMemos = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        int count;
        bool hasUnread;
        
        if (showOnlyNotifications) {
          count = notificationProvider.unreadCount;
          hasUnread = notificationProvider.hasUnreadNotifications;
        } else if (showOnlyMemos) {
          count = notificationProvider.unreadMemoCount;
          hasUnread = notificationProvider.hasUnreadMemos;
        } else {
          count = notificationProvider.totalUnreadCount;
          hasUnread = notificationProvider.hasAnyUnread;
        }

        return builder(context, hasUnread, count);
      },
    );
  }
}
