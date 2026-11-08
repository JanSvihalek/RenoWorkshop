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
}

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
  ),
  SloupecZakazek(
    klic: 'zodpovida',
    nazev: 'Zodpovídá',
    sirka: 110,
    hodnota: (z) => z.mechanicName ?? '-',
  ),
  // Hned vedle zodpovědné osoby z Heliosu: kdo má vůz právě v rukou.
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
List<SloupecZakazek> sloupceTabulky(
  NastaveniSloupcu nastaveni, {
  bool jenViditelne = true,
}) {
  final podleKlice = {for (final s in sloupceZakazek) s.klic: s};
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sloupce = sloupceTabulky(
      ref.watch(nastaveniProvider.select((n) => n.sloupce)),
    );
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
                  _Hlavicka(sloupce: sloupce),
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
  const _Hlavicka({required this.sloupce});

  final List<SloupecZakazek> sloupce;

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
              child: Text(
                sloupec.nazev.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.overline.copyWith(color: palette.muted),
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

    return InkWell(
      onTap: onTap,
      child: Container(
        height: Sizes.minTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: Insets.base),
        decoration: BoxDecoration(
          color: sudy ? palette.background : palette.card,
          border: Border(bottom: BorderSide(color: palette.hairline)),
        ),
        child: Row(
          children: [
            for (final sloupec in sloupce)
              SizedBox(
                width: sloupec.sirka,
                child: Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: switch (sloupec.stitek?.call(context, zakazka)) {
                    final stitek? => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                      style:
                          (sloupec.mono
                                  ? AppTextStyles.monoLabel
                                  : AppTextStyles.cardBody)
                              .copyWith(
                                fontSize: 13,
                                color:
                                    sloupec.barva?.call(zakazka) ??
                                    palette.text,
                              ),
                    ),
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
