import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/log_udalosti_provider.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../data/akce_data_source.dart';
import '../domain/marketingova_akce.dart';

/// Zdroj akcí je tentýž jako zdroj zakázek - vrací je stejná služba.
final akceDataSourceProvider = Provider<AkceDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is AkceDataSource) return zdroj as AkceDataSource;
  throw StateError(
    'Zdroj dat ${zdroj.runtimeType} neumí marketingové akce (AkceDataSource).',
  );
});

/// Dnešní den - v testech jde podvrhnout, ať časová osa nezávisí na tom,
/// kdy test běží.
final dnesProvider = Provider<DateTime>((ref) {
  final ted = DateTime.now();
  return DateTime(ted.year, ted.month, ted.day);
});

/// Panel akcí vysunutý přes detail na tabletu. Zůstává otevřený
/// i při přepnutí zakázky.
final akcePanelOtevrenyProvider = StateProvider<bool>((ref) => false);

/// Marketingové akce: seznam a zápis (jen správce).
final akceProvider = AsyncNotifierProvider<AkceController, PrehledAkci>(
  AkceController.new,
);

class AkceController extends AsyncNotifier<PrehledAkci> {
  AkceDataSource get _zdroj => ref.read(akceDataSourceProvider);

  @override
  Future<PrehledAkci> build() => ref.watch(akceDataSourceProvider).nactiAkce();

  /// Načte akce znovu - třeba po stažení seznamu prstem.
  Future<void> obnov() async {
    state = await AsyncValue.guard(_zdroj.nactiAkce);
  }

  /// Založí (akce bez id) nebo upraví akci. Chyba jde volajícímu - okno
  /// ji ukáže a zůstane otevřené.
  Future<void> uloz(MarketingovaAkce akce) async {
    await _zdroj.ulozAkci(akce);
    ref
        .read(logUdalostiProvider)
        .udalost(akce.id == null ? 'akce_pridana' : 'akce_upravena');
    await obnov();
  }

  Future<void> smaz(String id) async {
    await _zdroj.smazAkci(id);
    ref.read(logUdalostiProvider).udalost('akce_smazana');
    await obnov();
  }
}
