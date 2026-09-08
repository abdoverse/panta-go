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
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ChatBottomSheet(
          request: request,
          isHelper: isHelper,
        ),
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
    
    // Set up the current user for Flyer Chat
    final pId = _provider?.currentUserId ?? 'unknown';
    final pName = _provider?.currentUserDisplayName ?? 'Me';
    _currentUser = types.User(id: pId, firstName: pName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PantaProvider>().fetchChatMessages(widget.request.id);
        context.read<PantaProvider>().markChatAsRead(widget.request.id);
      }
    });
    
    // Fallback polling every 3 seconds while chat sheet is open
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

    final provider = context.read<PantaProvider>();
    await provider.sendChatMessage(
      widget.request.id,
      text,
      isPreset: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate height so it takes 85% of screen, but shrinks when keyboard opens
    final availableHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final targetHeight = (availableHeight * 0.85) - keyboardHeight;
    
    return Container(
      height: targetHeight > 0 ? targetHeight : availableHeight * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                    child: const Icon(Icons.support_agent,
                        color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isHelper 
                              ? 'Chat with ${widget.request.creatorName?.split(' ').first ?? 'Recycler'}' 
                              : 'Chat with ${widget.request.helperName?.split(' ').first ?? 'Helper'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${widget.request.id.substring(0, 8)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Chat UI
            Expanded(
              child: Consumer<PantaProvider>(
                builder: (context, provider, child) {
                  final req = provider.requests.firstWhere(
                    (r) => r.id == widget.request.id,
                    orElse: () => widget.request,
                  );
                  
                  // Convert Go ChatMessages to Flyer Chat Messages
                  // Note: FlyerHQ expects the list in reverse chronological order (newest first)
                  final flyerMessages = req.messages.reversed.map((msg) {
                    return msg.toFlyerMessage();
                  }).toList();

                  final presets = widget.isHelper 
                      ? ChatMessage.helperPresets 
                      : ChatMessage.recyclerPresets;

                  return Column(
                    children: [
                      Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: presets.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final preset = presets[index];
                            return ActionChip(
                              label: Text(preset, style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppTheme.primaryGreen.withOpacity(0.08),
                              side: BorderSide(
                                  color: AppTheme.primaryGreen.withOpacity(0.3)),
                              onPressed: () {
                                _handleSendPressed(types.PartialText(text: preset));
                              },
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: Chat(
                          messages: flyerMessages,
                          onSendPressed: _handleSendPressed,
                          user: _currentUser,
                          showUserAvatars: true,
                          showUserNames: true,
                          inputOptions: const InputOptions(
                            sendButtonVisibilityMode: SendButtonVisibilityMode.always,
                          ),
                          l10n: const ChatL10nEn(
                            inputPlaceholder: 'Type a message...',
                          ),
                          theme: DefaultChatTheme(
                            primaryColor: AppTheme.primaryGreen,
                            secondaryColor: const Color(0xFFF0F0F0),
                            backgroundColor: Colors.white,
                            inputBackgroundColor: const Color(0xFFF5F5F5),
                            inputTextColor: Colors.black87,
                            inputBorderRadius: BorderRadius.circular(24),
                            inputMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            inputPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            messageBorderRadius: 18,
                            dateDividerTextStyle: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
