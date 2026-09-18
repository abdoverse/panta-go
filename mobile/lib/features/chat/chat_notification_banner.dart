import '../../core/localization/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../models/request_model.dart';
import '../../providers/panta_provider.dart';
import '../../core/utils/sound_helper.dart';
import 'chat_bottom_sheet.dart';

/// A wrapper widget that listens for incoming chat messages in [PantaProvider]
/// and presents a prominent, animated in-app notification banner at the top of the screen.
class ChatNotificationListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const ChatNotificationListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  State<ChatNotificationListener> createState() =>
      _ChatNotificationListenerState();
}

class _ChatNotificationListenerState extends State<ChatNotificationListener>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  ChatMessage? _activeNotification;
  String? _lastNotifiedMessageId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _triggerNotification(ChatMessage msg) {
    _dismissTimer?.cancel();
    _lastNotifiedMessageId = msg.id;

    setState(() {
      _activeNotification = msg;
    });

    try {
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    } catch (_) {}

    final isArrival = msg.isArrivalAlert;
    if (isArrival) {
      playDingDongSound();
    }

    _animController.forward(from: 0.0);

    // Prolonged notification durations (20s for arrival, 15s for regular chat)
    _dismissTimer = Timer(Duration(seconds: isArrival ? 20 : 15), () {
      _dismiss();
    });
  }

  bool _isOpeningChat = false;

  void _dismiss() {
    _dismissTimer?.cancel();
    if (mounted && _animController.status != AnimationStatus.dismissed) {
      _animController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _activeNotification = null;
            _isOpeningChat = false;
          });
          context.read<PantaProvider>().clearLastIncomingChatMessage();
        }
      });
    } else {
      _isOpeningChat = false;
    }
  }

  void _openChat(PantaProvider provider, ChatMessage msg) {
    if (_isOpeningChat) return;
    _isOpeningChat = true;

    _dismiss();
    provider.markChatAsRead(msg.requestId);

    RecyclingRequest? targetRequest;
    for (final req in provider.requests) {
      if (req.id == msg.requestId) {
        targetRequest = req;
        break;
      }
    }

    // Fallback if request is not yet loaded into memory
    targetRequest ??= RecyclingRequest(
      id: msg.requestId,
      title: msg.senderName.isNotEmpty
          ? msg.senderName
          : (mounted ? context.l10n.newPickupRequest : 'Request'), // l10n-ignore
      creatorName: msg.senderRole == 'helper' ? null : msg.senderName,
      creatorId: msg.senderRole == 'helper' ? null : msg.senderId,
      helperName: msg.senderRole == 'helper' ? msg.senderName : null,
      helperId: msg.senderRole == 'helper' ? msg.senderId : null,
      scheduledFrom: msg.createdAt,
      scheduledTo: msg.createdAt.add(const Duration(hours: 2)),
      location: '',
      status: RequestStatus.accepted,
    );
    provider.fetchRequests(silent: true);

    final navContext = widget.navigatorKey?.currentState?.context ??
        widget.navigatorKey?.currentContext ??
        (Navigator.maybeOf(context)?.context ?? context);

    ChatBottomSheet.show(
      navContext,
      request: targetRequest,
      isHelper: provider.isHelper,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final lastMsg = provider.lastIncomingChatMessage;

    // Trigger incoming notification if a new message arrived from the other party
    if (lastMsg != null &&
        lastMsg.id != _lastNotifiedMessageId &&
        !provider.isMessageSentByMe(lastMsg)) {
      final isAlreadyShowingArrival = _activeNotification != null &&
          _activeNotification!.isArrivalAlert &&
          _activeNotification!.requestId == lastMsg.requestId;
      if (!isAlreadyShowingArrival) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _triggerNotification(lastMsg);
          }
        });
      }
    }

    final activeMsg = _activeNotification;
    final activeRequest = activeMsg != null
        ? provider.requests.cast<RecyclingRequest?>().firstWhere(
            (r) => r?.id == activeMsg.requestId,
            orElse: () => null,
          )
        : null;

    return Stack(
      children: [
        widget.child,
        if (activeMsg != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SlideTransition(
                  position: _offsetAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _ChatBannerCard(
                      message: activeMsg,
                      requestTitle: activeRequest?.title,
                      onOpen: () => _openChat(provider, activeMsg),
                      onDismiss: _dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatBannerCard extends StatelessWidget {
  final ChatMessage message;
  final String? requestTitle;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _ChatBannerCard({
    required this.message,
    this.requestTitle,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isArrival = message.isArrivalAlert;

    final gradientColors = isArrival
        ? const [
            Color(0xFF8D4F00), // Rich amber bronze
            Color(0xFFE65100), // Warm vibrant gold-orange
          ]
        : const [
            Color(0xFF0B3A22), // Deep Panta green
            Color(0xFF1B5E20), // Forest green
          ];

    final borderColor = isArrival
        ? const Color(0xFFFFD54F)
        : const Color(0xFF81C784);

    final shadowColor = isArrival
        ? Colors.amber.withValues(alpha: 0.5)
        : AppTheme.primaryGreen.withValues(alpha: 0.35);

    final avatarIcon = isArrival
        ? Icons.doorbell_rounded
        : Icons.mark_chat_unread_rounded;

    final badgeText = isArrival ? 'DING-DONG 🛎️' : l10n.newBadge;

    final buttonFgColor = isArrival
        ? const Color(0xFF8D4F00)
        : const Color(0xFF0B3A22);

    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isArrival ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: isArrival ? 20 : 16,
                spreadRadius: isArrival ? 3 : 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Glowing Avatar (Bell / Chat)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    avatarIcon,
                    color: Colors.white,
                    size: isArrival ? 26 : 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Message Text Info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            message.senderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (requestTitle != null && requestTitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.recycling_rounded,
                            size: 13,
                            color: Color(0xFFFFD54F),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.regardingRequestTitle(requestTitle!),
                              style: const TextStyle(
                                color: Color(0xFFFFF9C4),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      message.text.isNotEmpty ? message.text : '...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Action Button & Close
              ElevatedButton.icon(
                onPressed: onOpen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: buttonFgColor,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isArrival ? Icons.door_front_door_rounded : Icons.reply_rounded,
                  size: 16,
                ),
                label: Text(
                  context.l10n.open,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: l10n.dismiss,
                child: IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
