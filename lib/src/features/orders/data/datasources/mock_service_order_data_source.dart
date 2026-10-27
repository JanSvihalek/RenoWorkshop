import '../../../akce/data/akce_data_source.dart';
import '../../../akce/data/kampane_data_source.dart';
import '../../../akce/domain/kampan_podle_stari.dart';
import '../../../akce/domain/marketingova_akce.dart';
import '../../../akce/domain/technicka_kampan.dart';
import '../../../plan/data/plan_data_source.dart';
import '../../../plan/domain/prehled_planu.dart';
import '../../domain/entities/moje_prava.dart';
import '../../domain/entities/plan_klempirny.dart';
import '../../domain/entities/kampan_vozidla.dart';
import '../../domain/entities/obalka_klice.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../fotodokumentace/data/fotky_data_source.dart';
import '../../../fotodokumentace/domain/entities/dokument.dart';
import '../../../fotodokumentace/domain/entities/fotka.dart';
import '../../../prijem/data/prijem_data_source.dart';
import '../../../prijem/domain/entities/prijem.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../../../vozidla/data/vozidla_data_source.dart';
import '../../../vozidla/domain/entities/vozidlo.dart';
import '../../../ulozenky/data/ulozenky_data_source.dart';
import '../../../ulozenky/domain/ulozenka_pneu.dart';
import '../../../uzivatele/data/uzivatele_data_source.dart';
import '../../../uzivatele/domain/uzivatele.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/zpracovatel.dart';
import '../../domain/entities/branch.dart';
import '../dtos/service_order_dto.dart';
import 'service_order_data_source.dart';

/// Fáze 1: zakázky z lokálního JSONu, mutace jen v paměti.
///
/// Simuluje latenci sítě, aby UI muselo počítat s loading stavem stejně
/// jako u reálného API.
class MockServiceOrderDataSource
    implements
        ServiceOrderDataSource,
        VozidlaDataSource,
        FotkyDataSource,
        PrijemDataSource,
        AkceDataSource,
        KampaneDataSource,
        PlanDataSource,
        UzivateleDataSource,
        UlozenkyDataSource {
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
    _cache = orders;
    _promitniKampane();
    _zalozPlany(orders);
    return orders;
  }

  /// Klempířské útvary končí v ukázkových datech na 215 (11215, 12215…).
  static bool _klempirna(ServiceOrderDto o) =>
      (o.department?['code'] as String? ?? '').endsWith('215');

  /// Klempířské zakázky jde plánovat a dvě jsou rovnou v plánu tohoto
  /// týdne - ať záložka Plán není prázdná.
  void _zalozPlany(List<ServiceOrderDto> orders) {
    final po = pondeli(DateTime.now());
    var n = 0;
    for (var i = 0; i < orders.length; i++) {
      if (!_klempirna(orders[i])) continue;
      final od = po.add(Duration(days: n * 2));
      orders[i] = orders[i].copyWith(
        canPlanBodyshop: true,
        bodyshopPlan: n < 2
            ? PlanKlempirny(
                od: od,
                do_: od.add(const Duration(days: 2)),
                kodLaku: n == 0 ? '416' : 'C4P',
                zaplanoval: 'Dílna',
              ).toJson()
            : null,
      );
      n++;
    }
  }

  @override
  Future<ServiceOrderDto?> ulozPlanKlempirny(
    String orderId,
    PlanKlempirny plan,
  ) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;
    if (!orders[index].canPlanBodyshop) {
      throw const ServiceOrderException(
        'Na klempírnu/lakovnu se plánují jen zakázky klempířských útvarů.',
      );
    }
    return orders[index] = orders[index].copyWith(
      bodyshopPlan: {...plan.toJson(), 'plannedBy': 'Dílna'},
    );
  }

  @override
  Future<ServiceOrderDto?> zrusPlanKlempirny(String orderId) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;
    return orders[index] = orders[index].copyWith(vymazatPlan: true);
  }

  @override
  Future<PrehledPlanu> nactiPlan(DateTime od, DateTime do_) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    return PrehledPlanu(
      pobocky: const [
        PobockaPlanu(kod: '1', nazev: 'Brno'),
        PobockaPlanu(kod: '2', nazev: 'Nupaky'),
        PobockaPlanu(kod: '5', nazev: 'Bubeneč'),
      ],
      polozky: _polozkyPlanu(orders, od, do_),
    );
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
    String? misto,
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

  /// Ukázkoví zaměstnanci. Útvary odpovídají ukázkovým zakázkám, ať jde
  /// vyzkoušet nabídka jen z útvaru zakázky.
  static const _zamestnanci = <(int, String, String?)>[
    (501, 'Dvořák Jan', '11211'),
    (502, 'Kříž Martin', '11211'),
    (503, 'Válková Petra', '12211'),
    (504, 'Horáková Martina', '12211'),
    (505, 'Novotný Pavel', '12214'),
    (506, 'Svoboda Tomáš', '14211'),
    (507, 'Černý Lukáš', '13211'),
    (508, 'Procházka David', '11221'),
  ];

  /// Za koho se v ukázce převezme zakázka - přihlášeného mock nezná.
  static const _ja = (500, 'Ukázkový technik', null);

  @override
  Future<NabidkaZpracovatelu> nabidkaZpracovatelu(
    String orderId, {
    bool vsichni = false,
  }) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    final utvar = index == -1 ? null : orders[index].department;
    final kod = utvar?['code'] as String?;
    final jenUtvar =
        !vsichni && kod != null && _zamestnanci.any((z) => z.$3 == kod);

    return NabidkaZpracovatelu(
      utvarZakazky: utvar == null ? null : Department.fromJson(utvar),
      jenUtvar: jenUtvar,
      lide: [
        for (final (id, jmeno, utvarKod) in [_ja, ..._zamestnanci])
          if (!jenUtvar || utvarKod == kod)
            ZamestnanecKVyberu(
              id: id,
              jmeno: jmeno,
              kod: '$id',
              utvar: utvarKod == null
                  ? null
                  : Department(code: utvarKod, label: utvarKod),
            ),
      ]..sort((a, b) => a.jmeno.compareTo(b.jmeno)),
    );
  }

  @override
  Future<ServiceOrderDto?> nastavZpracovatele(
    String orderId,
    int? zamestnanecId,
  ) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;
    if (zamestnanecId == null) {
      return orders[index] = orders[index].copyWith(vymazatZpracovatele: true);
    }
    final kdo = [_ja, ..._zamestnanci].firstWhere(
      (z) => z.$1 == zamestnanecId,
      orElse: () => throw const ServiceOrderException(
        'Takový zaměstnanec v ukázkových datech není.',
      ),
    );
    return orders[index] = orders[index].copyWith(
      assignee: {
        'id': kdo.$1,
        'name': kdo.$2,
        'since': DateTime.now().toIso8601String().substring(0, 19),
        'assignedBy': 'Ukázkový technik',
      },
    );
  }

  @override
  Future<ServiceOrderDto?> prevezmiZakazku(String orderId) =>
      nastavZpracovatele(orderId, _ja.$1);

  /// Ukázkové akce kolem dneška - jedna běží, jedna brzy končí, jedna
  /// teprve začne. V ukázkových datech smí akce zadávat každý.
  late final List<MarketingovaAkce> _akce = () {
    final ted = DateTime.now();
    final dnes = DateTime(ted.year, ted.month, ted.day);
    return [
      MarketingovaAkce(
        id: 'ukazka-1',
        nazev: 'Zimní prohlídka -20 % na práci',
        text:
            'Kontrola vozu před zimou: baterie, stěrače, kapaliny, pneumatiky. '
            'Na práci sleva 20 %, platí pro všechny značky.',
        od: dnes.subtract(const Duration(days: 12)),
        do_: dnes.add(const Duration(days: 40)),
        zadalKdo: 'Marketing',
      ),
      MarketingovaAkce(
        id: 'ukazka-2',
        nazev: 'Stěrače zdarma k servisu',
        text: 'K servisní prohlídce sada předních stěračů zdarma.',
        od: dnes.subtract(const Duration(days: 20)),
        do_: dnes.add(const Duration(days: 4)),
        zadalKdo: 'Marketing',
      ),
      MarketingovaAkce(
        id: 'ukazka-3',
        nazev: 'Přezutí pneumatik s uskladněním',
        text: 'Přezutí a uskladnění kol za zvýhodněnou cenu.',
        od: dnes.add(const Duration(days: 9)),
        do_: dnes.add(const Duration(days: 55)),
        zadalKdo: 'Marketing',
      ),
    ];
  }();

  @override
  Future<PrehledAkci> nactiAkce() async {
    await _simulateLatency();
    final ted = DateTime.now();
    final dnes = DateTime(ted.year, ted.month, ted.day);
    return PrehledAkci(
      akce: [
        for (final a in _akce)
          if (!a.do_.isBefore(dnes)) a,
      ]..sort((a, b) => a.od.compareTo(b.od)),
      muzeUpravovat: true,
    );
  }

  @override
  Future<MarketingovaAkce> ulozAkci(MarketingovaAkce akce) async {
    await _simulateLatency();
    final id = akce.id;
    if (id == null) {
      final nova = akce.copyWith(id: 'ukazka-${_akce.length + 1}');
      _akce.add(nova);
      return nova;
    }
    final i = _akce.indexWhere((a) => a.id == id);
    if (i == -1) throw const ServiceOrderException('Akce nebyla nalezena.');
    return _akce[i] = akce;
  }

  @override
  Future<void> smazAkci(String id) async {
    await _simulateLatency();
    _akce.removeWhere((a) => a.id == id);
  }

  /// Ukázkové technické kampaně - týkají se prvních vozů z ukázkových
  /// zakázek (jednou celým VINem, jednou krátkým).
  final List<TechnickaKampan> _kampane = [
    const TechnickaKampan(
      id: 'ukazka-k1',
      kod: '0061960500',
      nazev: 'Kontrola upevnění airbagu spolujezdce',
      text:
          'Zkontrolovat a případně dotáhnout šrouby modulu airbagu '
          'spolujezdce. Doba práce 0,4 h.',
      zadalKdo: 'Servis',
    ),
    const TechnickaKampan(
      id: 'ukazka-k2',
      kod: '0032760300',
      nazev: 'Aktualizace softwaru řídicí jednotky motoru',
      text: 'Programování přes ISTA, doba práce 0,8 h.',
      zadalKdo: 'Servis',
    ),
  ];
  final Map<String, List<String>> _vinyKampani = {
    'ukazka-k1': ['WBAJN51070G980042', 'G973737', 'WBA00000000000017'],
    'ukazka-k2': ['WBAJN51070G980042'],
  };

  /// FitServis+ - v ukázkových datech ho smí upravovat každý.
  final List<KampanPodleStari> _kampaneStari = [
    const KampanPodleStari(
      id: 'fitservis-plus',
      nazev: 'FitServis+',
      text: 'Kampaň BMW pro vozy starší 48 měsíců.',
      odMesicu: 48,
    ),
  ];

  /// Ukázkové zakázky registraci nemají - dostanou smyšlenou, každá
  /// o rok starší, ať jsou vidět vozy v kampani i mimo ni.
  static String _registrace(int i) {
    final ted = DateTime.now();
    final d = DateTime(ted.year - 1 - i % 8, ted.month, 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-01';
  }

  /// Kampaně k zakázkám podle VINu a stáří - totéž dělá server.
  void _promitniKampane() {
    final orders = _cache;
    if (orders == null) return;
    final ted = DateTime.now();
    for (var i = 0; i < orders.length; i++) {
      final vin = orders[i].vin.toUpperCase();
      final registrace = DateTime.parse(_registrace(i));
      final stari =
          (ted.year - registrace.year) * 12 + ted.month - registrace.month;
      orders[i] = orders[i].copyWith(
        firstRegisteredAt: _registrace(i),
        vehicleColor: _barvy[i % _barvy.length],
        ageCampaigns: [
          for (final k in _kampaneStari)
            if (k.aktivni &&
                stari >= k.odMesicu &&
                (k.doMesicu == null || stari < k.doMesicu!))
              KampanVozidla(id: k.id!, nazev: k.nazev, text: k.text),
        ],
        technicalCampaigns: [
          for (final k in _kampane)
            if (vin.length == 17 &&
                (_vinyKampani[k.id] ?? const []).any(
                  (v) => v == vin || v == vin.substring(10),
                ))
              KampanVozidla(
                id: k.id!,
                kod: k.kod,
                nazev: k.nazev,
                text: k.text,
              ),
        ],
      );
    }
  }

  @override
  Future<PrehledKampani> nactiKampane() async {
    await _simulateLatency();
    return PrehledKampani(
      kampane: [
        for (final k in _kampane)
          k.copyWith(pocetVozidel: _vinyKampani[k.id]?.length ?? 0),
      ],
      muzeUpravovat: true,
    );
  }

  @override
  Future<List<String>> nactiVinyKampane(String id) async {
    await _simulateLatency();
    return [...?_vinyKampani[id]];
  }

  @override
  Future<TechnickaKampan> ulozKampan(
    TechnickaKampan kampan,
    List<String> viny,
  ) async {
    await _simulateLatency();
    final ulozena = kampan.copyWith(
      id: kampan.id ?? 'ukazka-k${_kampane.length + 1}',
      pocetVozidel: viny.length,
    );
    final i = _kampane.indexWhere((k) => k.id == ulozena.id);
    if (i == -1) {
      _kampane.add(ulozena);
    } else {
      _kampane[i] = ulozena;
    }
    _vinyKampani[ulozena.id!] = [...viny];
    _promitniKampane();
    return ulozena;
  }

  @override
  Future<void> smazKampan(String id) async {
    await _simulateLatency();
    _kampane.removeWhere((k) => k.id == id);
    _vinyKampani.remove(id);
    _promitniKampane();
  }

  @override
  Future<PrehledKampaniStari> nactiKampaneStari() async {
    await _simulateLatency();
    return PrehledKampaniStari(
      kampane: [..._kampaneStari],
      muzeUpravovat: true,
    );
  }

  @override
  Future<KampanPodleStari> ulozKampanStari(KampanPodleStari kampan) async {
    await _simulateLatency();
    final ulozena = kampan.copyWith(
      id: kampan.id ?? 'ukazka-s${_kampaneStari.length + 1}',
    );
    final i = _kampaneStari.indexWhere((k) => k.id == ulozena.id);
    if (i == -1) {
      _kampaneStari.add(ulozena);
    } else {
      _kampaneStari[i] = ulozena;
    }
    _promitniKampane();
    return ulozena;
  }

  @override
  Future<ServiceOrderDto?> priradObalku(
    String orderId,
    String kod, {
    bool prepsat = false,
  }) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;
    final jina = orders.indexWhere(
      (o) => o.id != orderId && o.keyEnvelope?['code'] == kod,
    );
    if (jina != -1 && !prepsat) {
      throw ServiceOrderException(
        'Obálka $kod patří zakázce ${orders[jina].id} '
        '(${orders[jina].licensePlate}). Přesunout ji k téhle zakázce?',
        kod: 'envelope_in_use',
      );
    }
    if (jina != -1) orders[jina] = orders[jina].copyWith(vymazatObalku: true);
    return orders[index] = orders[index].copyWith(
      keyEnvelope: {
        'code': kod,
        'branch': kod.substring(1, 4),
        'branchName': pobockyObalek[kod.substring(1, 4)],
        'assignedAt': DateTime.now().toIso8601String().substring(0, 19),
        'assignedBy': 'Ukázkový technik',
      },
    );
  }

  @override
  Future<ServiceOrderDto?> uvolniObalku(String orderId) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;
    return orders[index] = orders[index].copyWith(vymazatObalku: true);
  }

  @override
  Future<NalezenaObalka?> najdiObalku(String kod) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final zakazka = orders
        .where((o) => o.keyEnvelope?['code'] == kod)
        .firstOrNull;
    return NalezenaObalka(
      kod: kod,
      zakazkaId: zakazka?.id,
      spz: zakazka?.licensePlate,
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
  Future<bool> serverBezi() async => true;

  @override
  Future<void> synchronizuj() => _simulateLatency();

  /// Ukázková uloženka - zimní sada ve skladu, u každého vozu stejná.
  @override
  Future<List<UlozenkaPneu>> ulozenkyZakazky(String orderId) async {
    await _simulateLatency();
    return [
      UlozenkaPneu(
        id: 1,
        cislo: 'UBSL006451',
        stav: 'Uložen',
        zimni: true,
        pocet: 4,
        ulozeno: DateTime(2026, 4, 2),
        umisteni: 'Regál B2',
        kola: [
          for (final (pozice, mm) in [
            ('LP', 6.0),
            ('PP', 6.0),
            ('LZ', 4.5),
            ('PZ', 3.5),
          ])
            KoloUlozenky(
              pozice: pozice,
              vyrobce: 'GOODYEAR',
              vzorek: 'UltraGrip Performance 3',
              rozmer: '255/45 R20',
              dezen: mm,
              dot: '2625',
              indexRychlosti: 'V',
              indexNosnosti: 105,
            ),
        ],
      ),
    ];
  }

  /// Ukázková data - bez omezení.
  @override
  Future<MojePrava> mojePrava() async => MojePrava.vse;

  /// Ukázkoví uživatelé - jen v paměti.
  final List<UzivatelSpravy> _uzivatele = [
    const UzivatelSpravy(
      email: 'dilna@renocar.cz',
      jmeno: 'Dílna',
      role: 'admin',
    ),
    const UzivatelSpravy(
      email: 'jan.dvorak@renocar.cz',
      jmeno: 'Jan Dvořák',
      planovac: {'1': 'W', '2': 'R'},
      prava: {'10026': 'W', '16877': 'W', '16015': 'R'},
    ),
    const UzivatelSpravy(
      email: 'petr.kucera@renocar.cz',
      jmeno: 'Petr Kučera',
      prava: {'10026': 'W'},
    ),
  ];

  static const _pobockyPlanu = [
    PobockaPlanu(kod: '1', nazev: 'Brno'),
    PobockaPlanu(kod: '2', nazev: 'Nupaky'),
    PobockaPlanu(kod: '5', nazev: 'Bubeneč'),
  ];

  static const _poradace = [
    PoradacSpravy(kod: '10026', nazev: 'BMW BSL', pobockaNazev: 'Brno'),
    PoradacSpravy(kod: '16877', nazev: 'MOT BSL', pobockaNazev: 'Brno'),
    PoradacSpravy(kod: '16015', nazev: 'BMW CLI', pobockaNazev: 'Čestlice'),
    PoradacSpravy(kod: '16879', nazev: 'BMW CSK', pobockaNazev: 'Česká'),
    PoradacSpravy(kod: '17362', nazev: 'MOT CSK', pobockaNazev: 'Česká'),
    PoradacSpravy(kod: '17350', nazev: 'BMW PBU', pobockaNazev: 'Bubeneč'),
  ];

  @override
  Future<PrehledUzivatelu> nactiUzivatele() async {
    await _simulateLatency();
    return PrehledUzivatelu(
      poradace: _poradace,
      pobockyPlanu: _pobockyPlanu,
      uzivatele: [..._uzivatele],
    );
  }

  @override
  Future<void> ulozUzivatele(
    String email, {
    required String role,
    required Map<String, String?> prava,
    Map<String, String?>? planovac,
  }) async {
    await _simulateLatency();
    final i = _uzivatele.indexWhere((u) => u.email == email);
    final novy = UzivatelSpravy(
      email: email,
      role: role,
      planovac: planovac == null
          ? (i == -1 ? const {} : _uzivatele[i].planovac)
          : {
              for (final MapEntry(:key, :value) in planovac.entries)
                key: ?value,
            },
      prava: {for (final MapEntry(:key, :value) in prava.entries) key: ?value},
    );
    if (i == -1) {
      _uzivatele.add(novy);
    } else {
      _uzivatele[i] = UzivatelSpravy(
        email: email,
        jmeno: _uzivatele[i].jmeno,
        prihlasen: _uzivatele[i].prihlasen,
        role: role,
        planovac: novy.planovac,
        prava: novy.prava,
      );
    }
  }

  /// Příjmy jen v paměti, se stejnými pravidly jako server.
  final PametovyPrijem _prijmy = PametovyPrijem();

  Future<Prijem> _sPrijmem(Prijem Function() akce) async {
    await _simulateLatency();
    try {
      return akce();
    } on StateError catch (chyba) {
      throw ServiceOrderException(chyba.message);
    }
  }

  @override
  Future<Prijem> prijemZakazky(String orderId) =>
      _sPrijmem(() => _prijmy.nacti(orderId));

  @override
  Future<Prijem> zmenPolozku(String orderId, String kod, ZmenaPolozky zmena) =>
      _sPrijmem(() => _prijmy.zmen(orderId, kod, zmena));

  @override
  Future<Prijem> dokonciPrijem(String orderId) =>
      _sPrijmem(() => _prijmy.dokonci(orderId));

  @override
  Future<Prijem> znovuOtevriPrijem(String orderId) =>
      _sPrijmem(() => _prijmy.znovuOtevri(orderId));

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

  /// Ukázková data náhledy nezmenšují - fotky v mocku jsou malé.
  @override
  Future<Uint8List> stahniNahled(String id) => stahniFotku(id);

  @override
  Future<void> smazFotku(String id) async {
    _bajtyFotek.remove(id);
    for (final seznam in _fotky.values) {
      seznam.removeWhere((fotka) => fotka.id == id);
    }
  }

  /// Dokumenty jen v paměti, stejně jako fotky.
  final Map<String, List<Dokument>> _dokumenty = {};
  final Map<String, Uint8List> _bajtyDokumentu = {};

  @override
  Future<List<Dokument>> dokumentyZakazky(String orderId) async {
    await _simulateLatency();
    return List.of(_dokumenty[orderId] ?? const []);
  }

  /// Každá ukázková zakázka má v Heliosu jeden zakázkový list - ať je
  /// karta Dokumenty Helios vidět i bez firemní sítě.
  @override
  Future<List<Dokument>> dokumentyHeliosu(String orderId) async {
    await _simulateLatency();
    final orders = await _ensureLoaded();
    final index = _indexOf(orders, orderId);
    if (index < 0) return const [];
    final prijato = orders[index].receivedAt;
    return [
      Dokument(
        id: _ukazkovyZakazkovyList,
        nazev: 'Zakázkový list $orderId.pdf',
        velikost: null,
        zmenenoAt: prijato == null ? null : DateTime.tryParse(prijato),
        zHeliosu: true,
      ),
    ];
  }

  static const _ukazkovyZakazkovyList = 'helios-ukazka';

  /// Ukázkový protokol - stejné ukázkové PDF jako zakázkový list.
  static const _ukazkovyProtokol = 'protokol-ukazka';

  @override
  Future<Dokument> vytvorProtokol(String orderId) async {
    await _simulateLatency();
    return Dokument(
      id: _ukazkovyProtokol,
      nazev: 'Protokol $orderId.pdf',
      velikost: null,
      zmenenoAt: DateTime.now(),
    );
  }

  @override
  Future<Dokument> nahrajDokument(
    String orderId,
    String nazev,
    Uint8List data, {
    String? pobocka,
  }) async {
    await _simulateLatency();
    final dokument = Dokument(
      id: 'mock-dok-${DateTime.now().microsecondsSinceEpoch}',
      nazev: nazev,
      velikost: data.length,
      zmenenoAt: DateTime.now(),
    );
    _bajtyDokumentu[dokument.id] = data;
    _dokumenty.putIfAbsent(orderId, () => []).insert(0, dokument);
    return dokument;
  }

  @override
  Future<Uint8List> stahniDokument(String orderId, String id) async {
    if (id == _ukazkovyZakazkovyList || id == _ukazkovyProtokol) {
      final data = await _bundle.load('assets/mock/zakazkovy_list_ukazka.pdf');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    final bajty = _bajtyDokumentu[id];
    if (bajty == null) throw StateError('Dokument $id v mocku není.');
    return bajty;
  }
}

/// Řádky plánu ze zakázek v paměti - totéž skládá server.
List<PolozkaPlanu> _polozkyPlanu(
  List<ServiceOrderDto> orders,
  DateTime od,
  DateTime do_,
) {
  return [
    for (final o in orders)
      if (o.canPlanBodyshop ||
          (o.bodyshopPlan != null &&
              PlanKlempirny.fromJson(o.bodyshopPlan!).prekryva(od, do_)))
        PolozkaPlanu(
          zakazkaId: o.id,
          spz: o.licensePlate,
          model: o.model,
          zakaznik: o.customerName,
          pobockaKod: o.branch?['code'] as String?,
          prijato: o.receivedAt == null
              ? null
              : DateTime.tryParse(o.receivedAt!),
          plan: o.bodyshopPlan == null
              ? null
              : PlanKlempirny.fromJson(o.bodyshopPlan!),
          zakazka: o.toDomain(),
        ),
  ];
}

/// Ukázkové barvy BMW a MINI - kód laku z číselníku Heliosu.
const _barvy = <Map<String, dynamic>>[
  {'code': '475', 'name': 'Black Sapphire metalíza'},
  {'code': '300', 'name': 'Alpinweiss III'},
  {'code': 'C4P', 'name': 'Brooklyn Grey metalíza'},
  {'code': '416', 'name': 'Carbon Black metalíza'},
];
