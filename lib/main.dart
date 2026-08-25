import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Česká lokalizace datumů (AppDateFormat).
  await initializeDateFormatting('cs_CZ');

  runApp(const ProviderScope(child: RenoWorkshopApp()));
}
