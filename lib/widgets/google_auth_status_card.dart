import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/google_user_profile.dart';
import '../services/google_auth_service.dart';
import '../state/google_auth_store.dart';
import 'google_sign_in_button.dart';

class GoogleAuthStatusCard extends StatelessWidget {
  const GoogleAuthStatusCard({
    super.key,
    required this.authStore,
    required this.onShowMessage,
    required this.signedOutTitle,
    required this.signedOutDescription,
    this.showSignOutButton = false,
    this.guestHint,
    this.signedInBadgeText,
  });

  final GoogleAuthStore authStore;
  final ValueChanged<String> onShowMessage;
  final String signedOutTitle;
  final String signedOutDescription;
  final bool showSignOutButton;
  final String? guestHint;
  final String? signedInBadgeText;

  Future<void> _handleSignIn(BuildContext context) async {
    final successMessage = context.tr(
      'Google hesabi ile giris basarili.',
      'Signed in with Google successfully.',
    );
    final fallbackErrorMessage = context.tr(
      'Google ile giris yapilamadi. Lutfen tekrar deneyin.',
      'Google sign-in failed. Please try again.',
    );

    try {
      await authStore.signIn();
      onShowMessage(successMessage);
    } on GoogleAuthException catch (error) {
      onShowMessage(error.message);
    } on Object {
      onShowMessage(fallbackErrorMessage);
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final successMessage = context.tr(
      'Google oturumu kapatildi.',
      'Signed out from Google account.',
    );
    final fallbackErrorMessage = context.tr(
      'Google cikis islemi tamamlanamadi. Lutfen tekrar deneyin.',
      'Google sign-out failed. Please try again.',
    );

    try {
      await authStore.signOut();
      onShowMessage(successMessage);
    } on GoogleAuthException catch (error) {
      onShowMessage(error.message);
    } on Object {
      onShowMessage(fallbackErrorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    final signedIn = authStore.isSignedIn;
    final user = authStore.user;
    final syncStatus = authStore.cloudSyncStatus;

    final cardBorder = signedIn
        ? scheme.primary.withValues(alpha: 0.28)
        : pr.panelBorder;
    final gradient = signedIn
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pr.accentSoft.withValues(alpha: 0.95), pr.panelSurface],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pr.warningSoft.withValues(alpha: 0.62), pr.panelSurface],
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        gradient: gradient,
      ),
      padding: const EdgeInsets.all(14),
      child: signedIn && user != null
          ? _SignedInContent(
              user: user,
              isBusy: authStore.isBusy,
              showSignOutButton: showSignOutButton,
              badgeText: signedInBadgeText,
              syncStatus: syncStatus,
              onSignOut: () => _handleSignOut(context),
            )
          : _SignedOutContent(
              title: signedOutTitle,
              description: signedOutDescription,
              loading: authStore.isBusy,
              guestHint: guestHint,
              syncStatus: syncStatus,
              onSignIn: () => _handleSignIn(context),
            ),
    );
  }
}

class _SignedOutContent extends StatelessWidget {
  const _SignedOutContent({
    required this.title,
    required this.description,
    required this.loading,
    required this.guestHint,
    required this.syncStatus,
    required this.onSignIn,
  });

  final String title;
  final String description;
  final bool loading;
  final String? guestHint;
  final CloudSyncStatus syncStatus;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.error.withValues(alpha: 0.26)),
          ),
          child: Text(
            context.tr('Oturum acik degil', 'No active session'),
            style: textTheme.labelMedium?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.shield_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: textTheme.bodyMedium?.copyWith(
            color: pr.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              icon: Icons.storage_rounded,
              label: context.tr('Kasa: Yerel', 'Vault: Local only'),
              color: scheme.primary,
            ),
            _StatusChip(
              icon: _syncStatusIcon(syncStatus),
              label: _syncStatusLabel(context, syncStatus),
              color: _syncStatusColor(context, syncStatus),
            ),
          ],
        ),
        if ((guestHint ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            guestHint!,
            style: textTheme.bodySmall?.copyWith(
              color: pr.textMuted.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        GoogleSignInButton(
          label: context.tr('Google ile Giris Yap', 'Sign in with Google'),
          loadingLabel: context.tr(
            'Google baglantisi kuruluyor...',
            'Connecting to Google...',
          ),
          loading: loading,
          onPressed: onSignIn,
        ),
      ],
    );
  }
}

class _SignedInContent extends StatelessWidget {
  const _SignedInContent({
    required this.user,
    required this.isBusy,
    required this.showSignOutButton,
    required this.onSignOut,
    required this.syncStatus,
    this.badgeText,
  });

  final GoogleUserProfile user;
  final bool isBusy;
  final bool showSignOutButton;
  final VoidCallback onSignOut;
  final CloudSyncStatus syncStatus;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final badgeLabel = (badgeText ?? '').trim().isNotEmpty
        ? badgeText!.trim()
        : context.tr('Google hesabi bagli', 'Google account connected');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              icon: Icons.shield_rounded,
              label: context.tr('Oturum acik', 'Signed in'),
              color: scheme.tertiary,
            ),
            _StatusChip(
              icon: Icons.verified_rounded,
              label: badgeLabel,
              color: scheme.primary,
            ),
            _StatusChip(
              icon: _syncStatusIcon(syncStatus),
              label: _syncStatusLabel(context, syncStatus),
              color: _syncStatusColor(context, syncStatus),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.tr(
            'Google hesabi sadece kimlik dogrulamasi icin kullanilir. Kasa verileri bu cihazda sifreli kalir ve buluta otomatik aktarilmaz.',
            'Google account is used only for identity verification. Vault data stays encrypted on this device and is not automatically synced to cloud.',
          ),
          style: textTheme.bodySmall?.copyWith(
            color: pr.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _GoogleUserAvatar(user: user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: pr.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showSignOutButton) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isBusy ? null : onSignOut,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(context.tr('Cikis Yap', 'Sign Out')),
            ),
          ),
        ],
      ],
    );
  }
}

String _syncStatusLabel(BuildContext context, CloudSyncStatus status) {
  return switch (status) {
    CloudSyncStatus.disconnected => context.tr(
        'Bulut Senk.: Bagli degil',
        'Cloud Sync: Disconnected',
      ),
    CloudSyncStatus.unavailable => context.tr(
        'Bulut Senk.: Aktif degil',
        'Cloud Sync: Inactive',
      ),
    CloudSyncStatus.active => context.tr(
        'Bulut Senk.: Aktif',
        'Cloud Sync: Active',
      ),
    CloudSyncStatus.error => context.tr(
        'Bulut Senk.: Hata',
        'Cloud Sync: Error',
      ),
  };
}

Color _syncStatusColor(BuildContext context, CloudSyncStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    CloudSyncStatus.disconnected => scheme.outline,
    CloudSyncStatus.unavailable => scheme.error,
    CloudSyncStatus.active => scheme.tertiary,
    CloudSyncStatus.error => scheme.error,
  };
}

IconData _syncStatusIcon(CloudSyncStatus status) {
  return switch (status) {
    CloudSyncStatus.disconnected => Icons.cloud_off_outlined,
    CloudSyncStatus.unavailable => Icons.cloud_off_rounded,
    CloudSyncStatus.active => Icons.cloud_done_rounded,
    CloudSyncStatus.error => Icons.error_outline_rounded,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleUserAvatar extends StatelessWidget {
  const _GoogleUserAvatar({required this.user});

  final GoogleUserProfile user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (user.hasPhoto) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: scheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(user.photoUrl!),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: scheme.primary.withValues(alpha: 0.15),
      foregroundColor: scheme.primary,
      child: Text(
        user.initials,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
