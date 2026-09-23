import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Kde vůz fyzicky stojí se zapisuje spolu s dílenským stavem - vůz se
/// hýbe právě tehdy, když se mění, co se s ním děje.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> otevriDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serviceOrderDataSourceProvider.overrideWithValue(zdroj)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrderDetailScreen(orderId: 'ZK-26-0001', onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pridejStav(WidgetTester tester, {String? misto}) async {
    await tester.ensureVisible(find.byKey(const Key('pridat-stav')));
    await tester.tap(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vyberte stav'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lakovna').last);
    await tester.pumpAndSettle();
    if (misto != null) {
      await tester.enterText(find.byKey(const Key('stav-misto')), misto);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Přidat'));
    await tester.pumpAndSettle();
  }

  testWidgets('místo zapsané u stavu se ukáže v detailu', (tester) async {
    await otevriDetail(tester);
    // Zakázka přišla ze serveru se starým místem.
    expect(find.textContaining('Stání 1'), findsWidgets);

    await pridejStav(tester, misto: 'Stání 4');

    expect(find.byKey(const Key('kde-vuz-stoji')), findsOneWidget);
    expect(zdroj.posledniMisto, 'Stání 4');
    expect(find.textContaining('Stání 4'), findsWidgets);
  });

  testWidgets('u dalšího stavu je místo předvyplněné a nemění se', (
    tester,
  ) async {
    await otevriDetail(tester);
    await pridejStav(tester, misto: 'Stání 4');
    zdroj.posledniMisto = null;

    await tester.ensureVisible(find.byKey(const Key('pridat-stav')));
    await tester.tap(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();

    // Technik ho nepíše znovu - vůz obvykle zůstane stát.
    final pole = tester.widget<TextField>(find.byKey(const Key('stav-misto')));
    expect(pole.controller!.text, 'Stání 4');

    await tester.tap(find.text('Vyberte stav'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Připraveno k vyzvednutí').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Přidat'));
    await tester.pumpAndSettle();

    // Beze změny se místo neposílá, aby se nepřepsal čas zápisu.
    expect(zdroj.posledniMisto, isNull);
    expect(find.textContaining('Stání 4'), findsWidgets);
  });

  testWidgets('přesun vozu místo přepíše', (tester) async {
    await otevriDetail(tester);
    await pridejStav(tester, misto: 'Stání 4');
    await pridejStav(tester, misto: 'Lakovna');

    expect(zdroj.posledniMisto, 'Lakovna');
    expect(find.textContaining('Lakovna'), findsWidgets);
  });
}
