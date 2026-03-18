import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../l10n/lang_x.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../services/firebase_account_service.dart';
import '../state/app_settings_store.dart';
import 'app_shell.dart';
import 'app_theme.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.settingsStore});

  final AppSettingsStore settingsStore;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final FirebaseAccountService _accountService;
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();
    _accountService = FirebaseAccountService();
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return AppShell(settingsStore: widget.settingsStore);
    }

    return StreamBuilder<User?>(
      stream: _accountService.authStateChanges(),
      initialData: _accountService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _AuthLoadingView();
        }

        final user = snapshot.data;
        if (user != null) {
          return AppShell(settingsStore: widget.settingsStore);
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showRegister
              ? RegisterScreen(
                  key: const ValueKey<String>('register-screen'),
                  accountService: _accountService,
                  onOpenLogin: () {
                    setState(() {
                      _showRegister = false;
                    });
                  },
                )
              : LoginScreen(
                  key: const ValueKey<String>('login-screen'),
                  accountService: _accountService,
                  onOpenRegister: () {
                    setState(() {
                      _showRegister = true;
                    });
                  },
                ),
        );
      },
    );
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[pr.canvasGradientTop, pr.canvasGradientBottom],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: pr.panelSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pr.panelBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.3),
                ),
                const SizedBox(width: 10),
                Text(
                  context.tr(
                    'Hesap kontrol ediliyor...',
                    'Checking account...',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
