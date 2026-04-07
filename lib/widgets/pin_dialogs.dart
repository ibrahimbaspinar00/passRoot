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
                    maxLength: PinSecurityService.maxPinLength,
                    keyboardType: TextInputType.number,
                    obscureText: hidePin,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.tr('Yeni PIN / Kod', 'New PIN / Code'),
                      helperText: context.tr(
                        'PIN 4 veya 6 hane olmalidir.',
                        'PIN must be 4 or 6 digits.',
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
                    maxLength: PinSecurityService.maxPinLength,
                    keyboardType: TextInputType.number,
                    obscureText: hideRepeat,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  errorText = context.tr(
                    'PIN formati gecersiz. PIN 4 veya 6 hane olmalidir.',
                    'Invalid PIN format. PIN must be 4 or 6 digits.',
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
                if (result.locked) {
                  errorText = context.tr(
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
                    maxLength: PinSecurityService.maxPinLength,
                    keyboardType: TextInputType.number,
                    obscureText: hidden,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        'PIN 4 veya 6 hane olmalidir.',
                        'PIN must be 4 or 6 digits.',
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
                          context.tr('PIN\'i Unuttum', 'Forgot PIN'),
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
