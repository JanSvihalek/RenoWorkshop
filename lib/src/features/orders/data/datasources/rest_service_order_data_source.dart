import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../core/log/log_udalosti.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../../fotodokumentace/data/fotky_data_source.dart';
import '../../../fotodokumentace/domain/entities/dokument.dart';
import '../../../fotodokumentace/domain/entities/fotka.dart';
import '../../../prijem/data/prijem_data_source.dart';
import '../../../prijem/domain/entities/prijem.dart';
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
    implements
        ServiceOrderDataSource,
        VozidlaDataSource,
        FotkyDataSource,
        PrijemDataSource,
        OdesilaniUdalosti {
  RestServiceOrderDataSource({
    required Uri baseUrl,
    required Future<String?> Function() tokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    void Function(String nazev, String detail)? onChyba,
  }) : _baseUrl = baseUrl,
       _tokenProvider = tokenProvider,
       _client = client ?? http.Client(),
       _onChyba = onChyba;

  final Uri _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final http.Client _client;

  /// Výpadek sítě nebo chyba serveru - pro log událostí. Ve službě se
  /// nepovedený požadavek zapíše sám, ale ten, který k ní nedošel, ne.
  final void Function(String nazev, String detail)? _onChyba;

  /// Chyby při odesílání logu se nehlásí do logu - jinak by bez sítě
  /// každý pokus přidal další záznam.
  void _hlas(String nazev, String path, String detail) {
    if (path == 'events') return;
    _onChyba?.call(nazev, '${path.split('?').first}: $detail');
  }

  @override
  Future<void> odesliUdalosti(
    List<Map<String, Object?>> udalosti, {
    required String zarizeni,
    String? verze,
  }) async {
    await _send(
      'POST',
      'events',
      body: {'device': zarizeni, 'appVersion': verze, 'events': udalosti},
    );
  }

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
    String? misto,
  }) async {
    final data = await _send(
      'POST',
      'orders/${Uri.encodeComponent(orderId)}/stavy',
      body: {'code': ?kod, 'label': ?nazev, 'note': ?poznamka, 'bay': ?misto},
    );
    return data == null ? null : ServiceOrderDto.fromJson(_asMap(data));
  }

  @override
  Future<ServiceOrderDto?> ulozPredmetOpravy(
    String orderId,
    String text,
  ) async {
    final data = await _send(
      'PUT',
      'orders/${Uri.encodeComponent(orderId)}/repair-subject',
      body: {'text': text},
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
  Future<bool> serverBezi() async {
    try {
      // `/health` visí vedle `/api`, ne pod ním - proto o úroveň výš.
      final odpoved = await _client
          .get(_baseUrl.resolve('../health'))
          .timeout(const Duration(seconds: 5));
      return odpoved.statusCode == 200;
    } catch (_) {
      // Mimo firemní síť, vypnutá služba, špatná adresa - pro uživatele
      // je to jedno, stejně vidí „server nedostupný".
      return false;
    }
  }

  @override
  Future<void> synchronizuj() async {
    await _send('POST', 'sync', timeout: const Duration(seconds: 60));
  }

  @override
  Future<List<Fotka>> fotkyZakazky(String orderId) async {
    final data = await _send(
      'GET',
      'orders/${Uri.encodeComponent(orderId)}/photos',
    );
    if (data is! List) return const [];
    return data
        .map((item) => Fotka.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Fotka> nahrajFotku(
    String orderId,
    KategorieFotky kategorie,
    Uint8List jpeg, {
    String? pobocka,
  }) async {
    final data = await _send(
      'POST',
      'orders/${Uri.encodeComponent(orderId)}/photos'
          '?category=${Uri.encodeQueryComponent(kategorie.klic)}'
          '${pobocka == null ? '' : '&branch=${Uri.encodeQueryComponent(pobocka)}'}',
      bajty: jpeg,
      // Půl megabajtu po dílenské wi-fi - víc času než na běžný dotaz.
      timeout: const Duration(seconds: 90),
    );
    if (data is! Map<String, dynamic>) {
      throw const ServiceOrderException('Fotku se nepodařilo nahrát.');
    }
    return Fotka.fromJson(data);
  }

  @override
  Future<List<String>> slozkyPobocek() async {
    final data = await _send('GET', 'photos/branches');
    if (data is! List) {
      // 404 = služba ještě bez volby pobočky.
      throw const ServiceOrderException(
        'Server seznam poboček zatím nenabízí.',
      );
    }
    return data.whereType<String>().toList();
  }

  @override
  Future<Uint8List> stahniFotku(String id) async {
    final data = await _send(
      'GET',
      'photos/${Uri.encodeComponent(id)}',
      binarni: true,
      timeout: const Duration(seconds: 60),
    );
    if (data is! Uint8List) {
      throw const ServiceOrderException('Fotka nebyla nalezena.');
    }
    return data;
  }

  @override
  Future<void> smazFotku(String id) async {
    await _send('DELETE', 'photos/${Uri.encodeComponent(id)}');
  }

  String _cestaDokumentu(String orderId) =>
      'orders/${Uri.encodeComponent(orderId)}/documents';

  @override
  Future<List<Dokument>> dokumentyZakazky(String orderId) async {
    final data = await _send('GET', _cestaDokumentu(orderId));
    if (data is! List) return const [];
    return data
        .map((item) => Dokument.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Dokument> nahrajDokument(
    String orderId,
    String nazev,
    Uint8List data, {
    String? pobocka,
  }) async {
    final odpoved = await _send(
      'POST',
      '${_cestaDokumentu(orderId)}'
          '?name=${Uri.encodeQueryComponent(nazev)}'
          '${pobocka == null ? '' : '&branch=${Uri.encodeQueryComponent(pobocka)}'}',
      bajty: data,
      typBajtu: 'application/octet-stream',
      // Sken o desítkách MB po dílenské wi-fi.
      timeout: const Duration(minutes: 3),
    );
    if (odpoved is! Map<String, dynamic>) {
      throw const ServiceOrderException('Zakázka nebyla nalezena.');
    }
    return Dokument.fromJson({
      ...odpoved,
      'modifiedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Uint8List> stahniDokument(String orderId, String id) async {
    final data = await _send(
      'GET',
      '${_cestaDokumentu(orderId)}/${Uri.encodeComponent(id)}',
      binarni: true,
      timeout: const Duration(minutes: 3),
    );
    if (data is! Uint8List) {
      throw const ServiceOrderException('Dokument už ve složce zakázky není.');
    }
    return data;
  }

  String _cestaPrijmu(String orderId) =>
      'orders/${Uri.encodeComponent(orderId)}/intake';

  Prijem _prijem(Object? data) {
    // 404 pod orders/ vrací null: zakázka nebo kontrola na serveru není.
    if (data is! Map<String, dynamic>) {
      throw const ServiceOrderException(
        'Zakázka nebo kontrola příjmu nebyla nalezena.',
      );
    }
    return Prijem.fromJson(data);
  }

  @override
  Future<Prijem> prijemZakazky(String orderId) async =>
      _prijem(await _send('GET', _cestaPrijmu(orderId)));

  @override
  Future<Prijem> zmenPolozku(
    String orderId,
    String kod,
    ZmenaPolozky zmena,
  ) async => _prijem(
    await _send(
      'PUT',
      '${_cestaPrijmu(orderId)}/items/${Uri.encodeComponent(kod)}',
      body: zmena.json,
    ),
  );

  @override
  Future<Prijem> dokonciPrijem(String orderId) async =>
      _prijem(await _send('POST', '${_cestaPrijmu(orderId)}/complete'));

  @override
  Future<Prijem> znovuOtevriPrijem(String orderId) async =>
      _prijem(await _send('DELETE', '${_cestaPrijmu(orderId)}/complete'));

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
    Uint8List? bajty,
    String typBajtu = 'image/jpeg',
    bool binarni = false,
    Duration? timeout,
  }) async {
    final request = http.Request(method, _baseUrl.resolve(path))
      ..headers['Accept'] = binarni ? '*/*' : 'application/json';

    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    if (bajty != null) {
      request.headers['Content-Type'] = typBajtu;
      request.bodyBytes = bajty;
    }

    final http.Response odpoved;
    try {
      final streamed = await _client
          .send(request)
          .timeout(timeout ?? this.timeout);
      odpoved = await http.Response.fromStream(streamed);
    } on TimeoutException {
      _hlas('sit_timeout', path, '$method bez odpovědi');
      throw const ServiceOrderException(
        'Server neodpovídá. Zkuste to znovu, až budete v dosahu sítě.',
      );
    } on http.ClientException catch (chyba) {
      _hlas('sit_nedostupna', path, '$method ${chyba.message}');
      throw ServiceOrderException(
        'Nepodařilo se spojit se serverem: ${chyba.message}',
      );
    }

    return _zpracuj(odpoved, path, binarni: binarni);
  }

  Object? _zpracuj(http.Response odpoved, String path, {bool binarni = false}) {
    final kod = odpoved.statusCode;

    if (kod == 404) {
      // Volající rozliší chybějící zakázku nebo vozidlo podle null.
      if (path.startsWith('orders/') ||
          path.startsWith('vehicles/') ||
          path.startsWith('photos/')) {
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
      _hlas('chyba_serveru', path, '$kod ${_chybaZTela(odpoved) ?? ''}');
      // Konkrétní zpráva ze serveru má přednost - u fotek říká, jestli
      // chybí úložiště, nebo nešel zápis na souborový server.
      throw ServiceOrderException(
        _chybaZTela(odpoved) ??
            'Server hlásí chybu. Zkuste to za chvíli znovu.',
      );
    }
    if (kod < 200 || kod >= 300) {
      throw ServiceOrderException(
        _chybaZTela(odpoved) ?? 'Chyba serveru ($kod).',
      );
    }
    if (odpoved.bodyBytes.isEmpty) return null;
    if (binarni) return odpoved.bodyBytes;

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
