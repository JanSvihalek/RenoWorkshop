import '../domain/monitoring.dart';

/// Ukázkový monitoring pro ukázková data a testy - vymyšlení lidé.
PrehledMonitoringu ukazkovyMonitoring(int dni, {DateTime? dnes}) {
  final den = dnes ?? DateTime.now();
  final posledni = DateTime(den.year, den.month, den.day);
  final poDnech = [
    for (var i = 0; i < dni; i++)
      () {
        final datum = posledni.subtract(Duration(days: dni - 1 - i));
        final vikend = datum.weekday >= DateTime.saturday;
        final lidi = vikend ? 1 : 3 + i % 3;
        return DenMonitoringu(
          datum: datum,
          lidi: lidi,
          navstevy: lidi * 2 + i % 2,
          pozadavky: lidi * 110,
          zapisy: lidi * 5,
          podleKlienta: {'aplikace': lidi * 80, 'web': lidi * 30},
        );
      }(),
  ];
  return PrehledMonitoringu(
    dni: dni,
    od: poDnech.first.datum,
    do_: posledni,
    lidi: 4,
    navstevy: poDnech.fold(0, (s, d) => s + d.navstevy),
    pozadavky: poDnech.fold(0, (s, d) => s + d.pozadavky),
    zapisy: poDnech.fold(0, (s, d) => s + d.zapisy),
    chybySluzby: 1,
    chybyKlientu: 2,
    prumerMs: 380,
    ucty: 6,
    poDnech: poDnech,
    hodiny: {
      for (var d = 0; d < 5; d++)
        for (var h = 7; h < 17; h++)
          (d, h): (pozadavky: 20 + (h - 7) * (16 - h) * 3, lidi: 3),
    },
    uzivatele: [
      UzivatelMonitoringu(
        email: 'eva.mala@example.cz',
        jmeno: 'Eva Malá',
        klienti: const ['aplikace', 'web'],
        verze: '2.6.9+1',
        zarizeni: 'android 15',
        dni: dni.clamp(1, 6),
        navstevy: 18,
        zapisy: 64,
        naposledy: posledni.add(const Duration(hours: 8, minutes: 12)),
      ),
      UzivatelMonitoringu(
        email: 'petr.novak@example.cz',
        jmeno: 'Petr Novák',
        klienti: const ['plan'],
        dni: dni.clamp(1, 5),
        navstevy: 9,
        zapisy: 40,
        chyby: 1,
        naposledy: posledni.add(const Duration(hours: 7, minutes: 55)),
      ),
      UzivatelMonitoringu(
        email: 'jiri.dvorak@example.cz',
        jmeno: 'Jiří Dvořák',
        klienti: const ['aplikace'],
        verze: '2.6.5+1',
        zarizeni: 'ios 26.1',
        dni: dni.clamp(1, 3),
        navstevy: 5,
        zapisy: 12,
        chyby: 2,
        naposledy: posledni.subtract(const Duration(hours: 9)),
      ),
    ],
    neaktivni: [
      UzivatelMonitoringu(
        email: 'karel.svoboda@example.cz',
        jmeno: 'Karel Svoboda',
        naposledy: posledni.subtract(const Duration(days: 22)),
      ),
    ],
    akce: const [
      PolozkaPruhu(text: 'Seznam zakázek', pocet: 2900, lidi: 4),
      PolozkaPruhu(text: 'Otevřel detail zakázky', pocet: 820, lidi: 4),
      PolozkaPruhu(text: 'Zapsal stav', pocet: 96, lidi: 3, zvyraznit: true),
      PolozkaPruhu(text: 'Nahrál fotku', pocet: 54, lidi: 2, zvyraznit: true),
    ],
    obrazovky: const [
      PolozkaPruhu(
        text: 'Seznam zakázek',
        pocet: 420,
        lidi: 3,
        stitek: 'Aplikace',
      ),
      PolozkaPruhu(text: 'Plánovač', pocet: 150, lidi: 1, stitek: 'Plánovač'),
    ],
    verze: const [
      PolozkaPruhu(
        text: '2.6.9+1',
        pocet: 1,
        lidi: 1,
        stitek: 'nejnovější',
        zvyraznit: true,
      ),
      PolozkaPruhu(text: '2.6.5+1', pocet: 1, lidi: 1),
    ],
    chyby: [
      ChybaMonitoringu(
        kdy: posledni.subtract(const Duration(hours: 9)),
        kdo: 'Jiří Dvořák',
        verze: '2.6.5+1',
        co: 'POST /api/orders/:id/photos → 500',
        zakazka: 'ZK-26-0012',
        zprava: 'Fotku se nepodařilo uložit.',
      ),
    ],
  );
}

/// Ukázková časová osa uživatele.
OsaMonitoringu ukazkovaOsa(String email, {DateTime? dnes}) {
  final ted = dnes ?? DateTime.now();
  return OsaMonitoringu(
    email: email,
    polozky: [
      PolozkaOsy(
        kdy: ted,
        od: ted.subtract(const Duration(minutes: 30)),
        pocet: 31,
        klient: 'aplikace',
        druh: DruhOsy.cteni,
        popis: 'Seznam zakázek',
      ),
      PolozkaOsy(
        kdy: ted.subtract(const Duration(minutes: 31)),
        od: ted.subtract(const Duration(minutes: 31)),
        klient: 'aplikace',
        druh: DruhOsy.zapis,
        popis: 'Zapsal stav',
        zakazka: 'ZK-26-0001',
      ),
      PolozkaOsy(
        kdy: ted.subtract(const Duration(minutes: 32)),
        od: ted.subtract(const Duration(minutes: 32)),
        klient: 'aplikace',
        druh: DruhOsy.obrazovka,
        popis: 'Detail zakázky',
      ),
    ],
  );
}
