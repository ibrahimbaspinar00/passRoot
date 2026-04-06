import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passroot/app/app_shell.dart';
import 'package:passroot/app/app_theme.dart';
import 'package:passroot/models/app_settings.dart';
import 'package:passroot/screens/record_form_screen.dart';
import 'package:passroot/security/secure_storage_service.dart';
import 'package:passroot/services/encrypted_vault_storage_service.dart';
import 'package:passroot/services/google_auth_service.dart';
import 'package:passroot/services/pin_security_service.dart';
import 'package:passroot/services/vault_key_service.dart';
import 'package:passroot/state/account_store.dart';
import 'package:passroot/state/app_settings_store.dart';
import 'package:passroot/state/google_auth_store.dart';
import 'package:passroot/state/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Finder textEither(String tr, String en) {
    return find.byWidgetPredicate((widget) {
      return widget is Text && (widget.data == tr || widget.data == en);
    });
  }

  Finder textAny(List<String> values) {
    return find.byWidgetPredicate((widget) {
      return widget is Text && values.contains(widget.data);
    });
  }

  Future<void> pumpAppShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'passroot_onboarding_seen_v1': true,
    });
    final fakeStorage = _InMemorySecureStorage();
    final pinSecurityService = PinSecurityService(
      secureStorageService: fakeStorage,
    );
    final vaultKeyService = VaultKeyService(
      secureStorage: fakeStorage,
      pinSecurityService: pinSecurityService,
    );
    final settingsStore = AppSettingsStore(
      pinSecurityService: pinSecurityService,
      vaultKeyService: vaultKeyService,
    );
    final accountStore = AccountStore(secureStorageService: fakeStorage);
    final googleAuthStore = GoogleAuthStore(service: _FakeGoogleAuthService());
    final vaultStore = VaultStore(
      storageService: _InMemoryEncryptedVaultStorageService(),
    );
    await settingsStore.load();
    await accountStore.load();
    await googleAuthStore.load();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        theme: AppTheme.light(accent: AppThemeAccent.ocean),
        darkTheme: AppTheme.dark(accent: AppThemeAccent.ocean),
        home: AppShell(
          settingsStore: settingsStore,
          accountStore: accountStore,
          googleAuthStore: googleAuthStore,
          vaultStore: vaultStore,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Dashboard kartlari gorunur', (tester) async {
    await pumpAppShell(tester);

    expect(find.text('PassRoot Security Dashboard'), findsOneWidget);
    expect(textEither('Guclu Sifreler', 'Strong Passwords'), findsOneWidget);
    expect(textEither('Zayif Parolalar', 'Weak Passwords'), findsOneWidget);
    expect(textEither('Toplam Kayit', 'Total Records'), findsOneWidget);
  });

  testWidgets('Yeni kayit formu acilabilir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RecordFormScreen(settingsStore: AppSettingsStore())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final hasBasicFields =
        find.text('Temel Alanlar').evaluate().isNotEmpty ||
        find.text('Basic Fields').evaluate().isNotEmpty;
    expect(hasBasicFields, isTrue);
    await tester.scrollUntilVisible(
      find.text('Gelismis Alanlar').evaluate().isNotEmpty
          ? find.text('Gelismis Alanlar')
          : find.text('Advanced Fields'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    final hasAdvancedFields =
        find.text('Gelismis Alanlar').evaluate().isNotEmpty ||
        find.text('Advanced Fields').evaluate().isNotEmpty;
    expect(hasAdvancedFields, isTrue);
  });

  testWidgets('Dashboard kartina tiklayinca detay ekrani acilir', (
    tester,
  ) async {
    await pumpAppShell(tester);

    await tester.tap(textEither('Guclu Sifreler', 'Strong Passwords'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(textEither('Guclu Sifreler', 'Strong Passwords'), findsWidgets);
  });

  testWidgets(
    'Dashboarddaki Giris Yap butonu ayarlardaki hesap bolumune yonlendirir',
    (tester) async {
      await pumpAppShell(tester);

      final signInIcon = find.byIcon(Icons.arrow_forward_rounded);
      expect(signInIcon, findsOneWidget);
      await tester.tap(signInIcon);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(textAny(const ['Hesap', 'Account']), findsOneWidget);
      expect(
        textAny(const ['Oturum acik degil', 'No active session']),
        findsOneWidget,
      );
    },
  );

  testWidgets('Ayarlar sekmesi bolumleri gosterir', (tester) async {
    await pumpAppShell(tester);

    await tester.tap(textEither('Ayarlar', 'Settings'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(textAny(const ['Hesap', 'Account']), findsOneWidget);
    expect(textAny(const ['Guvenlik', 'Security']), findsOneWidget);
    await tester.scrollUntilVisible(
      textEither('Yedekleme ve Aktarim', 'Backup & Transfer'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      textEither('Yedekleme ve Aktarim', 'Backup & Transfer'),
      findsWidgets,
    );
    await tester.scrollUntilVisible(
      textEither('Hakkinda', 'About'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(textEither('Hakkinda', 'About'), findsWidgets);
  });
}

class _FakeGoogleAuthService extends GoogleAuthService {
  _FakeGoogleAuthService();

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<User?> restoreSession() async => null;

  @override
  Future<User> signIn() async {
    throw const GoogleAuthException('Fake service signIn is not implemented.');
  }

  @override
  Future<void> signOut() async {}
}

class _InMemorySecureStorage extends SecureStorageService {
  _InMemorySecureStorage() : super(storage: const FlutterSecureStorage());

  final Map<String, String> _memory = <String, String>{};

  @override
  Future<String?> read(String key) async => _memory[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
  }
}

class _InMemoryEncryptedVaultStorageService extends EncryptedVaultStorageService {
  String? _payload;

  @override
  Future<String?> loadJsonPayload() async => _payload;

  @override
  Future<void> saveJsonPayload(String jsonPayload) async {
    _payload = jsonPayload;
  }

  @override
  Future<void> clear() async {
    _payload = null;
  }
}
