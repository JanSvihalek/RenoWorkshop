import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/stav_serveru.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../../fotodokumentace/presentation/controllers/fotky_providers.dart';
import '../../../fotodokumentace/presentation/ulozeni_do_zarizeni.dart';
import '../../domain/entities/nastaveni.dart';
import '../controllers/nastaveni_controller.dart';

/// Nastavení: přihlášený zaměstnanec a odhlášení v hlavičce, pod ní volby
/// po skupinách - vzhled a spuštění, skener, výchozí filtr, fotodokumentace
/// a údaje o aplikaci. Na tabletu ve dvou sloupcích.
///
/// Volby se ukládají do telefonu, ne k účtu - na sdíleném dílenském
/// přístroji jde o pohodlí toho, kdo ho drží v ruce.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Od téhle šířky obsahu jsou skupiny ve dvou sloupcích.
  static const sirkaProDvaSloupce = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    const vlevo = [_VzhledASpusteni(), _SkenerAFotoaparat()];
    const vpravo = [_VychoziFiltr(), _Fotodokumentace(), _OAplikaci()];

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _Hlavicka(onOdhlasit: () => _potvrdOdhlaseni(context, ref)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const odsazeni = EdgeInsets.fromLTRB(
                  Insets.xl,
                  Insets.xl,
                  Insets.xl,
                  Insets.giant,
                );
                if (constraints.maxWidth < sirkaProDvaSloupce) {
                  return ListView(
                    padding: odsazeni,
                    children: const [...vlevo, ...vpravo],
                  );
                }
                return SingleChildScrollView(
                  padding: odsazeni,
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: vlevo)),
                      SizedBox(width: Insets.xl),
                      Expanded(child: Column(children: vpravo)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Odhlášení se ptá schválně: dílenský telefon se drží v rukavicích
  /// a omylem odhlášený kolega se pak musí znovu prokazovat.
  Future<void> _potvrdOdhlaseni(BuildContext context, WidgetRef ref) async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Odhlásit se?'),
        content: const Text(
          'Příště se budete muset znovu přihlásit firemním účtem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            key: const Key('potvrdit-odhlaseni'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odhlásit'),
          ),
        ],
      ),
    );

    if (potvrzeno ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

/// Tmavá hlavička s názvem a kartou přihlášeného - odhlášení je u jména,
/// ne na konci dlouhého seznamu.
class _Hlavicka extends ConsumerWidget {
  const _Hlavicka({required this.onOdhlasit});

  final VoidCallback onOdhlasit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(currentEmployeeProvider);
    final palette = context.palette;

    return Container(
      width: double.infinity,
      decoration: dekoraceHlavicky(palette),
      padding: EdgeInsets.fromLTRB(
        Insets.xxl,
        MediaQuery.paddingOf(context).top + Insets.xl,
        Insets.xxl,
        Insets.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nastavení',
            style: AppTextStyles.appBarTitle(
              isIOS: context.isIOS,
            ).copyWith(color: palette.naHlavicce),
          ),
          if (employee != null) ...[
            const SizedBox(height: Insets.lg),
            _KartaUzivatele(employee: employee, onOdhlasit: onOdhlasit),
          ],
        ],
      ),
    );
  }
}

class _KartaUzivatele extends StatelessWidget {
  const _KartaUzivatele({required this.employee, required this.onOdhlasit});

  final Employee employee;
  final VoidCallback onOdhlasit;

  @override
  Widget build(BuildContext context) {
    // Pobočku zatím zná jen ukázkový účet - u Microsoft účtu se štítek
    // ukáže, až se pobočky namapují na skupiny v Entra ID.
    final pobocka = employee.homeBranch?.label;
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.hlavickaPrvek,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hlavickaOkraj),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              employee.initials,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: Insets.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      employee.displayName,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: palette.naHlavicce,
                      ),
                    ),
                    if (pobocka != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(Radii.badge),
                        ),
                        child: Text(
                          pobocka.toUpperCase(),
                          style: AppTextStyles.overline.copyWith(
                            color: context.isDarkMode
                                ? const Color(0xFF9CC8FF)
                                : AppColors.accent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${employee.email} · Microsoft SSO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metaSmall.copyWith(
                    color: palette.naHlavicceTlumene,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.base),
          OutlinedButton.icon(
            key: const Key('odhlasit'),
            onPressed: onOdhlasit,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Odhlásit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.naHlavicce,
              side: BorderSide(color: palette.hlavickaOkraj),
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.base,
              ),
              textStyle: AppTextStyles.cardBody.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.button),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skupiny

/// Režim vzhledu a záložka po spuštění.
class _VzhledASpusteni extends ConsumerWidget {
  const _VzhledASpusteni();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nastaveni = ref.watch(nastaveniProvider);
    final ovladani = ref.read(nastaveniProvider.notifier);

    return _Skupina(
      nadpis: 'VZHLED A SPUŠTĚNÍ',
      radky: [
        _Radek(
          titul: 'Režim',
          dole: _Prepinac<RezimVzhledu>(
            hodnoty: RezimVzhledu.values,
            vybrana: nastaveni.vzhled,
            popisek: (rezim) => rezim.label,
            onZmena: ovladani.zmenVzhled,
          ),
        ),
        _Radek(
          titul: 'Úvodní záložka',
          popis: 'Po spuštění a po přihlášení.',
          dole: _Prepinac<UvodniZalozka>(
            key: const Key('uvodni-zalozka'),
            hodnoty: UvodniZalozka.values,
            vybrana: nastaveni.uvodniZalozka,
            popisek: (zalozka) => zalozka.label,
            onZmena: ovladani.zmenUvodniZalozku,
          ),
        ),
      ],
    );
  }
}

/// Kde je spoušť a jestli se skener otevírá sám.
class _SkenerAFotoaparat extends ConsumerWidget {
  const _SkenerAFotoaparat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nastaveni = ref.watch(nastaveniProvider);
    final ovladani = ref.read(nastaveniProvider.notifier);

    return _Skupina(
      nadpis: 'SKENER A FOTOAPARÁT',
      radky: [
        _Radek(
          titul: 'Poloha spouště',
          popis: 'Platí pro focení, sken SPZ/VIN a tlačítko Zahájit příjem.',
          dole: _VolbaSpouste(
            vybrana: nastaveni.spoust,
            onZmena: ovladani.zmenSpoust,
          ),
        ),
        _Radek(
          titul: 'Skenovat hned po otevření',
          popis: 'Příjem a Vozidla otevřou rovnou skener SPZ.',
          vpravo: Switch.adaptive(
            key: const Key('skenovat-po-otevreni'),
            value: nastaveni.skenovatPoOtevreni,
            activeTrackColor: AppColors.accent,
            onChanged: ovladani.zmenSkenovaniPoOtevreni,
          ),
        ),
      ],
    );
  }
}

/// Útvar, pořadač a zodpovědná osoba, na které se seznam zakázek otevře.
class _VychoziFiltr extends ConsumerWidget {
  const _VychoziFiltr();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final nastaveni = ref.watch(nastaveniProvider);
    final ovladani = ref.read(nastaveniProvider.notifier);
    final utvary = ref.watch(availableDepartmentsProvider);
    final zodpovedni = ref.watch(mechanicsProvider);
    final poradace = ref.watch(pouzitePoradaceProvider);
    final aktivnich = [
      nastaveni.vychoziUtvar,
      nastaveni.vychoziPoradac,
      nastaveni.vychoziZodpovida,
    ].whereType<String>().length;

    return _Skupina(
      nadpis: 'VÝCHOZÍ FILTR ZÁKAZEK',
      vedleNadpisu: aktivnich == 0
          ? null
          : Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$aktivnich',
                style: AppTextStyles.metaSmall.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      akce: nastaveni.maVychoziFiltr
          ? _Odkaz(
              key: const Key('zrusit-vychozi-filtr'),
              text: 'Vymazat',
              onTap: ovladani.zrusVychoziFiltr,
            )
          : null,
      poznamka: 'Seznam zakázek se otevře rovnou takto vyfiltrovaný.',
      radky: utvary.isEmpty && poradace.isEmpty && zodpovedni.isEmpty
          ? [
              _Radek(
                obsah: Text(
                  'Útvary a lidé se nabídnou, jakmile se načtou zakázky.',
                  style: AppTextStyles.cardBody.copyWith(color: palette.muted),
                ),
              ),
            ]
          : [
              _Vyber(
                popisek: 'Útvar',
                hodnota: nastaveni.vychoziUtvar,
                moznosti: {for (final utvar in utvary) utvar.code: utvar.code},
                onZmena: ovladani.zmenVychoziUtvar,
              ),
              _Vyber(
                popisek: 'Pořadač',
                hodnota: nastaveni.vychoziPoradac,
                moznosti: {for (final p in poradace) p.kod: p.nazev},
                onZmena: ovladani.zmenVychoziPoradac,
              ),
              _Vyber(
                popisek: 'Zodpovídá',
                hodnota: nastaveni.vychoziZodpovida,
                moznosti: {for (final jmeno in zodpovedni) jmeno: jmeno},
                onZmena: ovladani.zmenVychoziZodpovida,
              ),
            ],
    );
  }
}

/// Složka pobočky pro fotky z příjmu a kopie fotek do zařízení.
class _Fotodokumentace extends ConsumerWidget {
  const _Fotodokumentace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nastaveni = ref.watch(nastaveniProvider);
    final pobocky = ref.watch(slozkyPobocekProvider);

    return _Skupina(
      nadpis: 'FOTODOKUMENTACE',
      radky: [
        _Vyber(
          key: const Key('slozka-fotek'),
          popisek: 'Pobočka',
          popis: pobocky.hasError
              ? 'Seznam poboček se nepodařilo načíst.'
              : 'Složka pobočky pro fotky z příjmu.',
          chybaVPopisu: pobocky.hasError,
          prazdnaVolba: 'Podle pořadače',
          hodnota: nastaveni.slozkaFotek,
          // Nabízí se jen složky, které ve Foto-doc opravdu jsou - server
          // jinou pobočku stejně odmítne.
          moznosti: {for (final p in pobocky.valueOrNull ?? const []) p: p},
          onZmena: (slozka) =>
              ref.read(nastaveniProvider.notifier).zmenSlozkuFotek(slozka),
        ),
        _Radek(
          titul: 'Ukládat i do zařízení',
          popis: 'Kopie v albu $albumFotek, i když se nenahrají.',
          vpravo: Switch.adaptive(
            key: const Key('ukladat-do-zarizeni'),
            value: nastaveni.ukladatFotkyDoZarizeni,
            activeTrackColor: AppColors.accent,
            onChanged: (zapnout) =>
                _zmenUkladaniDoZarizeni(context, ref, zapnout),
          ),
        ),
      ],
    );
  }

  /// Přístup ke galerii se žádá hned při zapnutí, ne až při focení -
  /// jinak by se na něj přišlo až v hale s první fotkou v ruce.
  Future<void> _zmenUkladaniDoZarizeni(
    BuildContext context,
    WidgetRef ref,
    bool zapnout,
  ) async {
    final nastaveni = ref.read(nastaveniProvider.notifier);
    if (!zapnout) {
      nastaveni.zmenUkladaniFotekDoZarizeni(false);
      return;
    }
    final povoleno = await ref.read(ulozeniDoZarizeniProvider).pozadejPristup();
    if (povoleno) {
      nastaveni.zmenUkladaniFotekDoZarizeni(true);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Bez přístupu k fotkám nejde ukládat do telefonu. '
              'Povolte ho aplikaci v nastavení telefonu.',
            ),
          ),
        );
    }
  }
}

/// Verze, spojení se serverem a zdroj dat - hodí se při hlášení chyby.
class _OAplikaci extends ConsumerWidget {
  const _OAplikaci();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final verze = ref.watch(verzeAplikaceProvider).valueOrNull;

    return _Skupina(
      nadpis: 'O APLIKACI',
      radky: [
        if (verze != null)
          _Radek(
            titul: 'Verze',
            vpravo: Text(
              verze,
              style: AppTextStyles.monoLabel.copyWith(color: palette.text),
            ),
          ),
        const _RadekServeru(),
        // Jen když build službu má - jinak jsou ukázková data jediná.
        if (ref.watch(buildSeSluzbouProvider))
          _Radek(
            titul: 'Ukázková data',
            popis:
                'Smyšlené zakázky místo Heliosu - pro prohlídku appky '
                'mimo firmu. Nic se neuloží do Heliosu ani na server.',
            vpravo: Switch.adaptive(
              key: const Key('ukazkova-data'),
              value: ref.watch(nastaveniProvider).ukazkovaData,
              activeTrackColor: AppColors.accent,
              onChanged: ref.read(nastaveniProvider.notifier).zmenUkazkovaData,
            ),
          ),
        _Radek(
          titul: 'Zdroj dat',
          // Ukázková data vypadají stejně jako ostrá, ale znamenají něco
          // jiného - při hlášení chyby je to první otázka.
          vpravo: Text(
            ref.watch(pouzivaApiProvider) ? 'Helios Data' : 'Ukázková data',
            style: AppTextStyles.cardBody.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Jestli se zařízení teď dostane na server - stejný údaj jako pod
/// přihlášením. Dokud server neodpovídá, zkouší se každých pár vteřin
/// znovu; klepnutí zkusí hned.
class _RadekServeru extends ConsumerWidget {
  const _RadekServeru();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    // Záložka nastavení zůstává postavená i na pozadí. Na server se ale
    // ptá, jen když je vidět - skrytá záložka má vypnutý TickerMode.
    final viditelne = TickerMode.valuesOf(context).enabled;
    final stav = viditelne
        ? ref.watch(stavServeruProvider).valueOrNull ?? StavServeru.zjistuje
        : StavServeru.zjistuje;
    final barva = switch (stav) {
      StavServeru.online => AppColors.readyGreen,
      StavServeru.nedostupny => AppColors.danger,
      StavServeru.ukazka || StavServeru.zjistuje => palette.muted,
    };

    return InkWell(
      key: const Key('nastaveni-stav-serveru'),
      onTap: () => ref.invalidate(stavServeruProvider),
      child: _Radek(
        titul: 'Server',
        // Nejčastější příčina je špatná wi-fi, ne vypnutá služba.
        popis: stav == StavServeru.nedostupny
            ? 'Zkontrolujte, že jste připojeni k firemní wi-fi '
                  '(RenPriv, ISPA nebo ISPI). Klepnutím zkusíte znovu.'
            : null,
        vpravo: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: barva, shape: BoxShape.circle),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              stav.popisek,
              style: AppTextStyles.cardBody.copyWith(
                color: stav == StavServeru.nedostupny
                    ? AppColors.danger
                    : palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stavební kameny

/// Nadpis skupiny nad kartou, karta s řádky oddělenými čarou a případně
/// vysvětlivka pod ní.
class _Skupina extends StatelessWidget {
  const _Skupina({
    required this.nadpis,
    required this.radky,
    this.vedleNadpisu,
    this.akce,
    this.poznamka,
  });

  final String nadpis;
  final List<Widget> radky;

  /// Hned za nadpisem - počet aktivních filtrů.
  final Widget? vedleNadpisu;

  /// Na konci řádku s nadpisem - „Vymazat".
  final Widget? akce;
  final String? poznamka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Insets.xxs, bottom: Insets.sm),
            child: Row(
              children: [
                Text(
                  nadpis,
                  style: AppTextStyles.overline.copyWith(color: palette.muted),
                ),
                if (vedleNadpisu != null) ...[
                  const SizedBox(width: Insets.sm),
                  vedleNadpisu!,
                ],
                const Spacer(),
                ?akce,
              ],
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: palette.hairline),
              boxShadow: palette.cardShadow,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, radek) in radky.indexed) ...[
                    if (i > 0) Divider(height: 1, color: palette.hairline),
                    radek,
                  ],
                ],
              ),
            ),
          ),
          if (poznamka != null)
            Padding(
              padding: const EdgeInsets.only(left: Insets.xxs, top: Insets.sm),
              child: Text(
                poznamka!,
                style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Řádek v kartě: název a vysvětlivka vlevo, ovladač vpravo nebo pod nimi.
class _Radek extends StatelessWidget {
  const _Radek({this.titul, this.popis, this.vpravo, this.dole, this.obsah});

  final String? titul;
  final String? popis;
  final Widget? vpravo;
  final Widget? dole;

  /// Místo názvu a popisu vlastní obsah (prázdný stav).
  final Widget? obsah;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final texty =
        obsah ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titul != null)
              Text(
                titul!,
                style: AppTextStyles.cardBody.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (popis != null) ...[
              const SizedBox(height: 2),
              Text(
                popis!,
                style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
              ),
            ],
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: texty),
              if (vpravo != null) ...[
                const SizedBox(width: Insets.base),
                vpravo!,
              ],
            ],
          ),
          if (dole != null) ...[const SizedBox(height: Insets.md), dole!],
        ],
      ),
    );
  }
}

/// Přepínač z několika voleb - vybraná je „vystouplá" z podkladu. Velké
/// terče se v rukavicích trefují líp než položky rozbalovacího seznamu.
class _Prepinac<T> extends StatelessWidget {
  const _Prepinac({
    super.key,
    required this.hodnoty,
    required this.vybrana,
    required this.popisek,
    required this.onZmena,
  });

  final List<T> hodnoty;
  final T vybrana;
  final String Function(T hodnota) popisek;
  final ValueChanged<T> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          for (final hodnota in hodnoty)
            Expanded(
              child: Semantics(
                button: true,
                selected: hodnota == vybrana,
                child: GestureDetector(
                  onTap: () => onZmena(hodnota),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hodnota == vybrana
                          ? palette.card
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.button - 3),
                      border: hodnota == vybrana
                          ? Border.all(color: palette.hairline2)
                          : null,
                      boxShadow: hodnota == vybrana ? palette.cardShadow : null,
                    ),
                    child: Text(
                      popisek(hodnota),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardBody.copyWith(
                        color: hodnota == vybrana
                            ? palette.text
                            : palette.muted,
                        fontWeight: hodnota == vybrana
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tři dlaždice s obrázkem tabletu a tečkou, kde je spoušť.
class _VolbaSpouste extends StatelessWidget {
  const _VolbaSpouste({required this.vybrana, required this.onZmena});

  final UmisteniSpouste vybrana;
  final ValueChanged<UmisteniSpouste> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        for (final (i, umisteni) in UmisteniSpouste.values.indexed) ...[
          if (i > 0) const SizedBox(width: Insets.md),
          Expanded(
            child: Semantics(
              button: true,
              selected: umisteni == vybrana,
              label: 'Spoušť ${umisteni.label.toLowerCase()}',
              child: GestureDetector(
                key: Key('spoust-${umisteni.name}'),
                onTap: () => onZmena(umisteni),
                behavior: HitTestBehavior.opaque,
                child: _DlazdiceSpouste(
                  umisteni: umisteni,
                  vybrana: umisteni == vybrana,
                  palette: palette,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DlazdiceSpouste extends StatelessWidget {
  const _DlazdiceSpouste({
    required this.umisteni,
    required this.vybrana,
    required this.palette,
  });

  final UmisteniSpouste umisteni;
  final bool vybrana;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final barva = vybrana ? AppColors.accent : palette.muted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(
        Insets.sm,
        Insets.base,
        Insets.sm,
        Insets.md,
      ),
      decoration: BoxDecoration(
        color: vybrana
            ? AppColors.accent.withValues(alpha: 0.08)
            : palette.background,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(
          color: vybrana ? AppColors.accent : palette.hairline,
          width: vybrana ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Tablet na šířku s tečkou tam, kde bude spoušť.
          Container(
            width: 58,
            height: 38,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: barva.withValues(alpha: 0.7)),
            ),
            child: Align(
              alignment: switch (umisteni) {
                UmisteniSpouste.vlevo => Alignment.centerLeft,
                UmisteniSpouste.dole => Alignment.bottomCenter,
                UmisteniSpouste.vpravo => Alignment.centerRight,
              },
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: barva, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            umisteni.label,
            style: AppTextStyles.cardBody.copyWith(
              color: vybrana ? palette.text : palette.muted,
              fontWeight: vybrana ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Řádek s rozbalovacím výběrem. `null` znamená „vše" ([prazdnaVolba]).
class _Vyber extends StatelessWidget {
  const _Vyber({
    super.key,
    required this.popisek,
    required this.hodnota,
    required this.moznosti,
    required this.onZmena,
    this.popis,
    this.chybaVPopisu = false,
    this.prazdnaVolba = 'Vše',
  });

  final String popisek;
  final String? popis;
  final bool chybaVPopisu;
  final String? hodnota;
  final Map<String, String> moznosti;
  final ValueChanged<String?> onZmena;
  final String prazdnaVolba;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Uložená volba, která zrovna mezi načtenými zakázkami není (technik
    // dnes žádnou nemá), se nabídne i tak. Jinak by výběr ukazoval „Vše",
    // přestože filtr platí a seznam je kvůli němu prázdný.
    final vybrana = hodnota;
    final vsechny = {
      ...moznosti,
      if (vybrana != null && !moznosti.containsKey(vybrana)) vybrana: vybrana,
    };

    final popisky = [prazdnaVolba, ...vsechny.values];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.base,
      ),
      child: Row(
        // Výběr k pravému okraji, i když název vlevo zabere míň než půlku.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nejvýš polovina řádku - delší vysvětlivka se zalomí, výběr
          // vpravo zůstane celý.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  popisek,
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (popis != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    popis!,
                    style: AppTextStyles.metaSmall.copyWith(
                      color: chybaVPopisu ? AppColors.danger : palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.base),
          // Výběr vyplní zbytek řádku a dlouhé jméno zkrátí třemi tečkami -
          // jinak by „Bc. Jaroslava Nováková-Dvořáčková" vytlačila šipku
          // za okraj karty.
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: vybrana,
                isDense: true,
                isExpanded: true,
                borderRadius: BorderRadius.circular(Radii.input),
                icon: Icon(Icons.expand_more_rounded, color: palette.muted),
                style: AppTextStyles.cardBody.copyWith(color: palette.text),
                // Zvolená hodnota tučně, „Vše" obyčejně - na první pohled je
                // vidět, co filtr opravdu omezuje.
                selectedItemBuilder: (_) => [
                  for (final (i, text) in popisky.indexed)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.text,
                          fontWeight: i == 0
                              ? FontWeight.w400
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                ],
                items: [
                  DropdownMenuItem(value: null, child: Text(prazdnaVolba)),
                  for (final polozka in vsechny.entries)
                    DropdownMenuItem(
                      value: polozka.key,
                      child: Text(
                        polozka.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onZmena,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modrý textový odkaz v záhlaví skupiny.
class _Odkaz extends StatelessWidget {
  const _Odkaz({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xxs),
        child: Text(
          text,
          style: AppTextStyles.metaSmall.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
