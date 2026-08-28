import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/mock_service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';

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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nejdelší číslo zakázky i nejdelší název útvaru se musí vejít.
    expect(find.textContaining('Z121260'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
