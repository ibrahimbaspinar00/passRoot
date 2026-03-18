import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/lang_x.dart';
import '../../services/firebase_account_service.dart';
import 'auth_helpers.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.accountService,
    required this.onOpenLogin,
  });

  final FirebaseAccountService accountService;
  final VoidCallback onOpenLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordRepeatController = TextEditingController();

  bool _hidePassword = true;
  bool _hideRepeatPassword = true;
  String? _busyAction;

  bool get _busy => _busyAction != null;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runBusy(String action, Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busyAction = action;
    });
    try {
      await work();
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await _runBusy('register', () async {
      try {
        await widget.accountService.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      } on FirebaseAuthException catch (error) {
        if (!mounted) return;
        _snack(firebaseAuthErrorText(context, error));
      } catch (error) {
        if (!mounted) return;
        _snack(
          context.tr(
            'Kayit basarisiz: $error',
            'Registration failed: $error',
          ),
        );
      }
    });
  }

  Future<void> _registerWithGoogle() async {
    await _runBusy('google', () async {
      try {
        await widget.accountService.signInWithGoogle();
      } on FirebaseAuthException catch (error) {
        if (!mounted) return;
        _snack(firebaseAuthErrorText(context, error));
      } on FirebaseAccountException catch (error) {
        if (!mounted) return;
        _snack(error.message);
      } catch (error) {
        if (!mounted) return;
        _snack(
          context.tr(
            'Google ile kayit basarisiz: $error',
            'Google sign up failed: $error',
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('Kayit Ol', 'Register'),
      subtitle: context.tr(
        'Hesabini olustur, tum sifrelerine guvenle eris. Google ile hizli devam edebilirsin.',
        'Create your account to access your vault securely. You can continue quickly with Google.',
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('Ad Soyad', 'Full Name'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                final name = (value ?? '').trim();
                if (name.isEmpty) {
                  return context.tr(
                    'Ad Soyad bos birakilamaz.',
                    'Full name is required.',
                  );
                }
                if (name.length < 2) {
                  return context.tr(
                    'Ad Soyad en az 2 karakter olmali.',
                    'Full name must be at least 2 characters.',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.tr('E-posta', 'Email'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) {
                  return context.tr(
                    'E-posta bos birakilamaz.',
                    'Email is required.',
                  );
                }
                if (!isValidEmail(email)) {
                  return context.tr(
                    'Gecerli bir e-posta girin.',
                    'Enter a valid email.',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.tr('Sifre', 'Password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _hidePassword = !_hidePassword;
                    });
                  },
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
              validator: (value) {
                final pass = (value ?? '').trim();
                if (pass.isEmpty) {
                  return context.tr(
                    'Sifre bos birakilamaz.',
                    'Password is required.',
                  );
                }
                if (pass.length < 6) {
                  return context.tr(
                    'Sifre en az 6 karakter olmali.',
                    'Password must be at least 6 characters.',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordRepeatController,
              obscureText: _hideRepeatPassword,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onFieldSubmitted: (_) => _registerWithEmail(),
              decoration: InputDecoration(
                labelText: context.tr('Sifre Tekrar', 'Repeat Password'),
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _hideRepeatPassword = !_hideRepeatPassword;
                    });
                  },
                  icon: Icon(
                    _hideRepeatPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
              validator: (value) {
                final repeat = (value ?? '').trim();
                if (repeat.isEmpty) {
                  return context.tr(
                    'Sifre tekrar alani bos birakilamaz.',
                    'Repeat password is required.',
                  );
                }
                if (repeat != _passwordController.text.trim()) {
                  return context.tr(
                    'Sifreler eslesmiyor.',
                    'Passwords do not match.',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _registerWithEmail,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busyAction == 'register'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('Kayit Ol', 'Register')),
            ),
            const SizedBox(height: 10),
            GoogleAuthButton(
              onPressed: _busy ? null : _registerWithGoogle,
              loading: _busyAction == 'google',
              label: context.tr(
                'Google ile Kayit Ol / Devam Et',
                'Register / Continue with Google',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    context.tr('Zaten hesabin var mi?', 'Already have an account?'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : widget.onOpenLogin,
                  child: Text(context.tr('Giris yap', 'Sign In')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
