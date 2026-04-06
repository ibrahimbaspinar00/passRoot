import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/lang_x.dart';
import '../services/pin_security_service.dart';

class PinDialogs {
  static Future<String?> askNewPin(
    BuildContext context, {
    bool barrierDismissible = true,
    String? title,
    String? description,
    String? actionText,
  }) async {
    final pinController = TextEditingController();
    final repeatController = TextEditingController();
    String? errorText;
    var hidePin = true;
    var hideRepeat = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(title ?? context.tr('PIN Kodu Ayarla', 'Set PIN')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((description ?? '').trim().isNotEmpty) ...[
                    Text(
                      description!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: pinController,
                    maxLength: PinSecurityService.maxAlphanumericLength,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: hidePin,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    decoration: InputDecoration(
                      labelText: context.tr('Yeni PIN / Kod', 'New PIN / Code'),
                      helperText: context.tr(
                        'Sayisal PIN (8-12) veya alfanumerik kod (8-24).',
                        'Numeric PIN (8-12) or alphanumeric code (8-24).',
                      ),
                      errorText: errorText,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            hidePin = !hidePin;
                          });
                        },
                        icon: Icon(
                          hidePin
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: repeatController,
                    maxLength: PinSecurityService.maxAlphanumericLength,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: hideRepeat,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'PIN / Kod Tekrar',
                        'Repeat PIN / Code',
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            hideRepeat = !hideRepeat;
                          });
                        },
                        icon: Icon(
                          hideRepeat
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final pin = pinController.text.trim();
                    if (!PinSecurityService.isStrongPinCandidate(pin)) {
                      setDialogState(() {
                        errorText = context.tr(
                          PinSecurityService.enrollmentPolicyLabelTr(),
                          PinSecurityService.enrollmentPolicyLabelEn(),
                        );
                      });
                      return;
                    }
                    if (pin != repeatController.text.trim()) {
                      setDialogState(() {
                        errorText = context.tr(
                          'PIN kodlari eslesmiyor.',
                          'PIN values do not match.',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, pin);
                  },
                  child: Text(actionText ?? context.tr('Kaydet', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    repeatController.dispose();
    return result;
  }

  static Future<bool> verifyPin({
    required BuildContext context,
    required Future<PinVerificationResult> Function(String pin) onVerify,
    bool barrierDismissible = false,
    String? title,
    String? description,
    String? actionText,
    Future<void> Function()? onForgotPin,
    String? forgotPinText,
  }) async {
    final controller = TextEditingController();
    String? errorText;
    var hidden = true;
    var requiresMasterFallback = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> verifyNow() async {
              final pin = controller.text.trim();
              if (!PinSecurityService.isPotentialUnlockInput(pin)) {
                setDialogState(() {
                  requiresMasterFallback = false;
                  errorText = context.tr(
                    'PIN formati gecersiz. Sayisal PIN icin 8-12, alfanumerik kod icin 8-24 karakter kullanin.',
                    'Invalid PIN format. Use 8-12 digits for numeric PIN or 8-24 alphanumeric characters.',
                  );
                });
                return;
              }

              final result = await onVerify(pin);
              if (!context.mounted) return;
              if (result.success) {
                Navigator.pop(context, true);
                return;
              }
              setDialogState(() {
                requiresMasterFallback = result.requiresMasterPassword;
                if (result.locked) {
                  errorText = result.requiresMasterPassword
                      ? context.tr(
                          'PIN gecici olarak kilitlendi. ${result.retryAfterLabel()} sonra tekrar deneyin veya master password ile devam edin.',
                          'PIN is temporarily locked. Retry in ${result.retryAfterLabel()} or continue with master password.',
                        )
                      : context.tr(
                          'Cok fazla deneme yapildi. ${result.retryAfterLabel()} sonra tekrar deneyin.',
                          'Too many attempts. Try again in ${result.retryAfterLabel()}.',
                        );
                  return;
                }
                errorText =
                    result.message ??
                    context.tr('PIN hatali.', 'Incorrect PIN.');
              });
            }

            return AlertDialog(
              scrollable: true,
              title: Text(title ?? context.tr('PIN Dogrulama', 'Verify PIN')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((description ?? '').trim().isNotEmpty) ...[
                    Text(
                      description!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: controller,
                    maxLength: PinSecurityService.maxAlphanumericLength,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: hidden,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      verifyNow();
                    },
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'PIN / Erisim Kodu',
                        'PIN / Access Code',
                      ),
                      helperText: context.tr(
                        'Sayisal PIN (8-12) veya alfanumerik kod (8-24).',
                        'Numeric PIN (8-12) or alphanumeric code (8-24).',
                      ),
                      errorText: errorText,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            hidden = !hidden;
                          });
                        },
                        icon: Icon(
                          hidden
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (onForgotPin != null)
                  TextButton(
                    onPressed: () {
                      onForgotPin();
                    },
                    child: Text(
                      forgotPinText ??
                          (requiresMasterFallback
                              ? context.tr(
                                  'Master Password ile Devam Et',
                                  'Continue with Master Password',
                                )
                              : context.tr('PIN\'i Unuttum', 'Forgot PIN')),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: verifyNow,
                  child: Text(actionText ?? context.tr('Dogrula', 'Verify')),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result == true;
  }
}
