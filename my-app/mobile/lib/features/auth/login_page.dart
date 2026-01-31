import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/user_home_page.dart';
import '../dashboard/helper_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationCodeController = TextEditingController();
  bool _isLoading = false;
  String _selectedRole = 'Recycler'; // Default role

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
              child: SingleChildScrollView(
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

                    const SizedBox(height: 48),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.white70),
                              filled: false, // Override global theme
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                              errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                              focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                              prefixIcon: Icon(Icons.email, color: Colors.white70),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: Colors.white70),
                              filled: false, // Override global theme
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                              errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                              focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                              prefixIcon: Icon(Icons.lock, color: Colors.white70),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                                return 'Must contain at least one lowercase letter';
                              }
                              if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                                return 'Must contain at least one uppercase letter';
                              }
                              if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
                                return 'Must contain at least one number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: Colors.white))
                    else ...[
                      // Role Selection
                      _LoginButton(
                        label: 'Login as Recycler',
                        icon: Icons.eco,
                        onTap: () => _login(false),
                      ).animate().fadeIn(delay: 600.ms).slideX(),

                      const SizedBox(height: 16),

                      _LoginButton(
                        label: 'Login as Helper',
                        icon: Icons.local_shipping,
                        isOutlined: true,
                        onTap: () => _login(true),
                      ).animate().fadeIn(delay: 800.ms).slideX(),

                      TextButton(
                        onPressed: _signUp,
                        child: const Text('New? Sign Up Here', style: TextStyle(color: Colors.white)),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login(bool asHelper) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final error = await context.read<PantaProvider>().login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      asHelper
    );
    setState(() => _isLoading = false);

    if (error == null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => asHelper ? const HelperHomePage() : const UserHomePage()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Failed: $error'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final error = await context.read<PantaProvider>().signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _selectedRole,
    );
    setState(() => _isLoading = false);

    if (error == null && mounted) {
        _showConfirmationDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign Up Failed: $error'), backgroundColor: Colors.red),
      );
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A confirmation code has been sent to your email. Please enter it below.'),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmationCodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Confirmation Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _confirmAndLogin();
            },
            child: const Text('Confirm & Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndLogin() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final code = _confirmationCodeController.text.trim();

    // 1. Confirm User
    final confirmError = await context.read<PantaProvider>().confirmUser(email, code);

    if (confirmError != null) {
      setState(() => _isLoading = false);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirmation Failed: $confirmError'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // 2. Auto Login
    final isHelper = _selectedRole == 'Helper';
    final loginError = await context.read<PantaProvider>().login(
      email,
      _passwordController.text.trim(),
      isHelper
    );

    setState(() => _isLoading = false);

    if (loginError == null && mounted) {
       Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => isHelper ? const HelperHomePage() : const UserHomePage()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Login Failed after confirmation: $loginError'), backgroundColor: Colors.red),
      );
    }
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
