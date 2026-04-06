import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../state/vault_store.dart';

class StorageRecoveryScreen extends StatelessWidget {
  const StorageRecoveryScreen({
    super.key,
    required this.issue,
    required this.busy,
    required this.onRetry,
    required this.onOpenRestoreSettings,
    required this.onResetCorruptedVault,
  });

  final VaultStorageIssue issue;
  final bool busy;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenRestoreSettings;
  final Future<void> Function() onResetCorruptedVault;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Scaffold(
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
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: pr.panelSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: pr.panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: pr.panelShadow,
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: pr.dangerSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.warning_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('Kasa Verisi Okunamadı', 'Vault Data Error'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      issue.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      issue.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: pr.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                await onRetry();
                              },
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.tr('Yeniden Dene', 'Try Again')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onOpenRestoreSettings,
                        icon: const Icon(Icons.restore_rounded),
                        label: Text(
                          context.tr(
                            'Ayarlar > Yedekten Geri Yükle',
                            'Settings > Restore Backup',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                await onResetCorruptedVault();
                              },
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: Text(
                          context.tr(
                            'Bozuk Yerel Veriyi Temizle',
                            'Clear Corrupted Local Data',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr(
                        'Not: Bu ekran veri kaybını gizlemek için değil, veri sorunu tespit edildiğinde sizi güvenli kurtarma adımlarına yönlendirmek için gösterilir.',
                        'Note: This screen is shown to prevent silent data loss and guide safe recovery steps.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: pr.textMuted,
                        fontWeight: FontWeight.w600,
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
