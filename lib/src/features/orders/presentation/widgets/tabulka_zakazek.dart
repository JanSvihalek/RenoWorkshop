import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../settings/domain/entities/nastaveni.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';
import '../../domain/entities/service_order.dart';
import 'nova_zmena.dart';

/// Sloupec tabulky zakázek. Text i barva se berou ze zakázky, ať jde
/// sloupec přidat na jednom místě.
class SloupecZakazek {
  const SloupecZakazek({
    required this.klic,
    required this.nazev,
    required this.sirka,
    required this.hodnota,
    this.barva,
    this.stitek,
    this.mono = false,
    this.razeni,
  });

  /// Klíč sloupce v nastavení - stejný jako na webu (tabulka.ts).
  final String klic;
  final String nazev;
  final double sirka;
  final String Function(ServiceOrder zakazka) hodnota;

  /// Barva textu; bez ní běžná barva písma.
  final Color? Function(ServiceOrder zakazka)? barva;

  /// Hodnota jako barevný štítek (stavy) - pozadí a barva písma, stejně
  /// jako na webu. Bez něj prostý text.
  final ({Color pozadi, Color text}) Function(
    BuildContext context,
    ServiceOrder zakazka,
  )?
  stitek;

  /// Písmo s pevnou šířkou - čísla zakázek a SPZ se pak čtou po sloupcích.
  final bool mono;

  /// Podle čeho se řadí (číslo nebo text), když se nemá řadit podle
  /// zobrazeného textu - data, čísla obálek. Jako `razeni` na webu.
  final Object Function(ServiceOrder zakazka)? razeni;

  /// Hodnota pro řazení: [razeni], jinak zobrazený text (pomlčka = prázdné).
  Object hodnotaRazeni(ServiceOrder zakazka) {
    if (razeni case final r?) return r(zakazka);
    final text = hodnota(zakazka);
    return text == '-' ? '' : text;
  }

  /// Týž sloupec s jinou šířkou - z Nastavení.
  SloupecZakazek sSirkou(double novaSirka) => novaSirka == sirka
      ? this
      : SloupecZakazek(
          klic: klic,
          nazev: nazev,
          sirka: novaSirka,
          hodnota: hodnota,
          barva: barva,
          stitek: stitek,
          mono: mono,
          razeni: razeni,
        );
}

/// Výchozí šířka sloupce (bez nastavení); neznámý klíč `null`.
double? vychoziSirkaSloupce(String klic) =>
    sloupceZakazek.where((s) => s.klic == klic).firstOrNull?.sirka;

/// Zakázky seřazené podle sloupce - stejně jako `seradTabulku` na webu.
/// Bez řazení (nebo s neznámým sloupcem) zůstanou, jak přišly.
List<ServiceOrder> seradTabulku(
  List<ServiceOrder> zakazky,
  RazeniTabulky? razeni,
) {
  if (razeni == null) return zakazky;
  final sloupec = sloupceZakazek
      .where((s) => s.klic == razeni.klic)
      .firstOrNull;
  if (sloupec == null) return zakazky;
  final smer = razeni.sestupne ? -1 : 1;
  // Stabilní řazení: stejné hodnoty si nechají původní pořadí.
  final indexy = {for (final (i, z) in zakazky.indexed) z: i};
  return [...zakazky]..sort((a, b) {
    final x = sloupec.hodnotaRazeni(a);
    final y = sloupec.hodnotaRazeni(b);
    final v = x is num && y is num
        ? x.compareTo(y)
        : porovnejText(x.toString(), y.toString());
    return v != 0 ? v * smer : indexy[a]!.compareTo(indexy[b]!);
  });
}

/// Porovnání textu po česku zjednodušeně: bez ohledu na velikost písmen
/// a diakritiku, čísla v textu podle hodnoty (ZK-26-9 před ZK-26-10).
int porovnejText(String a, String b) {
  final x = _bezDiakritiky(a.toLowerCase());
  final y = _bezDiakritiky(b.toLowerCase());
  final casti = RegExp(r'\d+|\D+');
  final cx = casti.allMatches(x).map((m) => m[0]!).toList();
  final cy = casti.allMatches(y).map((m) => m[0]!).toList();
  for (var i = 0; i < cx.length && i < cy.length; i++) {
    final nx = int.tryParse(cx[i]);
    final ny = int.tryParse(cy[i]);
    final v = nx != null && ny != null
        ? nx.compareTo(ny)
        : cx[i].compareTo(cy[i]);
    if (v != 0) return v;
  }
  final delka = cx.length.compareTo(cy.length);
  // Shodné bez diakritiky: aspoň stabilně podle původního textu.
  return delka != 0 ? delka : a.compareTo(b);
}

const _diakritika = 'áäčďéěëíňóöřšťúůüýž';
const _bez = 'aacdeeeinoorstuuuyz';

String _bezDiakritiky(String text) => String.fromCharCodes(
  text.runes.map((r) {
    final i = _diakritika.indexOf(String.fromCharCode(r));
    return i < 0 ? r : _bez.codeUnitAt(i);
  }),
);

/// Sloupce v pořadí podle Heliosu: kdy přišel vůz a kdo ho má, komu
/// patří, pak zakázka a vozidlo, nakonec typ, stavy a termín.
///
/// „Ukončení" je **plánovaný termín dokončení** z Heliosu. Skutečné datum
/// uzavření zakázky aplikace zatím nezná - u rozdělaných zakázek stejně
/// žádné není.
final sloupceZakazek = <SloupecZakazek>[
  SloupecZakazek(
    klic: 'prijato',
    nazev: 'Přijato',
    sirka: 92,
    hodnota: (z) =>
        z.receivedAt == null ? '-' : AppDateFormat.dayMonthSmart(z.receivedAt!),
    razeni: (z) => z.receivedAt?.millisecondsSinceEpoch ?? 0,
  ),
  SloupecZakazek(
    klic: 'zodpovida',
    nazev: 'Zodpovídá',
    sirka: 110,
    hodnota: (z) => z.mechanicName ?? '-',
  ),
  // Hned vedle zodpovědné osoby z Heliosu: kdo má vůz právě v rukou -
  // skupina (Příjem, Dílna) a člověk.
  SloupecZakazek(
    klic: 'skupina',
    nazev: 'Skupina',
    sirka: 90,
    hodnota: (z) => z.skupina?.nazev ?? '-',
  ),
  SloupecZakazek(
    klic: 'zpracovava',
    nazev: 'Zpracovává',
    sirka: 110,
    hodnota: (z) => z.zpracovatel?.jmeno ?? '-',
  ),
  SloupecZakazek(
    klic: 'organizace',
    nazev: 'Organizace',
    sirka: 150,
    hodnota: (z) => z.customerName,
  ),
  SloupecZakazek(
    klic: 'zakazka',
    nazev: 'Zakázka',
    sirka: 120,
    hodnota: (z) => z.id,
    mono: true,
  ),
  SloupecZakazek(
    klic: 'spz',
    nazev: 'SPZ',
    sirka: 100,
    hodnota: (z) => z.licensePlate,
    mono: true,
  ),
  // Číslo obálky s klíčem (024) - podle něj se klíč vezme ze stolu.
  SloupecZakazek(
    klic: 'obalka',
    nazev: 'Obálka',
    sirka: 70,
    hodnota: (z) => z.obalka?.cislo ?? '-',
    mono: true,
    razeni: (z) => int.tryParse(z.obalka?.cislo ?? '') ?? 0,
  ),
  SloupecZakazek(
    klic: 'model',
    nazev: 'Model',
    sirka: 180,
    hodnota: (z) => z.model,
  ),
  SloupecZakazek(
    klic: 'vin',
    nazev: 'VIN',
    sirka: 175,
    hodnota: (z) => z.vin,
    mono: true,
  ),
  SloupecZakazek(
    klic: 'helios',
    nazev: 'Stav Helios',
    sirka: 80,
    hodnota: (z) => z.heliosStatus ?? '-',
    // Zelený štítek jako všude jinde - je pak poznat, který stav je z ERP.
    stitek: (context, z) => z.heliosStatus == null
        ? (pozadi: Colors.transparent, text: context.palette.muted)
        : (pozadi: AppColors.heliosGreen, text: Colors.white),
  ),
  SloupecZakazek(
    klic: 'dilna',
    nazev: 'Stav dílna',
    sirka: 100,
    hodnota: (z) => z.stav?.nazev ?? 'Bez stavu',
    // Jako na webu: tmavě modrý štítek, bez stavu šedý.
    stitek: (context, z) => z.stav == null
        ? (pozadi: context.palette.hairline, text: context.palette.muted)
        : (
            pozadi: context.isDarkMode ? AppColors.accent : AppColors.primary,
            text: Colors.white,
          ),
  ),
  SloupecZakazek(
    klic: 'typ',
    nazev: 'Typ',
    sirka: 80,
    hodnota: (z) => z.typZakazky?.nazev ?? '-',
  ),
  SloupecZakazek(
    klic: 'ukonceni',
    nazev: 'Ukončení',
    sirka: 100,
    hodnota: (z) =>
        z.dueAt == null ? '-' : AppDateFormat.dayMonthSmart(z.dueAt!),
    barva: (z) => z.isOverdue() ? AppColors.danger : null,
    // Bez termínu na konec - i při řazení od nejbližšího.
    razeni: (z) => z.dueAt?.millisecondsSinceEpoch ?? 1 << 53,
  ),
  SloupecZakazek(
    klic: 'utvar',
    nazev: 'Útvar',
    sirka: 90,
    hodnota: (z) => z.department?.code ?? '-',
  ),
];

/// Sloupce v pořadí podle nastavení: nejdřív uložené pořadí (neznámé klíče
/// se přeskočí), pak sloupce, které v něm nejsou - přibyly v nové verzi -
/// na konec ve výchozím pořadí. Skryté se vynechají, jen když [jenViditelne].
/// Šířka z nastavení, jinak výchozí.
List<SloupecZakazek> sloupceTabulky(
  NastaveniSloupcu nastaveni, {
  bool jenViditelne = true,
}) {
  final podleKlice = {
    for (final s in sloupceZakazek)
      s.klic: switch (nastaveni.sirky[s.klic]) {
        final sirka? => s.sSirkou(sirka.toDouble()),
        null => s,
      },
  };
  final serazene = [
    for (final klic in nastaveni.poradi) ?podleKlice.remove(klic),
    ...podleKlice.values,
  ];
  return [
    for (final s in serazene)
      if (!jenViditelne || !nastaveni.skryte.contains(s.klic)) s,
  ];
}

double _sirkaTabulky(List<SloupecZakazek> sloupce) =>
    sloupce.fold<double>(0, (soucet, s) => soucet + s.sirka) + 2 * Insets.base;

/// Co tabulka ukazuje pod hlavičkou sloupců: řádek zakázky, nebo vložka
/// přes šířku obrazovky - nadpis části nebo hláška (výsledky hledání mají
/// část Otevřené a Ukončené).
sealed class PolozkaTabulky {
  const PolozkaTabulky();
}

class RadekTabulky extends PolozkaTabulky {
  const RadekTabulky(this.zakazka);

  final ServiceOrder zakazka;
}

class VlozkaTabulky extends PolozkaTabulky {
  const VlozkaTabulky(this.child);

  final Widget child;
}

/// Řádkový přehled zakázek podobný Heliosu - hodně zakázek naráz a údaje
/// pod sebou ve sloupcích.
///
/// Karty jsou lepší na dílně v ruce, tabulka u stolu na tabletu, když se
/// prochází celý den práce. Proto jsou obě a přepínají se v hlavičce.
/// Sloupce jdou v pořadí a viditelnosti z Nastavení (nesou se s účtem).
class TabulkaZakazek extends ConsumerWidget {
  TabulkaZakazek({
    super.key,
    required List<ServiceOrder> zakazky,
    required this.onOpenOrder,
  }) : polozky = [for (final z in zakazky) RadekTabulky(z)];

  /// Řádky prokládané nadpisy a hláškami - výsledky hledání.
  const TabulkaZakazek.sPolozkami({
    super.key,
    required this.polozky,
    required this.onOpenOrder,
  });

  final List<PolozkaTabulky> polozky;
  final void Function(ServiceOrder zakazka) onOpenOrder;

  /// Řádky seřazené po částech - vložka (Otevřené, Ukončené) zůstává na
  /// místě, řadí se jen zakázky mezi nimi. Jako na webu otevřené
  /// a ukončené zvlášť.
  List<PolozkaTabulky> _serazene(RazeniTabulky? razeni) {
    if (razeni == null) return polozky;
    final vysledek = <PolozkaTabulky>[];
    var cast = <ServiceOrder>[];
    void uzavri() {
      vysledek.addAll(seradTabulku(cast, razeni).map(RadekTabulky.new));
      cast = [];
    }

    for (final p in polozky) {
      switch (p) {
        case RadekTabulky(:final zakazka):
          cast.add(zakazka);
        case VlozkaTabulky():
          uzavri();
          vysledek.add(p);
      }
    }
    uzavri();
    return vysledek;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sloupce = sloupceTabulky(
      ref.watch(nastaveniProvider.select((n) => n.sloupce)),
    );
    final razeni = ref.watch(nastaveniProvider.select((n) => n.razeniTabulky));
    final polozky = _serazene(razeni);
    final sirkaTabulky = _sirkaTabulky(sloupce);

    // Pořadí řádku v jeho části - střídání barev začíná po každé vložce
    // znovu, ať první řádek části vypadá vždycky stejně.
    final poradi = <int>[];
    var vCasti = 0;
    for (final polozka in polozky) {
      if (polozka is RadekTabulky) {
        poradi.add(vCasti++);
      } else {
        poradi.add(-1);
        vCasti = 0;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Vložka jen přes viditelnou šířku: hláška přes celou tabulku by
        // se na telefonu musela číst posouváním do strany.
        final sirkaVlozky = constraints.maxWidth < sirkaTabulky
            ? constraints.maxWidth
            : sirkaTabulky;

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: sirkaTabulky,
              child: Column(
                children: [
                  _Hlavicka(
                    sloupce: sloupce,
                    razeni: razeni,
                    onRadit: (klic) => ref
                        .read(nastaveniProvider.notifier)
                        .zmenRazeniTabulky(RazeniTabulky.dalsi(razeni, klic)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: polozky.length,
                      itemBuilder: (context, index) => switch (polozky[index]) {
                        RadekTabulky(:final zakazka) => _Radek(
                          zakazka: zakazka,
                          sloupce: sloupce,
                          // Střídavé pozadí - oko pak neuteče o řádek vedle.
                          sudy: poradi[index].isEven,
                          onTap: () => onOpenOrder(zakazka),
                        ),
                        VlozkaTabulky(:final child) => Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: sirkaVlozky,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Insets.base,
                                Insets.base,
                                Insets.base,
                                Insets.xxs,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      },
                    ),
                  ),
                  Container(height: 1, color: palette.hairline),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hlavicka extends StatelessWidget {
  const _Hlavicka({
    required this.sloupce,
    required this.razeni,
    required this.onRadit,
  });

  final List<SloupecZakazek> sloupce;
  final RazeniTabulky? razeni;

  /// Klepnutí na hlavičku: vzestupně → sestupně → bez řazení (jako web).
  final ValueChanged<String> onRadit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.base,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.hairline2)),
      ),
      child: Row(
        children: [
          for (final sloupec in sloupce)
            SizedBox(
              width: sloupec.sirka,
              child: InkWell(
                key: Key('tabulka-hlavicka-${sloupec.klic}'),
                onTap: () => onRadit(sloupec.klic),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          sloupec.nazev.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.overline.copyWith(
                            color: razeni?.klic == sloupec.klic
                                ? palette.text
                                : palette.muted,
                          ),
                        ),
                      ),
                      if (razeni?.klic == sloupec.klic)
                        Icon(
                          razeni!.sestupne
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          key: Key(
                            'tabulka-sipka-${razeni!.sestupne ? 'dolu' : 'nahoru'}',
                          ),
                          size: 14,
                          color: palette.text,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Radek extends StatelessWidget {
  const _Radek({
    required this.zakazka,
    required this.sloupce,
    required this.sudy,
    required this.onTap,
  });

  final ServiceOrder zakazka;
  final List<SloupecZakazek> sloupce;
  final bool sudy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final zmena = zakazka.novaZmena;

    final radek = InkWell(
      onTap: onTap,
      child: Container(
        height: Sizes.minTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: Insets.base),
        decoration: BoxDecoration(
          color: sudy ? palette.background : palette.card,
          border: Border(
            bottom: BorderSide(color: palette.hairline),
            // Nová změna od kolegy - modrý proužek vlevo a tečka.
            left: zmena == null
                ? BorderSide.none
                : const BorderSide(color: AppColors.accent, width: 3),
          ),
        ),
        child: Row(
          children: [
            for (final (i, sloupec) in sloupce.indexed)
              SizedBox(
                width: sloupec.sirka,
                child: Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: _sTeckou(
                    i == 0 && zmena != null,
                    _bunka(context, sloupec, palette, tucne: zmena != null),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (zmena == null) return radek;
    return Tooltip(
      message: '${zmena.text}\n${zmena.kdoKdy(DateTime.now())}',
      child: KeyedSubtree(
        key: Key('tabulka-zmena-${zakazka.id}'),
        child: radek,
      ),
    );
  }

  Widget _sTeckou(bool tecka, Widget obsah) => !tecka
      ? obsah
      : Row(
          children: [
            const TeckaZmeny(velikost: 7),
            const SizedBox(width: Insets.xs),
            Expanded(child: obsah),
          ],
        );

  Widget _bunka(
    BuildContext context,
    SloupecZakazek sloupec,
    AppPalette palette, {
    required bool tucne,
  }) {
    return switch (sloupec.stitek?.call(context, zakazka)) {
      final stitek? => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: stitek.pozadi,
            borderRadius: BorderRadius.circular(Radii.badge),
          ),
          child: Text(
            sloupec.hodnota(zakazka),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.badge.copyWith(
              fontSize: 11.5,
              color: stitek.text,
            ),
          ),
        ),
      ),
      null => Text(
        sloupec.hodnota(zakazka),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (sloupec.mono ? AppTextStyles.monoLabel : AppTextStyles.cardBody)
            .copyWith(
              fontSize: 13,
              fontWeight: tucne ? FontWeight.w700 : null,
              color: sloupec.barva?.call(zakazka) ?? palette.text,
            ),
      ),
    };
  }
}
