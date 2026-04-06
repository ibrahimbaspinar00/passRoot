import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../l10n/lang_x.dart';
import '../../services/vault_key_service.dart';

class MasterUnlockScreen extends StatefulWidget {
  const MasterUnlockScreen({
    super.key,
    required this.onVerifyMasterPassword,
    this.allowBack = true,
    this.description,
  });

  final Future<VaultUnlockResult> Function(String masterPassword)
  onVerifyMasterPassword;
  final bool allowBack;
  final String? description;

  @override
  State<MasterUnlockScreen> createState() => _MasterUnlockScreenState();
}

class _MasterUnlockScreenState extends State<MasterUnlockScreen> {
  final _controller = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    final value = _controller.text.trim();
    if (value.length < 12) {
      setState(() {
        _errorText = context.tr(
          'Master password en az 12 karakter olmali.',
          'Master password must be at least 12 characters.',
        );
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });
    final result = await widget.onVerifyMasterPassword(value);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _errorText =
          result.message ??
          context.tr(
            'Master password dogrulanamadi.',
            'Master password verification failed.',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return PopScope(
      canPop: widget.allowBack && !_busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.allowBack,
          title: Text(context.tr('Master Password', 'Master Password')),
        ),
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
                    widget.description ??
                        context.tr(
                          'Kasa anahtarini acmak icin master password girin.',
                          'Enter master password to unlock vault key.',
                        ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: pr.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    obscureText: _hidden,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verify(),
                    decoration: InputDecoration(
                      labelText: context.tr('Master Password', 'Master Password'),
                      errorText: _errorText,
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () {
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _verify,
                      icon: _busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(context.tr('Kilidi Ac', 'Unlock')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
