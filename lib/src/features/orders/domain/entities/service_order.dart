import 'branch.dart';
import 'order_note.dart';
import 'order_status.dart';
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
    required this.status,
    this.branch,
    this.department,
    this.typZakazky,
    required this.receivedAt,
    required this.dueAt,
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
  final OrderStatus status;

  /// Pobočka odvozená z útvaru. `null` = útvar chybí nebo se nedal zařadit.
  final Branch? branch;

  /// Útvar z Heliosu. `null` u zakázky bez vyplněného zpracovatele.
  final Department? department;

  /// Typ zakázky - běžná, interní, klempířská. `null`, dokud ho pohled
  /// nad Heliosem nedotahuje nebo když ho zakázka nemá vyplněný.
  final TypZakazky? typZakazky;

  /// Kdy vozidlo přijelo na příjem.
  final DateTime receivedAt;

  /// Předpokládaný termín dokončení.
  final DateTime dueAt;
  final String vin;

  /// Přiřazený mechanik. `null` = zakázka zatím nikomu nepřiřazena.
  final String? mechanicName;

  /// Servisní poradce, který zakázku vede.
  final String? serviceAdvisorName;

  /// Stání / box na dílně, např. "Stání 4".
  final String? bay;

  final List<OrderNote> notes;
  final List<WorkItem> workItems;

  /// Zakázka je po termínu (a ještě není hotová).
  bool isOverdue({DateTime? now}) {
    if (status.isFinished) return false;
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
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

  String get departmentLabel => department?.label ?? 'Bez útvaru';

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
    OrderStatus? status,
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
      status: status ?? this.status,
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
          other.status == status &&
          other.notes.length == notes.length &&
          other.workItems == workItems);

  @override
  int get hashCode => Object.hash(id, status, notes.length, workItems.length);
}
