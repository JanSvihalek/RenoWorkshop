import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/hlavicka_zakazky.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../domain/entities/dokument.dart';
import '../../domain/entities/fotka.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';
import '../controllers/fotky_providers.dart';
import '../prace_s_dokumenty.dart';
import '../ulozeni_do_zarizeni.dart';
import '../ziskani_fotek.dart';

/// Fotodokumentace zakázky - samostatná obrazovka z detailu zakázky.
class FotodokumentaceScreen extends ConsumerWidget {
  const FotodokumentaceScreen({
    super.key,
    required this.orderId,
    required this.onBack,
  });

  final String orderId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zakazka = ref.watch(orderByIdProvider(orderId)).valueOrNull;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: Column(
        children: [
          HlavickaZakazky(
            nadpis: 'Fotodokumentace',
            onBack: onBack,
            spz: zakazka?.licensePlate,
            model: zakazka?.model,
            cisloZakazky: orderId,
          ),
          Expanded(child: FotodokumentaceObsah(orderId: orderId)),
        ],
      ),
    );
  }
}

/// Karta na každou kategorii fotek. Samostatně ve fotodokumentaci
/// i jako krok příjmu vozidla.
///
/// Fotky se nahrávají hned po pořízení, jedna za druhou. Když nahrání
/// selže (hala bez signálu), fotka zůstane na kartě s červeným rámečkem
/// a jde poslat znovu.
class FotodokumentaceObsah extends ConsumerStatefulWidget {
  const FotodokumentaceObsah({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<FotodokumentaceObsah> createState() =>
      _FotodokumentaceObsahState();
}

class _FotodokumentaceObsahState extends ConsumerState<FotodokumentaceObsah> {
  /// Id vybraných fotek. Prázdné = běžný režim, klepnutí fotku otevře.
  final Set<String> _vybrane = {};
  bool _maze = false;

  /// Kolik vybraných dokumentů ještě čeká na nahrání.
  int _nahravaDokumentu = 0;

  /// Id dokumentu, který se právě stahuje k zobrazení.
  String? _oteviraDokument;

  String get orderId => widget.orderId;

  Future<void> _zGalerie(KategorieFotky kategorie) async {
    final fotky = await ref.read(ziskaniFotekProvider).zGalerie(context);
    if (fotky.isEmpty) return;
    await ref
        .read(nahravaniFotekProvider(orderId).notifier)
        .pridej(kategorie, fotky);
  }

  Future<void> _fotit(KategorieFotky kategorie) {
    final nahravani = ref.read(nahravaniFotekProvider(orderId).notifier);
    return ref
        .read(ziskaniFotekProvider)
        .foceni(
          context,
          nadpis: kategorie.nazev,
          onFotka: (fotka) {
            // Do telefonu jen z fotoaparátu - fotky z galerie v něm už jsou.
            // Záloha běží vedle nahrávání a nečeká se na ni.
            if (ref.read(nastaveniProvider).ukladatFotkyDoZarizeni) {
              _ulozDoZarizeni(kategorie, fotka);
            }
            nahravani.pridej(kategorie, [fotka]);
          },
        );
  }

  Future<void> _ulozDoZarizeni(
    KategorieFotky kategorie,
    Uint8List fotka,
  ) async {
    try {
      await ref
          .read(ulozeniDoZarizeniProvider)
          .uloz(
            fotka,
            nazev: nazevFotkyVZarizeni(orderId, kategorie, DateTime.now()),
          );
    } catch (chyba) {
      // Technik spoléhá, že fotku v telefonu má - když tam není, musí to
      // vědět hned, ne až ji bude hledat.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              chyba is UlozeniDoZarizeniException
                  ? chyba.message
                  : 'Fotku se nepodařilo uložit do telefonu.',
            ),
          ),
        );
    }
  }

  void _oznam(String zprava) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(zprava)));
  }

  /// Vybere dokumenty v zařízení a nahraje je jeden po druhém. Co nejde
  /// (moc velký soubor, odmítnutý typ), se oznámí a ostatní se nahrají.
  Future<void> _nahrajDokumenty() async {
    final List<VybranySoubor> soubory;
    try {
      soubory = await ref.read(praceSDokumentyProvider).vyber();
    } on PraceSDokumentyException catch (chyba) {
      _oznam(chyba.message);
      return;
    }
    if (soubory.isEmpty || !mounted) return;

    final zdroj = ref.read(fotkyDataSourceProvider);
    String? chyba;
    setState(() => _nahravaDokumentu = soubory.length);
    for (final soubor in soubory) {
      try {
        if (soubor.velikost > maxVelikostDokumentu) {
          chyba =
              '${soubor.nazev} je větší než '
              '${velikostSouboru(maxVelikostDokumentu)}.';
          continue;
        }
        await zdroj.nahrajDokument(
          orderId,
          soubor.nazev,
          await soubor.nacti(),
          // Do stejné pobočky jako fotky zakázky.
          pobocka: ref.read(nastaveniProvider).slozkaFotek,
        );
      } on ServiceOrderException catch (e) {
        chyba = e.message;
      } catch (_) {
        chyba = '${soubor.nazev} se nepodařilo nahrát.';
      } finally {
        if (mounted) setState(() => _nahravaDokumentu--);
      }
    }

    ref.invalidate(dokumentyZakazkyProvider(orderId));
    if (chyba != null) _oznam(chyba);
  }

  /// Stáhne dokument a ukáže ho.
  Future<void> _otevriDokument(Dokument dokument) async {
    if (_oteviraDokument != null) return;
    setState(() => _oteviraDokument = dokument.id);
    try {
      final data = await ref
          .read(fotkyDataSourceProvider)
          .stahniDokument(orderId, dokument.id);
      await ref.read(praceSDokumentyProvider).otevri(dokument.nazev, data);
    } on ServiceOrderException catch (chyba) {
      _oznam(chyba.message);
    } on PraceSDokumentyException catch (chyba) {
      _oznam(chyba.message);
    } catch (_) {
      _oznam('Dokument se nepodařilo otevřít.');
    } finally {
      if (mounted) setState(() => _oteviraDokument = null);
    }
  }

  /// Klepnutí na fotku: v běžném režimu otevře, ve výběru přidá a ubere.
  void _klepnuti(Fotka fotka) {
    if (_vybrane.isEmpty) {
      _ProhlizeniFotky.otevri(context, orderId: orderId, fotka: fotka);
      return;
    }
    _prepni(fotka);
  }

  void _prepni(Fotka fotka) => setState(() {
    if (!_vybrane.remove(fotka.id)) _vybrane.add(fotka.id);
  });

  void _zrusVyber() => setState(_vybrane.clear);

  /// Smaže vybrané fotky. Maže se po jedné; co se nepovede, zůstane
  /// vybrané, ať jde zkusit znovu.
  Future<void> _smazVybrane() async {
    final pocet = _vybrane.length;
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Smazat ${pocetFotek(pocet)}?'),
        content: const Text(
          'Fotky se smažou i ze sdílené složky. Vrátit to nejde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (!(potvrzeno ?? false) || !mounted) return;

    setState(() => _maze = true);
    final zdroj = ref.read(fotkyDataSourceProvider);
    String? chyba;
    for (final id in _vybrane.toList()) {
      try {
        await zdroj.smazFotku(id);
        _vybrane.remove(id);
      } catch (e) {
        chyba = e is ServiceOrderException
            ? e.message
            : 'Fotku se nepodařilo smazat.';
      }
    }

    ref.invalidate(fotkyZakazkyProvider(orderId));
    if (!mounted) return;
    setState(() => _maze = false);
    if (chyba != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(chyba)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotky = ref.watch(fotkyZakazkyProvider(orderId));
    final nahravane = ref.watch(nahravaniFotekProvider(orderId));
    final dokumenty = ref.watch(dokumentyZakazkyProvider(orderId));

    return Column(
      children: [
        if (_vybrane.isNotEmpty)
          _ListaVyberu(
            pocet: _vybrane.length,
            maze: _maze,
            onZrusit: _zrusVyber,
            onSmazat: _smazVybrane,
          ),
        if (fotky.hasError)
          _ChybaNacteni(
            zprava: fotky.error is ServiceOrderException
                ? (fotky.error! as ServiceOrderException).message
                : 'Fotky se nepodařilo načíst.',
            onZnovu: () => ref.invalidate(fotkyZakazkyProvider(orderId)),
          ),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(fotkyZakazkyProvider(orderId));
              ref.invalidate(dokumentyZakazkyProvider(orderId));
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.lg,
                Insets.xl,
                Insets.giant + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: KategorieFotky.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
              itemBuilder: (context, index) {
                final kategorie = KategorieFotky.values[index];
                return _KartaKategorie(
                  kategorie: kategorie,
                  nacita: fotky.isLoading && !fotky.hasValue,
                  fotky: [
                    for (final fotka in fotky.valueOrNull ?? const <Fotka>[])
                      if (fotka.kategorie == kategorie) fotka,
                  ],
                  nahravane: [
                    for (final fotka in nahravane)
                      if (fotka.kategorie == kategorie) fotka,
                  ],
                  onGalerie: () => _zGalerie(kategorie),
                  onFotit: () => _fotit(kategorie),
                  vybrane: _vybrane,
                  onOtevrit: _klepnuti,
                  onVybrat: _prepni,
                  onNahravana: _nabidkaNahravane,
                  // Ostatní dokumentace má navíc dokumenty ze složky
                  // zakázky - PDF i cokoli mimo ostatní kategorie.
                  dokumenty: kategorie == KategorieFotky.ostatni
                      ? _DokumentyKategorie(
                          dokumenty: dokumenty,
                          nahrava: _nahravaDokumentu,
                          oteviraId: _oteviraDokument,
                          onNahrat: _nahrajDokumenty,
                          onOtevrit: _otevriDokument,
                          onZnovu: () =>
                              ref.invalidate(dokumentyZakazkyProvider(orderId)),
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _nabidkaNahravane(NahravanaFotka fotka) async {
    if (!fotka.selhala) return;
    final nahravani = ref.read(nahravaniFotekProvider(orderId).notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: Text(
                fotka.chyba ?? '',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardBody.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ),
            const SizedBox(height: Insets.base),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Zkusit znovu'),
              onTap: () {
                Navigator.of(sheet).pop();
                nahravani.znovu(fotka.klic);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Zahodit fotku'),
              onTap: () {
                Navigator.of(sheet).pop();
                nahravani.zahod(fotka.klic);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChybaNacteni extends StatelessWidget {
  const _ChybaNacteni({required this.zprava, required this.onZnovu});

  final String zprava;
  final VoidCallback onZnovu;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.danger.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              zprava,
              style: AppTextStyles.cardBody.copyWith(color: AppColors.danger),
            ),
          ),
          TextButton(onPressed: onZnovu, child: const Text('Znovu')),
        ],
      ),
    );
  }
}

/// Karta jedné kategorie: ikona, název, přidání z galerie, focení
/// a miniatury pořízených fotek.
class _KartaKategorie extends StatelessWidget {
  const _KartaKategorie({
    required this.kategorie,
    required this.nacita,
    required this.fotky,
    required this.nahravane,
    required this.onGalerie,
    required this.onFotit,
    required this.vybrane,
    required this.onOtevrit,
    required this.onVybrat,
    required this.onNahravana,
    this.dokumenty,
  });

  final KategorieFotky kategorie;
  final bool nacita;
  final List<Fotka> fotky;
  final List<NahravanaFotka> nahravane;
  final VoidCallback onGalerie;
  final VoidCallback onFotit;

  /// Id vybraných fotek napříč všemi kategoriemi.
  final Set<String> vybrane;
  final void Function(Fotka fotka) onOtevrit;

  /// Dlouhý stisk: zapne výběr, případně fotku z výběru zase vyřadí.
  final void Function(Fotka fotka) onVybrat;
  final void Function(NahravanaFotka fotka) onNahravana;

  /// Dokumenty - jen u Ostatní dokumentace.
  final _DokumentyKategorie? dokumenty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pocet = fotky.length + nahravane.length;
    final pocetDok = dokumenty?.pocet ?? 0;
    // Zelený rámeček: kategorie je nafocená. Na první pohled je vidět, co
    // při obchůzce ještě chybí.
    final hotovo = fotky.isNotEmpty || pocetDok > 0;
    final souhrn = [
      if (pocet > 0) pocetFotek(pocet),
      if (pocetDok > 0) pocetDokumentu(pocetDok),
    ].join(' · ');

    return Container(
      key: Key('kategorie-${kategorie.klic}'),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card + 4),
        border: Border.all(
          color: hotovo
              ? AppColors.heliosGreen.withValues(alpha: 0.6)
              : palette.hairline,
          width: hotovo ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.base,
        Insets.sm,
        Insets.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kategorie.ikona, color: AppColors.accent, size: 28),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kategorie.nazev,
                      style: AppTextStyles.cardModel.copyWith(
                        color: palette.text,
                      ),
                    ),
                    if (souhrn.isNotEmpty)
                      Text(
                        souhrn,
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.muted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Přidat z galerie',
                onPressed: onGalerie,
                icon: Icon(Icons.photo_library_rounded, color: palette.muted),
              ),
              ?dokumenty?.tlacitko(context),
              IconButton(
                tooltip: 'Vyfotit',
                onPressed: onFotit,
                icon: const Icon(
                  Icons.add_a_photo_rounded,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          if (pocet > 0) ...[
            const SizedBox(height: Insets.sm),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Rozpracované první - na ty technik právě čeká.
                  for (final fotka in nahravane)
                    _MiniaturaNahravana(
                      fotka: fotka,
                      onTap: () => onNahravana(fotka),
                    ),
                  for (final fotka in fotky)
                    _Miniatura(
                      fotka: fotka,
                      vybrana: vybrane.contains(fotka.id),
                      onTap: () => onOtevrit(fotka),
                      onLongPress: () => onVybrat(fotka),
                    ),
                ],
              ),
            ),
          ] else if (nacita)
            const Padding(
              padding: EdgeInsets.only(top: Insets.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ?dokumenty,
        ],
      ),
    );
  }
}

/// Dokumenty v kartě Ostatní dokumentace: tlačítko pro nahrání do hlavičky
/// karty a seznam pod miniaturami fotek. Nahrané z aplikace i cokoli, co
/// kolega vložil do složky zakázky mimo ostatní kategorie.
class _DokumentyKategorie extends StatelessWidget {
  const _DokumentyKategorie({
    required this.dokumenty,
    required this.nahrava,
    required this.oteviraId,
    required this.onNahrat,
    required this.onOtevrit,
    required this.onZnovu,
  });

  final AsyncValue<List<Dokument>> dokumenty;

  /// Kolik souborů se ještě nahrává; 0 = nic.
  final int nahrava;
  final String? oteviraId;
  final VoidCallback onNahrat;
  final void Function(Dokument dokument) onOtevrit;
  final VoidCallback onZnovu;

  int get pocet => dokumenty.valueOrNull?.length ?? 0;

  /// Nahrání dokumentu - vedle galerie a focení v hlavičce karty.
  Widget tlacitko(BuildContext context) {
    if (nahrava > 0) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      key: const Key('nahrat-dokument'),
      tooltip: 'Nahrát dokument (PDF…)',
      onPressed: onNahrat,
      icon: Icon(Icons.upload_file_rounded, color: context.palette.muted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seznam = dokumenty.valueOrNull ?? const <Dokument>[];

    if (dokumenty.hasError && !dokumenty.hasValue) {
      return Row(
        children: [
          Expanded(
            child: Text(
              dokumenty.error is ServiceOrderException
                  ? (dokumenty.error! as ServiceOrderException).message
                  : 'Dokumenty se nepodařilo načíst.',
              style: AppTextStyles.metaSmall.copyWith(color: AppColors.danger),
            ),
          ),
          TextButton(onPressed: onZnovu, child: const Text('Znovu')),
        ],
      );
    }

    return Column(
      key: const Key('dokumenty'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nahrava > 0)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              'Nahrávám dokumenty… (zbývá $nahrava)',
              style: AppTextStyles.metaSmall.copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
        if (seznam.isNotEmpty) const SizedBox(height: Insets.xs),
        for (final dokument in seznam)
          _RadekDokumentu(
            dokument: dokument,
            otevira: oteviraId == dokument.id,
            onTap: () => onOtevrit(dokument),
          ),
      ],
    );
  }
}

class _RadekDokumentu extends StatelessWidget {
  const _RadekDokumentu({
    required this.dokument,
    required this.otevira,
    required this.onTap,
  });

  final Dokument dokument;
  final bool otevira;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final popis = [
      velikostSouboru(dokument.velikost),
      AppDateFormat.dateTime(dokument.zmenenoAt),
      // Soubor mimo složku Ostatni - ať ho kolega na serveru najde.
      ?dokument.umisteni,
    ].join(' · ');

    return InkWell(
      key: Key('dokument-${dokument.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          children: [
            Icon(dokument.ikona, color: palette.muted, size: 26),
            const SizedBox(width: Insets.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dokument.nazev,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    popis,
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              child: otevira
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(Icons.chevron_right_rounded, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Miniatura extends ConsumerWidget {
  const _Miniatura({
    required this.fotka,
    required this.vybrana,
    required this.onTap,
    required this.onLongPress,
  });

  final Fotka fotka;
  final bool vybrana;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final obrazek = ref.watch(obrazekFotkyProvider(fotka.id));

    return Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.input),
              child: Container(
                width: 80,
                height: 80,
                color: palette.plate,
                foregroundDecoration: vybrana
                    ? BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(Radii.input),
                        border: Border.all(color: AppColors.accent, width: 3),
                      )
                    : null,
                child: obrazek.when(
                  data: (bajty) => Image.memory(
                    bajty,
                    fit: BoxFit.cover,
                    // Dekódovat jen v rozměru miniatury, ne 2000 px.
                    cacheWidth: 240,
                    gaplessPlayback: true,
                  ),
                  loading: () => const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) =>
                      Icon(Icons.broken_image_outlined, color: palette.muted),
                ),
              ),
            ),
            if (vybrana)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lišta nad kategoriemi, když je něco vybrané.
class _ListaVyberu extends StatelessWidget {
  const _ListaVyberu({
    required this.pocet,
    required this.maze,
    required this.onZrusit,
    required this.onSmazat,
  });

  final int pocet;
  final bool maze;
  final VoidCallback onZrusit;
  final VoidCallback onSmazat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      key: const Key('vyber-fotek'),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.base,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zrušit výběr',
            onPressed: maze ? null : onZrusit,
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              'Vybráno: $pocet',
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (maze)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.base),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              key: const Key('smazat-vybrane'),
              onPressed: onSmazat,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Smazat'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

class _MiniaturaNahravana extends StatelessWidget {
  const _MiniaturaNahravana({required this.fotka, required this.onTap});

  final NahravanaFotka fotka;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: Key(fotka.selhala ? 'fotka-selhala' : 'fotka-nahrava'),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.input),
            border: fotka.selhala
                ? Border.all(color: AppColors.danger, width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.input - 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  fotka.jpeg,
                  fit: BoxFit.cover,
                  cacheWidth: 240,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
                ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
                Center(
                  child: fotka.selhala
                      ? const Icon(Icons.refresh_rounded, color: Colors.white)
                      : const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fotka přes celou obrazovku - zvětšení prsty, kdo a kdy ji nahrál,
/// smazání.
class _ProhlizeniFotky extends ConsumerWidget {
  const _ProhlizeniFotky({required this.orderId, required this.fotka});

  final String orderId;
  final Fotka fotka;

  static Future<void> otevri(
    BuildContext context, {
    required String orderId,
    required Fotka fotka,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ProhlizeniFotky(orderId: orderId, fotka: fotka),
      ),
    );
  }

  Future<void> _smaz(BuildContext context, WidgetRef ref) async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog.adaptive(
        title: const Text('Smazat fotku?'),
        content: const Text(
          'Fotka zmizí z aplikace i ze sdílené složky na serveru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (potvrzeno != true || !context.mounted) return;

    try {
      await ref.read(fotkyDataSourceProvider).smazFotku(fotka.id);
      ref.invalidate(fotkyZakazkyProvider(orderId));
      if (context.mounted) Navigator.of(context).pop();
    } on ServiceOrderException catch (chyba) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(chyba.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obrazek = ref.watch(obrazekFotkyProvider(fotka.id));
    final popis = [
      fotka.kategorie.nazev,
      AppDateFormat.dateTime(fotka.nahranoAt),
      if (fotka.nahralKdo != null) fotka.nahralKdo!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          popis,
          style: AppTextStyles.metaSmall.copyWith(color: Colors.white70),
        ),
        actions: [
          IconButton(
            tooltip: 'Smazat fotku',
            onPressed: () => _smaz(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Center(
        child: obrazek.when(
          data: (bajty) => InteractiveViewer(
            maxScale: 6,
            child: Image.memory(bajty, fit: BoxFit.contain),
          ),
          loading: () => const CircularProgressIndicator(color: Colors.white),
          error: (_, _) => const Text(
            'Fotku se nepodařilo načíst.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
