import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/repositories/service_order_repository.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../../vozidla/data/vozidla_data_source.dart';
import '../../../vozidla/domain/entities/vozidlo.dart';
import '../dtos/service_order_dto.dart';
import 'service_order_data_source.dart';

/// Zdroj dat nad REST API RenoWorkshopu (služba na RENDCAPP).
///
/// API stojí mezi appkou a Heliosem: samo si drží projekci zakázek
/// z DMS a k tomu dílenský stav, který v Heliosu není. Appka tedy nikdy
/// nemluví s databází DMS přímo.
///
/// Autorizace: Firebase ID token v hlavičce `Authorization`. Token dodává
/// [tokenProvider], aby datová vrstva nezávisela na Firebase a šla testovat.
class RestServiceOrderDataSource
    implements ServiceOrderDataSource, VozidlaDataSource {
  RestServiceOrderDataSource({
    required Uri baseUrl,
    required Future<String?> Function() tokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _baseUrl = baseUrl,
       _tokenProvider = tokenProvider,
       _client = client ?? http.Client();

  final Uri _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final http.Client _client;

  /// Dílenská wi-fi bývá vrtkavá - radši chybu než nekonečné čekání.
  final Duration timeout;

  @override
  Future<List<ServiceOrderDto>> fetchOrders() async {
    final data = await _send('GET', 'orders');
    if (data is! List) {
      throw const ServiceOrderException('Server vrátil neočekávaná data.');
    }
    return data
        .map((item) => ServiceOrderDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ServiceOrderDto?> fetchOrder(String orderId) async {
    final data = await _send('GET', 'orders/${Uri.encodeComponent(orderId)}');
    return data == null ? null : ServiceOrderDto.fromJson(_asMap(data));
  }

  @override
  Future<List<ServiceOrderDto>> searchOrders(String query) async {
    final data = await _send(
      'GET',
      'orders/search?q=${Uri.encodeQueryComponent(query)}',
    );
    if (data is! List) {
      throw const ServiceOrderException('Server vrátil neočekávaná data.');
    }
    return data
        .map((item) => ServiceOrderDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ServiceOrderDto?> pridejStav(
    String orderId, {
    String? kod,
    String? nazev,
    String? poznamka,
  }) async {
    final data = await _send(
      'POST',
      'orders/${Uri.encodeComponent(orderId)}/stavy',
      body: {'code': ?kod, 'label': ?nazev, 'note': ?poznamka},
    );
    return data == null ? null : ServiceOrderDto.fromJson(_asMap(data));
  }

  @override
  Future<ServiceOrderDto?> smazStav(String orderId, String zaznamId) async {
    final data = await _send(
      'DELETE',
      'orders/${Uri.encodeComponent(orderId)}'
          '/stavy/${Uri.encodeComponent(zaznamId)}',
    );
    return data == null ? null : ServiceOrderDto.fromJson(_asMap(data));
  }

  @override
  Future<List<NabidkaStavu>> nabidkaStavu() async {
    final data = await _send('GET', 'stavy');
    if (data is! List) return const [];
    return data
        .map((item) => NabidkaStavu.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ServiceOrderDto?> addNote({
    required String orderId,
    required String text,
    required String author,
  }) async {
    final data = await _send(
      'POST',
      'orders/${Uri.encodeComponent(orderId)}/notes',
      body: {'text': text, 'author': author},
    );
    return data == null ? null : ServiceOrderDto.fromJson(_asMap(data));
  }

  @override
  Future<ServiceOrderDto?> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  }) async {
    final data = await _send(
      'PATCH',
      'orders/${Uri.encodeComponent(orderId)}'
          '/work-items/${Uri.encodeComponent(workItemId)}',
      body: {'isDone': isDone},
    );
    return data == null ? null : ServiceOrderDto.fromJson(_asMap(data));
  }

  @override
  Future<List<NalezeneVozidlo>> hledejVozidla(String dotaz) async {
    final data = await _send(
      'GET',
      'vehicles/search?q=${Uri.encodeQueryComponent(dotaz)}',
    );
    if (data is! List) {
      throw const ServiceOrderException('Server vrátil neočekávaná data.');
    }
    return data
        .map((item) => VozidlaJson.nalezene(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<KartaVozidla?> kartaVozidla(int id) async {
    final data = await _send('GET', 'vehicles/$id');
    return data == null ? null : VozidlaJson.karta(_asMap(data));
  }

  /// Jedno místo pro sestavení požadavku, autorizaci a překlad chyb.
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _baseUrl.resolve(path))
      ..headers['Accept'] = 'application/json';

    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response odpoved;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      odpoved = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ServiceOrderException(
        'Server neodpovídá. Zkuste to znovu, až budete v dosahu sítě.',
      );
    } on http.ClientException catch (chyba) {
      throw ServiceOrderException(
        'Nepodařilo se spojit se serverem: ${chyba.message}',
      );
    }

    return _zpracuj(odpoved, path);
  }

  Object? _zpracuj(http.Response odpoved, String path) {
    final kod = odpoved.statusCode;

    if (kod == 404) {
      // Volající rozliší chybějící zakázku nebo vozidlo podle null.
      if (path.startsWith('orders/') || path.startsWith('vehicles/')) {
        return null;
      }
      throw const ServiceOrderException('Požadovaný zdroj nebyl nalezen.');
    }
    if (kod == 401 || kod == 403) {
      throw const ServiceOrderException(
        'Přihlášení vypršelo. Přihlaste se prosím znovu.',
      );
    }
    if (kod >= 500) {
      throw const ServiceOrderException(
        'Server hlásí chybu. Zkuste to za chvíli znovu.',
      );
    }
    if (kod < 200 || kod >= 300) {
      throw ServiceOrderException(
        _chybaZTela(odpoved) ?? 'Chyba serveru ($kod).',
      );
    }
    if (odpoved.bodyBytes.isEmpty) return null;

    try {
      return jsonDecode(utf8.decode(odpoved.bodyBytes));
    } on FormatException {
      throw const ServiceOrderException('Server vrátil poškozenou odpověď.');
    }
  }

  /// API vrací chyby jako `{"error": {"message": "..."}}`.
  String? _chybaZTela(http.Response odpoved) {
    try {
      final telo = jsonDecode(utf8.decode(odpoved.bodyBytes));
      if (telo is Map && telo['error'] is Map) {
        final zprava = (telo['error'] as Map)['message'];
        if (zprava is String && zprava.isNotEmpty) return zprava;
      }
    } on FormatException {
      // Chyba bez JSON těla - použije se obecná hláška.
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object data) {
    if (data is Map<String, dynamic>) return data;
    throw const ServiceOrderException('Server vrátil neočekávaná data.');
  }

  void dispose() => _client.close();
}
