import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/notes_card.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Přidání poznámky do pracovního listu a stavu do postupu - obě okna
/// mají stejný vzhled (OknoZapisu).
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
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  final ulozit = find.byKey(const Key('nova-poznamka-ulozit'));
  final pole = find.byKey(const Key('nova-poznamka-text'));

  Future<void> otevriDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();

    final pridat = find.descendant(
      of: find.byType(NotesCard),
      matching: find.text('Přidat'),
    );
    await tester.ensureVisible(pridat);
    await tester.pumpAndSettle();
    await tester.tap(pridat);
    await tester.pumpAndSettle();
  }

  bool povoleno(WidgetTester tester) =>
      tester.widget<FilledButton>(ulozit).onPressed != null;

  testWidgets('hlavička ukáže vůz a zakázku, pata autora', (tester) async {
    await otevriDialog(tester);

    expect(find.text('Nová poznámka'), findsOneWidget);
    expect(
      find.textContaining(
        'do pracovního listu · 8AB 4721 · ZK-26-0001',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Uloží se jako Jan Dvořák · teď'), findsOneWidget);
    expect(find.text('Diktovat přes klávesnici'), findsOneWidget);
    expect(find.text('0 / 500'), findsOneWidget);
  });

  testWidgets('Uložit jde až s textem, počítadlo počítá znaky', (tester) async {
    await otevriDialog(tester);
    expect(povoleno(tester), isFalse);

    await tester.enterText(pole, '   ');
    await tester.pump();
    expect(povoleno(tester), isFalse, reason: 'samé mezery nejsou poznámka');

    await tester.enterText(pole, 'Na heveru');
    await tester.pump();
    expect(povoleno(tester), isTrue);
    expect(find.text('9 / 500'), findsOneWidget);
  });

  testWidgets('delší text se zkrátí na 500 znaků', (tester) async {
    await otevriDialog(tester);

    await tester.enterText(pole, 'a' * 600);
    await tester.pump();
    expect(find.text('500 / 500'), findsOneWidget);
  });

  testWidgets('uložená poznámka je v pracovním listu pod autorem', (
    tester,
  ) async {
    await otevriDialog(tester);

    await tester.enterText(pole, '  Čeká na díl z Německa  ');
    await tester.pump();
    await tester.tap(ulozit);
    await tester.pumpAndSettle();

    expect(find.text('Nová poznámka'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NotesCard),
        matching: find.text('Čeká na díl z Německa'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NotesCard),
        matching: find.textContaining('Jan Dvořák'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Zrušit nic neuloží', (tester) async {
    await otevriDialog(tester);

    await tester.enterText(pole, 'Rozepsáno');
    await tester.pump();
    await tester.tap(find.text('Zrušit'));
    await tester.pumpAndSettle();

    expect(find.text('Nová poznámka'), findsNothing);
    expect(find.text('Rozepsáno'), findsNothing);
    expect(find.text('Zatím žádné poznámky.'), findsOneWidget);
  });

  testWidgets('okno stavu má stejnou hlavičku a Přidat až po výběru', (
    tester,
  ) async {
    await otevriDialog(tester);
    await tester.tap(find.text('Zrušit'));
    await tester.pumpAndSettle();

    final pridatStav = find.byKey(const Key('pridat-stav'));
    await tester.ensureVisible(pridatStav);
    await tester.pumpAndSettle();
    await tester.tap(pridatStav);
    await tester.pumpAndSettle();

    expect(find.text('Přidat stav'), findsOneWidget);
    expect(
      find.textContaining(
        'do postupu zakázky · 8AB 4721 · ZK-26-0001',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Uloží se jako Jan Dvořák · teď'), findsOneWidget);

    final pridat = find.widgetWithText(FilledButton, 'Přidat');
    expect(tester.widget<FilledButton>(pridat).onPressed, isNull);

    await tester.tap(find.text('Vyberte stav'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lakovna').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(pridat).onPressed, isNotNull);
  });
}
