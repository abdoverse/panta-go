import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/panta_provider.dart';
import '../../services/bankid_service.dart';

class BankIdDialog extends StatefulWidget {
  final bool isLogin;
  final bool isHelper;
  final String? initialPersonalNumber;

  const BankIdDialog({
    super.key,
    required this.isLogin,
    required this.isHelper,
    this.initialPersonalNumber,
  });

  static Future<bool?> show(
    BuildContext context, {
    required bool isLogin,
    required bool isHelper,
    String? initialPersonalNumber,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BankIdDialog(
        isLogin: isLogin,
        isHelper: isHelper,
        initialPersonalNumber: initialPersonalNumber,
      ),
    );
  }

  @override
  State<BankIdDialog> createState() => _BankIdDialogState();
}

class _BankIdDialogState extends State<BankIdDialog> {
  final _personalNumberController = TextEditingController();
  bool _isInitiating = false;
  bool _isPolling = false;
  bool _isSuccess = false;
  String? _errorMessage;
  String? _hintCode;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialPersonalNumber != null) {
      _personalNumberController.text = widget.initialPersonalNumber!;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _personalNumberController.dispose();
    super.dispose();
  }

  Future<void> _startBankId() async {
    setState(() {
      _isInitiating = true;
      _errorMessage = null;
      _hintCode = null;
    });

    final provider = context.read<PantaProvider>();
    final pNumber = _personalNumberController.text.trim();

    try {
      final res = await provider.initiateBankId(
        personalNumber: pNumber.isNotEmpty ? pNumber : null,
        asHelper: widget.isHelper,
      );

      if (res == null || res.orderRef.isEmpty) {
        setState(() {
          _isInitiating = false;
          _errorMessage = 'Could not initiate BankID order. Please check server.';
        });
        return;
      }

      setState(() {
        _isInitiating = false;
        _isPolling = true;
      });

      _startPolling(res.orderRef);
    } catch (e) {
      setState(() {
        _isInitiating = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _startPolling(String orderRef) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final provider = context.read<PantaProvider>();
      final collectRes = await provider.collectBankId(orderRef: orderRef);

      if (!mounted) return;

      if (collectRes == null) {
        timer.cancel();
        setState(() {
          _isPolling = false;
          _errorMessage = 'Failed to check BankID status.';
        });
        return;
      }

      setState(() {
        _hintCode = collectRes.hintCode;
      });

      if (collectRes.isComplete) {
        timer.cancel();
        await _handleSuccess(collectRes);
      } else if (collectRes.status == 'failed') {
        timer.cancel();
        setState(() {
          _isPolling = false;
          _errorMessage = 'BankID authentication was canceled or timed out.';
        });
      }
    });
  }

  Future<void> _handleSuccess(BankIdCollectResponse collectRes) async {
    setState(() {
      _isPolling = false;
      _isSuccess = true;
    });

    final provider = context.read<PantaProvider>();
    if (widget.isLogin) {
      final error = await provider.completeBankIdLogin(
        collectResponse: collectRes,
        asHelper: widget.isHelper,
      );
      if (error != null && mounted) {
        setState(() {
          _isSuccess = false;
          _errorMessage = error;
        });
        return;
      }
    } else {
      final verified = await provider.verifyCurrentAccountWithBankId(
        orderRef: collectRes.orderRef,
        personalNumber: collectRes.personalNumber,
      );
      if (!verified && mounted) {
        setState(() {
          _isSuccess = false;
          _errorMessage = 'Failed to verify current account with BankID.';
        });
        return;
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BankID Branding Header
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF235971), // Authentic Swedish BankID navy
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF235971).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'BankID',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1C3F60),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isLogin ? l10n.bankIdLogin : l10n.bankIdVerificationTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 20),

            // Main State View
            if (_isSuccess) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.accentLeaf,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primaryGreen,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.bankIdSuccess,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ] else if (_isPolling) ...[
              // QR / Verification Handshake in progress
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    // Mock QR Box with BankID animation
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            size: 110,
                            color: Color(0xFF1C3F60),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF235971),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF235971)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _hintCode == 'userSign'
                          ? 'Skriv in din säkerhetskod i BankID...'
                          : l10n.bankIdOpenApp,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C3F60),
                          ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Personal Number input
              TextField(
                controller: _personalNumberController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.bankIdPersonalNumber,
                  hintText: l10n.bankIdPersonalNumberHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.bankIdTrustSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            if (!_isSuccess) ...[
              if (!_isPolling) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF235971),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isInitiating ? null : _startBankId,
                  icon: _isInitiating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.shield_outlined, size: 20),
                  label: Text(
                    widget.isLogin ? l10n.bankIdLogin : l10n.bankIdVerify,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _pollingTimer?.cancel();
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
