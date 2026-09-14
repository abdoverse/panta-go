import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../providers/panta_provider.dart';

/// Floating banner displayed at the bottom of the screen when GDPR cookie consent
/// has not yet been given, compliant with Swedish LEK 2022:482 & PTS requirements.
class CookieConsentBanner extends StatelessWidget {
  const CookieConsentBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    if (!provider.showCookieConsentBanner) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ResponsiveContainer(
          maxWidth: 820,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 1.5),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLeaf,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.cookie_outlined,
                          color: AppTheme.primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.cookieBannerTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.cookieBannerDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => showCookiePreferencesDialog(context),
                        child: Text(l10n.cookieCustomize),
                      ),
                      OutlinedButton(
                        onPressed: () => provider.acceptNecessaryCookiesOnly(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderSubtle),
                        ),
                        child: Text(l10n.cookieNecessaryOnly),
                      ),
                      FilledButton(
                        onPressed: () => provider.acceptAllCookies(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                        child: Text(l10n.cookieAcceptAll),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the granular cookie preferences modal dialog.
Future<void> showCookiePreferencesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => const _CookiePreferencesDialog(),
  );
}

class _CookiePreferencesDialog extends StatefulWidget {
  const _CookiePreferencesDialog();

  @override
  State<_CookiePreferencesDialog> createState() =>
      _CookiePreferencesDialogState();
}

class _CookiePreferencesDialogState extends State<_CookiePreferencesDialog> {
  late bool _functional;
  late bool _analytics;
  late bool _marketing;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PantaProvider>();
    final current = provider.cookieConsent;
    _functional = current?.functional ?? false;
    _analytics = current?.analytics ?? false;
    _marketing = current?.marketing ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.read<PantaProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.primaryGreen,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.cookiePreferencesTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.cookiePreferencesDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 20),
                // Necessary
                _CategoryCard(
                  title: l10n.cookieCategoryNecessary,
                  description: l10n.cookieCategoryNecessaryDesc,
                  value: true,
                  locked: true,
                  lockedBadge: l10n.cookieAlwaysActive,
                  onChanged: null,
                ),
                const SizedBox(height: 12),
                // Functional
                _CategoryCard(
                  title: l10n.cookieCategoryFunctional,
                  description: l10n.cookieCategoryFunctionalDesc,
                  value: _functional,
                  locked: false,
                  onChanged: (val) => setState(() => _functional = val),
                ),
                const SizedBox(height: 12),
                // Analytics
                _CategoryCard(
                  title: l10n.cookieCategoryAnalytics,
                  description: l10n.cookieCategoryAnalyticsDesc,
                  value: _analytics,
                  locked: false,
                  onChanged: (val) => setState(() => _analytics = val),
                ),
                const SizedBox(height: 12),
                // Marketing
                _CategoryCard(
                  title: l10n.cookieCategoryMarketing,
                  description: l10n.cookieCategoryMarketingDesc,
                  value: _marketing,
                  locked: false,
                  onChanged: (val) => setState(() => _marketing = val),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await provider.acceptAllCookies();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.cookieConsentSaved)),
                          );
                        }
                      },
                      child: Text(l10n.cookieAcceptAll),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                      onPressed: () async {
                        await provider.saveCustomCookieConsent(
                          functional: _functional,
                          analytics: _analytics,
                          marketing: _marketing,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.cookieConsentSaved)),
                          );
                        }
                      },
                      child: Text(l10n.cookieSavePreferences),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final bool locked;
  final String? lockedBadge;
  final ValueChanged<bool>? onChanged;

  const _CategoryCard({
    required this.title,
    required this.description,
    required this.value,
    this.locked = false,
    this.lockedBadge,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (locked && lockedBadge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLeaf,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    lockedBadge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                )
              else
                Switch(
                  value: value,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: onChanged,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
