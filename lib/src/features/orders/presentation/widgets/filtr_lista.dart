import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';
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
    final zpracovatele = ref.watch(zpracovateleProvider);
    final nastaveni = ref.watch(nastaveniProvider);

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
            FiltrVyberVice<String>(
              popisek: 'Útvar',
              hodnoty: filter.departmentCodes,
              moznosti: {for (final utvar in utvary) utvar.code: utvar.code},
              onZmena: controller.setDepartments,
            ),
            const SizedBox(width: Insets.sm),
            FiltrVyberVice<String>(
              popisek: 'Pořadač',
              hodnoty: filter.poradacKody,
              moznosti: {for (final p in poradace) p.kod: p.nazev},
              onZmena: controller.setPoradace,
            ),
            const SizedBox(width: Insets.sm),
            // Dva nezávislé stavy jako na kartě: co o zakázce ví ERP
            // a co dílna.
            FiltrVyberVice<String>(
              popisek: 'Stav Helios',
              hodnoty: filter.heliosStavy,
              moznosti: {for (final stav in stavyHelios) stav: stav},
              onZmena: controller.setHeliosStavy,
            ),
            const SizedBox(width: Insets.sm),
            FiltrVyberVice<String>(
              popisek: 'Stav dílna',
              hodnoty: filter.statusCodes,
              moznosti: {
                for (final stav in stavy)
                  if (stav.kod != null) stav.kod!: stav.nazev,
              },
              onZmena: controller.setStatusy,
            ),
            const SizedBox(width: Insets.sm),
            FiltrVyberVice<String>(
              popisek: 'Typ',
              hodnoty: filter.typZakazkyKody,
              moznosti: {for (final typ in typy) typ.kod: typ.nazev},
              onZmena: controller.setTypyZakazky,
            ),
            const SizedBox(width: Insets.sm),
            FiltrVyberVice<String>(
              popisek: 'Zodpovídá',
              hodnoty: filter.mechanicNames,
              moznosti: {for (final clovek in lide) clovek: clovek},
              onZmena: controller.setMechanici,
            ),
            const SizedBox(width: Insets.sm),
            FiltrVyberVice<int>(
              popisek: 'Zpracovává',
              hodnoty: filter.zpracovatelIds,
              moznosti: {
                OrderFilter.ja: 'Já',
                OrderFilter.nikdo: 'Nikdo',
                for (final kdo in zpracovatele) kdo.id: kdo.jmeno,
                // Výchozí zpracovatelé z nastavení, kteří zrovna nemají
                // žádnou zakázku - jinak by filtr platil neviditelně.
                for (final id in nastaveni.vychoziZpracovatele)
                  if (id > 0 && !zpracovatele.any((kdo) => kdo.id == id))
                    id: nastaveni.jmenaZpracovatelu[id] ?? 'č. $id',
              },
              onZmena: controller.setZpracovatele,
            ),
            const SizedBox(width: Insets.sm),
            // Řazení není filtr, ale patří sem ze stejného důvodu: rozhoduje
            // o tom, jak seznam vypadá, a bylo schované pod tlačítkem.
            FiltrVyber<OrderSort>(
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

/// Výběr více hodnot v okně se zaškrtávátky. Vrací vybrané hodnoty, nebo
/// `null`, když se okno zavřelo bez potvrzení. Hodnota, která v nabídce
/// není (uložená z dřívějška), se nabídne taky, ať jde odškrtnout.
Future<Set<T>?> vyberViceHodnot<T>(
  BuildContext context, {
  required String popisek,
  required Map<T, String> moznosti,
  required Set<T> vybrane,
}) {
  final nabidka = {
    ...moznosti,
    for (final h in vybrane)
      if (!moznosti.containsKey(h)) h: '$h',
  };
  return showDialog<Set<T>>(
    context: context,
    builder: (context) {
      var vyber = {...vybrane};
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(popisek),
          contentPadding: const EdgeInsets.symmetric(vertical: Insets.sm),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final MapEntry(:key, :value) in nabidka.entries)
                  CheckboxListTile(
                    value: vyber.contains(key),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(value),
                    onChanged: (zaskrtnuto) => setState(() {
                      vyber = zaskrtnuto ?? false
                          ? {...vyber, key}
                          : ({...vyber}..remove(key));
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('vyber-vice-vse'),
              onPressed: () => Navigator.of(context).pop(<T>{}),
              child: const Text('Vše'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zrušit'),
            ),
            FilledButton(
              key: const Key('vyber-vice-pouzit'),
              // Pořadí podle nabídky, ať se uložený filtr nemění podle klikání.
              onPressed: () => Navigator.of(context).pop({
                for (final h in nabidka.keys)
                  if (vyber.contains(h)) h,
              }),
              child: const Text('Použít'),
            ),
          ],
        ),
      );
    },
  );
}

/// Filtr s více hodnotami: vypadá jako rozbalovací seznam, klepnutím se
/// otevře okno se zaškrtávátky. Vybraný je barevný, ať je poznat, že
/// zužuje. Lišta zakázek i filtry plánu klempírny.
class FiltrVyberVice<T> extends StatelessWidget {
  const FiltrVyberVice({
    super.key,
    required this.popisek,
    required this.hodnoty,
    required this.moznosti,
    required this.onZmena,
  });

  final String popisek;
  final Set<T> hodnoty;

  /// Hodnota → co se zobrazí v nabídce.
  final Map<T, String> moznosti;

  final ValueChanged<Set<T>> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final aktivni = hodnoty.isNotEmpty;
    final text = switch (hodnoty.length) {
      0 => popisek,
      1 => moznosti[hodnoty.single] ?? '${hodnoty.single}',
      final pocet => '$popisek: $pocet',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.chip),
      onTap: moznosti.isEmpty && hodnoty.isEmpty
          ? null
          : () async {
              final vyber = await vyberViceHodnot(
                context,
                popisek: popisek,
                moznosti: moznosti,
                vybrane: hodnoty,
              );
              if (vyber != null) onZmena(vyber);
            },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        decoration: BoxDecoration(
          color: aktivni ? AppColors.primary : palette.background,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(
            color: aktivni ? AppColors.primary : palette.hairline2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppTextStyles.chip.copyWith(
                color: aktivni ? Colors.white : palette.muted2,
                fontWeight: aktivni ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: aktivni ? Colors.white70 : palette.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Jeden rozbalovací výběr jedné hodnoty - řazení. Lišta zakázek.
class FiltrVyber<T> extends StatelessWidget {
  const FiltrVyber({
    super.key,
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
