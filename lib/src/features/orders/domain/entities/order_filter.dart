import 'service_order.dart';

/// Řazení seznamu zakázek.
enum OrderSort {
  receivedDate('Datum přijetí'),
  orderNumber('Zakázka'),
  dueDate('Datum ukončení');

  const OrderSort(this.label);

  final String label;
}

/// Kritéria pro seznam zakázek. Filtry se skládají (AND).
///
/// Ve výběru může být víc hodnot: zakázka projde, když sedí na kteroukoli
/// z nich (OR). Prázdný výběr = vše. Stejně jako na webu.
class OrderFilter {
  const OrderFilter({
    this.branchCodes = const {},
    this.departmentCodes = const {},
    this.typZakazkyKody = const {},
    this.poradacKody = const {},
    this.statusCodes = const {},
    this.heliosStavy = const {},
    this.mechanicNames = const {},
    this.zpracovatelIds = const {},
    this.query = '',
    this.sort = OrderSort.receivedDate,
    this.mujEmail,
  });

  /// Kódy poboček. Kód, ne název - názvy se mohou v Heliosu přepsat, kód
  /// drží.
  final Set<String> branchCodes;

  final Set<String> departmentCodes;

  /// Kódy typů zakázky (běžná, interní, klempířská).
  final Set<String> typZakazkyKody;

  /// Čísla pořadačů z Heliosu.
  final Set<String> poradacKody;

  /// Kódy dílenských stavů z číselníku.
  final Set<String> statusCodes;

  /// Stavy z Heliosu tak, jak je zakázka ukazuje („Zpracováváno").
  /// Podle textu, ne čísla: aplikace číslo stavu nedostává.
  final Set<String> heliosStavy;

  final Set<String> mechanicNames;

  /// Id zpracovatelů (zaměstnanec v Heliosu), [nikdo] = zakázky, které
  /// nikdo nezpracovává, [ja] = moje.
  final Set<int> zpracovatelIds;

  /// Hodnota v [zpracovatelIds] pro zakázky bez zpracovatele. Id z Heliosu
  /// jsou kladná, nula se s nimi nepotká.
  static const nikdo = 0;

  /// Hodnota v [zpracovatelIds] pro „Já" - zakázky, které zpracovává
  /// přihlášený ([mujEmail]). Jako volba Já na webu.
  static const ja = -1;

  /// E-mail přihlášeného (malými písmeny) - podle něj se pozná „Já".
  /// Není to filtr, jen údaj k němu.
  final String? mujEmail;

  final String query;
  final OrderSort sort;

  List<Set<Object>> get _vybery => [
    branchCodes,
    departmentCodes,
    typZakazkyKody,
    poradacKody,
    statusCodes,
    heliosStavy,
    mechanicNames,
    zpracovatelIds,
  ];

  bool get isActive =>
      _vybery.any((v) => v.isNotEmpty) || query.trim().isNotEmpty;

  /// Počet aktivních filtrů (pro badge u tlačítka filtru) - výběr se počítá
  /// jednou, ať je v něm hodnot kolik chce.
  int get activeCount =>
      _vybery.where((v) => v.isNotEmpty).length +
      (query.trim().isNotEmpty ? 1 : 0);

  /// Prázdná množina výběr zruší.
  OrderFilter copyWith({
    Set<String>? branchCodes,
    Set<String>? departmentCodes,
    Set<String>? typZakazkyKody,
    Set<String>? poradacKody,
    Set<String>? statusCodes,
    Set<String>? heliosStavy,
    Set<String>? mechanicNames,
    Set<int>? zpracovatelIds,
    String? query,
    OrderSort? sort,
    String? mujEmail,
  }) {
    return OrderFilter(
      branchCodes: branchCodes ?? this.branchCodes,
      departmentCodes: departmentCodes ?? this.departmentCodes,
      typZakazkyKody: typZakazkyKody ?? this.typZakazkyKody,
      poradacKody: poradacKody ?? this.poradacKody,
      statusCodes: statusCodes ?? this.statusCodes,
      heliosStavy: heliosStavy ?? this.heliosStavy,
      mechanicNames: mechanicNames ?? this.mechanicNames,
      zpracovatelIds: zpracovatelIds ?? this.zpracovatelIds,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      mujEmail: mujEmail ?? this.mujEmail,
    );
  }

  /// Aplikuje filtry i řazení. Čistá funkce - snadno testovatelná.
  List<ServiceOrder> apply(List<ServiceOrder> orders) {
    final result = orders.where(matches).toList();
    result.sort(_comparator);
    return result;
  }

  static bool _sedi<T>(Set<T> vyber, T? hodnota) =>
      vyber.isEmpty || vyber.contains(hodnota);

  /// Projde zakázka filtrem? Bez řazení - plán klempírny filtruje své
  /// řádky stejně jako seznam zakázek.
  bool matches(ServiceOrder order) {
    if (!_sedi(branchCodes, order.branch?.code)) return false;
    if (!_sedi(departmentCodes, order.department?.code)) return false;
    if (!_sedi(typZakazkyKody, order.typZakazky?.kod)) return false;
    if (!_sedi(poradacKody, order.poradac?.kod)) return false;
    if (!_sedi(statusCodes, order.stav?.kod)) return false;
    if (!_sedi(heliosStavy, order.heliosStatus)) return false;
    if (!_sedi(mechanicNames, order.mechanicName)) return false;
    if (zpracovatelIds.isNotEmpty &&
        !zpracovatelIds.any(_sediZpracovatel(order))) {
      return false;
    }
    return order.matchesQuery(query);
  }

  bool Function(int id) _sediZpracovatel(ServiceOrder order) => (id) {
    if (id == ja) {
      final email = order.zpracovatel?.email?.trim().toLowerCase();
      return mujEmail != null && email == mujEmail;
    }
    return (order.zpracovatel?.id ?? nikdo) == id;
  };

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
      OrderSort.receivedDate => _porovnejData(b.receivedAt, a.receivedAt),
      // Číslo zakázky roste v čase, takže od nejnovější - stejně jako
      // u data přijetí.
      OrderSort.orderNumber => b.id.compareTo(a.id),
      OrderSort.dueDate => _porovnejData(a.dueAt, b.dueAt),
    };
  }

  static bool _stejne<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderFilter &&
          _stejne(other.branchCodes, branchCodes) &&
          _stejne(other.departmentCodes, departmentCodes) &&
          // Typ tu dřív chyběl - „Zrušit filtry" pak s vybraným typem
          // shodilo i výchozí filtr z nastavení, místo aby se na něj vrátilo.
          _stejne(other.typZakazkyKody, typZakazkyKody) &&
          _stejne(other.poradacKody, poradacKody) &&
          _stejne(other.statusCodes, statusCodes) &&
          _stejne(other.heliosStavy, heliosStavy) &&
          _stejne(other.mechanicNames, mechanicNames) &&
          _stejne(other.zpracovatelIds, zpracovatelIds) &&
          other.query == query &&
          other.sort == sort);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(branchCodes),
    Object.hashAllUnordered(departmentCodes),
    Object.hashAllUnordered(typZakazkyKody),
    Object.hashAllUnordered(poradacKody),
    Object.hashAllUnordered(statusCodes),
    Object.hashAllUnordered(heliosStavy),
    Object.hashAllUnordered(mechanicNames),
    Object.hashAllUnordered(zpracovatelIds),
    query,
    sort,
  );
}
