import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../models/request_model.dart';
import '../../providers/panta_provider.dart';
import 'chat_bottom_sheet.dart';

/// A wrapper widget that listens for incoming chat messages in [PantaProvider]
/// and presents a prominent, animated in-app notification banner at the top of the screen.
class ChatNotificationListener extends StatefulWidget {
  final Widget child;

  const ChatNotificationListener({
    super.key,
    required this.child,
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

    _animController.forward(from: 0.0);

    // Auto dismiss after 6 seconds
    _dismissTimer = Timer(const Duration(seconds: 6), () {
      _dismiss();
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (mounted && _animController.status != AnimationStatus.dismissed) {
      _animController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _activeNotification = null;
          });
          context.read<PantaProvider>().clearLastIncomingChatMessage();
        }
      });
    }
  }

  void _openChat(PantaProvider provider, ChatMessage msg) {
    _dismiss();
    provider.markChatAsRead(msg.requestId);

    RecyclingRequest? targetRequest;
    for (final req in provider.requests) {
      if (req.id == msg.requestId) {
        targetRequest = req;
        break;
      }
    }

    if (targetRequest != null) {
      ChatBottomSheet.show(
        context,
        request: targetRequest,
        isHelper: provider.isHelper,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final lastMsg = provider.lastIncomingChatMessage;

    // Trigger incoming notification if a new message arrived from the other party
    if (lastMsg != null &&
        lastMsg.id != _lastNotifiedMessageId &&
        !provider.isMessageSentByMe(lastMsg)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerNotification(lastMsg);
        }
      });
    }

    return Stack(
      children: [
        widget.child,
        if (_activeNotification != null)
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
                      message: _activeNotification!,
                      onOpen: () => _openChat(provider, _activeNotification!),
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
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _ChatBannerCard({
    required this.message,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0B3A22), // Deep Panta green
                Color(0xFF1B5E20), // Forest green
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF81C784),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Glowing Chat Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white70,
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mark_chat_unread_rounded,
                    color: Colors.white,
                    size: 24,
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
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
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
                  foregroundColor: const Color(0xFF0B3A22),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text(
                  'Open',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
