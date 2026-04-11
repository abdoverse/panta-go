import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/panta_provider.dart';
import '../dashboard/helper_home_page.dart';
import '../dashboard/user_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _selectedRole = 'Recycler';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryGreen,
                  const Color(0xFF000000),
                ],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryLight.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.2, 1.2),
                duration: 4.seconds,
              ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentLeaf.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(begin: 0, end: 30, duration: 5.seconds),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GlassmorphicContainer(
                  width: double.infinity,
                  height: 680,
                  borderRadius: 24,
                  blur: 20,
                  alignment: Alignment.center,
                  border: 2,
                  linearGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                    stops: const [0.1, 1],
                  ),
                  borderGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.recycling,
                                size: 60, color: Colors.white)
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(),
                        const SizedBox(height: 16),
                        Text(
                          'Panta',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                        ).animate().fadeIn(delay: 200.ms).slideY(),
                        const Text(
                          'Sustainable recycling made easy',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ).animate().fadeIn(delay: 300.ms),
                        const SizedBox(height: 32),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Form(
                              key: _formKey,
                              child: AutofillGroup(
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _nameController,
                                      keyboardType: TextInputType.name,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      autofillHints: const [AutofillHints.name],
                                      style:
                                          const TextStyle(color: Colors.white),
                                      cursorColor: Colors.white,
                                      decoration: const InputDecoration(
                                        labelText: 'Name',
                                        labelStyle:
                                            TextStyle(color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.black12,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white30),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white),
                                        ),
                                        errorBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Colors.redAccent),
                                        ),
                                        focusedErrorBorder:
                                            UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Colors.redAccent),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person_outline,
                                          color: Colors.white70,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter your name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textCapitalization:
                                          TextCapitalization.none,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      autofillHints: const [
                                        AutofillHints.email
                                      ],
                                      style:
                                          const TextStyle(color: Colors.white),
                                      cursorColor: Colors.white,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        labelStyle:
                                            TextStyle(color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.black12,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white30),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white),
                                        ),
                                        errorBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Colors.redAccent),
                                        ),
                                        focusedErrorBorder:
                                            UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Colors.redAccent),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          color: Colors.white70,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (email.isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        if (!_looksLikeEmail(email) &&
                                            !_looksLikeEmail(
                                                _nameController.text.trim())) {
                                          return 'Please enter a valid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                        AutofillHints.password,
                                      ],
                                      style:
                                          const TextStyle(color: Colors.white),
                                      cursorColor: Colors.white,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle: const TextStyle(
                                            color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.black12,
                                        enabledBorder:
                                            const UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white30),
                                        ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white),
                                        ),
                                        errorBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Colors.redAccent),
                                        ),
                                        focusedErrorBorder:
                                            const UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Colors.redAccent),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: Colors.white70,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: Colors.white70,
                                          ),
                                          tooltip: _isPasswordVisible
                                              ? 'Hide password'
                                              : 'Show password',
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        if (value.length < 8) {
                                          return 'Password must be at least 8 characters';
                                        }
                                        if (!RegExp(r'(?=.*[a-z])')
                                            .hasMatch(value)) {
                                          return 'Must contain at least one lowercase letter';
                                        }
                                        if (!RegExp(r'(?=.*[A-Z])')
                                            .hasMatch(value)) {
                                          return 'Must contain at least one uppercase letter';
                                        }
                                        if (!RegExp(r'(?=.*[0-9])')
                                            .hasMatch(value)) {
                                          return 'Must contain at least one number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          )
                        else ...[
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
                            child: const Text(
                              'New? Sign Up Here',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
          asHelper,
        );
    setState(() => _isLoading = false);

    if (error == null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              asHelper ? const HelperHomePage() : const UserHomePage(),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final signupIdentity = _normalizeSignupIdentity();

    setState(() => _isLoading = true);
    final error = await context.read<PantaProvider>().signUp(
          email: signupIdentity.email,
          password: _passwordController.text.trim(),
          role: _selectedRole,
          name: signupIdentity.name,
        );
    setState(() => _isLoading = false);

    if (error == null && mounted) {
      _showConfirmationDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign Up Failed: $error'),
          backgroundColor: Colors.red,
        ),
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
            const Text(
              'A confirmation code has been sent to your email. Please enter it below.',
            ),
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
              Navigator.pop(context);
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
    final email = _emailController.text.trim().toLowerCase();
    final code = _confirmationCodeController.text.trim();

    final confirmError =
        await context.read<PantaProvider>().confirmUser(email, code);

    if (confirmError != null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirmation Failed: $confirmError'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final isHelper = _selectedRole == 'Helper';
    final loginError = await context.read<PantaProvider>().login(
          email,
          _passwordController.text.trim(),
          isHelper,
        );

    setState(() => _isLoading = false);

    if (loginError == null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isHelper ? const HelperHomePage() : const UserHomePage(),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Failed after confirmation: $loginError'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ({String name, String email}) _normalizeSignupIdentity() {
    var name = _nameController.text.trim();
    var email = _emailController.text.trim().toLowerCase();

    if (_looksLikeEmail(name) && !_looksLikeEmail(email)) {
      final swappedName = email;
      final swappedEmail = name.toLowerCase();

      _nameController.text = swappedName;
      _emailController.text = swappedEmail;

      name = swappedName;
      email = swappedEmail;
    }

    return (name: name, email: email);
  }

  bool _looksLikeEmail(String value) {
    return _emailPattern.hasMatch(value.trim());
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
