import '../../core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/impact_summary.dart';
import '../../providers/panta_provider.dart';

class ImpactDashboardView extends StatefulWidget {
  final bool isHelper;

  const ImpactDashboardView({
    super.key,
    this.isHelper = false,
  });

  @override
  State<ImpactDashboardView> createState() => _ImpactDashboardViewState();
}

class _ImpactDashboardViewState extends State<ImpactDashboardView> {
  ImpactSummary? _remoteSummary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final res = await context.read<PantaProvider>().fetchImpactAnalytics();
    if (mounted) {
      setState(() {
        _remoteSummary = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<PantaProvider>();
    final fallbackSummary = widget.isHelper
        ? provider.helperImpactSummary
        : provider.userImpactSummary;
    final summary = _remoteSummary ?? fallbackSummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isHelper ? l10n.myEarningsAndImpact : l10n.pantHistoryAndEcoImpact),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsiveContainer(
            maxWidth: 840,
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sustainability Eco Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.eco, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isHelper ? l10n.totalHelperEarnings : l10n.totalPantRefund,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              l10n.amountSek(summary.totalEarnings.toStringAsFixed(2)),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isHelper ? l10n.helperImpactDescription(summary.containersRecycled, summary.totalPickups) : l10n.recyclerImpactDescription(summary.containersRecycled),
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recycling Streak Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.streak.currentStreakWeeks > 0 ? l10n.weekStreakTitle(summary.streak.currentStreakWeeks) : l10n.startStreakTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            summary.streak.currentStreakWeeks > 0 ? l10n.keepRecyclingWeeklySubtitle : l10n.igniteFlameSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 Core Impact Metrics
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.recycling_rounded,
                      iconColor: Colors.teal,
                      title: l10n.impactContainers,
                      value: '${summary.containersRecycled}',
                      subtitle: l10n.impactCansBottles,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.cloud_outlined,
                      iconColor: Colors.blue,
                      title: l10n.impactCo2Saved,
                      value: '${summary.co2SavedKg} kg',
                      subtitle: l10n.impactEmissionsAvoided,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.forest_outlined,
                      iconColor: Colors.green,
                      title: l10n.impactTreesPlanted,
                      value: '${summary.treesEquivalent}',
                      subtitle: l10n.impactEquivalentAbsorption,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.task_alt,
                      iconColor: Colors.indigo,
                      title: l10n.impactPickups,
                      value: '${summary.totalPickups}',
                      subtitle: l10n.impactCompletedCycles,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Badges and Achievements
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.ecoBadgesAndMilestones,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    l10n.badgesUnlockedCount(summary.badges.where((b) => b.isUnlocked).length, summary.badges.length),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: summary.badges.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final badge = summary.badges[index];
                    return Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: badge.isUnlocked ? Colors.amber.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: badge.isUnlocked ? Colors.amber.shade400 : Colors.grey.shade300,
                          width: badge.isUnlocked ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(badge.icon, style: const TextStyle(fontSize: 24)),
                              if (badge.isUnlocked)
                                const Icon(Icons.check_circle, color: Colors.amber, size: 18)
                              else
                                Text(
                                  '${(badge.progress * 100).toInt()}%',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            l10n.badgeTitle(badge.id, fallback: badge.title),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l10n.badgeDescription(badge.id, fallback: badge.description),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Activity History Title
              Text(
                l10n.pickupActivityTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),

              if (summary.recentActivity.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        l10n.noCompletedPickupsYet,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.completeFirstPickupSubtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: summary.recentActivity.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = summary.recentActivity[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long, color: AppTheme.primaryGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title == 'Pickup' ? l10n.pantPickup : item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.verifiedDateAndAmount("${item.completedAt.year}-${item.completedAt.month.toString().padLeft(2, '0')}-${item.completedAt.day.toString().padLeft(2, '0')}", item.receiptAmount.toStringAsFixed(2)),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l10n.plusAmountSek(item.earnings.toStringAsFixed(2)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.co2SavedKg(item.co2SavedKg.toStringAsFixed(1)),
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
