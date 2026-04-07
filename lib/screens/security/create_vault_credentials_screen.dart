import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';
import '../../services/pin_security_service.dart';

class VaultCredentialSetupData {
  const VaultCredentialSetupData({required this.pin});

  final String pin;
}

class CreateVaultCredentialsScreen extends StatefulWidget {
  const CreateVaultCredentialsScreen({
    super.key,
    required this.onSubmit,
    required this.busy,
    required this.errorText,
  });

  final Future<void> Function(VaultCredentialSetupData data) onSubmit;
  final bool busy;
  final String? errorText;

  @override
  State<CreateVaultCredentialsScreen> createState() =>
      _CreateVaultCredentialsScreenState();
}

class _CreateVaultCredentialsScreenState
    extends State<CreateVaultCredentialsScreen> {
  final _pinController = TextEditingController();
  final _pinRepeatController = TextEditingController();

  bool _pinHidden = true;
  bool _pinRepeatHidden = true;
  String? _localError;

  @override
  void dispose() {
    _pinController.dispose();
    _pinRepeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy) return;

    final pin = _pinController.text.trim();
    final pinRepeat = _pinRepeatController.text.trim();

    if (!PinSecurityService.isStrongPinCandidate(pin)) {
      setState(() {
        _localError = context.tr(
          PinSecurityService.enrollmentPolicyLabelTr(),
          PinSecurityService.enrollmentPolicyLabelEn(),
        );
      });
      return;
    }
    if (pin != pinRepeat) {
      setState(() {
        _localError = context.tr(
          'PIN alanlari eslesmiyor.',
          'PIN values do not match.',
        );
      });
      return;
    }

    setState(() {
      _localError = null;
    });
    await widget.onSubmit(VaultCredentialSetupData(pin: pin));
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    final mergedError = (_localError ?? '').trim().isNotEmpty
        ? _localError
        : widget.errorText;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pr.canvasGradientTop, pr.canvasGradientBottom],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  shrinkWrap: true,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: pr.panelSurface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: pr.panelBorder),
                        boxShadow: [
                          BoxShadow(
                            color: pr.panelShadow,
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr(
                              'Guvenli Kasa Kurulumu',
                              'Secure Vault Setup',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              'Uygulama cihazinizda guclu bir sifreleme anahtari olusturur ve guvenli depolamada saklar. Devam etmek icin sadece 4 veya 6 haneli PIN belirleyin.',
                              'The app creates a strong encryption key on your device and stores it in secure storage. To continue, set a 4 or 6 digit PIN.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: pr.textMuted),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pinController,
                            maxLength: PinSecurityService.maxPinLength,
                            keyboardType: TextInputType.number,
                            obscureText: _pinHidden,
                            enabled: !widget.busy,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('PIN', 'PIN'),
                              helperText: context.tr(
                                'Sadece 4 veya 6 hane kullanin.',
                                'Use exactly 4 or 6 digits.',
                              ),
                              suffixIcon: IconButton(
                                onPressed: widget.busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _pinHidden = !_pinHidden;
                                        });
                                      },
                                icon: Icon(
                                  _pinHidden
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _pinRepeatController,
                            maxLength: PinSecurityService.maxPinLength,
                            keyboardType: TextInputType.number,
                            obscureText: _pinRepeatHidden,
                            enabled: !widget.busy,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('PIN Tekrar', 'Repeat PIN'),
                              suffixIcon: IconButton(
                                onPressed: widget.busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _pinRepeatHidden = !_pinRepeatHidden;
                                        });
                                      },
                                icon: Icon(
                                  _pinRepeatHidden
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                          ),
                          if ((mergedError ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                mergedError!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: scheme.onErrorContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: widget.busy ? null : _submit,
                            icon: widget.busy
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.1,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.shield_rounded),
                            label: Text(
                              context.tr('Kurulumu Tamamla', 'Complete Setup'),
                            ),
                          ),
                        ],
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
}
