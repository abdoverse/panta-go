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
    final displayName =
        context.watch<PantaProvider>().currentUserDisplayName?.trim();
    final resolvedName = (displayName == null || displayName.isEmpty)
        ? (isHelper ? 'Helper' : 'Recycler')
        : displayName;
    final subtitle = isHelper ? 'Helper' : 'Recycler';
    final avatarIcon =
        isHelper ? Icons.local_shipping_rounded : Icons.person_rounded;

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
          Text(
            'Account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _ProfileItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Manage app preferences',
                ),
                const Divider(height: 1),
                _ProfileItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Stay updated on activity',
                ),
                const Divider(height: 1),
                _ProfileItem(
                  icon: Icons.eco_outlined,
                  title: 'Impact stats',
                  subtitle: 'Track your recycling contribution',
                ),
                const Divider(height: 1),
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
