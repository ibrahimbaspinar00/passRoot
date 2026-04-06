import 'settings_screen.dart';

class SettingsPage extends SettingsScreen {
  const SettingsPage({
    super.key,
    required super.store,
    required super.settingsStore,
    required super.accountStore,
    required super.googleAuthStore,
    super.focusGoogleAuthSignal,
  });
}
