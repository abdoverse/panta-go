import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/panta_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import 'create_request_page.dart';
import '../shared/profile_screen.dart';
import '../../services/realtime_service.dart';
import '../../core/widgets/responsive_layout.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../shared/widgets/loading_skeletons.dart';
import '../analytics/impact_dashboard_view.dart';
import 'widgets/user_request_card.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    RealtimeService.instance.addHandler(_handleRealtimeMessage);
    RealtimeService.instance.connect();
  }

  void _handleRealtimeMessage(String message) {
    if (!mounted) return;
    context.read<PantaProvider>().handleRealtimeMessage(message);
  }

  @override
  void dispose() {
    RealtimeService.instance.removeHandler(_handleRealtimeMessage);
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
      roleBadge: l10n.recyclerRole,
      destinations: [
        AdaptiveNavigationDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: l10n.home,
        ),
        AdaptiveNavigationDestination(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history_rounded,
          label: l10n.history,
        ),
        AdaptiveNavigationDestination(
          icon: Icons.person_outline,
          selectedIcon: Icons.person_rounded,
          label: l10n.profileTitle,
        ),
      ],
      // Removed the FAB for a cleaner, less noisy look
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
    final displayName = provider.currentUserDisplayName;
    final l10n = context.l10n;
    final streak = provider.userImpactSummary.streak.currentStreakWeeks;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<PantaProvider>().fetchRequests(),
          context.read<PantaProvider>().fetchMarketNotifications(silent: true),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        children: [
          // DEBUG BANNER (To verify hot reloads)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Latest Change: Automated watcher removed, exceptions fixed, & dev loop fully managed by agent! (Safe port 3000)",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          // Header Row: Greeting + Optional Streak Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dynamicGreeting(displayName),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
                    const SizedBox(height: 8),
                    Text(
                      "Ready to clear out some space?",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                  ],
                ),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.streakWeeksShort(streak),
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
            ],
          ),

          const SizedBox(height: 48),

          // Main Call to Action - Big, soft, friendly button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateRequestPage(
                    startInQuickMode: provider.previousRequests.isNotEmpty ||
                        provider.savedAddresses.isNotEmpty ||
                        provider.requestTemplates.isNotEmpty,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.recycling_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Create a Pickup",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We'll come get your bags!",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms).scale(curve: Curves.easeOutBack),

          const SizedBox(height: 48),

          // Ongoing requests section
          if (provider.isLoading && ongoing.isEmpty)
             const LoadingSkeletons()
          else if (ongoing.isNotEmpty) ...[
            Text(
              l10n.ongoingRequests,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),
            ...ongoing.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: UserRequestCard(
                    request: e.value,
                    isInteractable: false,
                    index: e.key,
                  ).animate().fadeIn(duration: 400.ms, delay: (100 * e.key).ms),
                )),
          ],
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(l10n.userHistoryTitle),
        elevation: 0,
        backgroundColor: Colors.grey.shade50,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImpactDashboardView(isHelper: false),
              ),
            ),
            icon: const Icon(Icons.eco_rounded),
            label: Text(context.l10n.impact),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noOngoingRequests,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: UserRequestCard(
                        request: history.elementAt(index),
                        isInteractable: true,
                        index: index,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

