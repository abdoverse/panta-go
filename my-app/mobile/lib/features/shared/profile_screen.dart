import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/panta_provider.dart';
import '../auth/login_page.dart';

class ProfileScreen extends StatelessWidget {
  final bool isHelper;

  const ProfileScreen({super.key, required this.isHelper});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final displayName = provider.currentUserDisplayName?.trim();
    final resolvedName = (displayName == null || displayName.isEmpty)
        ? (isHelper ? 'Helper' : 'Recycler')
        : displayName;
    final subtitle = isHelper ? 'Helper' : 'Recycler';
    final avatarIcon =
        isHelper ? Icons.local_shipping_rounded : Icons.person_rounded;
    final completedJobs = provider.helperCompletedCount;
    final canceledPickups = provider.helperCancellationCount;
    final averageRating = provider.helperAverageRating;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.accentLeaf,
                    child: Icon(
                      avatarIcon,
                      size: 34,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    resolvedName,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLeaf,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.primaryGreen,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (isHelper) ...[
            Text(
              'Helper stats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _HelperStatTile(
                            icon: Icons.task_alt_rounded,
                            label: 'Completed jobs',
                            value: '$completedJobs',
                            iconColor: AppTheme.primaryGreen,
                            backgroundColor: AppTheme.accentLeaf,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HelperStatTile(
                            icon: Icons.cancel_outlined,
                            label: 'Cancelled pickups',
                            value: '$canceledPickups',
                            iconColor: Theme.of(context).colorScheme.error,
                            backgroundColor: const Color(0xFFFEE2E2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _HelperSummaryRow(
                      icon: Icons.star_rounded,
                      title: 'Recycler rating',
                      value: averageRating == null
                          ? 'No ratings yet'
                          : '${averageRating.toStringAsFixed(1)} / 5',
                    ),
                    const SizedBox(height: 8),
                    _HelperSummaryRow(
                      icon: Icons.insights_rounded,
                      title: 'Reliability context',
                      value:
                          '$completedJobs completed · $canceledPickups cancelled',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                _ProfileItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Manage app preferences',
                ),
                Divider(height: 1),
                _ProfileItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Stay updated on activity',
                ),
                Divider(height: 1),
                _ProfileItem(
                  icon: Icons.eco_outlined,
                  title: 'Impact stats',
                  subtitle: 'Track your recycling contribution',
                ),
                Divider(height: 1),
                _ProfileItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & support',
                  subtitle: 'Get help when you need it',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: _ProfileItem(
              icon: Icons.logout_rounded,
              title: 'Log out',
              subtitle: 'Return to the sign in screen',
              textColor: Theme.of(context).colorScheme.error,
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HelperStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color backgroundColor;

  const _HelperStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _HelperSummaryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _HelperSummaryRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? textColor;

  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = textColor ?? AppTheme.textPrimary;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: textColor ?? AppTheme.textSecondary, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: resolvedTextColor,
            ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
    );
  }
}
