import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Na širokém tabletu má detail dva sloupce: vlevo práce na voze (závady,
/// příjem, fotky, pracovní list), vpravo stav zakázky (postup, dokumenty
/// z Heliosu). Na telefonu i v rozděleném zobrazení zůstává jeden.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<void> otevri(WidgetTester tester, Size velikost) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(
            FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrderDetailScreen(
            orderId: 'ZK-26-0001',
            onBack: () {},
            onFotodokumentace: (_) {},
            onPrijem: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final fotkyKarta = find.byKey(const Key('otevrit-fotodokumentaci'));
  final postupKarta = find.byKey(const Key('pridat-stav'));

  testWidgets('na širokém tabletu je stav vpravo od práce', (tester) async {
    await otevri(tester, const Size(1280, 800));

    final vlevo = tester.getRect(fotkyKarta);
    final vpravo = tester.getRect(postupKarta);
    // Fotodokumentace (práce) končí dřív, než začíná postup (stav).
    expect(vlevo.right, lessThanOrEqualTo(vpravo.left));
    // Každá karta je ve své polovině obrazovky.
    expect(vlevo.right, lessThan(640));
    expect(vpravo.left, greaterThan(640));
  });

  testWidgets('na tabletu jsou vlevo závady, příjem, fotky a pracovní list', (
    tester,
  ) async {
    // Vysoký, ať jsou oba sloupce postavené najednou.
    await otevri(tester, const Size(1280, 2400));

    double y(Finder f) => tester.getRect(f).top;
    final zavady = find.text('ZÁVADY/ÚKONY');
    final prijem = find.byKey(const Key('otevrit-prijem'));
    final poznamky = find.text('PRACOVNÍ LIST / POZNÁMKY');

    for (final karta in [zavady, prijem, fotkyKarta, poznamky]) {
      expect(tester.getRect(karta).right, lessThan(640));
    }
    expect(y(zavady), lessThan(y(prijem)));
    expect(y(prijem), lessThan(y(fotkyKarta)));
    expect(y(fotkyKarta), lessThan(y(poznamky)));

    // Vpravo stav: postup a pod ním dokumenty z Heliosu.
    final dokumenty = find.byKey(const Key('dokumenty-heliosu'));
    expect(tester.getRect(postupKarta).left, greaterThan(640));
    expect(tester.getRect(dokumenty).left, greaterThan(640));
    expect(y(postupKarta), lessThan(y(dokumenty)));
  });

  testWidgets('na telefonu jsou karty pod sebou', (tester) async {
    await otevri(tester, const Size(800, 1400));

    final postup = tester.getRect(postupKarta);
    final fotky = tester.getRect(fotkyKarta);
    // Jeden sloupec: nejdřív práce (fotky), pod ní stav (postup), přes
    // celou šířku.
    expect(fotky.top, lessThan(postup.top));
    expect(fotky.width, greaterThan(700));
  });
}
