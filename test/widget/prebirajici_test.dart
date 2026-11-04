import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/core/utils/kontakt_odkazy.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Chlívek Kontakt (přebírající z Heliosu): klepnutím se volá nebo píše e-mail.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  final otevrene = <Uri>[];
  var povedlo = true;

  Future<void> otevri(
    WidgetTester tester,
    Map<String, dynamic>? kontakt, {
    Size velikost = const Size(390, 1000),
  }) async {
    otevrene.clear();
    povedlo = true;
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(
            FakeServiceOrderDataSource([
              buildOrderDto(id: 'ZK-26-0001', handoverContact: kontakt),
            ]),
          ),
          otevritOdkazProvider.overrideWithValue((odkaz) async {
            otevrene.add(odkaz);
            return povedlo;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrderDetailScreen(
            orderId: 'ZK-26-0001',
            onBack: () {},
            onFotodokumentace: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const kontakt = {
    'id': 7,
    'name': 'Jan Novák',
    'phone': '+420 603 118 442',
    'email': 'jan.novak@example.cz',
  };

  testWidgets('klepnutí na telefon volá, na e-mail píše', (tester) async {
    await otevri(tester, kontakt);

    expect(find.text('Jan Novák'), findsOneWidget);
    await tester.tap(find.byKey(const Key('prebirajici-telefon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prebirajici-email')));
    await tester.pumpAndSettle();

    expect(otevrene.map((o) => '$o'), [
      'tel:+420603118442',
      'mailto:jan.novak@example.cz',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bez kontaktu je Nezadán, chlívek v mřížce zůstane', (
    tester,
  ) async {
    await otevri(tester, null);

    expect(
      find.descendant(
        of: find.byKey(const Key('kontakt')),
        matching: find.text('Nezadán'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Kontakt je za zákazníkem, příjem a dokončení v jednom', (
    tester,
  ) async {
    await otevri(tester, kontakt, velikost: const Size(1600, 900));

    final zakaznik = tester.getRect(find.text('ZÁKAZNÍK'));
    final chlivek = tester.getRect(find.text('KONTAKT'));
    final zodpovida = tester.getRect(find.text('ZODPOVÍDÁ'));
    expect(chlivek.left, greaterThan(zakaznik.left));
    expect(chlivek.left, lessThan(zodpovida.left));
    expect(find.text('PŘIJATO → DOKONČENÍ'), findsOneWidget);
    expect(find.text('TERMÍN'), findsNothing);
  });

  testWidgets('bez telefonu a e-mailu je jen jméno', (tester) async {
    await otevri(tester, {'id': 7, 'name': 'Jan Novák'});

    expect(find.text('Jan Novák'), findsOneWidget);
    expect(find.byKey(const Key('prebirajici-telefon')), findsNothing);
    expect(find.byKey(const Key('prebirajici-email')), findsNothing);
  });

  testWidgets('zařízení, které neumí volat, to oznámí', (tester) async {
    await otevri(tester, kontakt, velikost: const Size(1280, 800));
    povedlo = false;

    await tester.tap(find.byKey(const Key('prebirajici-telefon')));
    await tester.pumpAndSettle();

    expect(find.textContaining('nejde otevřít'), findsOneWidget);
  });

  test('odkazy z údajů v Heliosu', () {
    expect('${odkazTelefon('+420 603 118 442')}', 'tel:+420603118442');
    expect('${odkazTelefon('603 118 442; 777 000 111')}', 'tel:603118442');
    expect(odkazTelefon('neuvedeno'), isNull);
    expect(odkazTelefon(null), isNull);
    expect('${odkazEmail(' a@b.cz; c@d.cz')}', 'mailto:a@b.cz');
    expect(odkazEmail('neuvedeno'), isNull);
    expect(odkazEmail(null), isNull);
  });
}
