import '../../orders/data/dtos/service_order_dto.dart';
import '../domain/entities/vozidlo.dart';

/// Zdroj dat o vozidlech.
///
/// Rozhraní zvlášť od zakázek, ale plní ho tentýž zdroj: vozidla i zakázky
/// vrací stejná služba na RENDCAPPu, takže REST i mock implementují obě
/// rozhraní a sdílí jedno spojení.
abstract interface class VozidlaDataSource {
  /// `GET /vehicles/search?q=...` - hledání podle SPZ nebo VIN.
  Future<List<NalezeneVozidlo>> hledejVozidla(String dotaz);

  /// `GET /vehicles/{id}` - karta vozidla. `null`, když vůz neexistuje.
  Future<KartaVozidla?> kartaVozidla(int id);
}

/// Převod odpovědí API na doménu. Na jednom místě, ať REST i testy
/// čtou JSON stejně.
abstract final class VozidlaJson {
  static NalezeneVozidlo nalezene(Map<String, dynamic> json) {
    return NalezeneVozidlo(
      id: (json['id'] as num).toInt(),
      spz: json['licensePlate'] as String? ?? '',
      vin: json['vin'] as String? ?? '',
      model: json['model'] as String? ?? '',
      majitel: _text(json['ownerName']),
      pocetZakazek: (json['orderCount'] as num?)?.toInt() ?? 0,
    );
  }

  static KartaVozidla karta(Map<String, dynamic> json) {
    final majitel = json['owner'];
    final kontakt = json['contact'];
    final zakazky = json['orders'];

    return KartaVozidla(
      id: (json['id'] as num).toInt(),
      spz: json['licensePlate'] as String? ?? '',
      vin: json['vin'] as String? ?? '',
      model: json['model'] as String? ?? '',
      serie: _text(json['series']),
      palivo: _text(json['fuel']),
      motor: _text(json['engine']),
      tachometr: (json['mileage'] as num?)?.toInt(),
      prodano: DateTime.tryParse(json['soldAt'] as String? ?? ''),
      majitel: majitel is Map<String, dynamic>
          ? MajitelVozidla(
              nazev: majitel['name'] as String? ?? '',
              cisloZakaznika: _text(majitel['customerNumber']),
              ico: _text(majitel['ico']),
              dic: _text(majitel['dic']),
              ulice: _text(majitel['street']),
              mesto: _text(majitel['city']),
              psc: _text(majitel['zip']),
              telefon: _text(majitel['phone']),
              email: _text(majitel['email']),
            )
          : null,
      kontakt: kontakt is Map<String, dynamic>
          ? KontaktVozidla(
              jmeno: kontakt['name'] as String? ?? '',
              telefon: _text(kontakt['phone']),
              email: _text(kontakt['email']),
            )
          : null,
      zakazky: zakazky is List
          ? zakazky
                .map(
                  (z) => ServiceOrderDto.fromJson(
                    z as Map<String, dynamic>,
                  ).toDomain(),
                )
                .toList()
          : const [],
    );
  }

  /// Prázdný text bereme jako nevyplněno - karta pak řádek vynechá.
  static String? _text(Object? hodnota) {
    if (hodnota is! String) return null;
    final orezane = hodnota.trim();
    return orezane.isEmpty ? null : orezane;
  }
}
