import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/data/prubezne_cteni.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/kod_vozidla.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/obalka_klice.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/obalka_klice.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Obálky s klíčem - části, které jdou ověřit bez obrazovky.
void main() {
  group('kód obálky', () {
    test('jednotný tvar z QR i z ručně napsaného', () {
      expect(kodObalky('KBSL-023'), 'KBSL-023');
      expect(kodObalky('kbsl-23'), 'KBSL-023');
      expect(kodObalky(' KCLI 7 '), 'KCLI-007');
      expect(kodObalky('KNUP200'), 'KNUP-200');
    });

    test('jiné texty obálka nejsou', () {
      expect(kodObalky('4Z49636'), isNull);
      expect(kodObalky('KXYZ-001'), isNull);
      expect(kodObalky('KBSL-000'), isNull);
      expect(kodObalky('KBSL-1234'), isNull);
      expect(kodObalky('https://renocar.cz'), isNull);
    });
  });

  test('štítek obálky přečtený jako text: obálka, ne SPZ', () {
    // Takhle vypadá text ze štítku (npm run stitky v RenoWorkshopApi).
    final kody = KodyZTextu.najdi('023\nKBSL-023\nBrno Slatina · klíč od vozu');

    expect(
      kody.first,
      const KodVozidla(druh: DruhKodu.obalka, hodnota: 'KBSL-023'),
    );
    expect(kody.where((k) => k.druh == DruhKodu.spz), isEmpty);
  });

  test('obálka se při průběžném čtení bere hned, bez potvrzení', () {
    const obalka = KodVozidla(druh: DruhKodu.obalka, hodnota: 'KBSL-023');
    expect(PotvrzeniSpz().pridej([obalka]), obalka);
  });

  test('obálka z odpovědi serveru', () {
    final obalka = ObalkaKlice.fromJson({
      'code': 'KCLI-042',
      'branch': 'CLI',
      'branchName': 'Čestlice',
      'assignedAt': '2026-10-12T08:15:00',
      'assignedBy': 'Petr Novák',
    });

    expect(obalka.kod, 'KCLI-042');
    expect(obalka.cislo, '042');
    expect(obalka.nazevPobocky, 'Čestlice');
    expect(obalka.prirazeno, DateTime(2026, 10, 12, 8, 15));
    expect(obalka.prirazilKdo, 'Petr Novák');
  });

  group('ručně napsané číslo', () {
    final brno = buildOrderDto(keyEnvelopeBranch: 'BSL').toDomain();
    final bezPobocky = buildOrderDto().toDomain();

    test('u zakázky se známou pobočkou stačí číslo', () {
      expect(predponaObalky(brno), 'KBSL-');
      expect(kodZNapsaneho('23', brno), 'KBSL-023');
      expect(kodZNapsaneho('kcli-5', brno), 'KCLI-005');
    });

    test('bez pobočky jen celý kód', () {
      expect(predponaObalky(bezPobocky), isNull);
      expect(kodZNapsaneho('23', bezPobocky), isNull);
      expect(kodZNapsaneho('KBSL-23', bezPobocky), 'KBSL-023');
    });
  });

  test('napsaný kód obálky najde zakázku v hledání', () {
    final zakazka = buildOrderDto(
      keyEnvelope: {'code': 'KBSL-023', 'branchName': 'Brno Slatina'},
    ).toDomain();

    expect(zakazka.matchesQuery('KBSL-023'), isTrue);
    expect(zakazka.matchesQuery('KBSL-024'), isFalse);
  });
}
