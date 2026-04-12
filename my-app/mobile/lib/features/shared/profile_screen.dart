import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/panta_provider.dart';

String _formatRating(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class ProfileScreen extends StatelessWidget {
  final bool isHelper;

  const ProfileScreen({super.key, required this.isHelper});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final l10n = context.l10n;
    final displayName = provider.currentUserDisplayName?.trim();
    final resolvedName = (displayName == null || displayName.isEmpty)
        ? (isHelper ? l10n.helperRole : l10n.recyclerRole)
        : displayName;
    final subtitle = isHelper ? l10n.helperRole : l10n.recyclerRole;
    final avatarIcon =
        isHelper ? Icons.local_shipping_rounded : Icons.person_rounded;
    final completedJobs = provider.helperCompletedCount;
    final canceledPickups = provider.helperCancellationCount;
    final reliabilityRating = provider.helperReliabilityRating;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
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
              l10n.helperStats,
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
                            label: l10n.completedJobs,
                            value: '$completedJobs',
                            iconColor: AppTheme.primaryGreen,
                            backgroundColor: AppTheme.accentLeaf,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HelperStatTile(
                            icon: Icons.cancel_outlined,
                            label: l10n.cancelledPickups,
                            value: '$canceledPickups',
                            iconColor: Theme.of(context).colorScheme.error,
                            backgroundColor: const Color(0xFFFEE2E2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _HelperRatingCard(
                      rating: reliabilityRating,
                      completedJobs: completedJobs,
                      canceledPickups: canceledPickups,
                    ),
                    const SizedBox(height: 8),
                    _HelperSummaryRow(
                        icon: Icons.insights_rounded,
                        title: l10n.reliabilityContext,
                        value: l10n.reliabilitySummary(
                          completedJobs,
                          canceledPickups,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            l10n.account,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _ProfileItem(
                  icon: Icons.settings_outlined,
                  title: l10n.settings,
                  subtitle: l10n.manageAppPreferences,
                ),
                const Divider(height: 1),
                _ProfileItem(
                  icon: Icons.language_rounded,
                  title: l10n.language,
                  subtitle: provider.locale.languageCode == 'sv'
                      ? l10n.swedish
                      : l10n.english,
                  onTap: () => _showLanguagePicker(context, provider),
                ),
                const Divider(height: 1),
                _ProfileItem(
                  icon: Icons.notifications_none_rounded,
                  title: l10n.notifications,
                  subtitle: l10n.stayUpdatedOnActivity,
                ),
                const Divider(height: 1),
                _ProfileItem(
                  icon: Icons.eco_outlined,
                  title: l10n.impactStats,
                  subtitle: l10n.trackRecyclingContribution,
                ),
                const Divider(height: 1),
                _ProfileItem(
                  icon: Icons.help_outline_rounded,
                  title: l10n.helpSupport,
                  subtitle: l10n.getHelpWhenYouNeedIt,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: _ProfileItem(
              icon: Icons.logout_rounded,
              title: l10n.logOut,
              subtitle: l10n.returnToSignInScreen,
              textColor: Theme.of(context).colorScheme.error,
              onTap: () async {
                await context.read<PantaProvider>().logout();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    PantaProvider provider,
  ) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.chooseLanguage),
                subtitle: Text(l10n.appLanguageDescription),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.swedish),
                onTap: () async {
                  await provider.setLocale(const Locale('sv', 'SE'));
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.english),
                onTap: () async {
                  await provider.setLocale(const Locale('en', 'US'));
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HelperRatingCard extends StatelessWidget {
  final double? rating;
  final int completedJobs;
  final int canceledPickups;

  const _HelperRatingCard({
    required this.rating,
    required this.completedJobs,
    required this.canceledPickups,
  });

  @override
  Widget build(BuildContext context) {
    final roundedRating = rating?.round() ?? 0;
    final l10n = context.l10n;
    final ratingLabel = switch (roundedRating) {
      5 => l10n.excellent,
      4 => l10n.strong,
      3 => l10n.fair,
      2 => l10n.needsImprovement,
      1 => l10n.atRisk,
      _ => l10n.noHistoryYet,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.recyclerRating,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                rating == null
                    ? l10n.noHistoryYet
                    : '${_formatRating(rating!)} / 5',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              return Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
                child: Icon(
                  index < roundedRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 22,
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            ratingLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.basedOnCompletedAndCancelled(
              completedJobs,
              canceledPickups,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
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
