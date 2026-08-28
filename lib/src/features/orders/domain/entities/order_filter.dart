import 'order_status.dart';
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
    this.status,
    this.mechanicName,
    this.query = '',
    this.sort = OrderSort.dueDate,
    this.includeClosed = true,
  });

  /// `null` = všechny pobočky. Kód pobočky, ne název - názvy se mohou
  /// v Heliosu přepsat, kód drží.
  final String? branchCode;

  /// `null` = všechny útvary.
  final String? departmentCode;

  /// Kód typu zakázky (běžná, interní, klempířská). `null` = všechny.
  final String? typZakazkyKod;

  /// `null` = všechny stavy.
  final OrderStatus? status;

  /// `null` = všichni mechanici.
  final String? mechanicName;

  final String query;
  final OrderSort sort;

  /// `false` skryje vyzvednuté zakázky (zavřené).
  final bool includeClosed;

  bool get isActive =>
      branchCode != null ||
      departmentCode != null ||
      typZakazkyKod != null ||
      status != null ||
      mechanicName != null ||
      query.trim().isNotEmpty ||
      !includeClosed;

  /// Počet aktivních filtrů (pro badge u tlačítka filtru).
  int get activeCount => [
    branchCode != null,
    departmentCode != null,
    typZakazkyKod != null,
    status != null,
    mechanicName != null,
    query.trim().isNotEmpty,
    !includeClosed,
  ].where((active) => active).length;

  OrderFilter copyWith({
    String? branchCode,
    String? departmentCode,
    String? typZakazkyKod,
    OrderStatus? status,
    String? mechanicName,
    String? query,
    OrderSort? sort,
    bool? includeClosed,
    bool clearBranch = false,
    bool clearDepartment = false,
    bool clearTypZakazky = false,
    bool clearStatus = false,
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
      status: clearStatus ? null : (status ?? this.status),
      mechanicName: clearMechanic ? null : (mechanicName ?? this.mechanicName),
      query: query ?? this.query,
      sort: sort ?? this.sort,
      includeClosed: includeClosed ?? this.includeClosed,
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
      if (status != null && order.status != status) return false;
      if (mechanicName != null && order.mechanicName != mechanicName) {
        return false;
      }
      if (!includeClosed && order.status.isClosed) return false;
      return order.matchesQuery(query);
    }).toList();

    result.sort(_comparator);
    return result;
  }

  int _comparator(ServiceOrder a, ServiceOrder b) {
    return switch (sort) {
      OrderSort.dueDate => a.dueAt.compareTo(b.dueAt),
      OrderSort.receivedDate => b.receivedAt.compareTo(a.receivedAt),
      OrderSort.status => a.status.step.compareTo(b.status.step),
      OrderSort.licensePlate => a.licensePlate.compareTo(b.licensePlate),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderFilter &&
          other.branchCode == branchCode &&
          other.departmentCode == departmentCode &&
          other.status == status &&
          other.mechanicName == mechanicName &&
          other.query == query &&
          other.sort == sort &&
          other.includeClosed == includeClosed);

  @override
  int get hashCode => Object.hash(
    branchCode,
    departmentCode,
    status,
    mechanicName,
    query,
    sort,
    includeClosed,
  );
}
