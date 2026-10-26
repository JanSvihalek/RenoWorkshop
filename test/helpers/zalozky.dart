import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Přepne sekci v detailu zakázky: `zavady`, `prijem`, `dokumenty`, nebo
/// `ulozenky` (menu vlevo, na úzkém displeji nahoře).
Future<void> naSekci(WidgetTester tester, String sekce) async {
  final polozka = find.byKey(Key('sekce-$sekce'));
  await tester.ensureVisible(polozka);
  await tester.pumpAndSettle();
  await tester.tap(polozka);
  await tester.pumpAndSettle();
}
