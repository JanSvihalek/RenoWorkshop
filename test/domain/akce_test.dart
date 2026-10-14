import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/features/akce/domain/marketingova_akce.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_panel.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  final dnes = DateTime(2026, 10, 14);
  MarketingovaAkce akce(DateTime od, DateTime do_) =>
      MarketingovaAkce(nazev: 'A', text: '', od: od, do_: do_);

  group('platnost akce', () {
    test('první i poslední den se počítá', () {
      final a = akce(DateTime(2026, 10, 14), DateTime(2026, 10, 20));
      expect(a.plati(DateTime(2026, 10, 14, 18, 30)), isTrue);
      expect(a.plati(DateTime(2026, 10, 20, 23, 59)), isTrue);
      expect(a.plati(DateTime(2026, 10, 21)), isFalse);
      expect(a.plati(DateTime(2026, 10, 13)), isFalse);
    });

    test('stav slovy', () {
      expect(
        stavAkce(akce(DateTime(2026, 10, 1), DateTime(2026, 11, 30)), dnes),
        ('Platí ještě 48 dní', false),
      );
      expect(
        stavAkce(akce(DateTime(2026, 10, 1), DateTime(2026, 10, 17)), dnes),
        ('Končí za 3 dny', true),
      );
      expect(stavAkce(akce(DateTime(2026, 10, 1), dnes), dnes), (
        'Končí dnes',
        true,
      ));
      expect(
        stavAkce(akce(DateTime(2026, 10, 15), DateTime(2026, 10, 30)), dnes),
        ('Začne zítra', false),
      );
      expect(
        stavAkce(akce(DateTime(2026, 10, 19), DateTime(2026, 10, 30)), dnes),
        ('Začne za 5 dní', false),
      );
    });
  });

  test('čeština v počtech', () {
    expect(dni(1), '1 den');
    expect(dni(3), '3 dny');
    expect(dni(5), '5 dní');
    expect(pocetAkci(1), '1 marketingová akce');
    expect(pocetAkci(2), '2 marketingové akce');
    expect(pocetAkci(6), '6 marketingových akcí');
  });

  test('období akce', () {
    expect(
      obdobi(akce(DateTime(2026, 10, 1), DateTime(2026, 11, 30))),
      '1. 10. – 30. 11. 2026',
    );
    expect(
      obdobi(akce(DateTime(2026, 12, 1), DateTime(2027, 1, 31))),
      '1. 12. 2026 – 31. 1. 2027',
    );
  });

  test('akce ze serveru a zpět', () {
    final a = MarketingovaAkce.fromJson({
      'id': 'a1',
      'title': 'Zimní prohlídka',
      'text': 'Sleva',
      'validFrom': '2026-10-01',
      'validTo': '2026-11-30',
      'createdBy': 'Marketing',
    });
    expect(a.od, DateTime(2026, 10, 1));
    expect(a.do_, DateTime(2026, 11, 30));
    expect(a.toJson(), {
      'title': 'Zimní prohlídka',
      'text': 'Sleva',
      'validFrom': '2026-10-01',
      'validTo': '2026-11-30',
    });
  });
}
