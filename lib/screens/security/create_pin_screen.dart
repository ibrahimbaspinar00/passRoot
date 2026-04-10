import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';
import '../../services/pin_security_service.dart';
import '../../widgets/passroot_logo.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({
    super.key,
    required this.onSubmitPin,
    required this.busy,
    required this.errorText,
  });

  final Future<void> Function(String pin) onSubmitPin;
  final bool busy;
  final String? errorText;

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  late final TextEditingController _pinController;
  late final TextEditingController _repeatController;
  bool _pinHidden = true;
  bool _repeatHidden = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _repeatController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy) return;
    final pin = _pinController.text.trim();
    final repeat = _repeatController.text.trim();

    if (!PinSecurityService.isStrongPinCandidate(pin)) {
      setState(() {
        _localError = context.tr(
          PinSecurityService.enrollmentPolicyLabelTr(),
          PinSecurityService.enrollmentPolicyLabelEn(),
        );
      });
      return;
    }
    if (pin != repeat) {
      setState(() {
        _localError = context.tr(
          'PIN kodlari eslesmiyor.',
          'PIN values do not match.',
        );
      });
      return;
    }

    setState(() {
      _localError = null;
    });
    await widget.onSubmitPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                constraints: const BoxConstraints(maxWidth: 460),
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
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: pr.accentSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(child: PassRootLogo(size: 48)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr(
                              'Giris PIN\'i Olustur',
                              'Create Access PIN',
                            ),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              'Bu uygulama hassas veri saklar. PIN sadece 4 veya 6 hane olmalidir.',
                              'This app stores sensitive data. PIN must be 4 or 6 digits.',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: pr.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
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
                              labelText: context.tr(
                                'Yeni PIN / Kod',
                                'New PIN / Code',
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
                            controller: _repeatController,
                            maxLength: PinSecurityService.maxPinLength,
                            keyboardType: TextInputType.number,
                            obscureText: _repeatHidden,
                            enabled: !widget.busy,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
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
                                          _repeatHidden = !_repeatHidden;
                                        });
                                      },
                                icon: Icon(
                                  _repeatHidden
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
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                                : const Icon(Icons.lock_reset_rounded),
                            label: Text(
                              context.tr('PIN\'i Kaydet', 'Save PIN'),
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
