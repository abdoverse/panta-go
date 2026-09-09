import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isSimulating = false;
  String? _errorMessage;
  String? _hintCode;

  String? _orderRef;
  String? _autoStartToken;
  String? _qrStartToken;
  String? _qrStartSecret;
  String? _currentQrString;
  String? _mode;
  DateTime? _authStartTime;

  Timer? _pollingTimer;
  Timer? _qrAnimationTimer;

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
    _qrAnimationTimer?.cancel();
    _personalNumberController.dispose();
    super.dispose();
  }

  String _computeBankIdQrCode(String qrStartToken, String qrStartSecret, int seconds) {
    final key = utf8.encode(qrStartSecret);
    final bytes = utf8.encode(seconds.toString());
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return 'bankid.$qrStartToken.$seconds.$digest';
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
          _errorMessage = 'Kunde inte initiera BankID. Kontrollera anslutningen.';
        });
        return;
      }

      _orderRef = res.orderRef;
      _autoStartToken = res.autoStartToken;
      _qrStartToken = res.qrStartToken;
      _qrStartSecret = res.qrStartSecret;
      _mode = res.mode;
      _currentQrString = res.qrCode;
      _authStartTime = DateTime.now();

      setState(() {
        _isInitiating = false;
        _isPolling = true;
      });

      // Start 1-second animated QR refresh according to BankID v6 standard
      if (_qrStartToken != null && _qrStartSecret != null) {
        _qrAnimationTimer?.cancel();
        _qrAnimationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || _qrStartToken == null || _qrStartSecret == null || _authStartTime == null) {
            timer.cancel();
            return;
          }
          final elapsed = DateTime.now().difference(_authStartTime!).inSeconds;
          setState(() {
            _currentQrString = _computeBankIdQrCode(_qrStartToken!, _qrStartSecret!, elapsed);
          });
        });
      }

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
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final provider = context.read<PantaProvider>();
      final collectRes = await provider.collectBankId(orderRef: orderRef);

      if (!mounted) return;

      if (collectRes == null) {
        timer.cancel();
        _qrAnimationTimer?.cancel();
        setState(() {
          _isPolling = false;
          _errorMessage = 'Kunde inte verifiera BankID-status.';
        });
        return;
      }

      setState(() {
        _hintCode = collectRes.hintCode;
      });

      if (collectRes.isComplete) {
        timer.cancel();
        _qrAnimationTimer?.cancel();
        await _handleSuccess(collectRes);
      } else if (collectRes.status == 'failed') {
        timer.cancel();
        _qrAnimationTimer?.cancel();
        setState(() {
          _isPolling = false;
          _errorMessage = collectRes.hintCode == 'userCancel'
              ? 'BankID-identifieringen avbröts.'
              : 'BankID-identifieringen misslyckades eller löpte ut.';
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
          _errorMessage = 'Kunde inte koppla BankID till nuvarande konto.';
        });
        return;
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _simulateApproval() async {
    if (_orderRef == null) return;
    setState(() => _isSimulating = true);

    final provider = context.read<PantaProvider>();
    final pNumber = _personalNumberController.text.trim();
    final res = await provider.simulateCompleteBankId(
      orderRef: _orderRef!,
      personalNumber: pNumber.isNotEmpty ? pNumber : null,
    );

    if (!mounted) return;
    setState(() => _isSimulating = false);

    if (res != null && res.isComplete) {
      _pollingTimer?.cancel();
      _qrAnimationTimer?.cancel();
      await _handleSuccess(res);
    } else {
      setState(() {
        _errorMessage = 'Kunde inte simulera godkännande.';
      });
    }
  }

  Future<void> _launchSameDeviceBankId() async {
    if (_autoStartToken == null) return;
    final uri = Uri.parse('bankid:///?autostarttoken=$_autoStartToken&redirect=null');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BankID-appen hittades inte på denna enhet.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte öppna BankID-appen.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleCancel() {
    _pollingTimer?.cancel();
    _qrAnimationTimer?.cancel();
    if (_orderRef != null) {
      context.read<PantaProvider>().cancelBankId(orderRef: _orderRef!);
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BankID Branding Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF235971), // Authentic Swedish BankID navy
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BankID',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF235971),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _mode == 'test' ? 'TESTMILJÖ (v6.0 API)' : 'SÄKER IDENTIFIERING',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF235971),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            Text(
              widget.isLogin ? l10n.bankIdLogin : l10n.bankIdVerificationTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 16),

            // Content Area
            if (_isSuccess) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primaryGreen,
                      size: 52,
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
              // Live Dynamic QR code and App Switch
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    // Dynamic animated QR box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _currentQrString != null && _currentQrString!.isNotEmpty
                          ? QrImageView(
                              data: _currentQrString!,
                              version: QrVersions.auto,
                              size: 150,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF235971),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF1C3F60),
                              ),
                            )
                          : const SizedBox(
                              width: 150,
                              height: 150,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),

                    // Status Hint & Spinner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF235971)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _hintCode == 'userSign'
                                ? 'Skriv in din säkerhetskod i BankID...'
                                : 'Scanna QR-koden i BankID-appen',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1C3F60),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Same-device app launch button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _launchSameDeviceBankId,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text(
                          'Öppna BankID på denna enhet',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF235971),
                          side: const BorderSide(color: Color(0xFF235971)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Simulation button for test mode
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isSimulating ? null : _simulateApproval,
                        icon: _isSimulating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_user_outlined, size: 16),
                        label: Text(
                          _isSimulating ? 'Simulerar...' : 'Simulera godkännande (Testmiljö)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
                  hintText: 'YYYYMMDDXXXX (valfritt för QR)',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'I BankID v6.0 kan du lämna personnumret tomt och scanna QR-koden direkt med appen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
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
                onPressed: _handleCancel,
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
