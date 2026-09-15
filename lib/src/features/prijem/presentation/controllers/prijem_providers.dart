import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../data/prijem_data_source.dart';
import '../../domain/entities/prijem.dart';

/// Zdroj příjmu je tentýž jako zdroj zakázek - vrací ho stejná služba.
final prijemDataSourceProvider = Provider<PrijemDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is PrijemDataSource) return zdroj as PrijemDataSource;
  throw StateError(
    'Zdroj dat ${zdroj.runtimeType} neumí příjem (PrijemDataSource).',
  );
});

/// Co se hledá na záložce Příjem. Mimo obrazovku, ať ho vyplní skener.
final dotazPrijmuProvider = StateProvider<String>((ref) => '');

/// Dotaz přišel ze skeneru - jediná nalezená zakázka se otevře rovnou.
final otevritJedinyPrijemProvider = StateProvider<bool>((ref) => false);

/// Příjem zakázky. Sdílí ho obrazovka checklistu i karta v detailu.
final prijemZakazkyProvider = AsyncNotifierProvider.autoDispose
    .family<PrijemController, Prijem, String>(PrijemController.new);

String _zprava(Object chyba) => chyba is ServiceOrderException
    ? chyba.message
    : 'Příjem se nepodařilo uložit.';

class PrijemController extends AutoDisposeFamilyAsyncNotifier<Prijem, String> {
  /// Poslední stav potvrzený serverem.
  Prijem? _server;

  /// Změny, které se ještě ukládají - na obrazovce už jsou vidět.
  final List<(String, ZmenaPolozky)> _cekajici = [];

  /// Změny jdou na server po jedné: technik odškrtává rychle za sebou
  /// a souběžné odpovědi by se mohly přepsat v jiném pořadí.
  Future<void> _fronta = Future.value();

  @override
  Future<Prijem> build(String arg) async {
    _cekajici.clear();
    final prijem = await ref.watch(prijemDataSourceProvider).prijemZakazky(arg);
    _server = prijem;
    return prijem;
  }

  Prijem _sCekajicimi(Prijem zaklad) {
    var prijem = zaklad;
    for (final (kod, zmena) in _cekajici) {
      final polozka = prijem.polozky.where((p) => p.kod == kod).firstOrNull;
      if (polozka != null) prijem = prijem.sPolozkou(zmena.pouzij(polozka));
    }
    return prijem;
  }

  /// Změní položku. Na obrazovce hned, uloží se na pozadí. Vrací chybovou
  /// zprávu, když uložení selhalo - změna se pak na obrazovce vrátí.
  Future<String?> zmen(String kod, ZmenaPolozky zmena) {
    final zaklad = _server;
    if (zaklad == null || zaklad.jeDokoncen) return Future.value(null);

    final polozka = (kod, zmena);
    _cekajici.add(polozka);
    state = AsyncData(_sCekajicimi(zaklad));

    final vysledek = Completer<String?>();
    _fronta = _fronta.then((_) async {
      String? chyba;
      try {
        _server = await ref
            .read(prijemDataSourceProvider)
            .zmenPolozku(arg, kod, zmena);
      } catch (e) {
        chyba = _zprava(e);
      }
      _cekajici.remove(polozka);
      final server = _server;
      if (server != null) state = AsyncData(_sCekajicimi(server));
      vysledek.complete(chyba);
    });
    return vysledek.future;
  }

  /// Dokončí příjem, až doběhnou rozpracované změny.
  Future<String?> dokonci() => _akce((zdroj) => zdroj.dokonciPrijem(arg));

  /// Znovu otevře dokončený příjem k úpravě.
  Future<String?> znovuOtevri() =>
      _akce((zdroj) => zdroj.znovuOtevriPrijem(arg));

  Future<String?> _akce(
    Future<Prijem> Function(PrijemDataSource zdroj) akce,
  ) async {
    await _fronta;
    try {
      final prijem = await akce(ref.read(prijemDataSourceProvider));
      _server = prijem;
      state = AsyncData(prijem);
      return null;
    } catch (chyba) {
      return _zprava(chyba);
    }
  }
}
