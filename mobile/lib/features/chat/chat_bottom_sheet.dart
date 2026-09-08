import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';
import '../../models/chat_message.dart';
import '../../providers/panta_provider.dart';

class ChatBottomSheet extends StatefulWidget {
  final RecyclingRequest request;
  final bool isHelper;

  const ChatBottomSheet({
    super.key,
    required this.request,
    required this.isHelper,
  });

  static void show(
    BuildContext context, {
    required RecyclingRequest request,
    required bool isHelper,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Let the sheet resize when keyboard appears
      builder: (context) => ChatBottomSheet(
        request: request,
        isHelper: isHelper,
      ),
    );
  }

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  Timer? _pollingTimer;
  PantaProvider? _provider;
  late types.User _currentUser;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PantaProvider>();
    _provider?.setActiveChatRequestId(widget.request.id);

    final pId = _provider?.currentUserId ?? 'unknown';
    final pName = _provider?.currentUserDisplayName ?? 'Me';
    _currentUser = types.User(id: pId, firstName: pName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PantaProvider>().fetchChatMessages(widget.request.id);
        context.read<PantaProvider>().markChatAsRead(widget.request.id);
      }
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        context.read<PantaProvider>().fetchChatMessages(widget.request.id);
        context.read<PantaProvider>().markChatAsRead(widget.request.id);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _provider?.setActiveChatRequestId(null);
    super.dispose();
  }

  void _handleSendPressed(types.PartialText message) async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    await context.read<PantaProvider>().sendChatMessage(
      widget.request.id,
      text,
      isPreset: false,
    );
  }

  String get _otherPersonName {
    if (widget.isHelper) {
      final name = widget.request.creatorName;
      return name != null && name.isNotEmpty ? name.split(' ').first : 'Recycler';
    } else {
      final name = widget.request.helperName;
      return name != null && name.isNotEmpty ? name.split(' ').first : 'Helper';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to correctly handle keyboard insets — the sheet itself
    // sits above the keyboard because showModalBottomSheet handles this natively.
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.9],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag Handle ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accentLeaf,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _otherPersonName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Active now',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Close button — fixed size, never overlaps
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Material(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────────
              const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),

              // ── Quick Presets ─────────────────────────────────────────────
              Consumer<PantaProvider>(
                builder: (context, provider, _) {
                  final presets = widget.isHelper
                      ? ChatMessage.helperPresets
                      : ChatMessage.recyclerPresets;

                  return SizedBox(
                    height: 52,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: presets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final preset = presets[index];
                        return GestureDetector(
                          onTap: () {
                            _handleSendPressed(types.PartialText(text: preset));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentLeaf,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              preset,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),

              // ── Flyer Chat ───────────────────────────────────────────────
              Expanded(
                child: Consumer<PantaProvider>(
                  builder: (context, provider, _) {
                    final req = provider.requests.firstWhere(
                      (r) => r.id == widget.request.id,
                      orElse: () => widget.request,
                    );

                    final flyerMessages = req.messages.reversed
                        .map((m) => m.toFlyerMessage())
                        .toList();

                    return Chat(
                      messages: flyerMessages,
                      onSendPressed: _handleSendPressed,
                      user: _currentUser,
                      showUserAvatars: false,
                      showUserNames: false,
                      inputOptions: const InputOptions(
                        sendButtonVisibilityMode: SendButtonVisibilityMode.always,
                      ),
                      l10n: const ChatL10nEn(
                        inputPlaceholder: 'Type a message...',
                      ),
                      theme: DefaultChatTheme(
                        primaryColor: AppTheme.primaryGreen,
                        secondaryColor: AppTheme.surfaceGrey,
                        backgroundColor: AppTheme.surfaceWhite,
                        // Input bar styling
                        inputBackgroundColor: AppTheme.surfaceGrey,
                        inputTextColor: AppTheme.textPrimary,
                        inputBorderRadius: BorderRadius.circular(28),
                        inputMargin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        inputPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8,
                        ),
                        inputTextStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: AppTheme.textPrimary,
                        ),
                        inputTextDecoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12,
                          ),
                        ),
                        // Message bubble styling
                        messageBorderRadius: 20,
                        messageInsetsHorizontal: 14,
                        messageInsetsVertical: 10,
                        sentMessageBodyTextStyle: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.4,
                        ),
                        receivedMessageBodyTextStyle: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                        // Date divider
                        dateDividerTextStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          letterSpacing: 0.4,
                        ),
                        // Timestamps
                        sentMessageCaptionTextStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        receivedMessageCaptionTextStyle: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
