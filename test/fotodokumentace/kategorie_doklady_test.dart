import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/fotodokumentace/domain/entities/fotka.dart';

/// Doklady (OP, ŘP, TP, plná moc, devinkulace, nehoda) jsou jedna sekce
/// fotodokumentace - v příjmu i v detailu zakázky.
void main() {
  test('kategorie Doklady se pozná podle klíče z API', () {
    expect(KategorieFotky.zKlice('doklady'), KategorieFotky.doklady);
    expect(
      Fotka.fromJson({
        'id': 'a1',
        'category': 'doklady',
        'uploadedAt': '2026-10-05T10:00:00',
      }).kategorie,
      KategorieFotky.doklady,
    );
    // V souhrnu v detailu bez výčtu v závorce.
    expect(KategorieFotky.doklady.kratkyNazev, 'Doklady');
  });

  test('doklady jsou za VIN, před umístěním a ostatní dokumentací', () {
    final poradi = KategorieFotky.values;
    expect(
      poradi.indexOf(KategorieFotky.doklady),
      poradi.indexOf(KategorieFotky.vin) + 1,
    );
    expect(poradi.last, KategorieFotky.ostatni);
  });
}
