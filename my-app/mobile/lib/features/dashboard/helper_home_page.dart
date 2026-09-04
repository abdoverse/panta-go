import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/widgets/responsive_layout.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/panta_provider.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../analytics/impact_dashboard_view.dart';
import '../shared/profile_screen.dart';
import '../shared/widgets/loading_skeletons.dart';
import 'widgets/helper_job_card.dart';

class HelperHomePage extends StatefulWidget {
  const HelperHomePage({super.key});

  @override
  State<HelperHomePage> createState() => _HelperHomePageState();
}

class _HelperHomePageState extends State<HelperHomePage> {
  int _currentIndex = 0;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket connection
    _connectWebSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PantaProvider>().refreshHelperLocation();
    });
  }

  void _connectWebSocket() async {
    final token = await AuthService().getToken();
    if (token == null) {
      debugPrint('WS Error: No Auth Token available');
      return;
    }

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
      roleBadge: 'Helper',
      destinations: [
        AdaptiveNavigationDestination(
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore,
          label: l10n.available,
        ),
        AdaptiveNavigationDestination(
          icon: Icons.check_circle_outline,
          selectedIcon: Icons.check_circle,
          label: l10n.myJobs,
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
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _MarketplaceView(),
          _MyJobsView(),
          _HistoryView(),
          ProfileScreen(isHelper: true),
        ],
      ),
    );
  }
}

class _MarketplaceView extends StatelessWidget {
  const _MarketplaceView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final jobs = provider.availableJobs;
    final displayName = provider.currentUserDisplayName;
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<PantaProvider>().refreshHelperLocation();
        await context.read<PantaProvider>().fetchRequests();
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: AppTheme.primaryGreen,
            pinned: true,
            actions: [
              if (provider.helperImpactSummary.streak.currentStreakWeeks > 0)
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
                        '${provider.helperImpactSummary.streak.currentStreakWeeks}w',
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
                    builder: (_) => const ImpactDashboardView(isHelper: true),
                  ),
                ),
                icon: const Icon(Icons.insights, color: Colors.white),
                tooltip: 'Earnings & Impact',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                l10n.welcomeBack(displayName),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.eco,
                      size: 100, color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
          ),
          if (provider.isLoading && jobs.isEmpty)
            const SliverFillRemaining(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: MarketplaceSkeleton(),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: provider.isSortingJobsByDistance
                            ? AppTheme.accentLeaf
                            : AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            provider.isSortingJobsByDistance
                                ? Icons.near_me_rounded
                                : Icons.location_disabled_outlined,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              provider.isSortingJobsByDistance
                                  ? l10n.closestJobsMessage
                                  : l10n.enableLocationMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (provider.isResolvingHelperLocation)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (jobs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(l10n.noJobsAvailable),
                        ),
                      )
                          .animate()
                          .fadeIn()
                    else
                      ResponsiveCardGrid(
                        children: jobs
                            .asMap()
                            .entries
                            .map((e) => HelperJobCard(
                                  job: e.value,
                                  isAcceptable: true,
                                  index: e.key,
                                )
                                    .animate()
                                    .fadeIn(delay: (100 * e.key).ms)
                                    .slideY(begin: 0.1, end: 0))
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

class _MyJobsView extends StatelessWidget {
  const _MyJobsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final jobs = provider.acceptedJobs;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myActiveJobs)),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<PantaProvider>().fetchRequests();
        },
        child: jobs.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(l10n.noActiveJobs,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              l10n.availableTabPrompt,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : ResponsiveContainer(
                maxWidth: Responsive.maxDashboardWidth,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ResponsiveCardGrid(
                      children: jobs
                          .asMap()
                          .entries
                          .map(
                            (e) => HelperJobCard(
                              job: e.value,
                              isAcceptable: false,
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

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final jobs = provider.completedJobs;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickupHistory),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImpactDashboardView(isHelper: true),
              ),
            ),
            icon: const Icon(Icons.insights),
            label: const Text('Earnings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<PantaProvider>().fetchRequests();
        },
        child: jobs.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: Text(l10n.noCompletedJobsYet)),
                  ),
                ),
              )
            : ResponsiveContainer(
                maxWidth: Responsive.maxDashboardWidth,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ResponsiveCardGrid(
                      children: jobs
                          .asMap()
                          .entries
                          .map(
                            (e) => HelperJobCard(
                              job: e.value,
                              isAcceptable: false,
                              isCompleted: true,
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

