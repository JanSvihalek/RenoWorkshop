import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/zavada.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';

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
            buildOrderDto(
              id: 'ZK-26-0001',
              licensePlate: '8AB 4721',
              defects: const [
                Zavada(
                  id: '9001',
                  kod: '001',
                  nazev: 'Zadní nárazník',
                  text: 'Vyměnit, lakovat do barvy, nové čidlo parkování',
                ),
                Zavada(id: '9002', text: 'Seřídit geometrii'),
              ],
            ),
            buildOrderDto(id: 'ZK-26-0002', licensePlate: '2SC 9014'),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  Future<void> otevri(WidgetTester tester, String spz) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(spz));
    await tester.pumpAndSettle();
  }

  testWidgets('detail ukáže závady z Heliosu v pořadí zápisu', (tester) async {
    await otevri(tester, '8AB 4721');

    final nadpis = find.text('ZÁVADY');
    await tester.scrollUntilVisible(
      find.text('Seřídit geometrii'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(nadpis, findsOneWidget);
    // Stručný popis tučně, podrobnosti pod ním menším písmem.
    final nazev = tester.widget<SelectableText>(
      find.widgetWithText(SelectableText, 'Zadní nárazník'),
    );
    final poznamka = tester.widget<SelectableText>(
      find.widgetWithText(
        SelectableText,
        'Vyměnit, lakovat do barvy, nové čidlo parkování',
      ),
    );
    expect(nazev.style!.fontWeight, FontWeight.w600);
    expect(poznamka.style!.fontSize, lessThan(nazev.style!.fontSize!));
    // Závada bez popisu ukáže aspoň poznámku.
    expect(find.text('Závada 001'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    // Jen ke čtení - žádné zaškrtávátko, závady zapisuje poradce v Heliosu.
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('zakázka bez závad to řekne', (tester) async {
    await otevri(tester, '2SC 9014');

    await tester.scrollUntilVisible(
      find.textContaining('nejsou u zakázky zapsané žádné závady'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.textContaining('nejsou u zakázky zapsané žádné závady'),
      findsOneWidget,
    );
  });
}
