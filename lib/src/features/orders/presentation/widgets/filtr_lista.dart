import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/order_filter.dart';
import '../controllers/orders_providers.dart';

/// Lišta filtrů nad seznamem zakázek.
///
/// Všechny filtry vedle sebe jako rozbalovací seznamy. Dřív byly
/// roztroušené na třech místech — útvar v hlavičce, stavy jako řada
/// štítků a zbytek schovaný pod tlačítkem — takže nebylo poznat, podle
/// čeho je seznam právě zúžený.
///
/// Řada se vodorovně posouvá: na úzkém displeji se pět seznamů vedle
/// sebe nevejde a zalomit je pod sebe by z lišty udělalo půl obrazovky.
class FiltrLista extends ConsumerWidget {
  const FiltrLista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final filter = ref.watch(orderFilterProvider);
    final controller = ref.read(orderFilterProvider.notifier);

    final utvary = ref.watch(availableDepartmentsProvider);
    final poradace = ref.watch(pouzitePoradaceProvider);
    final stavy = ref.watch(pouziteStavyProvider);
    final stavyHelios = ref.watch(pouziteStavyHeliosProvider);
    final typy = ref.watch(availableOrderTypesProvider);
    final lide = ref.watch(mechanicsProvider);

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xxl,
          vertical: Insets.base,
        ),
        child: Row(
          children: [
            _Filtr<String>(
              popisek: 'Útvar',
              hodnota: filter.departmentCode,
              moznosti: {for (final utvar in utvary) utvar.code: utvar.code},
              onZmena: controller.setDepartment,
            ),
            const SizedBox(width: Insets.sm),
            _Filtr<String>(
              popisek: 'Pořadač',
              hodnota: filter.poradacKod,
              moznosti: {for (final p in poradace) p.kod: p.nazev},
              onZmena: controller.setPoradac,
            ),
            const SizedBox(width: Insets.sm),
            // Dva nezávislé stavy jako na kartě: co o zakázce ví ERP
            // a co dílna.
            _Filtr<String>(
              popisek: 'Stav Helios',
              hodnota: filter.heliosStav,
              moznosti: {for (final stav in stavyHelios) stav: stav},
              onZmena: controller.setHeliosStav,
            ),
            const SizedBox(width: Insets.sm),
            _Filtr<String>(
              popisek: 'Stav dílna',
              hodnota: filter.statusCode,
              moznosti: {
                for (final stav in stavy)
                  if (stav.kod != null) stav.kod!: stav.nazev,
              },
              onZmena: controller.setStatus,
            ),
            const SizedBox(width: Insets.sm),
            _Filtr<String>(
              popisek: 'Typ',
              hodnota: filter.typZakazkyKod,
              moznosti: {for (final typ in typy) typ.kod: typ.nazev},
              onZmena: controller.setTypZakazky,
            ),
            const SizedBox(width: Insets.sm),
            _Filtr<String>(
              popisek: 'Zodpovídá',
              hodnota: filter.mechanicName,
              moznosti: {for (final clovek in lide) clovek: clovek},
              onZmena: controller.setMechanic,
            ),
            const SizedBox(width: Insets.sm),
            // Řazení není filtr, ale patří sem ze stejného důvodu: rozhoduje
            // o tom, jak seznam vypadá, a bylo schované pod tlačítkem.
            _Filtr<OrderSort>(
              popisek: 'Řadit',
              hodnota: filter.sort,
              moznosti: {for (final sort in OrderSort.values) sort: sort.label},
              vzdyVybrano: true,
              onZmena: (sort) =>
                  controller.setSort(sort ?? OrderSort.receivedDate),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jeden rozbalovací filtr. Vybraný je barevný, ať je poznat, že zužuje.
class _Filtr<T> extends StatelessWidget {
  const _Filtr({
    required this.popisek,
    required this.hodnota,
    required this.moznosti,
    required this.onZmena,
    this.vzdyVybrano = false,
  });

  final String popisek;
  final T? hodnota;

  /// Hodnota → co se zobrazí v nabídce.
  final Map<T, String> moznosti;

  final ValueChanged<T?> onZmena;

  /// Řazení nemá stav „nevybráno" - vždycky se podle něčeho řadí.
  final bool vzdyVybrano;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Uložená hodnota, která v datech není (jiný útvar, uzavřené zakázky),
    // by shodila DropdownButton na neexistující položce.
    final vybrano = moznosti.containsKey(hodnota) ? hodnota : null;
    final aktivni = vybrano != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: aktivni && !vzdyVybrano ? AppColors.primary : palette.background,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(
          color: aktivni && !vzdyVybrano
              ? AppColors.primary
              : palette.hairline2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: vybrano,
          isDense: true,
          borderRadius: BorderRadius.circular(Radii.input),
          dropdownColor: palette.card,
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: aktivni && !vzdyVybrano ? Colors.white70 : palette.muted,
          ),
          // Zavřený seznam leží na světlém podkladu, vybraný na tmavém -
          // barva textu se proto liší od té v rozbalené nabídce.
          // Musí mít přesně tolik položek a ve stejném pořadí jako `items`,
          // DropdownButton je páruje podle indexu. Řazení nemá položku
          // „Vše" - kdyby tu zůstal zástupný řádek, posunulo by se to o jednu
          // a u „Datum přijetí" by svítil „Termín dokončení".
          selectedItemBuilder: (context) => [
            if (!vzdyVybrano) _zavreny(popisek, false),
            for (final polozka in moznosti.entries)
              _zavreny(
                vzdyVybrano ? '$popisek: ${polozka.value}' : polozka.value,
                true,
              ),
          ],
          items: [
            if (!vzdyVybrano)
              DropdownMenuItem(
                value: null,
                child: Text(
                  'Vše',
                  style: AppTextStyles.chip.copyWith(color: palette.muted2),
                ),
              ),
            for (final polozka in moznosti.entries)
              DropdownMenuItem(
                value: polozka.key,
                child: Text(
                  polozka.value,
                  style: AppTextStyles.chip.copyWith(color: palette.text),
                ),
              ),
          ],
          onChanged: moznosti.isEmpty ? null : onZmena,
        ),
      ),
    );
  }

  Widget _zavreny(String text, bool aktivni) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Builder(
        builder: (context) {
          final palette = context.palette;
          return Text(
            text,
            style: AppTextStyles.chip.copyWith(
              color: aktivni && !vzdyVybrano ? Colors.white : palette.muted2,
              fontWeight: aktivni ? FontWeight.w600 : FontWeight.w400,
            ),
          );
        },
      ),
    );
  }
}
