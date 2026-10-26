import 'dart:typed_data';

import '../domain/diagnostika.dart';

/// Diagnostické protokoly - implementuje je stejná služba jako zakázky.
abstract interface class DiagnostikaDataSource {
  /// `GET /orders/{id}/diagnostics`, nejnovější první.
  Future<List<ProtokolDiagnostiky>> protokolyZakazky(String orderId);

  /// `GET /orders/{id}/diagnostics/{pid}/files`.
  Future<List<SouborDiagnostiky>> souboryProtokolu(
    String orderId,
    String protokolId,
  );

  /// `GET /orders/{id}/diagnostics/{pid}/files/{fid}`.
  Future<Uint8List> stahniSouborDiagnostiky(
    String orderId,
    String protokolId,
    String souborId,
  );
}
