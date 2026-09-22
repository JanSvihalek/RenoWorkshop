import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/core/theme/app_colors.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/core/widgets/workshop_bottom_nav.dart';
import 'package:renoworkshop/src/core/widgets/workshop_side_nav.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          PlaceholderAuthRepository(
            ssoDelay: Duration.zero,
            biometricDelay: Duration.zero,
          ),
        ),
        serviceOrderDataSourceProvider.overrideWithValue(
          FakeServiceOrderDataSource([
            buildOrderDto(id: 'ZK-26-0001', licensePlate: '8AB 4721'),
            buildOrderDto(
              id: 'ZK-26-0002',
              licensePlate: '2SC 9014',
              customerName: 'Lucie Marková',
            ),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  /// Rozměr dílenského tabletu na šířku.
  Future<void> tabletovaObrazovka(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> prihlas(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  testWidgets('na tabletu je navigace pruhem vlevo, ne lištou dole', (
    tester,
  ) async {
    await tabletovaObrazovka(tester);
    await prihlas(tester);

    expect(find.byType(WorkshopSideNav), findsOneWidget);
    // Dvě navigace najednou by braly místo a mátly.
    expect(find.byType(WorkshopBottomNav), findsNothing);
    // Iniciály přihlášeného jsou v hlavičce zakázek, ne ještě v pruhu.
    expect(
      find.descendant(
        of: find.byType(WorkshopSideNav),
        matching: find.text('JD'),
      ),
      findsNothing,
    );
  });

  testWidgets('na telefonu zůstává lišta dole', (tester) async {
    // Výchozí velikost testovacího plátna je 800x600, tedy pod prahem.
    await prihlas(tester);

    expect(find.byType(WorkshopBottomNav), findsOneWidget);
    expect(find.byType(WorkshopSideNav), findsNothing);
  });

  testWidgets('detail se na tabletu otevře vedle seznamu, ne přes něj', (
    tester,
  ) async {
    await tabletovaObrazovka(tester);
    await prihlas(tester);

    // Dokud si člověk nevybere, je pravý sloupec prázdný.
    expect(find.text('Vyberte zakázku ze seznamu'), findsOneWidget);

    await tester.tap(find.byType(OrderCard).first);
    await tester.pumpAndSettle();

    // Seznam zůstal: druhá zakázka je pořád vidět vedle otevřeného detailu.
    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('Vyberte zakázku ze seznamu'), findsNothing);
    // Detail je vedle seznamu, ne nad ním - není kam se vracet.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            (widget.icon == Icons.arrow_back_rounded ||
                widget.icon == Icons.arrow_back_ios_new_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('vybraná zakázka je v seznamu poznat', (tester) async {
    await tabletovaObrazovka(tester);
    await prihlas(tester);

    OrderCard karta(int index) =>
        tester.widgetList<OrderCard>(find.byType(OrderCard)).elementAt(index);

    expect(karta(0).jeVybrana, isFalse);

    await tester.tap(find.byType(OrderCard).first);
    await tester.pumpAndSettle();

    expect(karta(0).jeVybrana, isTrue);
    expect(karta(1).jeVybrana, isFalse);
  });

  /// Barva podkladu hlavičky seznamu - nejbližší obarvený Container nad
  /// nadpisem.
  Color barvaHlavicky(WidgetTester tester) {
    final kontejnery = tester.widgetList<Container>(
      find.ancestor(
        of: find.text('Zakázky na dílně'),
        matching: find.byType(Container),
      ),
    );
    return kontejnery.firstWhere((c) => c.color != null).color!;
  }

  testWidgets('na tabletu má hlavička seznamu stejnou šedou jako seznam', (
    tester,
  ) async {
    await tabletovaObrazovka(tester);
    await prihlas(tester);

    final palette = tester.element(find.text('Zakázky na dílně')).palette;
    expect(barvaHlavicky(tester), palette.background);

    // Pole hledání nesmí mít bílý text - na šedém by nebyl vidět.
    final pole = tester.widget<TextField>(find.byType(TextField).first);
    expect(pole.style!.color, isNot(Colors.white));
  });

  testWidgets('na telefonu zůstává hlavička tmavomodrá', (tester) async {
    await prihlas(tester);
    expect(barvaHlavicky(tester), AppColors.primary);
  });
}
