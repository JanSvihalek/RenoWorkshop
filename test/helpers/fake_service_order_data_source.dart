import 'dart:typed_data';

import 'package:renoworkshop/src/features/akce/data/akce_data_source.dart';
import 'package:renoworkshop/src/features/akce/data/kampane_data_source.dart';
import 'package:renoworkshop/src/features/akce/domain/kampan_podle_stari.dart';
import 'package:renoworkshop/src/features/akce/domain/marketingova_akce.dart';
import 'package:renoworkshop/src/features/akce/domain/technicka_kampan.dart';
import 'package:renoworkshop/src/features/uzivatele/data/uzivatele_data_source.dart';
import 'package:renoworkshop/src/features/uzivatele/domain/uzivatele.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/moje_prava.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/plan_klempirny.dart';
import 'package:renoworkshop/src/features/plan/data/plan_data_source.dart';
import 'package:renoworkshop/src/features/plan/domain/prehled_planu.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/kampan_vozidla.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/obalka_klice.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/repositories/service_order_repository.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/dilensky_stav.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/zavada.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/branch.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/zpracovatel.dart';
import 'package:renoworkshop/src/features/fotodokumentace/data/fotky_data_source.dart';
import 'package:renoworkshop/src/features/fotodokumentace/domain/entities/dokument.dart';
import 'package:renoworkshop/src/features/fotodokumentace/domain/entities/fotka.dart';
import 'package:renoworkshop/src/features/prijem/data/prijem_data_source.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/prijem.dart';
import 'package:renoworkshop/src/features/vozidla/data/vozidla_data_source.dart';
import 'package:renoworkshop/src/features/vozidla/domain/entities/vozidlo.dart';

/// In-memory zdroj dat pro testy - bez assetů a bez latence.
class FakeServiceOrderDataSource
    implements
        ServiceOrderDataSource,
        VozidlaDataSource,
        FotkyDataSource,
        PrijemDataSource,
        AkceDataSource,
        KampaneDataSource,
        PlanDataSource,
        UzivateleDataSource {
  /// [archiv] jsou ukončené zakázky: server je vrátí v hledání a v detailu,
  /// ale v seznamu dílny (`fetchOrders`) nejsou - stejně jako v API.
  FakeServiceOrderDataSource(
    List<ServiceOrderDto> orders, {
    List<ServiceOrderDto> archiv = const [],
    List<KartaVozidla> vozidla = const [],
  }) : _orders = [...orders, ...archiv],
       _archivIds = {for (final dto in archiv) dto.id},
       _vozidla = vozidla;

  final List<ServiceOrderDto> _orders;
  final Set<String> _archivIds;
  final List<KartaVozidla> _vozidla;

  /// Odpověď na dotaz „běží server?" z přihlašovací obrazovky.
  bool serverOdpovida = true;

  @override
  Future<bool> serverBezi() async => serverOdpovida;

  /// Kolikrát se volala synchronizace na vyžádání.
  int pocetSynchronizaci = 0;

  /// Zakázky, které se objeví až po synchronizaci - poradce je v Heliosu
  /// založil před chvílí.
  List<ServiceOrderDto> poSynchronizaci = const [];

  /// Hláška, se kterou synchronizace spadne - třeba minutový limit služby.
  String? chybaSynchronizace;

  /// Práva přihlášeného - test si je nastaví.
  MojePrava prava = MojePrava.vse;

  /// Správa uživatelů - pořadače a uživatelé v paměti.
  List<PoradacSpravy> poradaceSpravy = const [
    PoradacSpravy(kod: '10026', nazev: 'BMW BSL', pobockaNazev: 'Brno'),
    PoradacSpravy(kod: '16877', nazev: 'MOT BSL', pobockaNazev: 'Brno'),
    PoradacSpravy(kod: '16015', nazev: 'BMW CLI', pobockaNazev: 'Čestlice'),
  ];
  List<UzivatelSpravy> uzivatele = [];

  /// Co appka naposledy uložila - kontrola v testu.
  final ulozeniUzivatelu = <(String, String, Map<String, String?>)>[];

  /// Úroveň plánovače u uložení - kontrola v testu.
  final ulozeniPlanovace = <String>[];

  @override
  Future<PrehledUzivatelu> nactiUzivatele() async =>
      PrehledUzivatelu(poradace: poradaceSpravy, uzivatele: [...uzivatele]);

  @override
  Future<void> ulozUzivatele(
    String email, {
    required String role,
    required Map<String, String?> prava,
    String planovac = 'cist',
  }) async {
    ulozeniUzivatelu.add((email, role, prava));
    ulozeniPlanovace.add(planovac);
    final novy = UzivatelSpravy(
      email: email,
      role: role,
      planovac: planovac,
      prava: {for (final MapEntry(:key, :value) in prava.entries) key: ?value},
    );
    final i = uzivatele.indexWhere((u) => u.email == email);
    if (i == -1) {
      uzivatele.add(novy);
    } else {
      uzivatele[i] = novy;
    }
  }

  @override
  Future<MojePrava> mojePrava() async => prava;

  @override
  Future<void> synchronizuj() async {
    final chyba = chybaSynchronizace;
    if (chyba != null) throw ServiceOrderException(chyba);
    pocetSynchronizaci++;
    _orders.addAll(poSynchronizaci);
    poSynchronizaci = const [];
  }

  /// Příjmy v paměti. [ulozeniPrijmuSelze] simuluje výpadek sítě.
  final PametovyPrijem prijmy = PametovyPrijem();
  bool ulozeniPrijmuSelze = false;
  int pocetZmenPrijmu = 0;

  Future<Prijem> _sPrijmem(Prijem Function() akce) async {
    if (ulozeniPrijmuSelze) {
      throw const ServiceOrderException('Server neodpovídá.');
    }
    try {
      return akce();
    } on StateError catch (chyba) {
      throw ServiceOrderException(chyba.message);
    }
  }

  @override
  Future<Prijem> prijemZakazky(String orderId) async => prijmy.nacti(orderId);

  @override
  Future<Prijem> zmenPolozku(String orderId, String kod, ZmenaPolozky zmena) {
    pocetZmenPrijmu++;
    return _sPrijmem(() => prijmy.zmen(orderId, kod, zmena));
  }

  @override
  Future<Prijem> dokonciPrijem(String orderId) =>
      _sPrijmem(() => prijmy.dokonci(orderId));

  @override
  Future<Prijem> znovuOtevriPrijem(String orderId) =>
      _sPrijmem(() => prijmy.znovuOtevri(orderId));

  /// Fotky v paměti. [nahravaniSelze] simuluje výpadek sítě při nahrávání.
  final Map<String, List<Fotka>> fotky = {};
  final Map<String, Uint8List> bajtyFotek = {};
  bool nahravaniSelze = false;

  /// Složky poboček, které „server" nabízí, a pobočka poslední nahrané fotky.
  List<String> pobocky = const ['Brno', 'Cestlice', 'KCP'];
  String? posledniPobocka;

  @override
  Future<List<String>> slozkyPobocek() async => pobocky;

  @override
  Future<List<Fotka>> fotkyZakazky(String orderId) async =>
      List.of(fotky[orderId] ?? const []);

  @override
  Future<Fotka> nahrajFotku(
    String orderId,
    KategorieFotky kategorie,
    Uint8List jpeg, {
    String? pobocka,
  }) async {
    posledniPobocka = pobocka;
    if (nahravaniSelze) {
      throw const ServiceOrderException('Server neodpovídá.');
    }
    final seznam = fotky.putIfAbsent(orderId, () => []);
    final fotka = Fotka(
      id: 'fotka-${bajtyFotek.length + 1}',
      kategorie: kategorie,
      // Teď, ne pevné datum - fotka místa musí vyjít novější než
      // zápis místa u zakázky.
      nahranoAt: DateTime.now(),
      nahralKdo: 'Jan Dvořák',
    );
    bajtyFotek[fotka.id] = jpeg;
    seznam.insert(0, fotka);
    return fotka;
  }

  @override
  Future<Uint8List> stahniFotku(String id) async => bajtyFotek[id]!;

  @override
  Future<void> smazFotku(String id) async {
    bajtyFotek.remove(id);
    for (final seznam in fotky.values) {
      seznam.removeWhere((fotka) => fotka.id == id);
    }
  }

  /// Dokumenty v paměti. [nahravaniDokumentuSelze] simuluje odmítnutí
  /// serverem, [pobockaDokumentu] je pobočka posledního nahrání.
  final Map<String, List<Dokument>> dokumenty = {};
  final Map<String, Uint8List> bajtyDokumentu = {};
  String? nahravaniDokumentuSelze;
  String? pobockaDokumentu;

  @override
  Future<List<Dokument>> dokumentyZakazky(String orderId) async =>
      List.of(dokumenty[orderId] ?? const []);

  @override
  Future<Dokument> nahrajDokument(
    String orderId,
    String nazev,
    Uint8List data, {
    String? pobocka,
  }) async {
    final chyba = nahravaniDokumentuSelze;
    if (chyba != null) throw ServiceOrderException(chyba);
    pobockaDokumentu = pobocka;
    final dokument = Dokument(
      id: 'dok-${bajtyDokumentu.length + 1}',
      nazev: nazev,
      velikost: data.length,
      zmenenoAt: DateTime(2026, 9, 21, 12, 30),
      // Server nahrává do složky kategorie Ostatní.
      slozka: 'Ostatni',
    );
    bajtyDokumentu[dokument.id] = data;
    dokumenty.putIfAbsent(orderId, () => []).insert(0, dokument);
    return dokument;
  }

  @override
  Future<Uint8List> stahniDokument(String orderId, String id) async =>
      bajtyDokumentu[id]!;

  /// Kolikrát se žádalo o protokol.
  int vytvorenychProtokolu = 0;

  /// Hláška, se kterou vytvoření protokolu selže (otevřený soubor...).
  String? protokolSelze;

  @override
  Future<Dokument> vytvorProtokol(String orderId) async {
    final chyba = protokolSelze;
    if (chyba != null) throw ServiceOrderException(chyba);
    vytvorenychProtokolu++;
    final protokol = Dokument(
      id: 'protokol-$orderId',
      nazev: 'Protokol $orderId.pdf',
      velikost: 4,
      zmenenoAt: DateTime(2026, 10, 5, 14, 30),
    );
    bajtyDokumentu[protokol.id] = Uint8List.fromList('%PDF'.codeUnits);
    return protokol;
  }

  /// Dokumenty z EDM Heliosu podle zakázky; bajty v [bajtyDokumentu].
  final Map<String, List<Dokument>> dokumentyHeliosuZakazek = {};

  /// Simuluje nedostupný seznam z Heliosu (nespuštěný skript na serveru).
  String? dokumentyHeliosuSelzou;

  @override
  Future<List<Dokument>> dokumentyHeliosu(String orderId) async {
    final chyba = dokumentyHeliosuSelzou;
    if (chyba != null) throw ServiceOrderException(chyba);
    return List.of(dokumentyHeliosuZakazek[orderId] ?? const []);
  }

  /// Poslední dotaz na vozidla - test pozná, co šlo na server.
  String? posledniHledaniVozidla;

  @override
  Future<List<NalezeneVozidlo>> hledejVozidla(String dotaz) async {
    posledniHledaniVozidla = dotaz;
    String kod(String s) => s.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    final hledane = kod(dotaz);
    return [
      for (final v in _vozidla)
        if (kod(v.spz).contains(hledane) || kod(v.vin).contains(hledane))
          NalezeneVozidlo(
            id: v.id,
            spz: v.spz,
            vin: v.vin,
            model: v.model,
            majitel: v.majitel?.nazev,
            pocetZakazek: v.zakazky.length,
          ),
    ];
  }

  @override
  Future<KartaVozidla?> kartaVozidla(int id) async {
    for (final v in _vozidla) {
      if (v.id == id) return v;
    }
    return null;
  }

  int _indexOf(String orderId) =>
      _orders.indexWhere((order) => order.id == orderId);

  @override
  Future<List<ServiceOrderDto>> fetchOrders() async {
    pocetNacteni++;
    return _orders.where((dto) => !_archivIds.contains(dto.id)).toList();
  }

  /// Kolikrát se seznam načetl - test obnovy podle toho pozná, že se
  /// sáhlo na zdroj dat a nevrátilo se jen to, co je v paměti.
  int pocetNacteni = 0;

  @override
  Future<List<ServiceOrderDto>> searchOrders(String query) async {
    pocetHledani++;
    final hledane = query.trim().toUpperCase().replaceAll(' ', '');
    return _orders.where((dto) {
      final kde = [
        dto.id,
        dto.licensePlate,
        dto.vin,
        dto.customerName,
      ].join(' ').toUpperCase().replaceAll(' ', '');
      return kde.contains(hledane);
    }).toList();
  }

  /// Kolikrát se hledalo v archivu - testy podle toho poznají, že se
  /// dotaz opravdu poslal na server a nefiltrovalo se jen lokálně.
  int pocetHledani = 0;

  @override
  Future<ServiceOrderDto?> fetchOrder(String orderId) async {
    final index = _indexOf(orderId);
    return index == -1 ? null : _orders[index];
  }

  @override
  Future<ServiceOrderDto?> pridejStav(
    String orderId, {
    String? kod,
    String? nazev,
    String? poznamka,
    String? misto,
  }) async {
    posledniMisto = misto;
    final index = _indexOf(orderId);
    if (index == -1) return null;

    final popis = nazev ?? nabidka.firstWhere((s) => s.kod == kod).nazev;
    final zaznam = {
      'id': 'stav-${_orders[index].statusHistory.length + 1}',
      'code': kod,
      'label': popis,
      'note': poznamka,
      'author': 'Jan Dvořák',
      'createdAt': '2026-08-28T10:00:00',
    };

    return _orders[index] = _orders[index].copyWith(
      status: popis,
      statusCode: kod,
      statusHistory: [zaznam, ..._orders[index].statusHistory],
      bay: misto,
      // Server si k místu zapíše čas zápisu - fotka staršího místa
      // se pak u nového místa neukáže.
      bayAt: misto == null ? null : DateTime.now().toIso8601String(),
    );
  }

  /// Místo, které přišlo s posledním zápisem stavu - `null` znamená
  /// „neměnit".
  String? posledniMisto;

  /// Nabídka stavů, kterou fake vrací. Stačí pár položek - testy neověřují
  /// číselník, ale to, co se stane po výběru.
  static const nabidka = [
    NabidkaStavu(kod: 'klempirna', nazev: 'Klempířské práce'),
    NabidkaStavu(kod: 'lakovna', nazev: 'Lakovna'),
    NabidkaStavu(kod: 'pripraveno', nazev: 'Připraveno k vyzvednutí'),
  ];

  @override
  Future<ServiceOrderDto?> ulozPredmetOpravy(
    String orderId,
    String text,
  ) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    final orezany = text.trim();
    return _orders[index] = _orders[index].copyWith(
      repairSubject: orezany.isEmpty ? null : orezany,
      vymazatPredmet: orezany.isEmpty,
    );
  }

  /// Zaměstnanci z Heliosu pro výběr zpracovatele.
  List<ZamestnanecKVyberu> zamestnanci = const [
    ZamestnanecKVyberu(
      id: 501,
      jmeno: 'Dvořák Jan',
      email: 'jan.dvorak@renocar.cz',
      utvar: Department(code: '11211', label: 'Auta Servis'),
    ),
    ZamestnanecKVyberu(
      id: 502,
      jmeno: 'Kříž Martin',
      utvar: Department(code: '11211', label: 'Auta Servis'),
    ),
    ZamestnanecKVyberu(
      id: 601,
      jmeno: 'Novotný Pavel',
      utvar: Department(code: '13211', label: 'Moto Servis'),
    ),
  ];

  /// E-mail přihlášeného, podle kterého server páruje „Převzít".
  String? emailPrihlaseneho = 'jan.dvorak@renocar.cz';

  /// S jakým `vsichni` se naposledy žádalo o nabídku.
  bool? posledniNabidkaVsichni;

  @override
  Future<NabidkaZpracovatelu> nabidkaZpracovatelu(
    String orderId, {
    bool vsichni = false,
  }) async {
    posledniNabidkaVsichni = vsichni;
    final index = _indexOf(orderId);
    final kod = index == -1
        ? null
        : _orders[index].department?['code'] as String?;
    final jenUtvar = !vsichni && kod != null;
    return NabidkaZpracovatelu(
      utvarZakazky: kod == null
          ? null
          : Department(code: kod, label: 'Auta Servis'),
      jenUtvar: jenUtvar,
      lide: [
        for (final z in zamestnanci)
          if (!jenUtvar || z.utvar?.code == kod) z,
      ],
    );
  }

  @override
  Future<ServiceOrderDto?> nastavZpracovatele(
    String orderId,
    int? zamestnanecId,
  ) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    if (zamestnanecId == null) {
      return _orders[index] = _orders[index].copyWith(
        vymazatZpracovatele: true,
      );
    }
    final kdo = zamestnanci.firstWhere((z) => z.id == zamestnanecId);
    return _orders[index] = _orders[index].copyWith(
      assignee: {
        'id': kdo.id,
        'name': kdo.jmeno,
        'email': kdo.email,
        'since': '2026-10-05T09:30:00',
        'assignedBy': 'Test',
      },
    );
  }

  @override
  Future<ServiceOrderDto?> prevezmiZakazku(String orderId) async {
    final email = emailPrihlaseneho;
    final ja = zamestnanci.where((z) => email != null && z.email == email);
    if (ja.isEmpty) {
      throw ServiceOrderException(
        'K e-mailu $email není v Heliosu žádný zaměstnanec. '
        'Vyberte se ze seznamu.',
      );
    }
    return nastavZpracovatele(orderId, ja.first.id);
  }

  /// Marketingové akce a jestli je přihlášený smí zadávat.
  List<MarketingovaAkce> akce = [];
  bool spravceAkci = false;
  var _dalsiAkce = 1;

  @override
  Future<PrehledAkci> nactiAkce() async => PrehledAkci(
    akce: [...akce]..sort((a, b) => a.od.compareTo(b.od)),
    muzeUpravovat: spravceAkci,
  );

  @override
  Future<MarketingovaAkce> ulozAkci(MarketingovaAkce akce) async {
    if (!spravceAkci) {
      throw const ServiceOrderException(
        'Marketingové akce může zadávat jen jejich správce.',
      );
    }
    final id = akce.id;
    if (id == null) {
      final nova = akce.copyWith(id: 'akce-${_dalsiAkce++}');
      this.akce.add(nova);
      return nova;
    }
    this.akce = [
      for (final a in this.akce)
        if (a.id == id) akce else a,
    ];
    return akce;
  }

  @override
  Future<void> smazAkci(String id) async {
    if (!spravceAkci) {
      throw const ServiceOrderException(
        'Marketingové akce může zadávat jen jejich správce.',
      );
    }
    akce.removeWhere((a) => a.id == id);
  }

  /// Technické kampaně a jejich VINy. Zadávat smí [spravceAkci].
  List<TechnickaKampan> kampane = [];
  Map<String, List<String>> vinyKampani = {};
  var _dalsiKampan = 1;

  @override
  Future<PrehledKampani> nactiKampane() async => PrehledKampani(
    kampane: [
      for (final k in kampane)
        k.copyWith(pocetVozidel: vinyKampani[k.id]?.length ?? 0),
    ],
    muzeUpravovat: spravceAkci,
  );

  @override
  Future<List<String>> nactiVinyKampane(String id) async => [
    ...?vinyKampani[id],
  ];

  @override
  Future<TechnickaKampan> ulozKampan(
    TechnickaKampan kampan,
    List<String> viny,
  ) async {
    if (!spravceAkci) {
      throw const ServiceOrderException(
        'Technické kampaně může zadávat jen správce akcí.',
      );
    }
    final ulozena = kampan.copyWith(
      id: kampan.id ?? 'kampan-${_dalsiKampan++}',
      pocetVozidel: viny.length,
    );
    kampane = [
      for (final k in kampane)
        if (k.id != ulozena.id) k,
      ulozena,
    ];
    vinyKampani[ulozena.id!] = [...viny];
    return ulozena;
  }

  @override
  Future<void> smazKampan(String id) async {
    if (!spravceAkci) {
      throw const ServiceOrderException(
        'Technické kampaně může zadávat jen správce akcí.',
      );
    }
    kampane.removeWhere((k) => k.id == id);
    vinyKampani.remove(id);
  }

  /// Kampaně podle stáří vozu a jestli je přihlášený smí upravovat.
  List<KampanPodleStari> kampaneStari = [];
  bool spravceKampaniStari = false;

  @override
  Future<PrehledKampaniStari> nactiKampaneStari() async => PrehledKampaniStari(
    kampane: [...kampaneStari],
    muzeUpravovat: spravceKampaniStari,
  );

  @override
  Future<KampanPodleStari> ulozKampanStari(KampanPodleStari kampan) async {
    if (!spravceKampaniStari) {
      throw const ServiceOrderException(
        'Kampaně podle stáří vozu může upravovat jen jejich správce.',
      );
    }
    final ulozena = kampan.copyWith(
      id: kampan.id ?? 'stari-${kampaneStari.length + 1}',
    );
    kampaneStari = [
      for (final k in kampaneStari)
        if (k.id != ulozena.id) k,
      ulozena,
    ];
    return ulozena;
  }

  /// Kódy obálek, které „v evidenci nejsou" - server na ně vrátí 404.
  Set<String> neznameObalky = {};

  @override
  Future<ServiceOrderDto?> priradObalku(
    String orderId,
    String kod, {
    bool prepsat = false,
  }) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    if (neznameObalky.contains(kod)) {
      throw ServiceOrderException(
        'Obálka $kod v evidenci není.',
        kod: 'unknown_envelope',
      );
    }
    final jina = _orders.indexWhere(
      (o) =>
          o.id != orderId &&
          !_archivIds.contains(o.id) &&
          o.keyEnvelope?['code'] == kod,
    );
    if (jina != -1 && !prepsat) {
      throw ServiceOrderException(
        'Obálka $kod patří zakázce ${_orders[jina].id} '
        '(${_orders[jina].licensePlate}). Přesunout ji k téhle zakázce?',
        kod: 'envelope_in_use',
      );
    }
    if (jina != -1) {
      _orders[jina] = _orders[jina].copyWith(vymazatObalku: true);
    }
    return _orders[index] = _orders[index].copyWith(
      keyEnvelope: {
        'code': kod,
        'branch': kod.substring(1, 4),
        'branchName': pobockyObalek[kod.substring(1, 4)],
        'assignedAt': '2026-10-12T08:15:00',
        'assignedBy': 'Test',
      },
    );
  }

  @override
  Future<ServiceOrderDto?> uvolniObalku(String orderId) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    return _orders[index] = _orders[index].copyWith(vymazatObalku: true);
  }

  /// Zakázka tak, jak ji zdroj právě drží - kontrola, co se zapsalo.
  ServiceOrderDto ulozeneDto(String orderId) => _orders[_indexOf(orderId)];

  /// Pobočky klempíren, které vrací plán.
  List<PobockaPlanu> pobockyPlanu = const [
    PobockaPlanu(kod: '1', nazev: 'Brno'),
    PobockaPlanu(kod: '2', nazev: 'Nupaky'),
    PobockaPlanu(kod: '5', nazev: 'Bubeneč'),
  ];

  /// Období, na které se aplikace naposledy ptala.
  (DateTime, DateTime)? obdobiPlanu;

  @override
  Future<ServiceOrderDto?> ulozPlanKlempirny(
    String orderId,
    PlanKlempirny plan,
  ) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    if (!_orders[index].canPlanBodyshop) {
      throw const ServiceOrderException(
        'Na klempírnu/lakovnu se plánují jen zakázky klempířských útvarů.',
      );
    }
    return _orders[index] = _orders[index].copyWith(
      bodyshopPlan: {...plan.toJson(), 'plannedBy': 'Jan Dvořák'},
    );
  }

  @override
  Future<ServiceOrderDto?> zrusPlanKlempirny(String orderId) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    return _orders[index] = _orders[index].copyWith(vymazatPlan: true);
  }

  @override
  Future<PrehledPlanu> nactiPlan(DateTime od, DateTime do_) async {
    obdobiPlanu = (od, do_);
    return PrehledPlanu(
      pobocky: pobockyPlanu,
      // Jako server: klempířské zakázky s plánem i bez, a zakázky
      // s blokem v období.
      polozky: [
        for (final o in _orders)
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
      ],
    );
  }

  @override
  Future<NalezenaObalka?> najdiObalku(String kod) async {
    if (neznameObalky.contains(kod)) return null;
    final zakazka = _orders
        .where(
          (o) => !_archivIds.contains(o.id) && o.keyEnvelope?['code'] == kod,
        )
        .firstOrNull;
    return NalezenaObalka(
      kod: kod,
      zakazkaId: zakazka?.id,
      spz: zakazka?.licensePlate,
    );
  }

  @override
  Future<ServiceOrderDto?> smazStav(String orderId, String zaznamId) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;

    final zbyle = _orders[index].statusHistory
        .where((zaznam) => zaznam['id'] != zaznamId)
        .toList();

    return _orders[index] = _orders[index].copyWith(
      status: zbyle.isEmpty ? null : zbyle.first['label'] as String?,
      statusCode: zbyle.isEmpty ? null : zbyle.first['code'] as String?,
      statusHistory: zbyle,
      vymazatStav: zbyle.isEmpty,
    );
  }

  @override
  Future<List<NabidkaStavu>> nabidkaStavu() async => nabidka;

  @override
  Future<ServiceOrderDto?> addNote({
    required String orderId,
    required String text,
    required String author,
  }) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    final note = OrderNoteDto(
      id: 'N-test-${_orders[index].notes.length + 1}',
      text: text,
      author: author,
      createdAt: DateTime(2026, 8, 25, 12).toIso8601String(),
    );
    return _orders[index] = _orders[index].copyWith(
      notes: [note, ..._orders[index].notes],
    );
  }

  @override
  Future<ServiceOrderDto?> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  }) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;
    return _orders[index] = _orders[index].copyWith(
      workItems: _orders[index].workItems
          .map(
            (item) =>
                item.id == workItemId ? item.copyWith(isDone: isDone) : item,
          )
          .toList(),
    );
  }
}

/// Testovací zakázka s rozumnými výchozími hodnotami.
ServiceOrderDto buildOrderDto({
  String id = 'ZK-26-0001',
  String licensePlate = '1AA 1111',
  String model = 'BMW 320d',
  String customerName = 'Petr Novák',
  String status = 'Klempířské práce',
  String? statusCode = 'klempirna',
  String? heliosStatus = 'Zpracováváno',
  String utvar = '11211',
  String receivedAt = '2026-08-20T08:00:00',
  String dueAt = '2026-08-26T15:00:00',
  String? mechanicName = 'Jan Dvořák',
  List<WorkItemDto> workItems = const [],
  List<OrderNoteDto> notes = const [],
  List<Zavada> defects = const [],
  Map<String, dynamic>? insurer,
  Map<String, dynamic>? assignee,
  String? insuranceClaimNumber,
  Map<String, dynamic>? folder,
  Map<String, dynamic>? keyEnvelope,
  String? keyEnvelopeBranch,
  List<KampanVozidla> technicalCampaigns = const [],
  String? firstRegisteredAt,
  List<KampanVozidla> ageCampaigns = const [],
  Map<String, dynamic>? bodyshopPlan,
  bool canPlanBodyshop = false,
  Map<String, dynamic>? vehicleColor,
}) {
  return ServiceOrderDto(
    id: id,
    licensePlate: licensePlate,
    model: model,
    customerName: customerName,
    status: status,
    statusCode: statusCode,
    heliosStatus: heliosStatus,
    statusHistory: [
      {
        'id': 'stav-1',
        'code': statusCode,
        'label': status,
        'author': 'Jan Dvořák',
        'createdAt': '2026-08-20T09:00:00',
      },
    ],
    branch: {'code': utvar[1], 'label': _pobocka(utvar)},
    department: {'code': utvar, 'label': 'Útvar $utvar'},
    receivedAt: receivedAt,
    dueAt: dueAt,
    vin: 'WBATEST0000000001',
    mechanicName: mechanicName,
    serviceAdvisorName: 'Martina Horáková',
    bay: 'Stání 1',
    notes: notes,
    workItems: workItems,
    defects: defects,
    insurer: insurer,
    assignee: assignee,
    keyEnvelope: keyEnvelope,
    keyEnvelopeBranch: keyEnvelopeBranch,
    technicalCampaigns: technicalCampaigns,
    firstRegisteredAt: firstRegisteredAt,
    ageCampaigns: ageCampaigns,
    bodyshopPlan: bodyshopPlan,
    canPlanBodyshop: canPlanBodyshop,
    vehicleColor: vehicleColor,
    insuranceClaimNumber: insuranceClaimNumber,
    folder: folder,
  );
}

/// Název pobočky podle druhé číslice útvaru - stejné pravidlo, jaké
/// v provozu uplatňuje API.
String _pobocka(String utvar) =>
    const {
      '1': 'Brno',
      '2': 'Čestlice',
      '3': 'Kongresové Centrum',
      '4': 'Česká',
      '5': 'Bubeneč',
    }[utvar[1]] ??
    'Neurčeno';
