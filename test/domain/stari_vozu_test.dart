import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/utils/date_formats.dart';
import 'package:renoworkshop/src/core/utils/stari_vozu.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  test('stáří v měsících se dovrší ve stejný den - jako na serveru', () {
    final dnes = DateTime(2026, 10, 15);
    expect(stariVMesicich(DateTime(2022, 10, 16), dnes), 47);
    expect(stariVMesicich(DateTime(2022, 10, 15), dnes), 48);
    expect(stariVMesicich(DateTime(2022, 10, 31), DateTime(2026, 11, 30)), 48);
  });

  test('měsíce slovy a datum se stářím', () {
    expect(pocetMesicu(1), '1 měsíc');
    expect(pocetMesicu(3), '3 měsíce');
    expect(pocetMesicu(89), '89 měsíců');
    expect(pocetMesicu(0), '0 měsíců');
    final dnes = DateTime(2026, 10, 15);
    expect(
      registraceSeStarim(DateTime(2019, 5, 3), dnes, AppDateFormat.date),
      '3. 5. 2019 · 89 měsíců',
    );
    // Překlep v Heliosu - registrace v budoucnu - stáří nepíše.
    expect(
      registraceSeStarim(DateTime(2027, 1, 1), dnes, AppDateFormat.date),
      '1. 1. 2027',
    );
  });
}
