import 'service_order.dart';

/// Řazení seznamu zakázek.
enum OrderSort {
  dueDate('Termín dokončení'),
  receivedDate('Datum přijetí'),
  status('Stav zakázky'),
  licensePlate('SPZ');

  const OrderSort(this.label);

  final String label;
}

/// Kritéria pro seznam zakázek. Filtry se skládají (AND).
///
/// Zatím se vyhodnocují v paměti nad daty z repository. Až přijde REST API,
/// pošle se stejný objekt jako query parametry - UI se měnit nemusí.
class OrderFilter {
  const OrderFilter({
    this.branchCode,
    this.departmentCode,
    this.typZakazkyKod,
    this.poradacKod,
    this.statusCode,
    this.heliosStav,
    this.mechanicName,
    this.query = '',
    this.sort = OrderSort.receivedDate,
  });

  /// `null` = všechny pobočky. Kód pobočky, ne název - názvy se mohou
  /// v Heliosu přepsat, kód drží.
  final String? branchCode;

  /// `null` = všechny útvary.
  final String? departmentCode;

  /// Kód typu zakázky (běžná, interní, klempířská). `null` = všechny.
  final String? typZakazkyKod;

  /// Číslo pořadače z Heliosu. `null` = všechny.
  final String? poradacKod;

  /// Kód dílenského stavu z číselníku. `null` = všechny stavy.
  final String? statusCode;

  /// Stav z Heliosu tak, jak ho zakázka ukazuje („Zpracováváno").
  /// Podle textu, ne čísla: aplikace číslo stavu nedostává. `null` = všechny.
  final String? heliosStav;

  /// `null` = všichni mechanici.
  final String? mechanicName;

  final String query;
  final OrderSort sort;

  bool get isActive =>
      branchCode != null ||
      departmentCode != null ||
      typZakazkyKod != null ||
      poradacKod != null ||
      statusCode != null ||
      heliosStav != null ||
      mechanicName != null ||
      query.trim().isNotEmpty;

  /// Počet aktivních filtrů (pro badge u tlačítka filtru).
  int get activeCount => [
    branchCode != null,
    departmentCode != null,
    typZakazkyKod != null,
    poradacKod != null,
    statusCode != null,
    heliosStav != null,
    mechanicName != null,
    query.trim().isNotEmpty,
  ].where((active) => active).length;

  OrderFilter copyWith({
    String? branchCode,
    String? departmentCode,
    String? typZakazkyKod,
    String? poradacKod,
    String? statusCode,
    String? heliosStav,
    String? mechanicName,
    String? query,
    OrderSort? sort,
    bool clearBranch = false,
    bool clearDepartment = false,
    bool clearTypZakazky = false,
    bool clearPoradac = false,
    bool clearStatus = false,
    bool clearHeliosStav = false,
    bool clearMechanic = false,
  }) {
    return OrderFilter(
      branchCode: clearBranch ? null : (branchCode ?? this.branchCode),
      departmentCode: clearDepartment
          ? null
          : (departmentCode ?? this.departmentCode),
      typZakazkyKod: clearTypZakazky
          ? null
          : (typZakazkyKod ?? this.typZakazkyKod),
      poradacKod: clearPoradac ? null : (poradacKod ?? this.poradacKod),
      statusCode: clearStatus ? null : (statusCode ?? this.statusCode),
      heliosStav: clearHeliosStav ? null : (heliosStav ?? this.heliosStav),
      mechanicName: clearMechanic ? null : (mechanicName ?? this.mechanicName),
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }

  /// Aplikuje filtry i řazení. Čistá funkce - snadno testovatelná.
  List<ServiceOrder> apply(List<ServiceOrder> orders) {
    final result = orders.where((order) {
      if (branchCode != null && order.branch?.code != branchCode) return false;
      if (departmentCode != null && order.department?.code != departmentCode) {
        return false;
      }
      if (typZakazkyKod != null && order.typZakazky?.kod != typZakazkyKod) {
        return false;
      }
      if (poradacKod != null && order.poradac?.kod != poradacKod) return false;
      if (statusCode != null && order.stav?.kod != statusCode) return false;
      if (heliosStav != null && order.heliosStatus != heliosStav) return false;
      if (mechanicName != null && order.mechanicName != mechanicName) {
        return false;
      }
      return order.matchesQuery(query);
    }).toList();

    result.sort(_comparator);
    return result;
  }

  /// Zakázky bez data patří na konec seznamu, ať se řadí podle čehokoli.
  /// Chybějící termín neznamená „nejdřív" ani „nejpozději", jen se neví -
  /// a rozdělaná práce se známým termínem má být vidět dřív.
  static int _porovnejData(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int _comparator(ServiceOrder a, ServiceOrder b) {
    return switch (sort) {
      OrderSort.dueDate => _porovnejData(a.dueAt, b.dueAt),
      OrderSort.receivedDate => _porovnejData(b.receivedAt, a.receivedAt),
      // Podle stavu se řadí abecedně: pořadí z číselníku appka nezná
      // a odhadovat sled prací z názvu by bylo horší než nic.
      OrderSort.status => (a.stav?.nazev ?? '').compareTo(b.stav?.nazev ?? ''),
      OrderSort.licensePlate => a.licensePlate.compareTo(b.licensePlate),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderFilter &&
          other.branchCode == branchCode &&
          other.departmentCode == departmentCode &&
          // Typ tu dřív chyběl - „Zrušit filtry" pak s vybraným typem
          // shodilo i výchozí filtr z nastavení, místo aby se na něj vrátilo.
          other.typZakazkyKod == typZakazkyKod &&
          other.poradacKod == poradacKod &&
          other.statusCode == statusCode &&
          other.heliosStav == heliosStav &&
          other.mechanicName == mechanicName &&
          other.query == query &&
          other.sort == sort);

  @override
  int get hashCode => Object.hash(
    branchCode,
    departmentCode,
    typZakazkyKod,
    poradacKod,
    statusCode,
    heliosStav,
    mechanicName,
    query,
    sort,
  );
}
