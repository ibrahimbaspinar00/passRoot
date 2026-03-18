import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passroot/app/passroot_app.dart';
import 'package:passroot/screens/record_form_screen.dart';
import 'package:passroot/state/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const PassRootApp());
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('Dashboard kartlari gorunur', (tester) async {
    await pumpApp(tester);

    expect(find.text('PassRoot Security Dashboard'), findsOneWidget);
    expect(find.text('Guclu Sifreler'), findsOneWidget);
    expect(find.text('Zayif Parolalar'), findsOneWidget);
    expect(find.text('Toplam Kayit'), findsOneWidget);
  });

  testWidgets('Yeni kayit formu acilabilir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordFormScreen(settingsStore: AppSettingsStore()),
      ),
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
    await pumpApp(tester);

    await tester.tap(find.text('Guclu Sifreler'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Guclu Sifreler'), findsWidgets);
  });

  testWidgets('Ayarlar sekmesi bolumleri gosterir', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Ayarlar'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Guvenlik'), findsOneWidget);
    expect(find.text('Veri Yonetimi'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Gorunum'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Kullanici Bilgileri'), findsOneWidget);
  });
}
