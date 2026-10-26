import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Přepne záložku v detailu zakázky: `prace`, `vuz`, nebo `dokumenty`.
Future<void> naZalozku(WidgetTester tester, String zalozka) async {
  await tester.tap(find.byKey(Key('zalozka-$zalozka')));
  await tester.pumpAndSettle();
}
