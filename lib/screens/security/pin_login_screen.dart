import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';
import '../../services/pin_security_service.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({
    super.key,
    required this.onVerifyPin,
    this.title,
    this.description,
    this.allowBack = true,
    this.onForgotPin,
  });

  final Future<PinVerificationResult> Function(String pin) onVerifyPin;
  final String? title;
  final String? description;
  final bool allowBack;
  final Future<void> Function()? onForgotPin;

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  late final TextEditingController _pinController;
  bool _busy = false;
  bool _hidden = true;
  String? _errorText;
  bool _requiresMasterFallback = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    final pin = _pinController.text.trim();
    if (!PinSecurityService.isPotentialUnlockInput(pin)) {
      setState(() {
        _errorText = context.tr(
          'PIN formati gecersiz. Sayisal PIN icin 8-12, alfanumerik kod icin 8-24 karakter kullanin.',
          'Invalid PIN format. Use 8-12 digits for numeric PIN or 8-24 alphanumeric characters.',
        );
        _requiresMasterFallback = false;
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
      _requiresMasterFallback = false;
    });
    final result = await widget.onVerifyPin(pin);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _requiresMasterFallback = result.requiresMasterPassword;
      if (result.locked) {
        _errorText = result.requiresMasterPassword
            ? context.tr(
                'Guvenlik nedeniyle PIN gecici olarak kilitlendi. ${result.retryAfterLabel()} sonra tekrar deneyin veya master password ile giris yapin.',
                'PIN is temporarily locked for security. Retry in ${result.retryAfterLabel()} or continue with master password.',
              )
            : context.tr(
                'Cok fazla deneme yapildi. ${result.retryAfterLabel()} sonra tekrar deneyin.',
                'Too many attempts. Try again in ${result.retryAfterLabel()}.',
              );
        return;
      }
      _errorText =
          result.message ?? context.tr('PIN hatali.', 'Incorrect PIN.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: widget.allowBack && !_busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.allowBack,
          title: Text(
            widget.title ?? context.tr('PIN ile Giriş', 'Sign in with PIN'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pr.panelSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pr.panelBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.description ??
                        context.tr(
                          'Devam etmek için giriş PIN kodunuzu girin.',
                          'Enter your access PIN to continue.',
                        ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: pr.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    maxLength: PinSecurityService.maxAlphanumericLength,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: _hidden,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      _verify();
                    },
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'PIN / Erisim Kodu',
                        'PIN / Access Code',
                      ),
                      helperText: context.tr(
                        'Sayisal PIN (8-12) veya alfanumerik kod (8-24) kullanabilirsiniz.',
                        'Use numeric PIN (8-12) or alphanumeric code (8-24).',
                      ),
                      errorText: _errorText,
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _hidden = !_hidden;
                                });
                              },
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.onForgotPin != null) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await widget.onForgotPin!.call();
                              },
                        child: Text(
                          _requiresMasterFallback
                              ? context.tr(
                                  'Master Password ile Giris Yap',
                                  'Continue with Master Password',
                                )
                              : context.tr('PIN\'i Unuttum', 'Forgot PIN'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _verify,
                      icon: _busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(context.tr('Giris Yap', 'Sign In')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
