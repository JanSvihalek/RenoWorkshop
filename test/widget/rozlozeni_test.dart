import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/mock_service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_status.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/service_order.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/typ_zakazky.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';

/// Rozložení na úzkém displeji.
///
/// Skutečná data z Heliosu mají delší čísla zakázek (`Z1212608412`) a jiné
/// formáty SPZ, než na jaké byl návrh kreslený. Flutter hlásí přetečení
/// jako chybu testu, takže tenhle test odhalí rozsypanou kartu dřív,
/// než se objeví na telefonu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  testWidgets('seznam se vejde na úzký displej i s reálnými daty', (
    tester,
  ) async {
    // Nejužší telefon, který dnes někdo reálně používá (iPhone SE).
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(
            MockServiceOrderDataSource(latency: Duration.zero),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrdersListScreen(
            onOpenOrder: (_) {},
            onSelectTab: (_) {},
            onSearchArchive: (_) {},
            onScanCode: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nejdelší číslo zakázky i nejdelší název útvaru se musí vejít.
    expect(find.textContaining('Z121260'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dlouhý název řady zakázky kartu nerozsype', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final zakazka = ServiceOrder(
      id: 'Z1212608412',
      licensePlate: '2BK9485',
      model: 'BMW - 320d xDrive Touring',
      customerName: 'RENOCAR, a.s.',
      status: OrderStatus.values.first,
      // Řady se v Heliosu jmenují popisně, ne zkratkou.
      typZakazky: const TypZakazky(
        kod: 'KL',
        nazev: 'Klempířsko-lakýrnické práce - karoserie',
      ),
      receivedAt: DateTime(2026, 8, 20),
      dueAt: DateTime(2026, 8, 26),
      vin: 'WBAJN51070G980042',
      mechanicName: 'Jan Dvořák',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: OrderCard(order: zakazka, onTap: () {}),
          ),
        ),
      ),
    );

    final stitek = find.text('Klempířsko-lakýrnické práce - karoserie');
    expect(stitek, findsOneWidget, reason: 'typ zakázky má být na kartě');

    // Wrap dlouhý text nepřetéct nenechá - zalomí ho do dvou řádků
    // a štítek naroste do výšky. Právě to se hlídá: musí zůstat na
    // jednom řádku a zabrat nejvýš necelou polovinu šířky.
    final sirkaObrazovky =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final rozmer = tester.getSize(stitek);

    expect(rozmer.width, lessThanOrEqualTo(sirkaObrazovky * 0.42));
    expect(
      rozmer.height,
      lessThan(24),
      reason: 'zkrácený štítek se musí vejít na jeden řádek',
    );
  });
}
