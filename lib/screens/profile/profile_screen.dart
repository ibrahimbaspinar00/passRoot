import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';
import '../../state/account_store.dart';
import '../../state/app_settings_store.dart';
import '../../widgets/settings_section_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.accountStore,
    required this.settingsStore,
  });

  final AccountStore accountStore;
  final AppSettingsStore settingsStore;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      await action();
      if (successMessage != null) {
        _snack(successMessage);
      }
    } on AccountOperationException catch (error) {
      _snack(error.message);
    } on FormatException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openSignIn() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => _SignInScreen(accountStore: widget.accountStore),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _snack(context.tr('Oturum açıldı.', 'Signed in successfully.'));
    }
  }

  Future<void> _openRegister() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => _RegisterScreen(accountStore: widget.accountStore),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _snack(
        context.tr(
          'Hesap oluşturuldu ve giriş yapıldı.',
          'Account created and signed in.',
        ),
      );
    }
  }

  Future<void> _openEditProfile({bool photoOnly = false}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => _EditProfileScreen(
          accountStore: widget.accountStore,
          photoOnly: photoOnly,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _snack(context.tr('Profil bilgileri güncellendi.', 'Profile updated.'));
    }
  }

  Future<void> _openChangeEmail() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => _ChangeEmailScreen(accountStore: widget.accountStore),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _snack(context.tr('E-posta güncellendi.', 'Email updated.'));
    }
  }

  Future<void> _openChangePassword() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            _ChangePasswordScreen(accountStore: widget.accountStore),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _snack(context.tr('Şifre güncellendi.', 'Password updated.'));
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Oturumu Kapat', 'Sign Out')),
          content: Text(
            context.tr(
              'Bu cihazdaki oturum kapatılacak. Tekrar giriş yapabilirsiniz.',
              'Current session on this device will be closed. You can sign in again.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('İptal', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Oturumu Kapat', 'Sign Out')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _runAction(
      () => widget.accountStore.signOut(),
      successMessage: context.tr('Oturum kapatıldı.', 'Signed out.'),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    var hidden = true;
    String? errorText;

    final password = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.tr('Hesabı Sil', 'Delete Account')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      'Bu işlem geri alınamaz. Devam etmek için mevcut şifrenizi doğrulayın.',
                      'This action is irreversible. Verify your current password to continue.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: context.tr('Mevcut Şifre', 'Current Password'),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
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
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('İptal', 'Cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () {
                    final value = passwordController.text.trim();
                    if (value.isEmpty) {
                      setState(() {
                        errorText = context.tr(
                          'Şifre alanı boş bırakılamaz.',
                          'Password is required.',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: Text(context.tr('Hesabı Sil', 'Delete Account')),
                ),
              ],
            );
          },
        );
      },
    );
    passwordController.dispose();
    if (password == null) return;
    if (!mounted) return;

    await _runAction(
      () => widget.accountStore.deleteAccount(currentPassword: password),
      successMessage: context.tr(
        'Hesap silindi. Misafir moduna geçildi.',
        'Account deleted. Switched to guest mode.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.accountStore, widget.settingsStore]),
      builder: (context, _) {
        if (!widget.accountStore.loaded) {
          return Scaffold(
            appBar: AppBar(title: Text(context.tr('Profil', 'Profile'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final profile = widget.accountStore.profile;
        final hasPin = widget.settingsStore.pinAvailable;
        final appLockEnabled = widget.settingsStore.settings.appLockEnabled;

        return Scaffold(
          appBar: AppBar(title: Text(context.tr('Profil', 'Profile'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _ProfileHeaderCard(
                username: profile?.username,
                email: profile?.email,
                photoUrl: profile?.photoUrl,
                statusLabel: widget.accountStore.accountStatusLabel,
                signedIn: widget.accountStore.isSignedIn,
              ),
              const SizedBox(height: 12),
              if (!widget.accountStore.isSignedIn) ...[
                SettingsSectionCard(
                  title: context.tr('Hesap Erişimi', 'Account Access'),
                  children: [
                    Text(
                      context.tr(
                        'Henüz giriş yapılmadı. Verilerinizi daha güvenli ve taşınabilir yönetmek için hesap oluşturun.',
                        'No active session yet. Create an account to manage your data in a safer and portable way.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.pr.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _openSignIn,
                            icon: const Icon(Icons.login_rounded),
                            label: Text(context.tr('Giriş Yap', 'Sign In')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _openRegister,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(context.tr('Kayıt Ol', 'Register')),
                          ),
                        ),
                      ],
                    ),
                    if (widget.accountStore.hasRegisteredAccount) ...[
                      const SizedBox(height: 8),
                      _HintCard(
                        icon: Icons.info_outline_rounded,
                        text: context.tr(
                          'Bu cihazda kayıtlı bir hesap var. E-posta ve şifreyle giriş yapabilirsiniz.',
                          'A registered account exists on this device. You can sign in with email and password.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _HintCard(
                        icon: Icons.verified_user_outlined,
                        text: context.tr(
                          'Guvenlik nedeniyle dogrulamasiz "Sifremi unuttum" reseti yoktur. Sifre degistirme islemi yalnizca mevcut sifreyle dogrulama yapildiginda gerceklesir.',
                          'For security, unauthenticated "Forgot Password" reset is disabled. Password update is allowed only after verifying the current password.',
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                SettingsSectionCard(
                  title: context.tr('Hesap Yönetimi', 'Account Management'),
                  children: [
                    _ProfileActionTile(
                      icon: Icons.edit_outlined,
                      title: context.tr(
                        'Profil Bilgilerini Düzenle',
                        'Edit Profile',
                      ),
                      subtitle: context.tr(
                        'Kullanıcı adı ve profil görünümünü güncelleyin.',
                        'Update username and profile appearance.',
                      ),
                      onTap: _busy ? null : _openEditProfile,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.photo_camera_back_outlined,
                      title: context.tr(
                        'Profil Fotoğrafı Güncelle',
                        'Update Profile Photo',
                      ),
                      subtitle: context.tr(
                        'Profil fotoğraf URL bağlantısını değiştirin.',
                        'Change the profile photo URL.',
                      ),
                      onTap: _busy
                          ? null
                          : () => _openEditProfile(photoOnly: true),
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.alternate_email_rounded,
                      title: context.tr('E-posta Değiştir', 'Change Email'),
                      subtitle: context.tr(
                        'Yeni e-posta adresini doğrulayıp kaydet.',
                        'Validate and save a new email address.',
                      ),
                      onTap: _busy ? null : _openChangeEmail,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.lock_reset_rounded,
                      title: context.tr('Şifre Değiştir', 'Change Password'),
                      subtitle: context.tr(
                        'Mevcut şifreyi doğrulayarak yeni şifre belirleyin.',
                        'Verify current password and set a new one.',
                      ),
                      onTap: _busy ? null : _openChangePassword,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.logout_rounded,
                      title: context.tr('Çıkış Yap', 'Sign Out'),
                      subtitle: context.tr(
                        'Bu cihazdaki oturumu güvenli şekilde kapat.',
                        'Securely end session on this device.',
                      ),
                      onTap: _busy ? null : _confirmSignOut,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.delete_forever_rounded,
                      title: context.tr('Hesabı Sil', 'Delete Account'),
                      subtitle: context.tr(
                        'Geri alınamaz işlem: hesap bilgileri tamamen kaldırılır.',
                        'Irreversible action: account data will be removed.',
                      ),
                      danger: true,
                      onTap: _busy ? null : _confirmDeleteAccount,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (!hasPin || !appLockEnabled)
                SettingsSectionCard(
                  title: context.tr(
                    'Hesabını Güvene Al',
                    'Secure Your Account',
                  ),
                  children: [
                    _HintCard(
                      icon: Icons.security_rounded,
                      text: context.tr(
                        'Uygulama kilidi ve PIN kapalı görünüyor. Ayarlar > Güvenlik bölümünden etkinleştirerek hesabını daha iyi koruyabilirsin.',
                        'App lock or PIN appears disabled. You can improve account security from Settings > Security.',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.username,
    required this.email,
    required this.photoUrl,
    required this.statusLabel,
    required this.signedIn,
  });

  final String? username;
  final String? email;
  final String? photoUrl;
  final String statusLabel;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    final name = (username ?? '').trim();
    final safeName = name.isEmpty
        ? context.tr('Misafir Kullanıcı', 'Guest User')
        : name;
    final safeEmail = (email ?? '').trim().isEmpty
        ? context.tr('Hesap bağlı değil', 'No linked account')
        : email!.trim();
    final initials = safeName.length >= 2
        ? safeName.substring(0, 2).toUpperCase()
        : safeName.substring(0, 1).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pr.panelBorder),
        gradient: LinearGradient(
          colors: [pr.accentSoft, scheme.primary.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            foregroundImage: (photoUrl ?? '').trim().isEmpty
                ? null
                : NetworkImage(photoUrl!.trim()),
            child: Text(
              initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  safeEmail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: pr.textMuted),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: signedIn
                        ? scheme.primary.withValues(alpha: 0.14)
                        : pr.warningSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pr.softFill,
        border: Border.all(color: pr.panelBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: pr.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: danger ? pr.dangerSoft : pr.softFill,
          border: Border.all(
            color: danger
                ? scheme.error.withValues(alpha: 0.3)
                : pr.panelBorder,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: danger ? scheme.error : null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: danger ? scheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: pr.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _AccountFormScaffold extends StatelessWidget {
  const _AccountFormScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pr.softFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pr.panelBorder),
            ),
            child: Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: pr.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          SettingsSectionCard(title: title, children: [child]),
        ],
      ),
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen({required this.accountStore});

  final AccountStore accountStore;

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accountStore.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AccountOperationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordPolicy() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr('Sifre Kurtarma Politikasi', 'Password Recovery Policy'),
          ),
          content: Text(
            context.tr(
              'Passroot yerel guvenlik modeli kullanir. Bu nedenle e-posta eslesmesiyle sifre sifirlama yoktur. Sifrenizi degistirmek icin oturum acik durumdayken Profil > Sifre Degistir ekranindan mevcut sifrenizle dogrulama yapmaniz gerekir.',
              'Passroot uses a local-security model. Therefore, email-only password reset is not available. To change password, you must be signed in and verify your current password from Profile > Change Password.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Anladim', 'Understood')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AccountFormScaffold(
      title: context.tr('Giriş Yap', 'Sign In'),
      subtitle: context.tr(
        'Kayitli e-posta ve sifrenizi kullanarak hesabiniza giris yapin. Guvenlik nedeniyle dogrulamasiz sifre reseti kapatilidir.',
        'Sign in with your registered email and password. Unauthenticated password reset is disabled for security.',
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('E-posta', 'Email'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _hidden,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.tr('Şifre', 'Password'),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _hidden = !_hidden;
                  });
                },
                icon: Icon(
                  _hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(context.tr('Giriş Yap', 'Sign In')),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : _showForgotPasswordPolicy,
            icon: const Icon(Icons.help_outline_rounded),
            label: Text(
              context.tr(
                'Sifremi unuttum (guvenlik bilgisi)',
                'Forgot password (security info)',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterScreen extends StatefulWidget {
  const _RegisterScreen({required this.accountStore});

  final AccountStore accountStore;

  @override
  State<_RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatController = TextEditingController();
  final _photoController = TextEditingController();

  bool _passwordHidden = true;
  bool _repeatHidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final pass = _passwordController.text.trim();
    final repeat = _repeatController.text.trim();
    if (pass != repeat) {
      setState(() {
        _error = context.tr('Şifreler eşleşmiyor.', 'Passwords do not match.');
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accountStore.register(
        username: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        photoUrl: _photoController.text.trim().isEmpty
            ? null
            : _photoController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AccountOperationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountFormScaffold(
      title: context.tr('Kayıt Ol', 'Register'),
      subtitle: context.tr(
        'Hesabınızı oluşturarak profil ve güvenlik ayarlarını merkezi olarak yönetin.',
        'Create an account and manage profile/security settings from one place.',
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('Kullanıcı Adı', 'Username'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('E-posta', 'Email'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _passwordHidden,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('Şifre', 'Password'),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _passwordHidden = !_passwordHidden;
                  });
                },
                icon: Icon(
                  _passwordHidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _repeatController,
            obscureText: _repeatHidden,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('Şifre Tekrar', 'Repeat Password'),
              suffixIcon: IconButton(
                onPressed: () {
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
          const SizedBox(height: 8),
          TextField(
            controller: _photoController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.tr(
                'Profil Fotoğrafı URL (Opsiyonel)',
                'Profile Photo URL (Optional)',
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1_rounded),
            label: Text(context.tr('Hesap Oluştur', 'Create Account')),
          ),
        ],
      ),
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({
    required this.accountStore,
    required this.photoOnly,
  });

  final AccountStore accountStore;
  final bool photoOnly;

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _photoController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.accountStore.profile;
    _nameController = TextEditingController(text: profile?.username ?? '');
    _photoController = TextEditingController(text: profile?.photoUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.photoOnly) {
        await widget.accountStore.updatePhoto(
          _photoController.text.trim().isEmpty ? null : _photoController.text,
        );
      } else {
        await widget.accountStore.updateProfile(
          username: _nameController.text,
          photoUrl: _photoController.text.trim().isEmpty
              ? null
              : _photoController.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AccountOperationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.photoOnly
        ? context.tr('Profil Fotoğrafı', 'Profile Photo')
        : context.tr('Profili Düzenle', 'Edit Profile');
    return _AccountFormScaffold(
      title: title,
      subtitle: context.tr(
        'Profil bilgileriniz hesabınızla birlikte saklanır ve bu cihazda güvenli şekilde yönetilir.',
        'Your profile information is stored with your account and managed securely on this device.',
      ),
      child: Column(
        children: [
          if (!widget.photoOnly) ...[
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('Kullanıcı Adı', 'Username'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _photoController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.tr(
                'Profil Fotoğrafı URL',
                'Profile Photo URL',
              ),
              hintText: 'https://example.com/avatar.jpg',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(context.tr('Kaydet', 'Save')),
          ),
        ],
      ),
    );
  }
}

class _ChangeEmailScreen extends StatefulWidget {
  const _ChangeEmailScreen({required this.accountStore});

  final AccountStore accountStore;

  @override
  State<_ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<_ChangeEmailScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('E-posta Değiştir', 'Change Email')),
          content: Text(
            context.tr(
              'E-posta değişikliği sonrası giriş işlemlerinde yeni adres kullanılacaktır. Devam edilsin mi?',
              'After this change, sign-in will use the new email. Continue?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('İptal', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Devam Et', 'Continue')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accountStore.changeEmail(
        newEmail: _emailController.text,
        currentPassword: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AccountOperationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountFormScaffold(
      title: context.tr('E-posta Değiştir', 'Change Email'),
      subtitle: context.tr(
        'Hassas işlemdir. Değişiklik için mevcut şifrenizle onay gereklidir.',
        'Sensitive operation. Requires confirmation with current password.',
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('Yeni E-posta', 'New Email'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _hidden,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.tr('Mevcut Şifre', 'Current Password'),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _hidden = !_hidden;
                  });
                },
                icon: Icon(
                  _hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.alternate_email_rounded),
            label: Text(context.tr('E-postayı Güncelle', 'Update Email')),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen({required this.accountStore});

  final AccountStore accountStore;

  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _nextController = TextEditingController();
  final _repeatController = TextEditingController();
  bool _currentHidden = true;
  bool _nextHidden = true;
  bool _repeatHidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _nextController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_nextController.text.trim() != _repeatController.text.trim()) {
      setState(() {
        _error = context.tr(
          'Yeni şifreler eşleşmiyor.',
          'New passwords do not match.',
        );
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Şifre Değiştir', 'Change Password')),
          content: Text(
            context.tr(
              'Şifre değiştirildikten sonra sonraki girişlerde yeni şifre kullanılacaktır.',
              'After password update, future sign-ins will use the new password.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('İptal', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Onayla', 'Confirm')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accountStore.changePassword(
        currentPassword: _currentController.text,
        newPassword: _nextController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AccountOperationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountFormScaffold(
      title: context.tr('Şifre Değiştir', 'Change Password'),
      subtitle: context.tr(
        'Hesap güvenliğinizi artırmak için düzenli aralıklarla şifre değiştirin.',
        'Rotate your password periodically to improve account security.',
      ),
      child: Column(
        children: [
          TextField(
            controller: _currentController,
            obscureText: _currentHidden,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('Mevcut Şifre', 'Current Password'),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _currentHidden = !_currentHidden;
                  });
                },
                icon: Icon(
                  _currentHidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nextController,
            obscureText: _nextHidden,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr('Yeni Şifre', 'New Password'),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _nextHidden = !_nextHidden;
                  });
                },
                icon: Icon(
                  _nextHidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _repeatController,
            obscureText: _repeatHidden,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.tr('Yeni Şifre Tekrar', 'Repeat New Password'),
              suffixIcon: IconButton(
                onPressed: () {
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
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_reset_rounded),
            label: Text(context.tr('Şifreyi Güncelle', 'Update Password')),
          ),
        ],
      ),
    );
  }
}
