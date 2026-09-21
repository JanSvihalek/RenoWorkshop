import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/app/log_udalosti_provider.dart';
import 'src/core/log/log_udalosti.dart';
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
  final prefs = await _prefs();
  final container = ProviderContainer(
    overrides: [
      nastaveniUlozisteProvider.overrideWithValue(
        prefs == null ? PametoveNastaveni() : SharedPreferencesNastaveni(prefs),
      ),
      if (prefs != null)
        ulozisteLoguProvider.overrideWithValue(
          SharedPreferencesUlozisteLogu(prefs),
        ),
    ],
  );

  // Každá nezachycená chyba jde do logu událostí - technik ji často ani
  // nevidí, jen mu něco nefunguje.
  final log = container.read(logUdalostiProvider)..spust();
  _zachytavejChyby(log);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RenoWorkshopApp(),
    ),
  );
}

void _zachytavejChyby(LogUdalosti log) {
  final puvodni = FlutterError.onError;
  FlutterError.onError = (details) {
    log.chyba(
      'chyba_aplikace',
      details.exception,
      zasobnik: details.stack,
      detail: details.context?.toDescription(),
    );
    puvodni?.call(details);
  };
  PlatformDispatcher.instance.onError = (chyba, zasobnik) {
    log.chyba('chyba_aplikace', chyba, zasobnik: zasobnik);
    // Vypsat i do konzole - při vývoji ji chci vidět.
    FlutterError.presentError(
      FlutterErrorDetails(exception: chyba, stack: zasobnik),
    );
    return true;
  };
}

/// Když úložiště telefonu selže, appka poběží dál - jen si nastavení
/// nezapamatuje. Kvůli barvě témat nemá cenu nepustit mechanika k zakázkám.
Future<SharedPreferences?> _prefs() async {
  try {
    return await SharedPreferences.getInstance();
  } on Exception {
    return null;
  }
}
