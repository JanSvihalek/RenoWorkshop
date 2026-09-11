import 'branch.dart';
import 'dilensky_stav.dart';
import 'order_note.dart';
import 'typ_zakazky.dart';
import 'work_item.dart';

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
    this.stav,
    this.historieStavu = const [],
    this.heliosStatus,
    this.branch,
    this.department,
    this.typZakazky,
    this.receivedAt,
    this.dueAt,
    required this.vin,
    this.mechanicName,
    this.serviceAdvisorName,
    this.bay,
    this.notes = const [],
    this.workItems = const [],
  });

  /// Číslo zakázky, např. "ZK-26-0418".
  final String id;
  final String licensePlate;
  final String model;
  final String customerName;

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

  /// Kdy vozidlo přijelo na příjem.
  final DateTime? receivedAt;

  /// Předpokládaný termín dokončení.
  final DateTime? dueAt;
  final String vin;

  /// Přiřazený mechanik. `null` = zakázka zatím nikomu nepřiřazena.
  final String? mechanicName;

  /// Servisní poradce, který zakázku vede.
  final String? serviceAdvisorName;

  /// Stání / box na dílně, např. "Stání 4".
  final String? bay;

  final List<OrderNote> notes;
  final List<WorkItem> workItems;

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

  /// Fulltext přes SPZ, zákazníka, číslo zakázky a model.
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
    ].join(' ').toLowerCase();
    return haystack.contains(needle);
  }

  ServiceOrder copyWith({
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
      stav: stav ?? this.stav,
      historieStavu: historieStavu ?? this.historieStavu,
      heliosStatus: heliosStatus,
      branch: branch,
      department: department,
      typZakazky: typZakazky,
      receivedAt: receivedAt,
      dueAt: dueAt,
      vin: vin,
      mechanicName: mechanicName ?? this.mechanicName,
      serviceAdvisorName: serviceAdvisorName,
      bay: bay ?? this.bay,
      notes: notes ?? this.notes,
      workItems: workItems ?? this.workItems,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceOrder &&
          other.id == id &&
          other.stav == stav &&
          other.notes.length == notes.length &&
          other.workItems == workItems);

  @override
  int get hashCode => Object.hash(id, stav, notes.length, workItems.length);
}
