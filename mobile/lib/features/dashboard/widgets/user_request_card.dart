import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/request_model.dart';
import '../../../providers/panta_provider.dart';
import '../../chat/chat_bottom_sheet.dart';
import '../../shared/widgets/location_actions.dart';
import '../../tracking/live_map_tracking_view.dart';
import '../../../services/api_config.dart';
import '../create_request_page.dart';
import 'index_badge.dart';

class UserRequestCard extends StatelessWidget {
  final RecyclingRequest request;
  final bool isInteractable;
  final int? index;

  const UserRequestCard({
    super.key,
    required this.request,
    this.isInteractable = false,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<PantaProvider>();
    Color statusColor;
    String statusText;

    switch (request.status) {
      case RequestStatus.pending:
        statusColor = Colors.orange;
        statusText = l10n.waitingForHelper;
        break;
      case RequestStatus.accepted:
        statusColor = Colors.blue;
        statusText = l10n.helperOnTheWay;
        break;
      case RequestStatus.pickedUp:
        statusColor = Colors.green;
        statusText = l10n.pickedUp;
        break;
      case RequestStatus.canceled:
        statusColor = Colors.grey;
        statusText = l10n.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: IndexBadge(index: index!),
                  ),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RequestImage(imageUrl: request.imageUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            "${AppConstants.currencySymbol}${(request.reward as num?)?.toStringAsFixed(0) ?? '0'}",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusText.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // Bank ID chips removed visually per request
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${DateFormat('d MMM, HH:mm', l10n.localeName).format(request.scheduledFrom)} - ${DateFormat('HH:mm', l10n.localeName).format(request.scheduledTo)}",
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LocationActions(address: request.location),
                      if (request.receiptAmount != null &&
                          request.receiptAmount! > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.receipt,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.verifiedPantValue(request.receiptAmount!.toStringAsFixed(2)),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.teal.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet,
                                    size: 14,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.yourPayoutAmount((request.recyclerPayout ?? (request.receiptAmount! * request.splitPercentage / 100)).toStringAsFixed(2)),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (request.leaveAtDoor) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.door_front_door_outlined,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.leaveAtDoor,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.brown,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (request.dropoffPhotoUrl != null &&
                                request.dropoffPhotoUrl!.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(
                                            Icons.photo_camera,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 8),
                                          Text(context.l10n.dropoffPhotoProof),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            l10n.helperConfirmedPickupAtDoor,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 160,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle,
                                                    size: 40,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    l10n.photoVerifiedByHelper,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text(context.l10n.close),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.photo_camera,
                                        size: 12,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.viewPhotoProof,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (request.status == RequestStatus.accepted) ...[
              if (request.arrivedAtDoor != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🛎️', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.helperOutsideYourDoor,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.brown,
                              ),
                            ),
                            Text(
                              request.leaveAtDoor
                                  ? l10n.bagsCanBePickedUpOutsideDoor
                                  : l10n.pleaseOpenDoorToHandOverBags,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.brown.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LiveMapTrackingView(request: request),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final hasUnread = provider.hasUnreadChat(request.id);
                  final unreadCount = provider.getUnreadChatCount(request.id);
                  final messages = provider.getChatMessages(request.id);
                  final latestMsg = messages.isNotEmpty ? messages.last : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasUnread && latestMsg != null) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  AppTheme.primaryGreen.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              provider.markChatAsRead(request.id);
                              ChatBottomSheet.show(
                                context,
                                request: request,
                                isHelper: false,
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mark_chat_unread_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            latestMsg.senderName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.primaryGreen,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              l10n.unreadCountBadge(unreadCount),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        latestMsg.text,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.primaryGreen,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: hasUnread
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () {
                                  provider.markChatAsRead(request.id);
                                  ChatBottomSheet.show(
                                    context,
                                    request: request,
                                    isHelper: false,
                                  );
                                },
                                icon: const Icon(
                                  Icons.mark_chat_unread_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  l10n.chatWithHelperNew(unreadCount),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () {
                                  provider.markChatAsRead(request.id);
                                  ChatBottomSheet.show(
                                    context,
                                    request: request,
                                    isHelper: false,
                                  );
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                ),
                                label: Text(
                                  messages.isNotEmpty
                                      ? l10n.chatWithHelperCount(messages.length)
                                      : l10n.chatWithHelper,
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (request.status == RequestStatus.pending) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.pausePickupTitle),
                        content: Text(l10n.pausePickupContent),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.pausePickupNo),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.pausePickupYes),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await provider.cancelRequest(request.id);
                    }
                  },
                  icon: const Icon(Icons.pause_circle_outline),
                  label: Text(l10n.pausePickup),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (isInteractable)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateRequestPage(
                            initialRequest: request,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.l10n.bookAgain),
                  ),
                  if (request.status == RequestStatus.pickedUp &&
                      !request.isRated)
                    OutlinedButton(
                      onPressed: () {
                        _showRatingDialog(context, request);
                      },
                      child: Text(l10n.rateHelper),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, RecyclingRequest request) {
    final l10n = context.l10n;
    final commentController = TextEditingController();
    double currentRating = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.rateYourHelper),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.howWasPickupService),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final int starValue = index + 1;
                    return IconButton(
                      onPressed: () {
                        setState(() {
                          currentRating = starValue.toDouble();
                        });
                      },
                      icon: Icon(
                        starValue <= currentRating
                            ? Icons.star
                            : Icons.star_border,
                        size: 32,
                        color: Colors.amber,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: l10n.optionalCommentHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: currentRating > 0
                    ? () {
                        context.read<PantaProvider>().rateHelper(
                              request.id,
                              currentRating,
                              comment: commentController.text.isNotEmpty
                                  ? commentController.text
                                  : null,
                            );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.thankYouForRating)),
                        );
                      }
                    : null,
                child: Text(l10n.submit),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RequestImage extends StatelessWidget {
  final String? imageUrl;

  const RequestImage({super.key, required this.imageUrl});

  static String? resolveUrl(String? rawUrl) {
    var url = rawUrl?.trim();
    if (url == null || url.isEmpty || url == 'assets/images/generic.png') {
      return null;
    }
    if (url.contains('.console.aws.amazon.com/s3/') ||
        url.contains('console.aws.amazon.com')) {
      final uri = Uri.tryParse(url);
      final prefix =
          uri?.queryParameters['prefix'] ?? uri?.queryParameters['key'];
      if (prefix != null && prefix.isNotEmpty) {
        url = '/api/v1/images/$prefix';
      }
    }
    if (url.startsWith('/')) {
      return ApiConfig.apiUri(url).toString();
    }
    return url;
  }

  static void showPreview(BuildContext context, String fullUrl) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                constraints: const BoxConstraints(maxHeight: 500),
                child: InteractiveViewer(
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(context.l10n.imageNotAvailable,
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveUrl(imageUrl);
    if (resolvedUrl == null) {
      return _fallbackImage();
    }

    final hasRemoteSource =
        resolvedUrl.startsWith('http') || resolvedUrl.startsWith('data:image/');

    if (hasRemoteSource) {
      return InkWell(
        onTap: () => showPreview(context, resolvedUrl),
        child: Image.network(
          resolvedUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackImage(),
        ),
      );
    }

    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Container(
      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.primaryGreen,
        size: 28,
      ),
    );
  }
}
