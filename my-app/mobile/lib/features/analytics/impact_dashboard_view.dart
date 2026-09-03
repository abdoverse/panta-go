import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
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
  bool _isLoading = true;

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
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final fallbackSummary = widget.isHelper
        ? provider.helperImpactSummary
        : provider.userImpactSummary;
    final summary = _remoteSummary ?? fallbackSummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isHelper ? 'My Earnings & Impact' : 'Pant History & Eco Impact'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      color: Colors.green.withOpacity(0.3),
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
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.eco, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isHelper ? 'Total Helper Earnings' : 'Total Pant Refund',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              '${summary.totalEarnings.toStringAsFixed(2)} SEK',
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
                      widget.isHelper
                          ? 'You helped recycle ${summary.containersRecycled} containers across ${summary.totalPickups} completed pickups!'
                          : 'You recycled ${summary.containersRecycled} containers and offset carbon emissions with Panta Go!',
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4 Core Impact Metrics
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.recycling_rounded,
                      iconColor: Colors.teal,
                      title: 'Containers',
                      value: '${summary.containersRecycled}',
                      subtitle: 'Cans & bottles',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.cloud_outlined,
                      iconColor: Colors.blue,
                      title: 'CO₂ Saved',
                      value: '${summary.co2SavedKg} kg',
                      subtitle: 'Emissions avoided',
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
                      title: 'Trees Plated',
                      value: '${summary.treesEquivalent}',
                      subtitle: 'Equivalent absorption',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.task_alt,
                      iconColor: Colors.indigo,
                      title: 'Pickups',
                      value: '${summary.totalPickups}',
                      subtitle: 'Completed cycles',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Activity History Title
              Text(
                'Pickup Activity & Contribution',
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
                        'No completed pickups yet',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete your first recycling pickup to build your impact metrics!',
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
                              color: AppTheme.primaryGreen.withOpacity(0.1),
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
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.completedAt.year}-${item.completedAt.month.toString().padLeft(2, '0')}-${item.completedAt.day.toString().padLeft(2, '0')} • Verified: ${item.receiptAmount.toStringAsFixed(2)} SEK',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${item.earnings.toStringAsFixed(2)} SEK',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '-${item.co2SavedKg} kg CO₂',
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
