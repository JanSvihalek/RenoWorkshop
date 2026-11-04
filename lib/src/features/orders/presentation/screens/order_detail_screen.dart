import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/utils/stari_vozu.dart';
import '../../../akce/presentation/akce_providers.dart';
import '../../../fotodokumentace/domain/entities/fotka.dart';
import '../../../fotodokumentace/presentation/controllers/fotky_providers.dart';
import '../../../fotodokumentace/presentation/widgets/prohlizeni_fotek.dart';
import '../../../ulozenky/presentation/ulozenky_karta.dart';
import '../../../akce/presentation/stitek_kampane.dart';
import '../../../plan/presentation/plan_karta.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/utils/kontakt_odkazy.dart';
import '../../../prijem/presentation/widgets/prijem_souhrn.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/order_actions_controller.dart';
import '../controllers/orders_providers.dart';
import '../widgets/detail_cards.dart';
import '../widgets/sekce_detailu.dart';
import '../widgets/notes_card.dart';
import '../widgets/obalka_klice.dart';
import '../widgets/pridat_stav_sheet.dart';
import '../widgets/plate_chip.dart';
import '../widgets/predmet_opravy_card.dart';
import '../widgets/status_timeline.dart';
import '../widgets/zavady_card.dart';
import '../widgets/zpracovatel_sheet.dart';

/// Detail zakázky: stav, časová osa, fotodokumentace, poznámky, závady.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.onBack,
    this.zobrazitZpet = true,
    this.onFotodokumentace,
    this.onPrijem,
    this.onOpenVozidlo,
    this.onSkenujObalku,
  });

  final String orderId;
  final VoidCallback onBack;

  /// Skener obálky s klíčem. Bez něj jde obálku jen napsat.
  final SkenujObalku? onSkenujObalku;

  /// Otevření fotodokumentace. Bez něj se karta fotek nezobrazí.
  final ValueChanged<String>? onFotodokumentace;

  /// Otevření příjmu vozidla. Bez něj se karta příjmu nezobrazí.
  final ValueChanged<String>? onPrijem;

  /// Otevře kartu vozu podle jeho čísla.
  final ValueChanged<int>? onOpenVozidlo;

  /// V rozděleném zobrazení na tabletu není kam se vracet - detail je
  /// vedle seznamu, ne nad ním.
  final bool zobrazitZpet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    // Chybu zápisu ukážeme jednou, ať uživatel neztratí kontext obrazovky.
    ref.listen(orderActionsProvider, (previous, next) {
      final error = next.error;
      if (error != null && previous?.error != error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$error')));
      }
    });

    return Scaffold(
      backgroundColor: palette.background,
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailMessage(message: '$error', onBack: onBack),
        data: (order) {
          if (order == null) {
            return _DetailMessage(
              message: 'Zakázka $orderId nebyla nalezena.',
              onBack: onBack,
            );
          }
          return _DetailBody(
            order: order,
            onBack: onBack,
            zobrazitZpet: zobrazitZpet,
            onFotodokumentace: onFotodokumentace,
            onPrijem: onPrijem,
            onOpenVozidlo: onOpenVozidlo,
            onSkenujObalku: onSkenujObalku,
          );
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.order,
    required this.onBack,
    required this.zobrazitZpet,
    required this.onFotodokumentace,
    required this.onPrijem,
    required this.onOpenVozidlo,
    required this.onSkenujObalku,
  });

  final ServiceOrder order;
  final VoidCallback onBack;
  final bool zobrazitZpet;
  final ValueChanged<String>? onFotodokumentace;
  final ValueChanged<String>? onPrijem;

  /// Otevře kartu vozu podle jeho čísla.
  final ValueChanged<int>? onOpenVozidlo;
  final SkenujObalku? onSkenujObalku;

  Future<void> _pridejStav(BuildContext context, WidgetRef ref) =>
      pridatStavZakazce(context, ref, order);

  /// Smaže záznam z historie stavů. Ptá se, protože záznam zmizí nadobro
  /// a u cizího zápisu nemusí být zřejmé, že šlo o omyl.
  Future<void> _smazStav(
    BuildContext context,
    WidgetRef ref,
    DilenskyStav stav,
  ) async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Smazat stav?'),
        content: Text('Ze zakázky zmizí záznam „${stav.nazev}".'),
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

    if ((potvrzeno ?? false) && stav.id != null) {
      await ref
          .read(orderActionsProvider.notifier)
          .smazStav(order.id, stav.id!);
    }
  }

  /// Okno zpracovatele: převzít, přiřadit kolegovi, nebo uvolnit.
  Future<void> _zmenZpracovatele(BuildContext context, WidgetRef ref) async {
    final volba = await vyberZpracovatele(
      context,
      orderId: order.id,
      aktualni: order.zpracovatel,
      mujEmail: ref.read(currentEmployeeProvider)?.email,
    );
    if (volba == null) return;
    final akce = ref.read(orderActionsProvider.notifier);
    switch (volba) {
      case PrevzitZakazku():
        await akce.prevezmiZakazku(order.id);
      case PriraditZamestnance(:final id):
        await akce.nastavZpracovatele(order.id, id);
      case UvolnitZakazku():
        await akce.nastavZpracovatele(order.id, null);
    }
  }

  Future<void> _upravPredmet(BuildContext context, WidgetRef ref) async {
    final text = await upravPredmetOpravy(context, order.predmetOpravy);
    // null = zrušeno; prázdný text je platná úprava (smazání).
    if (text == null || text == (order.predmetOpravy ?? '')) return;
    await ref
        .read(orderActionsProvider.notifier)
        .ulozPredmetOpravy(order.id, text);
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final text = await showAddNoteDialog(
      context,
      spz: order.licensePlate,
      cisloZakazky: order.id,
      autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
    );
    if (text == null || text.isEmpty) return;
    await ref
        .read(orderActionsProvider.notifier)
        .addNote(orderId: order.id, text: text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(orderActionsProvider).isLoading;
    // Jen čtení (právo R k pořadači) - bez akcí, které zapisují.
    final smi = ref.watch(smiZapisovatProvider(order.poradac?.kod));
    // Stav jde zapsat i z plánovače - plánovač má práva zvlášť od pořadačů.
    final smiStav = smi || ref.watch(smiPlanovatProvider(order.branch?.code));
    final uzJeMoje =
        order.zpracovatel?.jeEmail(ref.watch(currentEmployeeProvider)?.email) ??
        false;
    // Klempířská zakázka: v jedné kartě co je teď, plán a sbalená historie.
    // Ostatní jen postup stavů.
    final sPlanem = order.lzePlanovatKlempirnu || order.planKlempirny != null;
    final historie = order.historieStavu;
    final onSmazat = smi
        ? (DilenskyStav stav) => _smazStav(context, ref, stav)
        : null;

    final postup = DetailCard(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.xl,
        Insets.xl,
        Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  sPlanem ? 'PRŮBĚH OPRAVY' : 'POSTUP ZAKÁZKY',
                ),
              ),
              if (smiStav)
                _PridatStavOdkaz(
                  isBusy: isBusy,
                  onTap: () => _pridejStav(context, ref),
                ),
            ],
          ),
          if (order.bay != null) ...[
            const SizedBox(height: Insets.sm),
            _KdeStoji(
              orderId: order.id,
              misto: order.bay!,
              od: order.bayAt,
              kdo: order.bayBy,
            ),
          ],
          const SizedBox(height: Insets.base),
          if (!sPlanem)
            StatusTimeline(
              historie: historie,
              bay: order.bay ?? '',
              onSmazat: onSmazat,
            )
          else ...[
            if (historie.isNotEmpty) const SectionLabel('TEĎ'),
            if (historie.isNotEmpty) const SizedBox(height: Insets.sm),
            StatusTimeline(
              historie: historie.take(1).toList(),
              bay: order.bay ?? '',
              onSmazat: onSmazat,
            ),
            const Divider(height: Insets.xxl),
            PlanVPrubehu(order: order),
            if (historie.length > 1) ...[
              const Divider(height: Insets.lg),
              SbalitelnaSkupina(
                key: const Key('prubeh-historie'),
                nazev: 'Historie stavů',
                pocet: historie.length - 1,
                rozbalena: false,
                children: [
                  StatusTimeline(
                    historie: historie.skip(1).toList(),
                    bay: '',
                    sAktualnim: false,
                    onSmazat: onSmazat,
                  ),
                  const SizedBox(height: Insets.sm),
                ],
              ),
            ],
          ],
        ],
      ),
    );

    final predmet = _zobrazitPredmetOpravy
        ? PredmetOpravyCard(
            predmet: order.predmetOpravy,
            onUpravit: smi ? () => _upravPredmet(context, ref) : null,
          )
        : null;

    final poznamky = NotesCard(
      notes: order.notes,
      onAddNote: smi ? () => _addNote(context, ref) : null,
    );

    // Souhrn příjmu - nálezy, dezén, STK, fotky. Zahájit a upravit ho
    // smí jen kdo má zápis; jinak jen ke čtení.
    final prijem = PrijemSouhrn(
      orderId: order.id,
      onOtevrit: onPrijem == null || !smi ? null : () => onPrijem!(order.id),
      onFotky: onFotodokumentace == null
          ? null
          : () => onFotodokumentace!(order.id),
    );

    // Závady z Heliosu, jen ke čtení. Dřív tu byla karta úkonů
    // s odškrtáváním, do které ale nikdy nic neteklo.
    final zavady = ZavadyCard(zavady: order.zavady);

    // Fotky, diagnostika a doklady z Heliosu v jedné kartě.
    final dokumenty = DokumentyKarta(
      orderId: order.id,
      onFotodokumentace: onFotodokumentace == null
          ? null
          : () => onFotodokumentace!(order.id),
    );

    // Uloženky pneu vozu z Heliosu, jen ke čtení.
    final ulozenky = UlozenkyZakazkyKarta(orderId: order.id);

    final hlavicka = _DetailHeader(
      order: order,
      // Příjem jde otevřít kdykoli, u ukončené zakázky už ne.
      onPrijem: onPrijem != null && smi && order.jeAktivni
          ? () => onPrijem!(order.id)
          : null,
      onKartaVozu: switch ((onOpenVozidlo, order.vozidloId)) {
        (final otevri?, final id?) => () => otevri(id),
        _ => null,
      },
      onBack: onBack,
      zobrazitZpet: zobrazitZpet,
      jenCteni: !smi,
      onZpracovatel: smi ? () => _zmenZpracovatele(context, ref) : null,
      onZadatMisto: smiStav ? () => _pridejStav(context, ref) : null,
      onPrevzit: smi && !uzJeMoje
          ? () => ref
                .read(orderActionsProvider.notifier)
                .prevezmiZakazku(order.id)
          : null,
      onPriraditObalku: smi
          ? () => zmenObalku(context, ref, order, onSkenuj: onSkenujObalku)
          : null,
      onUvolnitObalku: smi ? () => uvolnitObalku(context, ref, order) : null,
    );

    // Klíč: po přepnutí na jinou zakázku zase na závadách.
    final telo = _TeloDetailu(
      key: ValueKey(order.id),
      orderId: order.id,
      pocetZavad: order.zavady.length,
      sekce: {
        SekceDetailu.zavady: zavady,
        SekceDetailu.prijem: prijem,
        SekceDetailu.dokumenty: dokumenty,
        SekceDetailu.ulozenky: ulozenky,
      },
      prubeh: [postup, ?predmet, poznamky],
    );

    // Na telefonu hlavička roluje spolu s obsahem - chlívky po dvou by
    // jinak zabralo většinu displeje. Šířeji zůstává nahoře.
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < _sirkaCtyriSloupce
          ? ColoredBox(
              color: context.palette.hlavicka,
              child: SafeArea(
                bottom: false,
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(child: hlavicka),
                  ],
                  body: ColoredBox(
                    color: context.palette.background,
                    child: telo,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                hlavicka,
                Expanded(child: telo),
              ],
            ),
    );
  }
}

/// Tělo detailu podle Janova návrhu (26. 10. 2026): vlevo menu sekcí
/// s počty, vedle vybraná sekce přes celou šířku. Průběh (plán, postup,
/// poznámky) je v sekci Závady/úkony - patří k závadám.
/// Otevírá se vždy na závadách. Jako na webu.
///
///   tablet     menu vlevo; v závadách průběh vedle, když je místo
///   telefon    menu nahoře vodorovně, pod ním sekce
class _TeloDetailu extends StatefulWidget {
  const _TeloDetailu({
    super.key,
    required this.orderId,
    required this.pocetZavad,
    required this.sekce,
    required this.prubeh,
  });

  final String orderId;
  final int pocetZavad;
  final Map<SekceDetailu, Widget> sekce;

  /// Průběh opravy a poznámky - v sekci Závady/úkony.
  final List<Widget> prubeh;

  @override
  State<_TeloDetailu> createState() => _TeloDetailuState();
}

class _TeloDetailuState extends State<_TeloDetailu> {
  SekceDetailu _vybrana = SekceDetailu.zavady;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sekce = widget.sekce[_vybrana]!;
    MenuSekci menu({required bool svisle}) => MenuSekci(
      orderId: widget.orderId,
      pocetZavad: widget.pocetZavad,
      vybrana: _vybrana,
      svisle: svisle,
      onVyber: (s) => setState(() => _vybrana = s),
    );
    final cara = BorderSide(color: palette.hairline);

    // Závady s průběhem (klempírna, postup, poznámky) - patří k sobě.
    // Na širokém displeji vedle sebe, jinak pod sebou. Ostatní sekce
    // mají celou šířku.
    final obsah = _vybrana == SekceDetailu.zavady
        ? LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= _sirkaZavadVedlePrubehu
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Každý sloupec se posouvá zvlášť - časová osa
                      // postupu bývá dlouhá.
                      Expanded(child: _Sloupec(karty: [sekce])),
                      Expanded(child: _Sloupec(karty: widget.prubeh)),
                    ],
                  )
                : _Sloupec(karty: [sekce, ...widget.prubeh]),
          )
        : _Sloupec(karty: [sekce]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sirka = constraints.maxWidth;
        if (sirka >= _sirkaProMenuVlevo) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: sirka >= _sirkaProSirokeMenu ? 220 : 200,
                decoration: BoxDecoration(border: Border(right: cara)),
                child: menu(svisle: true),
              ),
              Expanded(child: obsah),
            ],
          );
        }
        // Hlavička na malém telefonu může být vyšší než displej - tělo pak
        // má nulovou výšku, dokud se neodroluje, a menu by přeteklo.
        final vyska = max(constraints.maxHeight, _nejmensiVyskaTela);
        return ClipRect(
          child: OverflowBox(
            minHeight: vyska,
            maxHeight: vyska,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(border: Border(bottom: cara)),
                  child: menu(svisle: false),
                ),
                Expanded(child: obsah),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Výška, se kterou se tělo detailu na telefonu rozvrhne, i když je z něj
/// zatím vidět míň.
const double _nejmensiVyskaTela = 200;

/// Předmět opravy se zatím nepoužívá (21. 9. 2026), karta je v detailu
/// schovaná. Data i API zůstávají - vrátí se přepnutím na `true`.
const bool _zobrazitPredmetOpravy = false;

/// Od téhle šířky je menu vlevo; na telefonu vodorovně nahoře.
const double _sirkaProMenuVlevo = 640;

/// Od téhle šířky detailu má menu 220 px, jinak 200.
const double _sirkaProSirokeMenu = 1000;

/// Od téhle šířky sekce jsou v závadách průběh (postup, poznámky) vedle
/// závad, jinak pod nimi.
const double _sirkaZavadVedlePrubehu = 700;

/// Karty pod sebou s mezerami a odsazením.
class _Sloupec extends StatelessWidget {
  const _Sloupec({required this.karty});

  final List<Widget> karty;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // Dole i systémová lišta telefonu: spodní tlačítko, které ji dřív
      // krylo, už tu není.
      padding: EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.xl,
        Insets.xl,
        Insets.huge + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: karty.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.base),
      itemBuilder: (_, index) => karty[index],
    );
  }
}

/// Navy hlavička detailu - identifikace vozidla a zakázky.
class _DetailHeader extends ConsumerWidget {
  const _DetailHeader({
    required this.order,
    required this.onBack,
    required this.zobrazitZpet,
    required this.onPrijem,
    required this.onKartaVozu,
    required this.onZpracovatel,
    required this.onZadatMisto,
    required this.onPrevzit,
    required this.onPriraditObalku,
    required this.onUvolnitObalku,
    this.jenCteni = false,
  });

  final ServiceOrder order;
  final VoidCallback onBack;
  final bool zobrazitZpet;

  /// Průvodce příjmem. `null` tlačítko schová.
  final VoidCallback? onPrijem;

  /// Otevře kartu vozu. `null` = vůz bez evidence, odkaz se neukáže.
  final VoidCallback? onKartaVozu;

  /// Klepnutí na řádek zpracovatele - otevře jeho výběr.
  final VoidCallback? onZpracovatel;

  /// Místo se zapisuje s dílenským stavem - otevře jeho okno; `null` = jen
  /// čtení.
  final VoidCallback? onZadatMisto;

  /// Převzít zakázku; `null` = jen čtení, nebo už ji zpracovává přihlášený.
  final VoidCallback? onPrevzit;

  /// Právo jen ke čtení - štítek „Jen čtení", akce chybí (`null`).
  final bool jenCteni;

  /// Obálka s klíčem - přiřadit (skener nebo číslo), uvolnit.
  final VoidCallback? onPriraditObalku;
  final VoidCallback? onUvolnitObalku;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = context.isIOS;
    final palette = context.palette;

    // V rozděleném zobrazení není kam se vracet - detail je vedle seznamu,
    // ne nad ním.
    final zpet = Padding(
      padding: const EdgeInsets.only(right: Insets.md),
      child: Semantics(
        button: true,
        label: 'Zpět na seznam zakázek',
        child: GestureDetector(
          onTap: onBack,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.hlavickaOkraj),
            ),
            child: Icon(
              // iOS chevron, Android arrow.
              isIOS
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back_rounded,
              size: isIOS ? 18 : 20,
              color: palette.naHlavicce,
            ),
          ),
        ),
      ),
    );

    final dnes = ref.watch(dnesProvider);
    final popisek = AppTextStyles.overline.copyWith(
      fontSize: 10.5,
      color: palette.naHlavicceTlumene,
    );
    final pod = AppTextStyles.metaSmall.copyWith(
      color: palette.naHlavicceTlumene,
    );
    final tucne = AppTextStyles.cardBody.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: palette.naHlavicce,
    );
    final mono = AppTextStyles.monoLabel.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: palette.naHlavicce,
    );
    Widget cara() => Container(
      width: 1,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: Insets.base),
      color: palette.hlavickaOkraj,
    );

    final vuz = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (order.licensePlate.isNotEmpty) ...[
            SpzRamecek(licensePlate: order.licensePlate),
            const SizedBox(height: Insets.xs),
          ],
          Text(
            order.model,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: pod.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    // Vždy celé: na úzkém displeji se raději zmenší, než aby se uřízlo.
    final vin = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        order.vin,
        maxLines: 1,
        softWrap: false,
        style: mono.copyWith(letterSpacing: 0),
      ),
    );
    final kopirovat = order.vin.isEmpty
        ? null
        : _OdkazHlavicky(
            'Kopírovat',
            key: const Key('kopirovat-vin'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: order.vin));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('VIN zkopírován')));
            },
          );
    final barvaVozu = order.barvaVozu;
    final barva = barvaVozu == null
        ? Text('neuvedena', style: pod)
        : Text(barvaVozu.popis, maxLines: 2, style: tucne);
    final registrace = order.prvniRegistrace;
    // První registrace (`prodej_datum` z Heliosu), stáří v měsících a hned
    // vedle štítek FitServis+, když do něj vůz spadá.
    final prvniRegistrace = Wrap(
      key: const Key('prvni-registrace'),
      spacing: Insets.xs,
      runSpacing: Insets.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (registrace == null)
          Text('neuvedena', style: pod)
        else
          Text(
            registraceSeStarim(registrace, dnes, AppDateFormat.date),
            style: tucne,
          ),
        for (final kampan in order.kampanePodleStari)
          StitekKampane(
            key: Key('kampan-stari-${kampan.id}'),
            druh: DruhStitku.podleStari,
            maly: true,
            popisek: kampan.nazev,
            nadpis: kampan.nazev,
            podrobnosti: kampan.text.trim().isEmpty
                ? 'Vůz do kampaně spadá podle stáří od první registrace.'
                : kampan.text.trim(),
          ),
      ],
    );

    // VIN, barva a první registrace: popisek nad hodnotou, nebo vedle ní.
    Widget faktaVedleSebe() => Wrap(
      spacing: Insets.xl,
      runSpacing: Insets.sm,
      children: [
        for (final (nazev, hodnota, akce) in [
          ('VIN', vin, kopirovat),
          ('BARVA', barva, null),
          ('1. REG.', prvniRegistrace, null),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nazev, style: popisek),
                  if (akce != null) ...[const SizedBox(width: Insets.sm), akce],
                ],
              ),
              const SizedBox(height: 2),
              hodnota,
            ],
          ),
      ],
    );
    Widget faktaPodSebou() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (nazev, hodnota, akce) in [
          ('VIN', vin, kopirovat),
          ('BARVA', barva, null),
          ('1. REG.', prvniRegistrace, null),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 56, child: Text(nazev, style: popisek)),
                Flexible(child: hodnota),
                if (akce != null) ...[const SizedBox(width: Insets.sm), akce],
              ],
            ),
          ),
      ],
    );

    final zarazeni = [
      if (order.typZakazky case final typ?)
        'Řada ${typ.kod.split('/').first} ${typ.nazev}',
      if (order.department != null) 'Stř. ${order.departmentLabel}',
    ].join(' · ');
    final pojisteni = [
      ?order.pojistovna,
      if (order.cisloPojistneUdalosti case final cislo?) 'PU $cislo',
    ].join(' · ');
    final zakazka = Column(
      key: const Key('hlavicka-zarazeni'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ZAKÁZKA', style: popisek),
        const SizedBox(height: 2),
        Text(order.id, maxLines: 1, style: mono),
        if (zarazeni.isNotEmpty) Text(zarazeni, maxLines: 2, style: pod),
        if (pojisteni.isNotEmpty) Text(pojisteni, maxLines: 2, style: pod),
      ],
    );

    final heliosZelena = context.isDarkMode
        ? const Color(0xFF81C784)
        : AppColors.heliosGreen;
    final stavy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stav z Heliosu zeleně - Helios je zelený, takže je na první
        // pohled poznat, který stav je z ERP a který z dílny.
        if (order.heliosStatus case final stav?)
          _RadekStavu('Helios: $stav', barva: heliosZelena, plna: true),
        _RadekStavu(
          'Dílna: ${order.stav?.nazev ?? 'bez stavu'}',
          barva: order.stav == null
              ? palette.naHlavicceTlumene
              : palette.naHlavicce,
          plna: order.stav != null,
        ),
        // Právo jen ke čtení - ať je vidět, proč chybí tlačítka.
        if (jenCteni)
          const Padding(
            padding: EdgeInsets.only(top: Insets.xs),
            child: _HeaderChip('Jen čtení', key: Key('jen-cteni')),
          ),
        // Svolávací akce BMW, které se vozu týkají - oranžově, ať je dílna
        // při příjmu nepřehlédne. FitServis+ je u první registrace.
        // Zatím schované (technickeKampaneZapnuteProvider).
        if (ref.watch(technickeKampaneZapnuteProvider))
          for (final kampan in order.technickeKampane)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: StitekKampane(
                key: Key('kampan-vozu-${kampan.id}'),
                druh: DruhStitku.technicka,
                popisek: [?kampan.kod, kampan.nazev].join(' · '),
                nadpis: kampan.nazev,
                podrobnosti: [
                  if (kampan.kod != null) 'Technická kampaň ${kampan.kod}',
                  if (kampan.text.trim().isNotEmpty) kampan.text.trim(),
                ].join('\n\n'),
              ),
            ),
      ],
    );

    final prijem = onPrijem == null
        ? null
        : _TlacitkoHlavicky(
            key: const Key('prijem-hlavicka'),
            text: 'Příjem zakázky',
            zvyraznene: false,
            onTap: onPrijem!,
          );
    final prevzit = onPrevzit == null
        ? null
        : _TlacitkoHlavicky(
            key: const Key('prevzit-hlavicka'),
            text: 'Převzít zakázku',
            zvyraznene: true,
            onTap: onPrevzit!,
          );
    // Pod sebou a stejně široká.
    Widget akce() => prijem == null && prevzit == null
        ? const SizedBox.shrink()
        : IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ?prijem,
                if (prijem != null && prevzit != null)
                  const SizedBox(height: Insets.sm),
                ?prevzit,
              ],
            ),
          );

    return Container(
      decoration: dekoraceHlavicky(palette),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sirka = constraints.maxWidth;
          final Widget horni;
          if (sirka >= _sirkaVseVJedneRade) {
            horni = Row(
              children: [
                if (zobrazitZpet) zpet,
                vuz,
                cara(),
                Expanded(
                  flex: 4,
                  child: sirka >= _sirkaJednaRada
                      ? faktaVedleSebe()
                      : faktaPodSebou(),
                ),
                cara(),
                Flexible(flex: 2, child: zakazka),
                cara(),
                Flexible(flex: 2, child: stavy),
                const SizedBox(width: Insets.base),
                akce(),
              ],
            );
          } else if (sirka >= _sirkaCtyriSloupce) {
            horni = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (zobrazitZpet) zpet,
                    vuz,
                    cara(),
                    Expanded(child: faktaVedleSebe()),
                  ],
                ),
                Divider(height: Insets.xl, color: palette.hlavickaOkraj),
                Padding(
                  // Zakázka začíná pod značkou, ne pod tlačítkem zpět.
                  padding: EdgeInsets.only(left: zobrazitZpet ? 50 : 0),
                  child: Row(
                    children: [
                      Flexible(child: zakazka),
                      cara(),
                      Expanded(child: stavy),
                      const SizedBox(width: Insets.base),
                      akce(),
                    ],
                  ),
                ),
              ],
            );
          } else {
            horni = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (zobrazitZpet) zpet,
                    Expanded(child: vuz),
                  ],
                ),
                const SizedBox(height: Insets.md),
                faktaPodSebou(),
                Divider(height: Insets.xl, color: palette.hlavickaOkraj),
                Row(
                  children: [
                    Expanded(child: zakazka),
                    cara(),
                    Expanded(child: stavy),
                  ],
                ),
                if (prijem != null || prevzit != null) ...[
                  const SizedBox(height: Insets.md),
                  // Mobil: vedle sebe přes celou šířku.
                  Row(
                    children: [
                      if (prijem != null) Expanded(child: prijem),
                      if (prijem != null && prevzit != null)
                        const SizedBox(width: Insets.sm),
                      if (prevzit != null) Expanded(child: prevzit),
                    ],
                  ),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Insets.xl,
                  MediaQuery.paddingOf(context).top + Insets.md,
                  Insets.xl,
                  Insets.base,
                ),
                child: horni,
              ),
              _PruhUdaju(
                order: order,
                onKartaVozu: onKartaVozu,
                sloupcu: sirka >= _sirkaJednaRada
                    ? 7
                    : sirka >= _sirkaCtyriSloupce
                    ? 4
                    : 2,
                onZpracovatel: onZpracovatel,
                onZadatMisto: onZadatMisto,
                onPriraditObalku: onPriraditObalku,
                onUvolnitObalku: onUvolnitObalku,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Otevře volání nebo e-mail; zařízení, které to neumí, to oznámí.
Future<void> _otevriKontakt(
  BuildContext context,
  WidgetRef ref,
  Uri odkaz,
  String hodnota,
) async {
  final zpravy = ScaffoldMessenger.of(context);
  var povedlo = false;
  try {
    povedlo = await ref.read(otevritOdkazProvider)(odkaz);
  } catch (_) {
    // Bez aplikace na telefon nebo poštu - hláška níž.
  }
  if (povedlo) return;
  zpravy
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('Na tomhle zařízení to nejde otevřít: $hodnota')),
    );
}

/// Od téhle šířky jsou fakta vedle sebe a chlívky v jedné řadě.
const double _sirkaJednaRada = 1250;

/// Od téhle šířky je vůz, fakta, zakázka, stavy i tlačítka v jedné řadě.
const double _sirkaVseVJedneRade = 1100;

/// Od téhle šířky jsou chlívky po čtyřech. Míň je mobil - po dvou a tlačítka
/// přes celou šířku.
const double _sirkaCtyriSloupce = 560;

/// Odkaz v rohu chlívku nebo vedle údaje.
class _OdkazHlavicky extends StatelessWidget {
  const _OdkazHlavicky(this.text, {super.key, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Text(
      text,
      style: AppTextStyles.metaSmall.copyWith(
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Řádek stavu: tečka a text. Plná tečka = stav je, prázdná = bez stavu.
class _RadekStavu extends StatelessWidget {
  const _RadekStavu(this.text, {required this.barva, required this.plna});

  final String text;
  final Color barva;
  final bool plna;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: plna ? barva : null,
            border: Border.all(color: barva, width: 1.5),
          ),
        ),
        const SizedBox(width: Insets.sm),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.metaSmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: barva,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Pruh údajů pod hlavičkou: sedm chlívků v řadě, po čtyřech nebo po dvou.
class _PruhUdaju extends ConsumerWidget {
  const _PruhUdaju({
    required this.order,
    required this.onKartaVozu,
    required this.sloupcu,
    required this.onZpracovatel,
    required this.onZadatMisto,
    required this.onPriraditObalku,
    required this.onUvolnitObalku,
  });

  final ServiceOrder order;

  /// Otevře kartu vozu - majitel a všechny zakázky.
  final VoidCallback? onKartaVozu;
  final int sloupcu;
  final VoidCallback? onZpracovatel;
  final VoidCallback? onZadatMisto;
  final VoidCallback? onPriraditObalku;
  final VoidCallback? onUvolnitObalku;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final dnes = ref.watch(dnesProvider);
    // Na navy hlavičce by plná červená zanikla.
    final poTerminu = order.isOverdue()
        ? (context.isDarkMode ? const Color(0xFFFF7A7A) : AppColors.danger)
        : null;
    final tlumene = AppTextStyles.cardBody.copyWith(
      fontSize: 14,
      color: palette.naHlavicceTlumene,
    );
    final hodnota = AppTextStyles.cardBody.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: palette.naHlavicce,
    );
    final mono = AppTextStyles.monoLabel.copyWith(
      fontSize: 14,
      color: palette.naHlavicce,
    );
    final pod = AppTextStyles.metaSmall.copyWith(
      color: palette.naHlavicceTlumene,
    );
    Widget text(String? t, {TextStyle? styl}) => t == null
        ? Text('Neuvedeno', style: tlumene)
        : Text(
            t,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: styl ?? hodnota,
          );
    Widget odkaz(String t, {Key? key, VoidCallback? onTap}) =>
        _OdkazHlavicky(t, key: key, onTap: onTap);
    final pozadiBunky = palette.hlavickaPrvek.withValues(
      // Polovina krytí barvy, ne pevná hodnota: v tmavém vzhledu je
      // hlavickaPrvek bílá s 10 % a pevných 50 % by z buňky udělalo šedou.
      alpha: palette.hlavickaPrvek.a * 0.5,
    );
    Widget bunka(
      String popisek,
      List<Widget> obsah, {
      Widget? akce,
      Color? pozadi,
    }) => Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.base,
        Insets.md,
        Insets.md,
        Insets.md,
      ),
      color: pozadi ?? pozadiBunky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  popisek,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.overline.copyWith(
                    fontSize: 10.5,
                    color: palette.naHlavicceTlumene,
                  ),
                ),
              ),
              ?akce,
            ],
          ),
          const SizedBox(height: 3),
          ...obsah,
        ],
      ),
    );

    final kdo = order.zpracovatel;
    final misto = order.bay;
    final mistoOd = [
      if (order.bayAt != null) 'od ${AppDateFormat.dateTime(order.bayAt!)}',
      ?order.bayBy,
    ].join(' · ');
    final obalka = order.obalka;

    final kontakt = order.prebirajici;
    final maKontakt =
        odkazTelefon(kontakt?.telefon) != null ||
        odkazEmail(kontakt?.email) != null;
    // Celý řádek je klepací, ať se do něj dá trefit prstem.
    Widget odkazKontaktu(Key key, String popis, Uri cil) => InkWell(
      key: key,
      onTap: () => _otevriKontakt(context, ref, cil, popis),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          popis,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.metaSmall.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    final prijato = order.receivedAt;
    final dokonceni = order.dueAt;
    final bunky = <Widget>[
      bunka(
        'ZÁKAZNÍK',
        [text(order.customerName), Text('Vlastník vozidla', style: pod)],
        akce: onKartaVozu == null
            ? null
            : odkaz(
                'Karta vozu',
                key: const Key('karta-vozu'),
                onTap: onKartaVozu,
              ),
      ),
      KeyedSubtree(
        key: const Key('kontakt'),
        child: bunka('KONTAKT', [
          if (kontakt == null || kontakt.jmeno.isEmpty && !maKontakt)
            Text('Nezadán', style: tlumene)
          else if (kontakt.jmeno.isNotEmpty)
            text(kontakt.jmeno),
          if (kontakt?.email case final adresa?)
            if (odkazEmail(adresa) case final cil?)
              odkazKontaktu(const Key('prebirajici-email'), adresa, cil),
          if (kontakt?.telefon case final cislo?)
            if (odkazTelefon(cislo) case final cil?)
              odkazKontaktu(const Key('prebirajici-telefon'), cislo, cil),
        ]),
      ),
      bunka(ServiceOrder.rolePopisek.toUpperCase(), [
        text(order.mechanicName),
        Text('Servisní poradce', style: pod),
      ]),
      // Zpracovatel se na rozdíl od zodpovědné osoby mění v aplikaci -
      // klepnutím se otevře výběr.
      InkWell(
        key: const Key('zpracovatel'),
        onTap: onZpracovatel,
        child: bunka('ZPRACOVÁVÁ', [
          if (kdo == null) Text('Nikdo', style: tlumene) else text(kdo.jmeno),
          Text(kdo == null ? 'Technik nepřiřazen' : 'Technik', style: pod),
        ]),
      ),
      // Bez času: hodina příjmu nikoho nezajímá.
      bunka('PŘIJATO → DOKONČENÍ', [
        if (prijato == null && dokonceni == null)
          Text('Neuvedeno', style: tlumene)
        else
          // Vždy celé: v úzkém chlívku se raději zmenší, než aby se uřízlo.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: switch ((prijato, dokonceni)) {
                      (final od?, final konec?) => AppDateFormat.dayMonthSmart(
                        od,
                        now: konec,
                      ),
                      (final od?, null) => AppDateFormat.date(od),
                      _ => '—',
                    },
                  ),
                  const TextSpan(text: ' → '),
                  TextSpan(
                    text: dokonceni == null
                        ? '—'
                        : AppDateFormat.date(dokonceni),
                    style: poTerminu == null
                        ? null
                        : TextStyle(color: poTerminu),
                  ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              style: mono.copyWith(letterSpacing: 0),
            ),
          ),
        if ([
              if (prijato != null) predKolika(prijato, dnes),
              if (poTerminu != null)
                'Po termínu'
              else if (dokonceni != null)
                zbyvaDo(dokonceni, dnes),
            ].where((t) => t.isNotEmpty).join(' · ')
            case final popis when popis.isNotEmpty)
          Text(
            popis,
            style: poTerminu == null ? pod : pod.copyWith(color: poTerminu),
          ),
      ]),
      // Místo se zapisuje spolu s dílenským stavem - proto přes jeho okno.
      bunka(
        'KDE STOJÍ',
        [
          if (misto == null) Text('Neuvedeno', style: tlumene) else text(misto),
          Text(
            mistoOd.isEmpty ? 'Parkovací místo' : mistoOd,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: pod,
          ),
        ],
        akce: misto != null || onZadatMisto == null
            ? null
            : odkaz(
                'Zadat',
                key: const Key('kde-stoji-zadat'),
                onTap: onZadatMisto,
              ),
      ),
      // Obálka s klíčem - náhrada desek s kapsičkou. Číslo jako na štítku
      // obálky - velké, podle něj se hledá na tabuli s klíči.
      KeyedSubtree(
        key: const Key('obalka'),
        child: bunka(
          'OBÁLKA S KLÍČEM',
          [
            if (obalka == null)
              Text('Nepřiřazena', style: tlumene)
            else
              CisloObalky(obalka: obalka, barva: palette.naHlavicce),
            if (obalka == null) Text('Klíč bez obálky', style: pod),
          ],
          pozadi: AppColors.accent.withValues(alpha: 0.1),
          akce: switch ((obalka, onPriraditObalku, onUvolnitObalku)) {
            (null, final priradit?, _) => odkaz(
              'Přiřadit',
              key: const Key('obalka-priradit-hlavicka'),
              onTap: priradit,
            ),
            (_?, _, final uvolnit?) => odkaz(
              'Uvolnit',
              key: const Key('obalka-uvolnit-hlavicka'),
              onTap: uvolnit,
            ),
            _ => null,
          },
        ),
      ),
    ];

    // Čáry mřížky jsou mezery mezi buňkami s vlastním pozadím. Lichý počet
    // chlívků: zbytek řádku stejnou barvou, ne šedou mezerou.
    return Container(
      key: const Key('hlavicka-udaje'),
      color: palette.hlavickaOkraj,
      padding: const EdgeInsets.only(top: 1),
      child: Column(
        children: [
          for (var i = 0; i < bunky.length; i += sloupcu) ...[
            if (i > 0) const SizedBox(height: 1),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + sloupcu; j++) ...[
                    if (j > i) const SizedBox(width: 1),
                    Expanded(
                      child: ColoredBox(
                        color: palette.hlavicka,
                        child: j < bunky.length
                            ? bunky[j]
                            : ColoredBox(color: pozadiBunky),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tlačítko v hlavičce - hlavní akce plná, ostatní jen obrys.
class _TlacitkoHlavicky extends StatelessWidget {
  const _TlacitkoHlavicky({
    super.key,
    required this.text,
    required this.zvyraznene,
    required this.onTap,
  });

  final String text;
  final bool zvyraznene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final styl = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Insets.base),
      ),
      // Tlačítka jsou pod sebou - výplň kolem by je od sebe zbytečně vzdálila.
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: WidgetStatePropertyAll(AppTextStyles.chip),
    );

    return zvyraznene
        ? FilledButton(
            onPressed: onTap,
            style: styl.copyWith(
              backgroundColor: const WidgetStatePropertyAll(AppColors.accent),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
            child: Text(text),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: styl.copyWith(
              foregroundColor: WidgetStatePropertyAll(palette.naHlavicce),
              side: WidgetStatePropertyAll(
                BorderSide(color: palette.hlavickaOkraj),
              ),
            ),
            child: Text(text),
          );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 5),
      // Delší štítek (VIN, dlouhý název řady) si vezme celý řádek a zbytek
      // se zalomí pod něj; přes šířku obrazovky ale nesmí.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 2 * Insets.xxl,
      ),
      decoration: BoxDecoration(
        color: palette.hlavickaPrvek,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.meta.copyWith(
          color: palette.naHlavicce,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

/// Spodní lišta s hlavní akcí - posun zakázky o krok dál.
/// Odkaz „Přidat" v záhlaví karty Postup zakázky.
///
/// Dřív to bylo velké tlačítko přes celou šířku dole. Stav se ale přidává
/// k postupu, tak patří k němu - stejně jako Přidat u poznámek - a dole
/// uvolnil místo, které na telefonu v hale chybí.
/// Kde vůz fyzicky stojí, i s tím, odkdy a od koho - místo bez času
/// stárne a nikdo neví, jestli mu má věřit. Zapisuje se s každým
/// dílenským stavem.
class _KdeStoji extends ConsumerWidget {
  const _KdeStoji({
    required this.orderId,
    required this.misto,
    this.od,
    this.kdo,
  });

  final String orderId;
  final String misto;
  final DateTime? od;
  final String? kdo;

  /// Fotka místa, ale jen ta pořízená po posledním zápisu místa - starší
  /// by ukazovala kout haly, kde už vůz nestojí.
  Fotka? _fotkaMista(List<Fotka> fotky) {
    for (final fotka in fotky) {
      if (fotka.kategorie != KategorieFotky.umisteni) continue;
      if (od != null && fotka.nahranoAt.isBefore(od!)) continue;
      return fotka;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final fotka = _fotkaMista(
      ref.watch(fotkyZakazkyProvider(orderId)).valueOrNull ?? const [],
    );
    final popis = [
      if (od != null) 'od ${AppDateFormat.dateTime(od!)}',
      ?kdo,
    ].join(' · ');

    return Row(
      key: const Key('kde-vuz-stoji'),
      children: [
        if (fotka != null) ...[
          _MiniaturaMista(orderId: orderId, fotka: fotka),
          const SizedBox(width: Insets.base),
        ] else
          Icon(Icons.place_outlined, size: 18, color: palette.muted),
        if (fotka == null) const SizedBox(width: Insets.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: misto,
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (popis.isNotEmpty)
                  TextSpan(
                    text: '  $popis',
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Náhled fotky místa; klepnutím se otevře přes celou obrazovku.
class _MiniaturaMista extends ConsumerWidget {
  const _MiniaturaMista({required this.orderId, required this.fotka});

  final String orderId;
  final Fotka fotka;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final obrazek = ref.watch(nahledFotkyProvider(fotka.id));

    return GestureDetector(
      key: const Key('fotka-mista'),
      onTap: () =>
          otevriProhlizeniFotky(context, orderId: orderId, fotka: fotka),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.input),
        child: Container(
          width: 44,
          height: 44,
          color: palette.plate,
          child: obrazek.when(
            data: (bajty) =>
                Image.memory(bajty, fit: BoxFit.cover, cacheWidth: 132),
            loading: () => const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) =>
                Icon(Icons.broken_image_outlined, color: palette.muted),
          ),
        ),
      ),
    );
  }
}

class _PridatStavOdkaz extends StatelessWidget {
  const _PridatStavOdkaz({required this.isBusy, required this.onTap});

  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Stav jde přidat vždycky - i k zakázce, která už nějaký má, a i po
    // vyzvednutí: reklamace a dodělávky jsou na klempírně běžné. Jen ne
    // dvakrát naráz, dokud se předchozí ukládá.
    return Semantics(
      button: true,
      enabled: !isBusy,
      label: 'Přidat stav zakázky',
      child: GestureDetector(
        key: const Key('pridat-stav'),
        onTap: isBusy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Větší plocha pro prst, než je samotné slovo.
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: isBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : Text(
                  'Přidat',
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 13,
                    color: AppColors.accent,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 34, color: palette.muted),
              const SizedBox(height: Insets.base),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.cardBody.copyWith(color: palette.text),
              ),
              const SizedBox(height: Insets.xl),
              FilledButton(
                onPressed: onBack,
                child: const Text('Zpět na seznam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
