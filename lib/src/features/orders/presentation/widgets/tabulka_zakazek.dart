import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/service_order.dart';
import 'order_status_visuals.dart';

/// Sloupec tabulky zakázek. Text i barva se berou ze zakázky, ať jde
/// sloupec přidat na jednom místě.
class SloupecZakazek {
  const SloupecZakazek({
    required this.nazev,
    required this.sirka,
    required this.hodnota,
    this.barva,
    this.mono = false,
  });

  final String nazev;
  final double sirka;
  final String Function(ServiceOrder zakazka) hodnota;

  /// Barva textu; bez ní běžná barva písma.
  final Color? Function(ServiceOrder zakazka)? barva;

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
    nazev: 'Přijato',
    sirka: 92,
    hodnota: (z) =>
        z.receivedAt == null ? '-' : AppDateFormat.dayMonthSmart(z.receivedAt!),
  ),
  SloupecZakazek(
    nazev: 'Zodpovídá',
    sirka: 110,
    hodnota: (z) => z.mechanicName ?? '-',
  ),
  SloupecZakazek(
    nazev: 'Organizace',
    sirka: 150,
    hodnota: (z) => z.customerName,
  ),
  SloupecZakazek(
    nazev: 'Zakázka',
    sirka: 120,
    hodnota: (z) => z.id,
    mono: true,
  ),
  SloupecZakazek(
    nazev: 'SPZ',
    sirka: 100,
    hodnota: (z) => z.licensePlate,
    mono: true,
  ),
  SloupecZakazek(nazev: 'Model', sirka: 180, hodnota: (z) => z.model),
  SloupecZakazek(nazev: 'VIN', sirka: 175, hodnota: (z) => z.vin, mono: true),
  SloupecZakazek(
    nazev: 'Stav Helios',
    sirka: 80,
    hodnota: (z) => z.heliosStatus ?? '-',
    // Zeleně jako všude jinde - je pak poznat, který stav je z ERP.
    barva: (z) => z.heliosStatus == null ? null : AppColors.heliosGreen,
  ),
  SloupecZakazek(
    nazev: 'Stav dílna',
    sirka: 100,
    hodnota: (z) => z.stav?.nazev ?? 'Bez stavu',
    barva: (z) => z.stav?.color,
  ),
  SloupecZakazek(
    nazev: 'Typ',
    sirka: 80,
    hodnota: (z) => z.typZakazky?.nazev ?? '-',
  ),
  SloupecZakazek(
    nazev: 'Ukončení',
    sirka: 100,
    hodnota: (z) =>
        z.dueAt == null ? '-' : AppDateFormat.dayMonthSmart(z.dueAt!),
    barva: (z) => z.isOverdue() ? AppColors.danger : null,
  ),
  SloupecZakazek(
    nazev: 'Útvar',
    sirka: 90,
    hodnota: (z) => z.department?.code ?? '-',
  ),
];

double get _sirkaTabulky =>
    sloupceZakazek.fold<double>(0, (soucet, s) => soucet + s.sirka) +
    2 * Insets.base;

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
class TabulkaZakazek extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final palette = context.palette;

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
        final sirkaVlozky = constraints.maxWidth < _sirkaTabulky
            ? constraints.maxWidth
            : _sirkaTabulky;

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _sirkaTabulky,
              child: Column(
                children: [
                  _Hlavicka(),
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: polozky.length,
                      itemBuilder: (context, index) => switch (polozky[index]) {
                        RadekTabulky(:final zakazka) => _Radek(
                          zakazka: zakazka,
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
          for (final sloupec in sloupceZakazek)
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
    required this.sudy,
    required this.onTap,
  });

  final ServiceOrder zakazka;
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
            for (final sloupec in sloupceZakazek)
              SizedBox(
                width: sloupec.sirka,
                child: Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Text(
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
                                  sloupec.barva?.call(zakazka) ?? palette.text,
                            ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
