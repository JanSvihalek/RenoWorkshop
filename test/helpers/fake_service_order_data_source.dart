import 'package:renoworkshop/src/features/orders/data/datasources/service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/dilensky_stav.dart';

/// In-memory zdroj dat pro testy - bez assetů a bez latence.
class FakeServiceOrderDataSource implements ServiceOrderDataSource {
  FakeServiceOrderDataSource(List<ServiceOrderDto> orders)
    : _orders = [...orders];

  final List<ServiceOrderDto> _orders;

  int _indexOf(String orderId) =>
      _orders.indexWhere((order) => order.id == orderId);

  @override
  Future<List<ServiceOrderDto>> fetchOrders() async {
    pocetNacteni++;
    return List.of(_orders);
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
  }) async {
    final index = _indexOf(orderId);
    if (index == -1) return null;

    final popis = nazev ?? nabidka.firstWhere((s) => s.kod == kod).nazev;
    final zaznam = {
      'code': kod,
      'label': popis,
      'author': 'Jan Dvořák',
      'createdAt': '2026-08-28T10:00:00',
    };

    return _orders[index] = _orders[index].copyWith(
      status: popis,
      statusCode: kod,
      statusHistory: [zaznam, ..._orders[index].statusHistory],
    );
  }

  /// Nabídka stavů, kterou fake vrací. Stačí pár položek - testy neověřují
  /// číselník, ale to, co se stane po výběru.
  static const nabidka = [
    NabidkaStavu(kod: 'klempirna', nazev: 'Klempířské práce'),
    NabidkaStavu(kod: 'lakovna', nazev: 'Lakovna'),
    NabidkaStavu(kod: 'pripraveno', nazev: 'Připraveno k vyzvednutí'),
  ];

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
