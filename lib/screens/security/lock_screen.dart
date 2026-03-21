import 'package:flutter/material.dart';

import '../../widgets/app_lock_overlay.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.errorText,
    required this.onUnlockPressed,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final String? errorText;
  final Future<void> Function() onUnlockPressed;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppLockOverlay(
          title: title,
          subtitle: subtitle,
          busy: busy,
          errorText: errorText,
          onUnlock: onUnlockPressed,
        ),
      ),
    );
  }
}
