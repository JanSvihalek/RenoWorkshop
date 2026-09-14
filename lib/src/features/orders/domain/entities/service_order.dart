import 'branch.dart';
import 'dilensky_stav.dart';
import 'order_note.dart';
import 'poradac.dart';
import 'typ_zakazky.dart';
import 'work_item.dart';
import 'zavada.dart';

/// Servisní zakázka na dílně - hlavní entita fáze 1.
///
/// Čistý Dart bez závislosti na Flutteru ani na formátu API. Mapování z/na
/// JSON řeší `ServiceOrderDto` v datové vrstvě.
class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.licensePlate,
    required this.model,
    required this.customerName,
    this.predmetOpravy,
    this.pojistovna,
    this.cisloPojistneUdalosti,
    this.stav,
    this.historieStavu = const [],
    this.heliosStatus,
    this.branch,
    this.department,
    this.typZakazky,
    this.poradac,
    this.receivedAt,
    this.dueAt,
    required this.vin,
    this.mechanicName,
    this.serviceAdvisorName,
    this.bay,
    this.notes = const [],
    this.workItems = const [],
    this.zavady = const [],
  });

  /// Číslo zakázky, např. "ZK-26-0418".
  final String id;
  final String licensePlate;
  final String model;
  final String customerName;

  /// Co se na voze opravuje. Zapisuje dílna ručně (dřív do Excelu),
  /// Helios to nezná. `null` = zatím nezadáno.
  final String? predmetOpravy;

  /// Název pojišťovny u pojistné události (z Heliosu). `null` = zakázka
  /// pojistnou událostí není.
  final String? pojistovna;

  /// Číslo pojistné události, jak ho vede Helios. Podle něj se dílna
  /// s pojišťovnou dorozumívá. `null` = nezadáno.
  final String? cisloPojistneUdalosti;

  /// Pojišťovna a číslo události na jeden řádek - „Kooperativa · PU 42012".
  /// `null`, když zakázka nemá ani jedno.
  String? get pojisteniPopisek {
    final casti = [
      ?pojistovna,
      if (cisloPojistneUdalosti case final cislo?) 'PU $cislo',
    ];
    return casti.isEmpty ? null : casti.join(' · ');
  }

  /// Aktuální dílenský stav = poslední záznam v historii. `null` u zakázky,
  /// které stav ještě nikdo nedal - z Heliosu se neodvozuje.
  final DilenskyStav? stav;

  /// Historie dílenských stavů, nejnovější první. U opravy, která běží
  /// měsíce, je to hlavní přehled o tom, co se dělo.
  final List<DilenskyStav> historieStavu;

  /// Stav z Heliosu. Vede ho ERP a aplikace ho nemění - je to druhý,
  /// nezávislý pohled na tutéž zakázku.
  final String? heliosStatus;

  /// Pobočka odvozená z útvaru. `null` = útvar chybí nebo se nedal zařadit.
  final Branch? branch;

  /// Útvar z Heliosu. `null` u zakázky bez vyplněného zpracovatele.
  final Department? department;

  /// Typ zakázky - běžná, interní, klempířská. `null`, dokud ho pohled
  /// nad Heliosem nedotahuje nebo když ho zakázka nemá vyplněný.
  final TypZakazky? typZakazky;

  /// Pořadač v Heliosu (značka a pobočka zpracování). `null` = neznámý.
  final Poradac? poradac;

  /// Kdy vozidlo přijelo na příjem.
  final DateTime? receivedAt;

  /// Předpokládaný termín dokončení.
  final DateTime? dueAt;
  final String vin;

  /// Kdo za zakázku zodpovídá. Vede to Helios, aplikace to nemění.
  /// `null` = v Heliosu není vyplněno.
  final String? mechanicName;

  /// Servisní poradce, který zakázku vede.
  final String? serviceAdvisorName;

  /// Stání / box na dílně, např. "Stání 4".
  final String? bay;

  final List<OrderNote> notes;
  final List<WorkItem> workItems;

  /// Závady z Heliosu, v pořadí, v jakém je poradce zapsal. Jen ke čtení.
  final List<Zavada> zavady;

  /// Zakázka je po termínu.
  ///
  /// Neváže se na dílenský stav: ten je nově volný text z číselníku, takže
  /// z něj nejde poznat, že je hotovo. Hotová zakázka ze seznamu stejně
  /// zmizí sama, jakmile ji Helios uzavře.
  bool isOverdue({DateTime? now}) {
    // Bez termínu není co hlídat - zakázka není po termínu, jen ho nemá.
    final termin = dueAt;
    if (termin == null) return false;
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final due = DateTime(termin.year, termin.month, termin.day);
    return due.isBefore(today);
  }

  /// Jméno mechanika pro UI, včetně stavu bez přiřazení.
  String get mechanicLabel => mechanicName ?? 'Nepřiřazeno';

  /// Popisek role u jména - v Heliosu je to „zodpovídá", ne mechanik,
  /// který na voze zrovna dělá.
  static const String rolePopisek = 'Zodpovídá';

  /// Iniciály do avataru; "?" u nepřiřazené zakázky.
  String get mechanicInitials {
    final name = mechanicName;
    if (name == null || name.trim().isEmpty) return '?';
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2)
        .join();
  }

  String get bayLabel => bay ?? '-';

  /// Název pobočky pro UI, včetně zakázek, které ji nemají.
  String get branchLabel => branch?.label ?? 'Bez pobočky';

  /// Útvar se v appce ukazuje **kódem** (`11211`), ne názvem z Heliosu.
  /// Na dílně se s kódy pracuje běžně, jsou krátké a jednoznačné, kdežto
  /// názvy typu `RAS BSL AFS auta Servis` se do řádku nevejdou. Název
  /// z API dál chodí, jen se nezobrazuje.
  String get departmentLabel => department?.code ?? 'Bez útvaru';

  /// Fulltext přes SPZ, zákazníka, číslo zakázky, model, předmět opravy,
  /// pojišťovnu a číslo pojistné události.
  bool matchesQuery(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final haystack = [
      licensePlate,
      customerName,
      id,
      model,
      mechanicName ?? '',
      vin,
      predmetOpravy ?? '',
      pojistovna ?? '',
      cisloPojistneUdalosti ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(needle);
  }

  ServiceOrder copyWith({
    String? predmetOpravy,
    DilenskyStav? stav,
    List<DilenskyStav>? historieStavu,
    String? mechanicName,
    String? bay,
    List<OrderNote>? notes,
    List<WorkItem>? workItems,
  }) {
    return ServiceOrder(
      id: id,
      licensePlate: licensePlate,
      model: model,
      customerName: customerName,
      predmetOpravy: predmetOpravy ?? this.predmetOpravy,
      pojistovna: pojistovna,
      cisloPojistneUdalosti: cisloPojistneUdalosti,
      stav: stav ?? this.stav,
      historieStavu: historieStavu ?? this.historieStavu,
      heliosStatus: heliosStatus,
      branch: branch,
      department: department,
      typZakazky: typZakazky,
      poradac: poradac,
      receivedAt: receivedAt,
      dueAt: dueAt,
      vin: vin,
      mechanicName: mechanicName ?? this.mechanicName,
      serviceAdvisorName: serviceAdvisorName,
      bay: bay ?? this.bay,
      notes: notes ?? this.notes,
      workItems: workItems ?? this.workItems,
      zavady: zavady,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceOrder &&
          other.id == id &&
          // Předmět opravy je obsah zakázky jako stav - dvě verze lišící se
          // jen v něm nejsou tatáž zakázka.
          other.predmetOpravy == predmetOpravy &&
          other.stav == stav &&
          other.notes.length == notes.length &&
          other.workItems == workItems);

  @override
  int get hashCode =>
      Object.hash(id, predmetOpravy, stav, notes.length, workItems.length);
}
