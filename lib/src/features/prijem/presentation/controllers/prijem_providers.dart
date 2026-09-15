import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../data/fotky_data_source.dart';
import '../../domain/entities/fotka.dart';

/// Zdroj fotek je tentýž jako zdroj zakázek - vrací je stejná služba.
final fotkyDataSourceProvider = Provider<FotkyDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is FotkyDataSource) return zdroj as FotkyDataSource;
  throw StateError(
    'Zdroj dat ${zdroj.runtimeType} neumí fotky (FotkyDataSource).',
  );
});

/// Co se hledá na záložce Příjem. Mimo obrazovku, ať ho vyplní skener.
final dotazPrijmuProvider = StateProvider<String>((ref) => '');

/// Dotaz přišel ze skeneru - jediná nalezená zakázka se otevře rovnou.
final otevritJedinouZakazkuProvider = StateProvider<bool>((ref) => false);

/// Nahrané fotky zakázky, nejnovější první.
final fotkyZakazkyProvider = FutureProvider.autoDispose
    .family<List<Fotka>, String>((ref, orderId) async {
      try {
        return await ref.watch(fotkyDataSourceProvider).fotkyZakazky(orderId);
      } on ServiceOrderException {
        rethrow;
      } catch (chyba) {
        throw ServiceOrderException('Fotky se nepodařilo načíst: $chyba');
      }
    });

/// Bajty jedné fotky. Fotka se pod stejným id nikdy nemění, takže se po
/// načtení drží, dokud ji někdo zobrazuje.
final obrazekFotkyProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, id) {
      return ref.watch(fotkyDataSourceProvider).stahniFotku(id);
    });

/// Příprava fotky k nahrání (srovnání, zmenšení, JPEG). Vlastní provider,
/// ať testy nemusí pouštět izolát.
final pripravaFotkyProvider = Provider<Future<Uint8List?> Function(Uint8List)>(
  (ref) =>
      (data) => Isolate.run(() => pripravFotku(data)),
);

/// Fotka, která se nahrává nebo nahrát nešla.
@immutable
class NahravanaFotka {
  const NahravanaFotka({
    required this.klic,
    required this.kategorie,
    required this.jpeg,
    this.chyba,
  });

  /// Místní identifikátor - fotka ještě nemá id ze serveru.
  final String klic;
  final KategorieFotky kategorie;

  /// Připravený JPEG - náhled i data pro „Zkusit znovu".
  final Uint8List jpeg;

  /// `null` = nahrává se; text = nahrát nešla.
  final String? chyba;

  bool get selhala => chyba != null;

  NahravanaFotka sChybou(String? chyba) => NahravanaFotka(
    klic: klic,
    kategorie: kategorie,
    jpeg: jpeg,
    chyba: chyba,
  );
}

/// Fotky zakázky, které ještě nejsou na serveru.
///
/// Nahrávají se po jedné za sebou: sériové focení umí vyrobit deset fotek
/// za chvíli a deset souběžných uploadů po dílenské wi-fi by spadlo spíš
/// než jeden po druhém. Stav přežije odchod z obrazovky - fotky se
/// dohrají, i když se technik mezitím vrátí na seznam.
final nahravaniFotekProvider =
    NotifierProvider.family<NahravaniFotek, List<NahravanaFotka>, String>(
      NahravaniFotek.new,
    );

class NahravaniFotek extends FamilyNotifier<List<NahravanaFotka>, String> {
  Future<void> _fronta = Future.value();
  int _citac = 0;

  String get _orderId => arg;

  @override
  List<NahravanaFotka> build(String arg) => const [];

  /// Přidá fotky do fronty. Připraví je a nahraje jednu po druhé.
  Future<void> pridej(KategorieFotky kategorie, List<Uint8List> surove) {
    for (final data in surove) {
      _fronta = _fronta.then((_) => _zpracuj(kategorie, data));
    }
    return _fronta;
  }

  Future<void> _zpracuj(KategorieFotky kategorie, Uint8List data) async {
    Uint8List? jpeg;
    try {
      jpeg = await ref.read(pripravaFotkyProvider)(data);
    } catch (_) {
      // Chyba jedné fotky nesmí přerušit frontu - další by v ní zůstaly
      // viset a nikdy by se nenahrály.
      jpeg = null;
    }
    if (jpeg == null) {
      state = [
        ...state,
        NahravanaFotka(
          klic: 'mistni-${_citac++}',
          kategorie: kategorie,
          jpeg: data,
          chyba: 'Obrázek se nepodařilo přečíst.',
        ),
      ];
      return;
    }

    final fotka = NahravanaFotka(
      klic: 'mistni-${_citac++}',
      kategorie: kategorie,
      jpeg: jpeg,
    );
    state = [...state, fotka];
    await _nahraj(fotka);
  }

  Future<void> _nahraj(NahravanaFotka fotka) async {
    try {
      await ref
          .read(fotkyDataSourceProvider)
          .nahrajFotku(_orderId, fotka.kategorie, fotka.jpeg);
      state = [
        for (final f in state)
          if (f.klic != fotka.klic) f,
      ];
      ref.invalidate(fotkyZakazkyProvider(_orderId));
    } catch (chyba) {
      final zprava = chyba is ServiceOrderException
          ? chyba.message
          : 'Fotku se nepodařilo nahrát.';
      state = [
        for (final f in state)
          if (f.klic == fotka.klic) f.sChybou(zprava) else f,
      ];
    }
  }

  /// Nahraje znovu fotku, která nešla.
  Future<void> znovu(String klic) {
    final fotka = state.where((f) => f.klic == klic).firstOrNull;
    if (fotka == null || !fotka.selhala) return _fronta;
    final cekajici = fotka.sChybou(null);
    state = [
      for (final f in state)
        if (f.klic == klic) cekajici else f,
    ];
    return _fronta = _fronta.then((_) => _nahraj(cekajici));
  }

  /// Zahodí fotku, která nešla nahrát.
  void zahod(String klic) {
    state = [
      for (final f in state)
        if (f.klic != klic) f,
    ];
  }
}
