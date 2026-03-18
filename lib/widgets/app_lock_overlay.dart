import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';

class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({
    super.key,
    required this.onUnlock,
    required this.biometricEnabled,
    required this.onUseBiometric,
  });

  final Future<void> Function() onUnlock;
  final bool biometricEnabled;
  final Future<bool> Function() onUseBiometric;

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
                  context.tr('Uygulama Kilitli', 'App Locked'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Devam etmek icin kasayi tekrar acin.',
                    'Unlock to continue.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pr.textMuted),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () async {
                    await onUnlock();
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(context.tr('Kilidi Ac', 'Unlock')),
                ),
                if (biometricEnabled) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await onUseBiometric();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                'Biyometrik dogrulama basarisiz.',
                                'Biometric authentication failed.',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(context.tr('Biyometrik Dene', 'Try Biometric')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
