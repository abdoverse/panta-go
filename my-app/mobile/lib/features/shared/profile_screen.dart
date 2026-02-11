import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_page.dart';

class ProfileScreen extends StatelessWidget {
  final bool isHelper;

  const ProfileScreen({super.key, required this.isHelper});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
              child: Icon(isHelper ? Icons.local_shipping : Icons.person, size: 60, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 20),
            Text(isHelper ? "John Helper" : "Jane Recycler",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            Text(isHelper ? "Top Rated Helper" : "Eco Warrior Level 5",
               style: const TextStyle(color: Colors.grey)
            ),
             const SizedBox(height: 40),

            Expanded(
              child: ListView(
                children: [
                  _ProfileItem(icon: Icons.settings, title: "Settings"),
                  _ProfileItem(icon: Icons.notifications, title: "Notifications"),
                  _ProfileItem(icon: Icons.eco, title: "Impact Stats"),
                  _ProfileItem(icon: Icons.help, title: "Help & Support"),
                  const SizedBox(height: 20),
                   _ProfileItem(
                     icon: Icons.logout,
                     title: "Log Out",
                     textColor: Colors.red,
                     onTap: () {
                       Navigator.pushAndRemoveUntil(
                         context,
                         MaterialPageRoute(builder: (_) => const LoginPage()),
                         (route) => false
                       );
                     }
                   ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color textColor;

  const _ProfileItem({required this.icon, required this.title, this.onTap, this.textColor = Colors.black});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.grey[700]),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
    );
  }
}

