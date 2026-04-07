import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';

class PinRecoveryScreen extends StatelessWidget {
  const PinRecoveryScreen({
    super.key,
    required this.biometricRecoveryAvailable,
    required this.busy,
    required this.errorText,
    required this.onBiometricResetPin,
    required this.onResetVault,
  });

  final bool biometricRecoveryAvailable;
  final bool busy;
  final String? errorText;
  final Future<void> Function() onBiometricResetPin;
  final Future<void> Function() onResetVault;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('PIN Kurtarma', 'PIN Recovery'))),
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
                  context.tr(
                    'PIN unutuldugunda kasa verisine sifresiz geri donus yoktur.',
                    'When PIN is forgotten, there is no passwordless way to recover vault access.',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  biometricRecoveryAvailable
                      ? context.tr(
                          'Bu cihazda biyometri aktif. Biyometrik dogrulama ile yeni PIN belirleyebilirsiniz.',
                          'Biometrics is active on this device. You can verify biometrically and set a new PIN.',
                        )
                      : context.tr(
                          'Biyometri kullanilamiyor veya kapali. Mevcut kasaya erisim geri getirilemez. Yedek varsa geri yukleyebilir veya kasayi sifirlayabilirsiniz.',
                          'Biometrics is unavailable or disabled. Access to current vault cannot be recovered. If you have a backup, restore/import after reset.',
                        ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: pr.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((errorText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      errorText!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (biometricRecoveryAvailable)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onBiometricResetPin,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(
                        context.tr(
                          'Biyometri ile PIN Sifirla',
                          'Reset PIN with Biometrics',
                        ),
                      ),
                    ),
                  ),
                if (biometricRecoveryAvailable) const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onResetVault,
                    icon: const Icon(Icons.delete_forever_rounded),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                    ),
                    label: Text(context.tr('Kasayi Sifirla', 'Reset Vault')),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Kasa sifirlama islemi geri alinamaz. Tum yerel veriler ve anahtar materyali silinir.',
                    'Vault reset is irreversible. All local data and key material will be deleted.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: pr.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
