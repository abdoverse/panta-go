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
import '../../core/widgets/responsive_layout.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Ensure animate is imported
import '../shared/widgets/loading_skeletons.dart'; // Import skeletons
import '../analytics/impact_dashboard_view.dart';
import 'widgets/user_request_card.dart';

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

    return AdaptiveNavigationScaffold(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      appTitle: 'Panta',
      roleBadge: 'Recycler',
      destinations: [
        AdaptiveNavigationDestination(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: l10n.home,
        ),
        AdaptiveNavigationDestination(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
          label: l10n.history,
        ),
        AdaptiveNavigationDestination(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: l10n.profileTitle,
        ),
      ],
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
                    ),
                  ),
                );
              },
              backgroundColor: AppTheme.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                l10n.recycleNow,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardView(),
          _HistoryView(),
          ProfileScreen(isHelper: false),
        ],
      ),
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
              child: ResponsiveContainer(
                maxWidth: Responsive.maxDashboardWidth,
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
                    Text(
                      l10n.ongoingRequests,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (ongoing.isEmpty)
                      _EmptyState(message: l10n.noOngoingRequests)
                          .animate()
                          .fadeIn()
                          .scale()
                    else
                      ResponsiveCardGrid(
                        children: ongoing
                            .asMap()
                            .entries
                            .map((e) => UserRequestCard(
                                  request: e.value,
                                  isInteractable: false,
                                  index: e.key,
                                )
                                    .animate()
                                    .fadeIn(
                                      duration: 400.ms,
                                      delay: (100 * e.key).ms,
                                    )
                                    .slideX(begin: 0.1, end: 0))
                            .toList(),
                      ),
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
        child: ResponsiveContainer(
          maxWidth: Responsive.maxDashboardWidth,
          child: history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(l10n.noOngoingRequests),
                  ),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ResponsiveCardGrid(
                      children: history
                          .asMap()
                          .entries
                          .map(
                            (e) => UserRequestCard(
                              request: e.value,
                              isInteractable: true,
                              index: e.key,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
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

