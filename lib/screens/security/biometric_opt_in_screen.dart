import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';

class BiometricOptInScreen extends StatelessWidget {
  const BiometricOptInScreen({
    super.key,
    required this.busy,
    required this.errorText,
    required this.onEnable,
    required this.onSkip,
  });

  final bool busy;
  final String? errorText;
  final Future<void> Function() onEnable;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;

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
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.fingerprint_rounded,
                            size: 42,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr(
                              'Biyometrik Giris Acilsin mi?',
                              'Enable Biometric Unlock?',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              'PIN girisiniz devam eder. Biyometriyi acarsaniz kilit ekraninda daha hizli dogrulama kullanabilirsiniz.',
                              'PIN login remains available. If enabled, you can use faster biometric verification on the lock screen.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: pr.textMuted),
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
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: scheme.onErrorContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: busy ? null : onEnable,
                            icon: busy
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.1,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              context.tr(
                                'Biyometriyi Etkinlestir',
                                'Enable Biometrics',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: busy ? null : onSkip,
                            child: Text(
                              context.tr('Simdilik Gec', 'Skip for now'),
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
