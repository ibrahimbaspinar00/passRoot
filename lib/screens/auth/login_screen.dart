import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/lang_x.dart';
import '../../services/firebase_account_service.dart';
import 'auth_helpers.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.accountService,
    required this.onOpenRegister,
  });

  final FirebaseAccountService accountService;
  final VoidCallback onOpenRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  String? _busyAction;

  bool get _busy => _busyAction != null;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await _runBusy('email', () async {
      try {
        await widget.accountService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (error) {
        if (!mounted) return;
        _snack(firebaseAuthErrorText(context, error));
      } catch (error) {
        if (!mounted) return;
        _snack(
          context.tr(
            'Giris basarisiz: $error',
            'Sign in failed: $error',
          ),
        );
      }
    });
  }

  Future<void> _signInWithGoogle() async {
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
            'Google giris basarisiz: $error',
            'Google sign in failed: $error',
          ),
        );
      }
    });
  }

  Future<void> _continueAsGuest() async {
    await _runBusy('guest', () async {
      try {
        await widget.accountService.signInAnonymously();
      } on FirebaseAuthException catch (error) {
        if (!mounted) return;
        _snack(firebaseAuthErrorText(context, error));
      } catch (error) {
        if (!mounted) return;
        _snack(
          context.tr(
            'Misafir girisi basarisiz: $error',
            'Guest sign in failed: $error',
          ),
        );
      }
    });
  }

  Future<String?> _askResetEmail() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Sifre Sifirla', 'Reset Password')),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.tr('E-posta', 'Email'),
                  errorText: errorText,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final email = controller.text.trim();
                    if (!isValidEmail(email)) {
                      setDialogState(() {
                        errorText = context.tr(
                          'Gecerli bir e-posta girin.',
                          'Enter a valid email.',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, email);
                  },
                  child: Text(context.tr('Gonder', 'Send')),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _forgotPassword() async {
    final current = _emailController.text.trim();
    final email = isValidEmail(current) ? current : await _askResetEmail();
    if (!mounted || email == null) return;
    await _runBusy('reset', () async {
      try {
        await widget.accountService.sendPasswordResetEmail(email: email);
        if (!mounted) return;
        _snack(
          context.tr(
            'Sifre sifirlama e-postasi gonderildi.',
            'Password reset email has been sent.',
          ),
        );
      } on FirebaseAuthException catch (error) {
        if (!mounted) return;
        _snack(firebaseAuthErrorText(context, error));
      } catch (error) {
        if (!mounted) return;
        _snack(
          context.tr(
            'Sifre sifirlama basarisiz: $error',
            'Password reset failed: $error',
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('Giris Yap', 'Sign In'),
      subtitle: context.tr(
        'Hesabina guvenli sekilde giris yap. Google, e-posta veya misafir olarak devam edebilirsin.',
        'Sign in securely. Continue with Google, email, or as a guest.',
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _signInWithEmail(),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                child: Text(context.tr('Sifremi Unuttum', 'Forgot Password')),
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _signInWithEmail,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busyAction == 'email'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('Giris Yap', 'Sign In')),
            ),
            const SizedBox(height: 10),
            GoogleAuthButton(
              onPressed: _busy ? null : _signInWithGoogle,
              loading: _busyAction == 'google',
              label: context.tr('Google ile Giris Yap', 'Sign In with Google'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _continueAsGuest,
              child: _busyAction == 'guest'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.tr(
                        'Misafir Olarak Devam Et',
                        'Continue as Guest',
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    context.tr('Hesabin yok mu?', 'Don\'t have an account?'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : widget.onOpenRegister,
                  child: Text(context.tr('Kayit ol', 'Register')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
