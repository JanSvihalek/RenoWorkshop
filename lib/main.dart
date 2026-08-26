import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Česká lokalizace datumů (AppDateFormat).
  await initializeDateFormatting('cs_CZ');

  // Firebase Auth drží přihlášení firemním účtem (Microsoft OIDC).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: RenoWorkshopApp()));
}
