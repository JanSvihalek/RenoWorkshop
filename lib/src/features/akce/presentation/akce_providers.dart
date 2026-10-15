import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/log_udalosti_provider.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../data/akce_data_source.dart';
import '../data/kampane_data_source.dart';
import '../domain/kampan_podle_stari.dart';
import '../domain/marketingova_akce.dart';
import '../domain/technicka_kampan.dart';

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

/// Technické kampaně - tentýž zdroj jako zakázky.
final kampaneDataSourceProvider = Provider<KampaneDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is KampaneDataSource) return zdroj as KampaneDataSource;
  throw StateError(
    'Zdroj dat ${zdroj.runtimeType} neumí technické kampaně '
    '(KampaneDataSource).',
  );
});

/// Panel vysunutý přes detail na tabletu. Zůstává otevřený i při
/// přepnutí zakázky.
final akcePanelOtevrenyProvider = StateProvider<bool>((ref) => false);

/// Co je v panelu na tabletu - marketingové akce, nebo technické kampaně.
enum DruhPanelu { akce, kampane }

/// Který panel naposled vybral pruh v seznamu zakázek. Bez vybrané
/// zakázky je místo detailu, u zakázky se vysouvá přes detail.
final druhPaneluProvider = StateProvider<DruhPanelu>((ref) => DruhPanelu.akce);

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

/// Technické kampaně: seznam a zápis (jen správce akcí).
final kampaneProvider =
    AsyncNotifierProvider<KampaneController, PrehledKampani>(
      KampaneController.new,
    );

class KampaneController extends AsyncNotifier<PrehledKampani> {
  KampaneDataSource get _zdroj => ref.read(kampaneDataSourceProvider);

  @override
  Future<PrehledKampani> build() =>
      ref.watch(kampaneDataSourceProvider).nactiKampane();

  Future<void> obnov() async {
    state = await AsyncValue.guard(_zdroj.nactiKampane);
  }

  /// VINy kampaně - k úpravě seznamu.
  Future<List<String>> viny(String id) => _zdroj.nactiVinyKampane(id);

  /// Založí (kampaň bez id) nebo upraví kampaň a nahradí její VINy.
  /// Chyba jde volajícímu - okno ji ukáže a zůstane otevřené.
  Future<void> uloz(TechnickaKampan kampan, List<String> viny) async {
    await _zdroj.ulozKampan(kampan, viny);
    ref
        .read(logUdalostiProvider)
        .udalost(kampan.id == null ? 'kampan_pridana' : 'kampan_upravena');
    await _poZmene();
  }

  Future<void> smaz(String id) async {
    await _zdroj.smazKampan(id);
    ref.read(logUdalostiProvider).udalost('kampan_smazana');
    await _poZmene();
  }

  /// Kampaně u zakázek dohledává server - zakázky se načtou znovu, ať je
  /// změna vidět i v detailu.
  Future<void> _poZmene() async {
    ref.invalidate(ordersStreamProvider);
    await obnov();
  }
}

/// Kampaně podle stáří vozu (FitServis+) - upravuje jen jejich správce,
/// v Nastavení.
final kampaneStariProvider =
    AsyncNotifierProvider<KampaneStariController, PrehledKampaniStari>(
      KampaneStariController.new,
    );

class KampaneStariController extends AsyncNotifier<PrehledKampaniStari> {
  @override
  Future<PrehledKampaniStari> build() =>
      ref.watch(kampaneDataSourceProvider).nactiKampaneStari();

  /// Chyba jde volajícímu - okno ji ukáže a zůstane otevřené.
  Future<void> uloz(KampanPodleStari kampan) async {
    final zdroj = ref.read(kampaneDataSourceProvider);
    await zdroj.ulozKampanStari(kampan);
    ref
        .read(logUdalostiProvider)
        .udalost(
          kampan.id == null ? 'kampan_stari_pridana' : 'kampan_stari_upravena',
        );
    // Které vozy do kampaně spadají, počítá server u zakázek.
    ref.invalidate(ordersStreamProvider);
    state = await AsyncValue.guard(zdroj.nactiKampaneStari);
  }
}
