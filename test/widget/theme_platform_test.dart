import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Obě obrazovky musí projít ve světlém i tmavém režimu a v obou variantách
/// chrome - tmavý režim se na dílně používá běžně.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Widget harness(
    Widget child, {
    required Brightness brightness,
    required TargetPlatform platform,
  }) {
    final theme = (brightness == Brightness.dark
        ? AppTheme.dark()
        : AppTheme.light());

    return ProviderScope(
      overrides: [
        serviceOrderDataSourceProvider.overrideWithValue(
          FakeServiceOrderDataSource([
            buildOrderDto(id: 'ZK-26-0001', licensePlate: '8AB 4721'),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: theme.copyWith(platform: platform),
        home: child,
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('seznam se vykreslí (${brightness.name})', (tester) async {
      await tester.pumpWidget(
        harness(
          OrdersListScreen(
            onOpenOrder: (_) {},
            onSelectTab: (_) {},
            onSearchArchive: (_) {},
            onScanCode: () {},
          ),
          brightness: brightness,
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zakázky na dílně'), findsOneWidget);
      expect(find.text('8AB 4721'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail se vykreslí (${brightness.name})', (tester) async {
      await tester.pumpWidget(
        harness(
          OrderDetailScreen(orderId: 'ZK-26-0001', onBack: () {}),
          brightness: brightness,
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('POSTUP ZAKÁZKY'), findsOneWidget);

      // Spodní karty jsou pod přehybem - projdeme celý obsah.
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text('ÚKONY NA ZAKÁZCE'), findsOneWidget);
      expect(find.text('POZNÁMKY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('iOS chrome: chevron zpět', (tester) async {
    await tester.pumpWidget(
      harness(
        OrderDetailScreen(orderId: 'ZK-26-0001', onBack: () {}),
        brightness: Brightness.light,
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('Android chrome: šipka zpět', (tester) async {
    await tester.pumpWidget(
      harness(
        OrderDetailScreen(orderId: 'ZK-26-0001', onBack: () {}),
        brightness: Brightness.light,
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });
}
