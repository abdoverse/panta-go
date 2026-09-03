import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/panta_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';
import 'create_request_page.dart';
import '../shared/profile_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Ensure animate is imported
import '../shared/widgets/loading_skeletons.dart'; // Import skeletons
import '../shared/widgets/location_actions.dart';
import '../tracking/live_map_tracking_view.dart';
import '../chat/chat_bottom_sheet.dart';
import '../analytics/impact_dashboard_view.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _currentIndex = 0;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket connection
    _connectWebSocket();
  }

  void _connectWebSocket() async {
    final token = await AuthService().getToken();
    if (token == null) return;

    final uri = ApiConfig.webSocketUri(queryParameters: {'token': token});

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          if (!mounted) return;
          context
              .read<PantaProvider>()
              .handleRealtimeMessage(message.toString());
        },
        onError: (error) {
          debugPrint('WS Error: $error');
          // Simple reconnect logic could go here
        },
        onDone: () {
          debugPrint('WS Closed');
        },
      );
    } catch (e) {
      debugPrint('WS Connection Error: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Force refresh data on hot reload to handle model changes
    context.read<PantaProvider>().fetchRequests(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _DashboardView(),
          const _HistoryView(),
          const ProfileScreen(isHelper: false),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: l10n.home),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: l10n.history),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: l10n.profileTitle),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                final provider = context.read<PantaProvider>();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CreateRequestPage(
                              startInQuickMode:
                                  provider.previousRequests.isNotEmpty ||
                                      provider.savedAddresses.isNotEmpty ||
                                      provider.requestTemplates.isNotEmpty,
                            )));
              },
              backgroundColor: AppTheme.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(l10n.recycleNow,
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final ongoing = provider.ongoingRequests;
    final history = provider.previousRequests;
    final latestRequest = history.isEmpty
        ? null
        : (history.toList()
              ..sort((a, b) => b.scheduledTo.compareTo(a.scheduledTo)))
            .first;
    final displayName = provider.currentUserDisplayName;
    final l10n = context.l10n;
    final hasQuickData = history.isNotEmpty ||
        provider.savedAddresses.isNotEmpty ||
        provider.requestTemplates.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<PantaProvider>().fetchRequests();
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            backgroundColor: AppTheme.primaryGreen,
            pinned: true,
            actions: [
              if (provider.userImpactSummary.streak.currentStreakWeeks > 0)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.userImpactSummary.streak.currentStreakWeeks}w',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ImpactDashboardView(isHelper: false),
                  ),
                ),
                icon: const Icon(Icons.insights, color: Colors.white),
                tooltip: 'Pant History & Eco Impact',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                l10n.welcomeBack(displayName),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.primaryGreen.withOpacity(0.8)
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(Icons.eco,
                          size: 150, color: Colors.white.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (provider.isLoading && ongoing.isEmpty)
            const SliverFillRemaining(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: LoadingSkeletons(),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasQuickData) ...[
                      _QuickRequestLauncher(
                        latestRequest: latestRequest,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(l10n.ongoingRequests,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (ongoing.isEmpty)
                      _EmptyState(message: l10n.noOngoingRequests)
                          .animate()
                          .fadeIn()
                          .scale(),
                    ...ongoing.asMap().entries.map((e) => _RequestCard(
                            request: e.value,
                            isInteractable: false,
                            index: e.key)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (100 * e.key).ms)
                        .slideX(begin: 0.1, end: 0)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final history = provider.previousRequests;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userHistoryTitle),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImpactDashboardView(isHelper: false),
              ),
            ),
            icon: const Icon(Icons.eco),
            label: const Text('Impact'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<PantaProvider>().fetchRequests();
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            return _RequestCard(
                request: history[index], isInteractable: true, index: index);
          },
        ),
      ),
    );
  }
}

class _QuickRequestLauncher extends StatelessWidget {
  const _QuickRequestLauncher({required this.latestRequest});

  final RecyclingRequest? latestRequest;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final theme = Theme.of(context);
    final recentAddressLabels = [
      ...provider.savedAddresses.map((address) => address.label),
      if (latestRequest != null) latestRequest!.location,
    ].take(3).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book in 30 seconds',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use your recent pickup details and confirm in one tap.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentAddressLabels.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentAddressLabels
                  .map(
                    (label) => Chip(
                      label: Text(label),
                      avatar: const Icon(Icons.history, size: 16),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (recentAddressLabels.isNotEmpty) const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateRequestPage(
                      initialRequest: latestRequest,
                      startInQuickMode: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Start quick request'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.recycling, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final RecyclingRequest request;
  final bool isInteractable;
  final int? index;

  const _RequestCard(
      {required this.request, this.isInteractable = false, this.index});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2, // Slight elevation
      shadowColor: Colors.black.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20), // Increased padding
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Text(
                      "#${index! + 1}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _RequestImage(imageUrl: request.imageUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      // Show Reward
                      Row(
                        children: [
                          Text(
                            "${AppConstants.currencySymbol}${(request.reward as num?)?.toStringAsFixed(0) ?? '0'}",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(20), // Pill shape
                            ),
                            child: Text(statusText.toUpperCase(),
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        // Added icon for schedule
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey[500]),
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
                      if (request.receiptAmount != null && request.receiptAmount! > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.receipt, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified Pant: ${request.receiptAmount!.toStringAsFixed(2)} SEK',
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_wallet, size: 14, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Your Payout: ${(request.recyclerPayout ?? (request.receiptAmount! * request.splitPercentage / 100)).toStringAsFixed(2)} SEK',
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.door_front_door_outlined, size: 12, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text(
                                    'Leave at Door',
                                    style: TextStyle(
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
                                      title: const Row(
                                        children: [
                                          Icon(Icons.photo_camera, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('Drop-off Photo Proof'),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Helper confirmed pickup at door:',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 160,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check_circle, size: 40, color: Colors.green),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Photo Verified by Helper',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
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
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_camera, size: 12, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text(
                                        'View Photo Proof ✓',
                                        style: TextStyle(
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
              const SizedBox(height: 12),
              LiveMapTrackingView(request: request),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => ChatBottomSheet.show(
                    context,
                    request: request,
                    isHelper: false,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Chat with Helper'),
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
                    label: const Text('Book again'),
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
    // We need a stateful widget inside the dialog to manage the text controller or selection state
    // But since we just click a star to submit, we can just add a text field and a submit button.
    // Or keep the star-click-to-submit flow but make it weirder with comment.
    // Better: Select stars, type comment, then click "Submit".

    final commentController = TextEditingController();
    double currentRating = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      }),
    );
  }
}

class _RequestImage extends StatelessWidget {
  final String? imageUrl;

  const _RequestImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = imageUrl?.trim();
    if (normalizedImageUrl == null || normalizedImageUrl.isEmpty) {
      return _fallbackImage();
    }

    final hasRemoteSource = normalizedImageUrl.startsWith('http') ||
        normalizedImageUrl.startsWith('data:image/');

    if (hasRemoteSource) {
      return Image.network(
        normalizedImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }

    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Container(
      color: AppTheme.primaryGreen.withOpacity(0.08),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.primaryGreen,
        size: 28,
      ),
    );
  }
}
