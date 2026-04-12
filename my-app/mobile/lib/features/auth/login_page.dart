import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/panta_provider.dart';

enum _AuthMode { login, signUp }

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
  _AuthMode _authMode = _AuthMode.login;

  bool get _isSignUpMode => _authMode == _AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 700;
    final l10n = context.l10n;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6FBF7),
              AppTheme.surfaceGrey,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.accentLeaf,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.recycling_rounded,
                          color: AppTheme.primaryGreen,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Panta',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appTagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<_AuthMode>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: _AuthMode.login,
                                  label: Text(l10n.logIn),
                                  icon: Icon(Icons.login_rounded),
                                ),
                                ButtonSegment(
                                  value: _AuthMode.signUp,
                                  label: Text(l10n.createAccount),
                                  icon: Icon(Icons.person_add_alt_1_rounded),
                                ),
                              ],
                              selected: {_authMode},
                              onSelectionChanged: (selection) {
                                setState(() {
                                  _authMode = selection.first;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: SegmentedButton<String>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: 'Recycler',
                                    label: Text(l10n.recyclerRole),
                                    icon: Icon(Icons.eco_outlined),
                                  ),
                                  ButtonSegment(
                                    value: 'Helper',
                                    label: Text(l10n.helperRole),
                                    icon: Icon(Icons.local_shipping_outlined),
                                  ),
                                ],
                                selected: {_selectedRole},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    _selectedRole = selection.first;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _isSignUpMode
                                  ? l10n.createRoleAccount(_selectedRole)
                                  : l10n.continueAsRole(_selectedRole),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isSignUpMode
                                  ? l10n.signUpDescription
                                  : l10n.signInDescription,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            Form(
                              key: _formKey,
                              child: AutofillGroup(
                                child: Column(
                                  children: [
                                    if (_isSignUpMode) ...[
                                      TextFormField(
                                        controller: _nameController,
                                        keyboardType: TextInputType.name,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        autofillHints: const [
                                          AutofillHints.name
                                        ],
                                        decoration: InputDecoration(
                                          labelText: l10n.fullName,
                                          hintText: l10n.enterFullName,
                                          prefixIcon: const Icon(
                                            Icons.person_outline_rounded,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (!_isSignUpMode) return null;
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return l10n.pleaseEnterName;
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ],
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
                                      decoration: InputDecoration(
                                        labelText: l10n.email,
                                        hintText: 'name@example.com',
                                        prefixIcon: const Icon(
                                          Icons.email_outlined,
                                        ),
                                      ),
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (email.isEmpty) {
                                          return l10n.pleaseEnterEmail;
                                        }
                                        if (!_looksLikeEmail(email) &&
                                            !(_isSignUpMode &&
                                                _looksLikeEmail(_nameController
                                                    .text
                                                    .trim()))) {
                                          return l10n.pleaseEnterValidEmail;
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
                                      autofillHints: [
                                        _isSignUpMode
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: l10n.password,
                                        hintText: _isSignUpMode
                                            ? l10n.createStrongPassword
                                            : l10n.enterPassword,
                                        prefixIcon: const Icon(
                                            Icons.lock_outline_rounded),
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
                                          ),
                                          tooltip: _isPasswordVisible
                                              ? l10n.hidePassword
                                              : l10n.showPassword,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return l10n.pleaseEnterPassword;
                                        }
                                        if (_isSignUpMode && value.length < 8) {
                                          return l10n.passwordMinLength;
                                        }
                                        if (_isSignUpMode &&
                                            !RegExp(r'(?=.*[a-z])')
                                                .hasMatch(value)) {
                                          return l10n.passwordLowercase;
                                        }
                                        if (_isSignUpMode &&
                                            !RegExp(r'(?=.*[A-Z])')
                                                .hasMatch(value)) {
                                          return l10n.passwordUppercase;
                                        }
                                        if (_isSignUpMode &&
                                            !RegExp(r'(?=.*[0-9])')
                                                .hasMatch(value)) {
                                          return l10n.passwordNumber;
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else ...[
                              ElevatedButton.icon(
                                onPressed: _submit,
                                icon: Icon(
                                  _isSignUpMode
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.login_rounded,
                                ),
                                label: Text(
                                  _isSignUpMode ? l10n.createAccount : l10n.logIn,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedRole = _selectedRole == 'Recycler'
                                        ? 'Helper'
                                        : 'Recycler';
                                  });
                                },
                                icon: const Icon(Icons.swap_horiz_rounded),
                                label: Text(
                                  l10n.switchToRole(
                                    _selectedRole == 'Recycler'
                                        ? 'Helper'
                                        : 'Recycler',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _authMode = _isSignUpMode
                                        ? _AuthMode.login
                                        : _AuthMode.signUp;
                                  });
                                },
                                child: Text(
                                  _isSignUpMode
                                      ? l10n.alreadyHaveAccount
                                      : l10n.newToPanta,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isWideLayout)
                      Text(
                        l10n.platformTagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSignUpMode) {
      await _signUp();
      return;
    }

    await _login();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final isHelper = _selectedRole == 'Helper';
    final error = await context.read<PantaProvider>().login(
          _emailController.text.trim().toLowerCase(),
          _passwordController.text.trim(),
          isHelper,
        );
    setState(() => _isLoading = false);

    if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.loginFailed(error ?? ''))),
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
          SnackBar(content: Text(context.l10n.signUpFailed(error ?? ''))),
        );
      }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmYourEmail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.verificationCodeDescription),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmationCodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.confirmationCode,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmAndLogin();
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndLogin() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim().toLowerCase();
    final code = _confirmationCodeController.text.trim();
    final provider = context.read<PantaProvider>();

    final confirmError = await provider.confirmUser(email, code);

    if (confirmError != null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.confirmationFailed(confirmError))),
        );
      }
      return;
    }

    final isHelper = _selectedRole == 'Helper';
    final loginError = await provider.login(
      email,
      _passwordController.text.trim(),
      isHelper,
    );

    setState(() => _isLoading = false);

    if (loginError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.loginFailedAfterConfirmation(loginError ?? ''),
            ),
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
