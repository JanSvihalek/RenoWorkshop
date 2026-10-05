import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/zpracovatel.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Zpracovatel zakázky - kdo má vůz právě na starosti. Převzít, přiřadit
/// kolegovi z útvaru zakázky (nebo z jiného), uvolnit.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> otevri(
    WidgetTester tester, {
    Map<String, dynamic>? zpracovatel,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    zdroj = FakeServiceOrderDataSource([
      buildOrderDto(id: 'ZK-26-0001', assignee: zpracovatel),
    ]);
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

  Future<void> otevriVyber(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('zpracovatel')));
    await tester.pumpAndSettle();
  }

  final radek = find.byKey(const Key('zpracovatel'));

  testWidgets('zakázku bez zpracovatele jde převzít', (tester) async {
    await otevri(tester);
    expect(
      find.descendant(of: radek, matching: find.textContaining('nikdo')),
      findsOneWidget,
    );

    await otevriVyber(tester);
    await tester.tap(find.byKey(const Key('prevzit-zakazku')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: radek, matching: find.textContaining('Dvořák Jan')),
      findsOneWidget,
    );
  });

  testWidgets('nabídka je z útvaru zakázky, na požádání všichni', (
    tester,
  ) async {
    await otevri(tester);
    await otevriVyber(tester);

    expect(zdroj.posledniNabidkaVsichni, isFalse);
    // Útvar kódem, ne názvem.
    expect(
      find.descendant(
        of: find.byKey(const Key('zpracovatele-utvar')),
        matching: find.text('11211'),
      ),
      findsOneWidget,
    );
    expect(find.text('Auta Servis'), findsNothing);
    expect(find.byKey(const Key('zpracovatel-501')), findsOneWidget);
    expect(find.byKey(const Key('zpracovatel-502')), findsOneWidget);
    // Novotný je z jiného útvaru.
    expect(find.byKey(const Key('zpracovatel-601')), findsNothing);

    await tester.tap(find.byKey(const Key('zpracovatele-vsichni')));
    await tester.pumpAndSettle();
    expect(zdroj.posledniNabidkaVsichni, isTrue);
    expect(find.byKey(const Key('zpracovatel-601')), findsOneWidget);

    await tester.tap(find.byKey(const Key('zpracovatel-601')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: radek,
        matching: find.textContaining('Novotný Pavel'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hledání zúží nabídku podle jména', (tester) async {
    await otevri(tester);
    await otevriVyber(tester);

    await tester.enterText(find.byKey(const Key('hledat-zpracovatele')), 'kří');
    await tester.pump();

    expect(find.byKey(const Key('zpracovatel-502')), findsOneWidget);
    expect(find.byKey(const Key('zpracovatel-501')), findsNothing);
  });

  testWidgets('kolegovi předat a zakázku uvolnit', (tester) async {
    await otevri(
      tester,
      zpracovatel: {
        'id': 501,
        'name': 'Dvořák Jan',
        'since': '2026-10-01T08:00:00',
      },
    );
    expect(
      find.descendant(of: radek, matching: find.textContaining('Dvořák Jan')),
      findsOneWidget,
    );

    await otevriVyber(tester);
    await tester.tap(find.byKey(const Key('zpracovatel-502')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: radek, matching: find.textContaining('Kříž Martin')),
      findsOneWidget,
    );

    await otevriVyber(tester);
    await tester.tap(find.byKey(const Key('uvolnit-zakazku')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: radek, matching: find.textContaining('nikdo')),
      findsOneWidget,
    );
  });

  testWidgets('převzetí bez zaměstnance v Heliosu řekne proč', (tester) async {
    await otevri(tester);
    zdroj.emailPrihlaseneho = 'host@renocar.cz';

    await otevriVyber(tester);
    await tester.tap(find.byKey(const Key('prevzit-zakazku')));
    await tester.pumpAndSettle();

    expect(find.textContaining('host@renocar.cz'), findsOneWidget);
    expect(
      find.descendant(of: radek, matching: find.textContaining('nikdo')),
      findsOneWidget,
    );
  });

  test('zpracovatel z API a poznání sebe podle e-mailu', () {
    final zpracovatel = Zpracovatel.fromJson({
      'id': 501,
      'name': 'Dvořák Jan',
      'email': 'Jan.Dvorak@renocar.cz',
      'since': '2026-10-05T09:30:00',
      'assignedBy': 'Petra Válková',
    });
    expect(zpracovatel.od, DateTime(2026, 10, 5, 9, 30));
    expect(zpracovatel.jeEmail(' jan.dvorak@RENOCAR.cz'), isTrue);
    expect(zpracovatel.jeEmail('jiny@renocar.cz'), isFalse);
    expect(zpracovatel.jeEmail(null), isFalse);

    // Starší API pole neposílá - zakázka je bez zpracovatele.
    expect(buildOrderDto().toDomain().zpracovatel, isNull);
    expect(
      buildOrderDto(
        assignee: {'id': 7, 'name': 'Kříž Martin'},
      ).toDomain().zpracovatel?.jmeno,
      'Kříž Martin',
    );
  });
}
