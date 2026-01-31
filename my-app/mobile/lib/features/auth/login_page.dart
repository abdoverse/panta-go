import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/user_home_page.dart';
import '../dashboard/helper_home_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: AppTheme.secondaryGreen.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
           Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.accentLeaf.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.recycling, size: 80, color: Colors.white)
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(),

                    const SizedBox(height: 24),

                    const Text(
                      'Panta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(),

                    const Text(
                      'Recycling made effortless.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 64),

                    // Role Selection
                    _LoginButton(
                      label: 'I want to Recycle',
                      icon: Icons.eco,
                      onTap: () {
                        context.read<PantaProvider>().login(false);
                         Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const UserHomePage()),
                        );
                      },
                    ).animate().fadeIn(delay: 600.ms).slideX(),

                    const SizedBox(height: 16),

                    _LoginButton(
                      label: 'I am a Helper',
                      icon: Icons.local_shipping,
                      isOutlined: true,
                      onTap: () {
                         context.read<PantaProvider>().login(true);
                         Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HelperHomePage()),
                        );
                      },
                    ).animate().fadeIn(delay: 800.ms).slideX(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isOutlined;

  const _LoginButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
       return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppTheme.primaryGreen),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryGreen,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
