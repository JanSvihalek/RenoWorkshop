import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/settings/presentation/controllers/nastaveni_controller.dart';
import 'router.dart';
import 'package:flutter/services.dart';

/// Kořen appky. Světlý i tmavý režim si volí uživatel v nastavení,
/// výchozí je podle systému. Hlavičky obrazovek jsou ve tmavém režimu
/// firemní navy, ve světlém bílé.
class RenoWorkshopApp extends ConsumerWidget {
  const RenoWorkshopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RenoWorkshop',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(nastaveniProvider).vzhled.themeMode,
      // Hodiny a baterie podle hlavičky: na bílé tmavé, na navy bílé.
      // Tmavé obrazovky (přihlášení, skener) si nastavují bílé samy.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: child!,
      ),
      locale: const Locale('cs', 'CZ'),
      supportedLocales: const [Locale('cs', 'CZ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
