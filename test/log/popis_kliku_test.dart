import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/core/log/log_udalosti.dart';
import 'package:renoworkshop/src/core/log/popis_kliku.dart';

void main() {
  late List<String> kliky;

  Future<void> postav(WidgetTester tester, Widget obsah) async {
    kliky = [];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            SledovaniKliku(onKlik: kliky.add, child: child!),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Závady'),
                  Tab(text: 'Fotky'),
                ],
              ),
            ),
            body: ListView(children: [obsah]),
          ),
        ),
      ),
    );
  }

  testWidgets('jen obecně, na co se kliklo - bez nápisů', (tester) async {
    await postav(
      tester,
      Column(
        children: [
          FilledButton(onPressed: () {}, child: const Text('Uložit')),
          IconButton(
            tooltip: 'Zavřít',
            onPressed: () {},
            icon: const Icon(Icons.close),
          ),
          FilterChip(
            label: const Text('Jen moje'),
            selected: false,
            onSelected: (_) {},
          ),
          const TextField(decoration: InputDecoration(hintText: 'Hledat')),
          InkWell(onTap: () {}, child: const Text('Jan Novák · 1AB 2345')),
          ListTile(title: const Text('Jana Dvořáková'), onTap: () {}),
          SwitchListTile(
            title: const Text('Tmavý vzhled'),
            value: false,
            onChanged: (_) {},
          ),
        ],
      ),
    );

    await tester.tap(find.text('Uložit'));
    await tester.tap(find.byIcon(Icons.close));
    await tester.tap(find.text('Jen moje'));
    await tester.tap(find.text('Fotky'));
    await tester.tap(find.byType(TextField));
    await tester.tap(find.text('Jan Novák · 1AB 2345'));
    await tester.tap(find.text('Jana Dvořáková'));
    await tester.tap(find.text('Tmavý vzhled'));
    await tester.pumpAndSettle();

    expect(kliky, [
      'tlačítko',
      'ikona',
      'čip',
      'záložka',
      'pole',
      'prvek',
      'položka',
      'přepínač',
    ]);
  });

  testWidgets('spodní navigace a položka vyskakovacího menu', (tester) async {
    kliky = [];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            SledovaniKliku(onKlik: kliky.add, child: child!),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Další akce',
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'u', child: Text('Upravit')),
                ],
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(icon: Icon(Icons.list), label: 'Zakázky'),
              NavigationDestination(
                icon: Icon(Icons.search),
                label: 'Vyhledat',
              ),
            ],
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Vyhledat'));
    await tester.tap(find.byTooltip('Další akce'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upravit'));
    await tester.pumpAndSettle();

    expect(kliky, ['navigace', 'ikona', 'menu']);
  });

  testWidgets('text, posouvání a dlouhý stisk nejsou klik', (tester) async {
    await postav(
      tester,
      Column(
        children: [
          const Text('Jen text'),
          FilledButton(onPressed: () {}, child: const Text('Uložit')),
          const SizedBox(height: 2000),
        ],
      ),
    );

    await tester.tap(find.text('Jen text'));
    await tester.drag(find.text('Uložit'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Uložit'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(kliky, isEmpty);
  });

  test('klik nese zakázku z obrazovky; dvojklik jen jednou', () {
    var ted = DateTime(2026, 11, 19, 10);
    final log = LogUdalosti(
      odesilani: () => null,
      prihlasen: () => false,
      uloziste: PametoveUlozisteLogu(),
      zarizeni: 'android 14',
      ted: () => ted,
    )..obrazovka('/orders/ZK-26-0418');
    log
      ..klik('tlačítko')
      ..klik('tlačítko');
    ted = ted.add(const Duration(seconds: 1));
    log.klik('tlačítko');

    final kliky = log.fronta.where((u) => u.nazev == 'klik').toList();
    expect(kliky, hasLength(2));
    expect(kliky.first.toJson(), {
      'at': '2026-11-19T10:00:00',
      'type': 'event',
      'name': 'klik',
      'screen': '/orders/ZK-26-0418',
      'order': 'ZK-26-0418',
      'detail': 'tlačítko',
    });
  });
}
