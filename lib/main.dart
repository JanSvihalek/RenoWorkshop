import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/features/settings/data/nastaveni_uloziste.dart';
import 'src/features/settings/presentation/controllers/nastaveni_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Česká lokalizace datumů (AppDateFormat).
  await initializeDateFormatting('cs_CZ');

  // Firebase Auth drží přihlášení firemním účtem (Microsoft OIDC).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Nastavení se načte ještě před prvním vykreslením, jinak by appka
  // blikla systémovým tématem, než by se dočetla to zvolené.
  final uloziste = await _nactiUloziste();

  runApp(
    ProviderScope(
      overrides: [nastaveniUlozisteProvider.overrideWithValue(uloziste)],
      child: const RenoWorkshopApp(),
    ),
  );
}

/// Když úložiště telefonu selže, appka poběží dál - jen si nastavení
/// nezapamatuje. Kvůli barvě témat nemá cenu nepustit mechanika k zakázkám.
Future<NastaveniUloziste> _nactiUloziste() async {
  try {
    return SharedPreferencesNastaveni(await SharedPreferences.getInstance());
  } on Exception {
    return PametoveNastaveni();
  }
}
