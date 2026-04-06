import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';
import '../../services/pin_security_service.dart';

class VaultCredentialSetupData {
  const VaultCredentialSetupData({required this.masterPassword, this.pin});

  final String masterPassword;
  final String? pin;
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
  final _masterController = TextEditingController();
  final _masterRepeatController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinRepeatController = TextEditingController();

  bool _masterHidden = true;
  bool _masterRepeatHidden = true;
  bool _pinHidden = true;
  bool _pinRepeatHidden = true;
  bool _enablePin = true;
  String? _localError;

  @override
  void dispose() {
    _masterController.dispose();
    _masterRepeatController.dispose();
    _pinController.dispose();
    _pinRepeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy) return;

    final master = _masterController.text.trim();
    final masterRepeat = _masterRepeatController.text.trim();
    if (master.length < 12) {
      setState(() {
        _localError = context.tr(
          'Master password en az 12 karakter olmali.',
          'Master password must be at least 12 characters.',
        );
      });
      return;
    }
    if (master != masterRepeat) {
      setState(() {
        _localError = context.tr(
          'Master password alanlari eslesmiyor.',
          'Master password values do not match.',
        );
      });
      return;
    }

    String? pin;
    if (_enablePin) {
      final value = _pinController.text.trim();
      final repeat = _pinRepeatController.text.trim();
      if (!PinSecurityService.isStrongPinCandidate(value)) {
        setState(() {
          _localError = context.tr(
            PinSecurityService.enrollmentPolicyLabelTr(),
            PinSecurityService.enrollmentPolicyLabelEn(),
          );
        });
        return;
      }
      if (value != repeat) {
        setState(() {
          _localError = context.tr(
            'PIN alanlari eslesmiyor.',
            'PIN values do not match.',
          );
        });
        return;
      }
      pin = value;
    }

    setState(() {
      _localError = null;
    });
    await widget.onSubmit(
      VaultCredentialSetupData(masterPassword: master, pin: pin),
    );
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
                              'Kasa anahtari master password ile korunur. Bu parola olmadan veriler cozumlenemez.',
                              'Vault key is protected by a master password. Data cannot be decrypted without it.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: pr.textMuted),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _masterController,
                            obscureText: _masterHidden,
                            textInputAction: TextInputAction.next,
                            enabled: !widget.busy,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: context.tr(
                                'Master Password',
                                'Master Password',
                              ),
                              helperText: context.tr(
                                'En az 12 karakter onerilir.',
                                'Use at least 12 characters.',
                              ),
                              suffixIcon: IconButton(
                                onPressed: widget.busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _masterHidden = !_masterHidden;
                                        });
                                      },
                                icon: Icon(
                                  _masterHidden
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _masterRepeatController,
                            obscureText: _masterRepeatHidden,
                            textInputAction: TextInputAction.next,
                            enabled: !widget.busy,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: context.tr(
                                'Master Password Tekrar',
                                'Repeat Master Password',
                              ),
                              suffixIcon: IconButton(
                                onPressed: widget.busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _masterRepeatHidden =
                                              !_masterRepeatHidden;
                                        });
                                      },
                                icon: Icon(
                                  _masterRepeatHidden
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            value: _enablePin,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.tr(
                                'Hizli acilis icin PIN kullan',
                                'Use PIN for quick unlock',
                              ),
                            ),
                            subtitle: Text(
                              context.tr(
                                '8-12 sayisal PIN veya en az bir harf + bir rakam iceren 8-24 karakter kod kullanabilirsiniz.',
                                'Use 8-12 numeric PIN or an 8-24 character code with at least one letter and one digit.',
                              ),
                            ),
                            onChanged: widget.busy
                                ? null
                                : (value) {
                                    setState(() {
                                      _enablePin = value;
                                    });
                                  },
                          ),
                          if (_enablePin) ...[
                            TextField(
                              controller: _pinController,
                              maxLength:
                                  PinSecurityService.maxAlphanumericLength,
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: _pinHidden,
                              enabled: !widget.busy,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: context.tr(
                                  'PIN / Kod',
                                  'PIN / Code',
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
                            TextField(
                              controller: _pinRepeatController,
                              maxLength:
                                  PinSecurityService.maxAlphanumericLength,
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: _pinRepeatHidden,
                              enabled: !widget.busy,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: context.tr(
                                  'PIN / Kod Tekrar',
                                  'Repeat PIN / Code',
                                ),
                                suffixIcon: IconButton(
                                  onPressed: widget.busy
                                      ? null
                                      : () {
                                          setState(() {
                                            _pinRepeatHidden =
                                                !_pinRepeatHidden;
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
                          ],
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
                              context.tr(
                                'Guvenli Kurulumu Tamamla',
                                'Complete Secure Setup',
                              ),
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
