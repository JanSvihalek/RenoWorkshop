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

/// Nastavení: přihlášený zaměstnanec, vzhled, výchozí filtr seznamu
/// a odhlášení.
///
/// Volby se ukládají do telefonu, ne k účtu - na sdíleném dílenském
/// přístroji jde o pohodlí toho, kdo ho drží v ruce.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final employee = ref.watch(currentEmployeeProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.xl,
                Insets.xl,
                Insets.giant,
              ),
              children: [
                if (employee != null) _EmployeeCard(employee: employee),
                const SizedBox(height: Insets.base),
                const _VzhledCard(),
                const SizedBox(height: Insets.base),
                const _SkenerCard(),
                const SizedBox(height: Insets.base),
                const _VychoziFiltrCard(),
                const SizedBox(height: Insets.base),
                const _FotodokumentaceCard(),
                const SizedBox(height: Insets.base),
                const _AboutCard(),
                const SizedBox(height: Insets.huge),
                _SignOutButton(onSignOut: () => _confirmSignOut(context, ref)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Odhlášení se ptá schválně: dílenský telefon se drží v rukavicích
  /// a omylem odhlášený kolega se pak musí znovu prokazovat.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.xxl,
        topInset + Insets.xl,
        Insets.xxl,
        Insets.xl,
      ),
      child: Text(
        'Nastavení',
        style: AppTextStyles.appBarTitle(
          isIOS: context.isIOS,
        ).copyWith(color: Colors.white),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _Card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              employee.initials,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.displayName,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.email,
                  style: AppTextStyles.meta.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Volba světlého a tmavého vzhledu.
class _VzhledCard extends ConsumerWidget {
  const _VzhledCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vybrany = ref.watch(nastaveniProvider).vzhled;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VZHLED',
            style: AppTextStyles.overline.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.base),
          // Přepínač přes celou šířku - tři velké terče se trefují líp
          // než položky v rozbalovacím seznamu.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<RezimVzhledu>(
              segments: [
                for (final rezim in RezimVzhledu.values)
                  ButtonSegment(value: rezim, label: Text(rezim.label)),
              ],
              selected: {vybrany},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                textStyle: AppTextStyles.cardBody,
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: Colors.white,
              ),
              onSelectionChanged: (vyber) =>
                  ref.read(nastaveniProvider.notifier).zmenVzhled(vyber.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kde je spoušť na obrazovce skeneru.
class _SkenerCard extends ConsumerWidget {
  const _SkenerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vybrane = ref.watch(nastaveniProvider).spoust;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPOUŠŤ SKENERU',
            style: AppTextStyles.overline.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            'Kde je tlačítko na vyfocení SPZ a VINu. Na tabletu na šířku je '
            'po straně blíž palci.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted2),
          ),
          const SizedBox(height: Insets.base),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<UmisteniSpouste>(
              segments: [
                for (final umisteni in UmisteniSpouste.values)
                  ButtonSegment(value: umisteni, label: Text(umisteni.label)),
              ],
              selected: {vybrane},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                textStyle: AppTextStyles.cardBody,
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: Colors.white,
              ),
              onSelectionChanged: (vyber) =>
                  ref.read(nastaveniProvider.notifier).zmenSpoust(vyber.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// Útvar, na který se seznam zakázek otevře.
class _VychoziFiltrCard extends ConsumerWidget {
  const _VychoziFiltrCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final nastaveni = ref.watch(nastaveniProvider);
    final utvary = ref.watch(availableDepartmentsProvider);
    final zodpovedni = ref.watch(mechanicsProvider);
    final poradace = ref.watch(pouzitePoradaceProvider);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VÝCHOZÍ FILTR',
                style: AppTextStyles.overline.copyWith(color: palette.muted),
              ),
              if (nastaveni.maVychoziFiltr)
                GestureDetector(
                  onTap: () =>
                      ref.read(nastaveniProvider.notifier).zrusVychoziFiltr(),
                  child: Text(
                    'Zrušit',
                    style: AppTextStyles.metaSmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            'Seznam zakázek se otevře rovnou takto vyfiltrovaný.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted2),
          ),
          const SizedBox(height: Insets.base),
          if (utvary.isEmpty && poradace.isEmpty && zodpovedni.isEmpty)
            Text(
              'Útvary a lidé se nabídnou, jakmile se načtou zakázky.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            )
          else ...[
            _Vyber(
              popisek: 'Útvar',
              hodnota: nastaveni.vychoziUtvar,
              moznosti: {for (final utvar in utvary) utvar.code: utvar.code},
              onZmena: (kod) =>
                  ref.read(nastaveniProvider.notifier).zmenVychoziUtvar(kod),
            ),
            const SizedBox(height: Insets.base),
            _Vyber(
              popisek: 'Pořadač',
              hodnota: nastaveni.vychoziPoradac,
              moznosti: {for (final p in poradace) p.kod: p.nazev},
              onZmena: (kod) =>
                  ref.read(nastaveniProvider.notifier).zmenVychoziPoradac(kod),
            ),
            const SizedBox(height: Insets.base),
            _Vyber(
              popisek: 'Zodpovídá',
              hodnota: nastaveni.vychoziZodpovida,
              moznosti: {for (final jmeno in zodpovedni) jmeno: jmeno},
              onZmena: (jmeno) => ref
                  .read(nastaveniProvider.notifier)
                  .zmenVychoziZodpovida(jmeno),
            ),
          ],
        ],
      ),
    );
  }
}

/// Složka pobočky, kam se ukládají fotky z příjmu.
class _FotodokumentaceCard extends ConsumerWidget {
  const _FotodokumentaceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final nastaveni = ref.watch(nastaveniProvider);
    final slozka = nastaveni.slozkaFotek;
    final pobocky = ref.watch(slozkyPobocekProvider);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FOTODOKUMENTACE',
            style: AppTextStyles.overline.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            'Do které složky pobočky se ukládají fotky z příjmu. Bez volby '
            'rozhodne pořadač zakázky.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted2),
          ),
          const SizedBox(height: Insets.base),
          _Vyber(
            key: const Key('slozka-fotek'),
            popisek: 'Pobočka',
            prazdnaVolba: 'Podle pořadače',
            hodnota: slozka,
            // Nabízí se jen složky, které ve Foto-doc opravdu jsou - server
            // jinou pobočku stejně odmítne.
            moznosti: {for (final p in pobocky.valueOrNull ?? const []) p: p},
            onZmena: (slozka) =>
                ref.read(nastaveniProvider.notifier).zmenSlozkuFotek(slozka),
          ),
          if (pobocky.hasError) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Seznam poboček se nepodařilo načíst.',
              style: AppTextStyles.metaSmall.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: Insets.base),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ukládat i do telefonu',
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fotky z fotoaparátu se hned uloží i do galerie, album '
                      '$albumFotek. Nepřijdete o ně, ani když se nenahrají.',
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.base),
              Switch.adaptive(
                key: const Key('ukladat-do-zarizeni'),
                value: nastaveni.ukladatFotkyDoZarizeni,
                activeTrackColor: AppColors.accent,
                onChanged: (zapnout) =>
                    _zmenUkladaniDoZarizeni(context, ref, zapnout),
              ),
            ],
          ),
        ],
      ),
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

/// Řádek s rozbalovacím výběrem. `null` znamená „vše" ([prazdnaVolba]).
class _Vyber extends StatelessWidget {
  const _Vyber({
    super.key,
    required this.popisek,
    required this.hodnota,
    required this.moznosti,
    required this.onZmena,
    this.prazdnaVolba = 'Vše',
  });

  final String popisek;
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

    return Row(
      children: [
        Text(
          popisek,
          style: AppTextStyles.cardBody.copyWith(color: palette.muted),
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
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
              selectedItemBuilder: (_) => [
                for (final text in popisky)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final verze = ref.watch(verzeAplikaceProvider).valueOrNull;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O APLIKACI',
            style: AppTextStyles.overline.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.md),
          _Row(
            label: 'Zdroj dat',
            // Užitečné při hlášení chyby: ukázková data vypadají stejně
            // jako ostrá, ale znamenají něco jiného.
            value: ref.watch(pouzivaApiProvider)
                ? 'Helios Data'
                : 'Ukázková data',
          ),
          const SizedBox(height: Insets.sm),
          const _RadekServeru(),
          const SizedBox(height: Insets.sm),
          const _Row(label: 'Přihlášení', value: 'Firemní účet Microsoft'),
          if (verze != null) ...[
            const SizedBox(height: Insets.sm),
            _Row(label: 'Verze aplikace', value: verze),
          ],
        ],
      ),
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
    final stav =
        ref.watch(stavServeruProvider).valueOrNull ?? StavServeru.zjistuje;
    final (text, barva) = switch (stav) {
      StavServeru.online => ('Připojeno', AppColors.readyGreen),
      StavServeru.nedostupny => ('Nedostupný', AppColors.danger),
      StavServeru.ukazka => ('Ukázková data', palette.muted),
      StavServeru.zjistuje => ('Zjišťuji…', palette.muted),
    };

    return InkWell(
      key: const Key('nastaveni-stav-serveru'),
      onTap: () => ref.invalidate(stavServeruProvider),
      borderRadius: BorderRadius.circular(Radii.input),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Server',
                  style: AppTextStyles.cardBody.copyWith(color: palette.muted),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: barva, shape: BoxShape.circle),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                text,
                style: AppTextStyles.cardBody.copyWith(
                  color: stav == StavServeru.nedostupny
                      ? AppColors.danger
                      : palette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // Nejčastější příčina je špatná wi-fi, ne vypnutá služba.
          if (stav == StavServeru.nedostupny)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xxs),
              child: Text(
                'Zkontrolujte, že jste připojeni k firemní wi-fi '
                '(RenPriv, ISPA nebo ISPI). Klepnutím zkusíte znovu.',
                style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.cardBody.copyWith(color: palette.muted),
        ),
        Text(
          value,
          style: AppTextStyles.cardBody.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      child: child,
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: Sizes.ctaHeight,
      child: OutlinedButton.icon(
        onPressed: onSignOut,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Odhlásit se'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: palette.hairline2),
          textStyle: AppTextStyles.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              context.isIOS ? Radii.ctaIos : Radii.ctaAndroid,
            ),
          ),
        ),
      ),
    );
  }
}
