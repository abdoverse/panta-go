import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/market_notification.dart';
import '../../providers/panta_provider.dart';

/// Top-level in-app market notification banner that displays operational notices,
/// technical issue alerts, or service announcements fetched directly from the backend.
///
/// Designed to work seamlessly on both mobile viewports and desktop web viewports.
class MarketNotificationBanner extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const MarketNotificationBanner({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final notification = provider.activeMarketNotification;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1.0,
        child: child,
      ),
      child: notification == null
          ? const SizedBox.shrink()
          : _NotificationCard(
              key: ValueKey(notification.id),
              notification: notification,
              navigatorKey: navigatorKey,
              onDismiss: () =>
                  provider.dismissMarketNotification(notification.id),
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final MarketNotification notification;
  final GlobalKey<NavigatorState>? navigatorKey;
  final VoidCallback onDismiss;

  const _NotificationCard({
    super.key,
    required this.notification,
    this.navigatorKey,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSwedish = Localizations.localeOf(context).languageCode == 'sv';

    final Color bgColor;
    final Color borderColor;
    final Color primaryColor;
    final Color textColor;
    final IconData iconData;

    switch (notification.severity) {
      case MarketNotificationSeverity.critical:
      case MarketNotificationSeverity.incident:
        bgColor = const Color(0xFFFFF2F2);
        borderColor = const Color(0xFFFFCDD2);
        primaryColor = const Color(0xFFD32F2F);
        textColor = const Color(0xFF5C0000);
        iconData = Icons.error_outline_rounded;
        break;
      case MarketNotificationSeverity.info:
        bgColor = const Color(0xFFF0F7FF);
        borderColor = const Color(0xFFBBDEFB);
        primaryColor = const Color(0xFF1976D2);
        textColor = const Color(0xFF0D47A1);
        iconData = Icons.info_outline_rounded;
        break;
      case MarketNotificationSeverity.warning:
      default:
        bgColor = const Color(0xFFFFFBEB); // Warm amber surface
        borderColor = const Color(0xFFFFE082); // Subtle golden border
        primaryColor = const Color(0xFFE65100); // Dark amber-orange
        textColor = const Color(0xFF4E342E); // Deep readable warm dark brown
        iconData = Icons.warning_amber_rounded;
        break;
    }

    final title = notification.localizedTitle(isSwedish).isNotEmpty
        ? notification.localizedTitle(isSwedish)
        : l10n.technicalIssuesTitle;

    final message = notification.localizedMessage(isSwedish).isNotEmpty
        ? notification.localizedMessage(isSwedish)
        : l10n.technicalIssuesDefault;

    final marketBadge = notification.market.toUpperCase() == 'ALL'
        ? l10n.marketNoticeActiveBadge
        : '${l10n.marketNoticeActiveBadge} (${notification.market.toUpperCase()})';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: ResponsiveContainer(
            maxWidth: 1080,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Warning / Alert Icon Badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    iconData,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Notification Content
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              marketBadge,
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Optional Action Button or Dismiss Button
                if (notification.actionUrl != null &&
                    notification.actionUrl!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _showNoticeDetailsDialog(context, title, message);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 32),
                    ),
                    child: Text(
                      notification.actionLabel ?? l10n.marketNoticeLearnMore,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],

                if (notification.dismissible) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      semanticLabel: l10n.marketNoticeDismiss,
                    ),
                    color: textColor.withValues(alpha: 0.6),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismiss,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNoticeDetailsDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    final navContext = navigatorKey?.currentContext ??
        (Navigator.maybeOf(context)?.context ?? context);
    showDialog(
      context: navContext,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }
}
