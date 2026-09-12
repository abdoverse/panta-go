import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../providers/panta_provider.dart';
import '../auth/bankid_dialog.dart';

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
    final savedAddresses = provider.savedAddresses;
    final requestTemplates = provider.requestTemplates;
    final email = provider.currentUserEmail?.trim();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ResponsiveContainer(
        maxWidth: 680,
        padding: EdgeInsets.zero,
        child: ListView(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            resolvedName,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showEditNameDialog(context, provider),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: AppTheme.textSecondary,
                          tooltip: context.l10n.editName,
                        ),
                      ],
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
                    if (provider.isBankIdVerified) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.bankIdVerifiedBadge,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (email != null && email.isNotEmpty) ...[
              _ProfileItem(
                icon: Icons.email_outlined,
                title: "Email",
                subtitle: email,
              ),
              const SizedBox(height: 12),
            ],
            if (!provider.isBankIdVerified) ...[
              const SizedBox(height: 16),
              _BankIdVerificationCard(isHelper: isHelper),
            ],
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
            if (!isHelper) ...[
              Text(
                'Pickup shortcuts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _HelperSummaryRow(
                        icon: Icons.location_on_outlined,
                        title: 'Saved addresses',
                        value: '${savedAddresses.length}',
                      ),
                      if (savedAddresses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            savedAddresses
                                .map((item) => item.label)
                                .take(2)
                                .join(' • '),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _HelperSummaryRow(
                        icon: Icons.copy_all_rounded,
                        title: 'Request templates',
                        value: '${requestTemplates.length}',
                      ),
                      if (requestTemplates.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            requestTemplates
                                .map((item) => item.name)
                                .take(2)
                                .join(' • '),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'About Panta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const _AboutAppTile(),
            const SizedBox(height: 20),
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
                  _ProfileItem(
                    icon: Icons.feedback_outlined,
                    title: "Feedback",
                    subtitle: "Tell the Panta team what to improve",
                    onTap: () => _showFeedbackDialog(context, provider),
                  ),
                  const Divider(height: 1),
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
            Text(
              'Demo & Local Testing Tools',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFF1F8E9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFAED581), width: 1.2),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded,
                        color: AppTheme.primaryGreen),
                    title: Text(isHelper
                        ? 'Switch to Recycler (Anna)'
                        : 'Switch to Helper (Erik)'),
                    subtitle: const Text(
                        'Switch role in 1 click to test marketplace interaction'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await provider.switchDemoRole();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isHelper
                                  ? 'Switched to Recycler (Anna)'
                                  : 'Switched to Helper (Erik)',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF235971)),
                    title: const Text('Re-seed Sample Requests'),
                    subtitle: const Text(
                        'Populate pending, accepted, and completed requests with chat & photos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final ok = await provider.seedDemoData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Sample requests re-seeded!'
                                : 'Failed to seed requests'),
                          ),
                        );
                      }
                    },
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
      ),
    );
  }

  Future<void> _showFeedbackDialog(
      BuildContext context, PantaProvider provider) async {
    final messageController = TextEditingController();
    var category = "General";
    var contactRequested = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.sendFeedback),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(labelText: context.l10n.category),
                items: ["General", "Bug", "Idea", "Account"]
                    .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item == "General"
                            ? context.l10n.general
                            : item == "Bug"
                                ? context.l10n.bug
                                : item == "Idea"
                                    ? context.l10n.idea
                                    : context.l10n.accountCategory)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => category = value ?? "General"),
              ),
              TextField(
                  controller: messageController,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration:
                      InputDecoration(labelText: context.l10n.yourFeedback)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: contactRequested,
                  title: Text(context.l10n.openToBeingContacted),
                  onChanged: (value) =>
                      setState(() => contactRequested = value ?? false)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel)),
            FilledButton(
                onPressed: () async {
                  final ok = messageController.text.trim().isNotEmpty &&
                      await provider.submitFeedback(
                          category: category,
                          message: messageController.text.trim(),
                          contactRequested: contactRequested);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
                },
                child: Text(context.l10n.send)),
          ],
        ),
      ),
    );
    messageController.dispose();
    if (context.mounted && submitted != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(submitted
              ? "Thanks for your feedback!"
              : "Could not send feedback.")));
    }
  }

  Future<void> _showEditNameDialog(
      BuildContext context, PantaProvider provider) async {
    final controller =
        TextEditingController(text: provider.currentUserDisplayName);
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.editName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.l10n.firstAndLastName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(context.l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (updatedName == null || !context.mounted) return;
    final error = await provider.updateDisplayName(updatedName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Name updated.')),
      );
    }
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

class _BankIdVerificationCard extends StatelessWidget {
  final bool isHelper;

  const _BankIdVerificationCard({required this.isHelper});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF235971).withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF235971),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.bankIdVerificationTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1C3F60),
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.bankIdTrustSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF235971),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  BankIdDialog.show(
                    context,
                    isLogin: false,
                    isHelper: isHelper,
                  );
                },
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(
                  l10n.bankIdVerify,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutAppTile extends StatefulWidget {
  const _AboutAppTile();

  @override
  State<_AboutAppTile> createState() => _AboutAppTileState();
}

class _AboutAppTileState extends State<_AboutAppTile> {
  late Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    // Cache the future so it doesn't get recreated on every build
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<PackageInfo>(
        future: _packageInfoFuture,
        builder: (context, snapshot) => _ProfileItem(
          icon: Icons.info_outline_rounded,
          title: 'About Panta',
          subtitle: snapshot.hasData
              ? "v${snapshot.data!.version} (Build ${snapshot.data!.buildNumber})"
              : 'Loading version…',
        ),
      ),
    );
  }
}
