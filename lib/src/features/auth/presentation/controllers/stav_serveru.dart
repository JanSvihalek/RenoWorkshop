import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';

/// Co ukazuje řádek pod přihlášením.
enum StavServeru {
  /// Dotaz na službu ještě běží.
  zjistuje('ZJIŠŤUJI'),

  /// Služba odpověděla - technik je na firemní síti.
  online('ONLINE'),

  /// Služba neodpovídá: telefon je mimo firemní síť, nebo služba neběží.
  nedostupny('SERVER NEDOSTUPNÝ'),

  /// Build bez API - jede na ukázkových datech.
  ukazka('UKÁZKOVÁ DATA');

  const StavServeru(this.popisek);

  final String popisek;
}

/// Jede build proti ostré službě? Vlastní provider, ať jde v testech
/// přepnout - jinak by se stav serveru testoval jen v režimu ukázkových dat.
final pouzivaApiProvider = Provider<bool>((ref) => AppConfig.pouzivaApi);

/// Dostupnost služby. Ptá se na `/health`, tedy bez přihlášení - smysl to
/// má právě předtím, než se technik přihlásí.
final stavServeruProvider = FutureProvider.autoDispose<StavServeru>((
  ref,
) async {
  if (!ref.watch(pouzivaApiProvider)) return StavServeru.ukazka;
  final bezi = await ref.watch(serviceOrderDataSourceProvider).serverBezi();
  return bezi ? StavServeru.online : StavServeru.nedostupny;
});

/// Verze aplikace i s číslem buildu, např. `1.2.0 (73)`. Bere se ze
/// skutečného balíčku, ne z natvrdo psaného textu - jinak by čísla
/// v hlášení chyb nikomu nepomohla.
final verzeAplikaceProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber;
  return build.isEmpty ? info.version : '${info.version} ($build)';
});
