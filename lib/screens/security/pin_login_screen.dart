import 'package:flutter/material.dart';

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
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() {
        _errorText = context.tr(
          'PIN 4-8 rakam olmali.',
          'PIN must be 4-8 digits.',
        );
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });
    final result = await widget.onVerifyPin(pin);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      if (result.locked) {
        _errorText = context.tr(
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
                    maxLength: 8,
                    keyboardType: TextInputType.number,
                    obscureText: _hidden,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      _verify();
                    },
                    decoration: InputDecoration(
                      labelText: context.tr('PIN Kodu', 'PIN Code'),
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
                        child: Text(context.tr('PIN\'i Unuttum', 'Forgot PIN')),
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
