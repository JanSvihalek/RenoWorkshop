import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/log_udalosti.dart';
import '../features/auth/domain/entities/auth_state.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/controllers/stav_serveru.dart';
import '../features/orders/presentation/controllers/orders_providers.dart';

/// Kam se fronta logu ukládá mezi spuštěními. V `main` se přepíše na
/// úložiště telefonu, testy zůstávají v paměti.
final ulozisteLoguProvider = Provider<UlozisteLogu>(
  (ref) => PametoveUlozisteLogu(),
);

/// Log událostí aplikace (viz [LogUdalosti]).
final Provider<LogUdalosti> logUdalostiProvider = Provider<LogUdalosti>((ref) {
  final log = LogUdalosti(
    // Zdroj i přihlášení se berou až při odeslání - log vzniká dřív než
    // přihlášení a zdroj dat se v testech přepisuje.
    odesilani: () {
      final zdroj = ref.read(serviceOrderDataSourceProvider);
      return zdroj is OdesilaniUdalosti ? zdroj as OdesilaniUdalosti : null;
    },
    prihlasen: () => ref.read(authControllerProvider) is AuthSignedIn,
    uloziste: ref.watch(ulozisteLoguProvider),
    verze: () => ref.read(verzeAplikaceProvider).valueOrNull,
  );
  ref.onDispose(log.zastav);
  return log;
});

/// Fronta logu v úložišti telefonu (SharedPreferences).
class SharedPreferencesUlozisteLogu implements UlozisteLogu {
  SharedPreferencesUlozisteLogu(this._prefs);

  static const _klic = 'log_udalosti_fronta';
  final SharedPreferences _prefs;

  @override
  String? nacti() => _prefs.getString(_klic);

  @override
  Future<void> uloz(String? json) async {
    if (json == null) {
      await _prefs.remove(_klic);
    } else {
      await _prefs.setString(_klic, json);
    }
  }
}
