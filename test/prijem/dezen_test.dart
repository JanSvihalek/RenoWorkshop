import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/dezen.dart';

/// Dezén pneu - stejná pravidla jako služba (src/domain/pneu.ts).
void main() {
  test('zápis tam a zpět, neúplný i nečitelný', () {
    final dezen = Dezen.precti('Z;5.2;4.8;3.1;6')!;
    expect(dezen, const Dezen(zimni: true, lp: 5.2, pp: 4.8, lz: 3.1, pz: 6));
    expect(dezen.zapis(), 'Z;5.2;4.8;3.1;6');
    expect(Dezen.precti('L;5;;;')!.jeKompletni, isFalse);
    expect(Dezen.precti('X;5;5;5;5'), isNull);
    expect(Dezen.precti('L;52;5;5;5'), isNull);
  });

  test('hranice: 4 mm doporučeno, 1,6 mm nutné, zimní pod 4 mm nutné', () {
    const letni = Dezen();
    expect(letni.stavKola(4), StavDezenu.ok);
    expect(letni.stavKola(3.9), StavDezenu.doporuceno);
    expect(letni.stavKola(1.5), StavDezenu.nutne);
    expect(const Dezen(zimni: true).stavKola(3.9), StavDezenu.nutne);
    expect(const Dezen(lp: 6, pp: 6, lz: 3, pz: 6).stav, StavDezenu.doporuceno);
    expect(const Dezen().stav, isNull);
  });

  test('text z pole: čárka i tečka, desetiny, nesmysl', () {
    expect(Dezen.zTextu('5,25'), 5.3);
    expect(Dezen.zTextu('4.8'), 4.8);
    expect(Dezen.zTextu(' '), isNull);
    expect(() => Dezen.zTextu('25'), throwsFormatException);
  });

  test('z karty vozu (API)', () {
    expect(
      Dezen.zApi({
        'winter': true,
        'wheels': {'fl': 5.2, 'fr': 4.8, 'rl': 3.1, 'rr': 6},
      }),
      const Dezen(zimni: true, lp: 5.2, pp: 4.8, lz: 3.1, pz: 6),
    );
    expect(Dezen.zApi(null), isNull);
  });
}
