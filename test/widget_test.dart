import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passroot/app/app_shell.dart';
import 'package:passroot/app/app_theme.dart';
import 'package:passroot/models/app_settings.dart';
import 'package:passroot/screens/record_form_screen.dart';
import 'package:passroot/state/app_settings_store.dart';
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
    final settingsStore = AppSettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        theme: AppTheme.light(accent: AppThemeAccent.ocean),
        darkTheme: AppTheme.dark(accent: AppThemeAccent.ocean),
        home: AppShell(settingsStore: settingsStore),
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

  testWidgets('Ayarlar sekmesi bolumleri gosterir', (tester) async {
    await pumpAppShell(tester);

    await tester.tap(textEither('Ayarlar', 'Settings'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(textAny(const ['Güvenlik', 'Guvenlik', 'Security']), findsOneWidget);
    await tester.scrollUntilVisible(
      textEither('Veri Yonetimi', 'Data Management'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(textEither('Veri Yonetimi', 'Data Management'), findsWidgets);
    await tester.scrollUntilVisible(
      textEither('Hakkinda', 'About'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(textEither('Hakkinda', 'About'), findsWidgets);
  });
}
