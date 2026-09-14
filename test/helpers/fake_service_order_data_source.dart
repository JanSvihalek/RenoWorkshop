import 'package:renoworkshop/src/features/orders/data/datasources/service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/dilensky_stav.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/zavada.dart';
import 'package:renoworkshop/src/features/vozidla/data/vozidla_data_source.dart';
import 'package:renoworkshop/src/features/vozidla/domain/entities/vozidlo.dart';

/// In-memory zdroj dat pro testy - bez assetů a bez latence.
class FakeServiceOrderDataSource
    implements ServiceOrderDataSource, VozidlaDataSource {
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
  }) async {
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
