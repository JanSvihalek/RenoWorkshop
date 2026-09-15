import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../fotodokumentace/data/fotky_data_source.dart';
import '../../../fotodokumentace/domain/entities/fotka.dart';
import '../../../vozidla/data/vozidla_data_source.dart';
import '../../../vozidla/domain/entities/vozidlo.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../dtos/service_order_dto.dart';
import 'service_order_data_source.dart';

/// Fáze 1: zakázky z lokálního JSONu, mutace jen v paměti.
///
/// Simuluje latenci sítě, aby UI muselo počítat s loading stavem stejně
/// jako u reálného API.
class MockServiceOrderDataSource
    implements ServiceOrderDataSource, VozidlaDataSource, FotkyDataSource {
  MockServiceOrderDataSource({
    AssetBundle? bundle,
    this.assetPath = 'assets/mock/service_orders.json',
    this.latency = const Duration(milliseconds: 320),
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  /// Umělé zpoždění "sítě". V testech se nastavuje na [Duration.zero].
  final Duration latency;

  /// In-memory stav dílny. Přežije navigaci, ne restart appky.
  List<ServiceOrderDto>? _cache;

  Future<List<ServiceOrderDto>> _ensureLoaded() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final orders = (decoded['orders'] as List<dynamic>)
        .map((item) => ServiceOrderDto.fromJson(item as Map<String, dynamic>))
        .toList();
    return _cache = orders;
  }

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  int _indexOf(List<ServiceOrderDto> orders, String orderId) =>
      orders.indexWhere((order) => order.id == orderId);

  @override
  Future<List<ServiceOrderDto>> fetchOrders() async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    return List.unmodifiable(orders);
  }

  @override
  Future<ServiceOrderDto?> fetchOrder(String orderId) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    return index == -1 ? null : orders[index];
  }

  @override
  Future<List<ServiceOrderDto>> searchOrders(String query) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();

    final hledane = query.trim().toUpperCase().replaceAll(' ', '');
    if (hledane.isEmpty) return const [];

    // Mock nemá archiv uzavřených zakázek, hledá se tedy v tom, co je.
    // Proti API je rozdíl jen v rozsahu dat, ne v chování.
    return orders.where((dto) {
      final prohledavane = [
        dto.id,
        dto.licensePlate,
        dto.vin,
        dto.customerName,
      ].join(' ').toUpperCase().replaceAll(' ', '');
      return prohledavane.contains(hledane);
    }).toList();
  }

  @override
  Future<ServiceOrderDto?> pridejStav(
    String orderId, {
    String? kod,
    String? nazev,
    String? poznamka,
  }) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final popis =
        nazev ??
        _nabidka
            .firstWhere(
              (stav) => stav.kod == kod,
              orElse: () => NabidkaStavu(kod: kod ?? '', nazev: kod ?? ''),
            )
            .nazev;

    // Nejnovější záznam patří na začátek - stejně jako je vrací server.
    final zaznam = {
      'id': 'stav-${DateTime.now().microsecondsSinceEpoch}',
      'code': kod,
      'label': popis,
      'note': poznamka,
      'author': 'Jan Dvořák',
      'createdAt': DateTime.now().toIso8601String(),
    };

    final updated = orders[index].copyWith(
      status: popis,
      statusCode: kod,
      statusHistory: [zaznam, ...orders[index].statusHistory],
    );
    orders[index] = updated;
    return updated;
  }

  /// Nabídka odpovídá výchozímu číselníku na serveru, ať ukázková data
  /// vypadají jako ostrá.
  static const _nabidka = [
    NabidkaStavu(kod: 'prijato', nazev: 'Přijato'),
    NabidkaStavu(kod: 'prohlidka', nazev: 'Prohlídka a nafocení'),
    NabidkaStavu(kod: 'rozpocet', nazev: 'Rozpočet'),
    NabidkaStavu(kod: 'ceka_pojistovna', nazev: 'Čeká na pojišťovnu'),
    NabidkaStavu(kod: 'objednano', nazev: 'Díly objednány'),
    NabidkaStavu(kod: 'ceka_dily', nazev: 'Čeká na díly'),
    NabidkaStavu(kod: 'demontaz', nazev: 'Demontáž'),
    NabidkaStavu(kod: 'klempirna', nazev: 'Klempířské práce'),
    NabidkaStavu(kod: 'priprava_lak', nazev: 'Příprava na lak'),
    NabidkaStavu(kod: 'lakovna', nazev: 'Lakovna'),
    NabidkaStavu(kod: 'montaz', nazev: 'Montáž'),
    NabidkaStavu(kod: 'kontrola', nazev: 'Kontrola'),
    NabidkaStavu(kod: 'pripraveno', nazev: 'Připraveno k vyzvednutí'),
    NabidkaStavu(kod: 'vyzvednuto', nazev: 'Vyzvednuto'),
  ];

  @override
  Future<ServiceOrderDto?> ulozPredmetOpravy(
    String orderId,
    String text,
  ) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final orezany = text.trim();
    return orders[index] = orders[index].copyWith(
      repairSubject: orezany.isEmpty ? null : orezany,
      vymazatPredmet: orezany.isEmpty,
    );
  }

  @override
  Future<ServiceOrderDto?> smazStav(String orderId, String zaznamId) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final zbyle = orders[index].statusHistory
        .where((zaznam) => zaznam['id'] != zaznamId)
        .toList();

    final updated = orders[index].copyWith(
      status: zbyle.isEmpty ? null : zbyle.first['label'] as String?,
      statusCode: zbyle.isEmpty ? null : zbyle.first['code'] as String?,
      statusHistory: zbyle,
      vymazatStav: zbyle.isEmpty,
    );
    orders[index] = updated;
    return updated;
  }

  @override
  Future<List<NabidkaStavu>> nabidkaStavu() async {
    await _simulateLatency();
    return _nabidka;
  }

  @override
  Future<ServiceOrderDto?> addNote({
    required String orderId,
    required String text,
    required String author,
  }) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final note = OrderNoteDto(
      id: 'N-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      author: author,
      createdAt: DateTime.now().toIso8601String(),
    );
    final updated = orders[index].copyWith(
      notes: [note, ...orders[index].notes],
    );
    orders[index] = updated;
    return updated;
  }

  @override
  Future<ServiceOrderDto?> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  }) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final updated = orders[index].copyWith(
      workItems: orders[index].workItems
          .map(
            (item) =>
                item.id == workItemId ? item.copyWith(isDone: isDone) : item,
          )
          .toList(),
    );
    orders[index] = updated;
    return updated;
  }

  /// Mock nemá zrcadlo vozidel - vozidla skládá ze zakázek podle SPZ.
  /// Pořadí je stálé (podle SPZ), ať má vůz mezi voláními stejné `id`.
  Future<List<List<ServiceOrderDto>>> _vozidlaZeZakazek() async {
    final orders = await _ensureLoaded();
    final podleSpz = <String, List<ServiceOrderDto>>{};
    for (final dto in orders) {
      podleSpz.putIfAbsent(dto.licensePlate, () => []).add(dto);
    }
    final spz = podleSpz.keys.toList()..sort();
    return [for (final s in spz) podleSpz[s]!];
  }

  @override
  Future<List<NalezeneVozidlo>> hledejVozidla(String dotaz) async {
    final vozidla = await _vozidlaZeZakazek();
    await _simulateLatency();

    String kod(String s) => s.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    final hledane = kod(dotaz);
    if (hledane.length < 3) return const [];

    return [
      for (var i = 0; i < vozidla.length; i++)
        if (kod(vozidla[i].first.licensePlate).contains(hledane) ||
            kod(vozidla[i].first.vin).contains(hledane))
          NalezeneVozidlo(
            id: i + 1,
            spz: vozidla[i].first.licensePlate,
            vin: vozidla[i].first.vin,
            model: vozidla[i].first.model,
            majitel: vozidla[i].first.customerName,
            pocetZakazek: vozidla[i].length,
          ),
    ];
  }

  @override
  Future<KartaVozidla?> kartaVozidla(int id) async {
    final vozidla = await _vozidlaZeZakazek();
    await _simulateLatency();
    if (id < 1 || id > vozidla.length) return null;

    final zakazky = vozidla[id - 1];
    final prvni = zakazky.first;
    return KartaVozidla(
      id: id,
      spz: prvni.licensePlate,
      vin: prvni.vin,
      model: prvni.model,
      majitel: MajitelVozidla(nazev: prvni.customerName),
      zakazky: [for (final dto in zakazky) dto.toDomain()],
    );
  }

  @override
  Future<void> synchronizuj() => _simulateLatency();

  /// Fotky jen v paměti - bez serveru se ukládají, dokud appka běží.
  final Map<String, List<Fotka>> _fotky = {};
  final Map<String, Uint8List> _bajtyFotek = {};

  @override
  Future<List<Fotka>> fotkyZakazky(String orderId) async {
    await _simulateLatency();
    return List.of(_fotky[orderId] ?? const []);
  }

  @override
  Future<Fotka> nahrajFotku(
    String orderId,
    KategorieFotky kategorie,
    Uint8List jpeg, {
    String? pobocka,
  }) async {
    await _simulateLatency();
    final fotka = Fotka(
      id: 'mock-${DateTime.now().microsecondsSinceEpoch}',
      kategorie: kategorie,
      nahranoAt: DateTime.now(),
      nahralKdo: 'Mock',
    );
    _bajtyFotek[fotka.id] = jpeg;
    _fotky.putIfAbsent(orderId, () => []).insert(0, fotka);
    return fotka;
  }

  @override
  Future<List<String>> slozkyPobocek() async {
    await _simulateLatency();
    return const ['Brno', 'Bubenec', 'Ceska', 'Cestlice', 'KCP'];
  }

  @override
  Future<Uint8List> stahniFotku(String id) async {
    final bajty = _bajtyFotek[id];
    if (bajty == null) {
      throw StateError('Fotka $id v mocku není.');
    }
    return bajty;
  }

  @override
  Future<void> smazFotku(String id) async {
    _bajtyFotek.remove(id);
    for (final seznam in _fotky.values) {
      seznam.removeWhere((fotka) => fotka.id == id);
    }
  }
}
