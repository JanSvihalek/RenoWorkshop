import 'dart:async';

import 'package:renoworkshop/src/features/plan/presentation/osa_prubehu.dart';

/// Společné nastavení všech testů (flutter test ho načte sám).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Nekonečný pulz probíhajícího kroku by nenechal doběhnout pumpAndSettle.
  pulzovaniOsy = false;
  await testMain();
}
