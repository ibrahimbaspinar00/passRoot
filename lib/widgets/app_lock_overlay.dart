import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';

class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({
    super.key,
    required this.onUnlock,
    this.busy = false,
    this.errorText,
    this.title,
    this.subtitle,
    this.onBiometricUnlock,
    this.showBiometricUnlock = false,
  });

  final Future<void> Function() onUnlock;
  final bool busy;
  final String? errorText;
  final String? title;
  final String? subtitle;
  final Future<void> Function()? onBiometricUnlock;
  final bool showBiometricUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pr = context.pr;
    return ColoredBox(
      color: pr.lockOverlay,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: pr.panelSurface,
              borderRadius: BorderRadius.circular(24),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: pr.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title ?? context.tr('Uygulama Kilitli', 'App Locked'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle ??
                      context.tr(
                        'Devam etmek icin kimliginizi dogrulayin.',
                        'Verify your identity to continue.',
                      ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: pr.textMuted,
                  ),
                ),
                if ((errorText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      errorText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (showBiometricUnlock && onBiometricUnlock != null) ...[
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            await onBiometricUnlock!.call();
                          },
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(context.tr('Biyometrik Dene', 'Try Biometric')),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await onUnlock();
                        },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Text(context.tr('Kilidi Ac', 'Unlock')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
