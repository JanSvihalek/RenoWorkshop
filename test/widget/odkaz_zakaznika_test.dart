import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Odkaz pro zákazníka v hlavičce detailu - vytvoří se ručně, jde zrušit.
/// Stejně jako okno na webu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<FakeServiceOrderDataSource> otevri(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zakazka = buildOrderDto();
    final zdroj = FakeServiceOrderDataSource([zakazka]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serviceOrderDataSourceProvider.overrideWithValue(zdroj)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrderDetailScreen(orderId: zakazka.id, onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return zdroj;
  }

  testWidgets('odkaz se vytvoří ručně a jde zrušit', (tester) async {
    final zdroj = await otevri(tester);
    final id = buildOrderDto().id;

    await tester.tap(find.byKey(const Key('odkaz-zakaznika')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('okno-odkazu-zakaznika')), findsOneWidget);
    expect(
      find.textContaining('Zákazník zatím průběh zakázky nevidí'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('odkaz-vytvorit')));
    await tester.pumpAndSettle();
    expect(zdroj.odkazyZakazniku.containsKey(id), isTrue);
    expect(find.byKey(const Key('odkaz-adresa')), findsOneWidget);
    expect(
      find.textContaining('Po ukončení zakázky přestane fungovat'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('odkaz-zrusit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('odkaz-zrusit-ano')));
    await tester.pumpAndSettle();
    expect(zdroj.odkazyZakazniku, isEmpty);
    expect(
      find.textContaining('Zákazník zatím průběh zakázky nevidí'),
      findsOneWidget,
    );
  });
}
