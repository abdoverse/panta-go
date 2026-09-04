import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../models/request_model.dart';
import '../../providers/panta_provider.dart';

class ChatBottomSheet extends StatefulWidget {
  final RecyclingRequest request;
  final bool isHelper;

  const ChatBottomSheet({
    super.key,
    required this.request,
    this.isHelper = false,
  });

  static Future<void> show(
    BuildContext context, {
    required RecyclingRequest request,
    bool isHelper = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatBottomSheet(
        request: request,
        isHelper: isHelper,
      ),
    );
  }

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Fetch initial chat messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PantaProvider>().fetchChatMessages(widget.request.id);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, {bool isPreset = false}) async {
    final clean = text.trim();
    if (clean.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    final ok = await context.read<PantaProvider>().sendChatMessage(
          widget.request.id,
          clean,
          isPreset: isPreset,
        );

    if (mounted) {
      setState(() => _isSending = false);
      if (ok) {
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final currentReq = provider.myRequests.firstWhere(
      (r) => r.id == widget.request.id,
      orElse: () => widget.request,
    );
    final messages = currentReq.messages;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final presets = widget.isHelper
        ? ChatMessage.helperPresets
        : ChatMessage.recyclerPresets;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: widget.isHelper
                    ? AppTheme.primaryGreen.withOpacity(0.15)
                    : Colors.blue.withOpacity(0.15),
                child: Icon(
                  widget.isHelper ? Icons.person : Icons.recycling,
                  color: widget.isHelper ? AppTheme.primaryGreen : Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isHelper ? 'Chat with Recycler' : 'Chat with Helper',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      widget.request.title,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send a quick preset message or type below.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = widget.isHelper
                          ? msg.senderRole == 'helper'
                          : msg.senderRole == 'user';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.primaryGreen : Colors.grey.shade100,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                            border: isMe ? null : Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Preset Quick Message Chips
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = presets[index];
                return ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.08),
                  side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.3)),
                  onPressed: () {
                    if (preset.endsWith(': ')) {
                      _textController.text = preset;
                    } else {
                      _sendMessage(preset, isPreset: true);
                    }
                  },
                );
              },
            ),
          ),
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (t) => _sendMessage(t),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
}
}
