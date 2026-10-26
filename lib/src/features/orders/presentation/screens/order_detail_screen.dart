import 'package:flutter/material.dart';
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
import '../../../prijem/presentation/widgets/prijem_souhrn.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/obalka_klice.dart';
import '../../domain/entities/plan_klempirny.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/zpracovatel.dart';
import '../controllers/order_actions_controller.dart';
import '../controllers/orders_providers.dart';
import '../widgets/detail_cards.dart';
import '../widgets/sekce_detailu.dart';
import '../widgets/notes_card.dart';
import '../widgets/obalka_klice.dart';
import '../widgets/status_badge.dart';
import '../widgets/pridat_stav_sheet.dart';
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
    required this.onSkenujObalku,
  });

  final ServiceOrder order;
  final VoidCallback onBack;
  final bool zobrazitZpet;
  final ValueChanged<String>? onFotodokumentace;
  final ValueChanged<String>? onPrijem;
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
              const Expanded(child: SectionLabel('POSTUP ZAKÁZKY')),
              if (smi)
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
          StatusTimeline(
            historie: order.historieStavu,
            bay: order.bay ?? '',
            onSmazat: smi ? (stav) => _smazStav(context, ref, stav) : null,
          ),
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

    // Plán klempírny a lakovny - u klempířských zakázek vždy, u ostatních
    // jen když plán mají.
    final klempirna = order.lzePlanovatKlempirnu || order.planKlempirny != null
        ? PlanKarta(order: order)
        : null;

    return Column(
      children: [
        _DetailHeader(
          order: order,
          onBack: onBack,
          zobrazitZpet: zobrazitZpet,
          jenCteni: !smi,
          onZpracovatel: smi ? () => _zmenZpracovatele(context, ref) : null,
          onPriraditObalku: smi
              ? () => zmenObalku(context, ref, order, onSkenuj: onSkenujObalku)
              : null,
          onUvolnitObalku: smi
              ? () => uvolnitObalku(context, ref, order)
              : null,
        ),
        Expanded(
          // Klíč: po přepnutí na jinou zakázku zase na závadách.
          child: _TeloDetailu(
            key: ValueKey(order.id),
            orderId: order.id,
            pocetZavad: order.zavady.length,
            sekce: {
              SekceDetailu.zavady: zavady,
              SekceDetailu.prijem: prijem,
              SekceDetailu.dokumenty: dokumenty,
              SekceDetailu.ulozenky: ulozenky,
            },
            prubeh: [?klempirna, ?predmet, postup, poznamky],
          ),
        ),
      ],
    );
  }
}

/// Tělo detailu podle Janova návrhu (26. 10. 2026): vlevo menu sekcí
/// s počty, vedle vybraná sekce přes celou šířku. Průběh (klempírna,
/// postup, poznámky) je v sekci Závady/úkony - patří k závadám.
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

  /// Klempírna, postup a poznámky - v sekci Závady/úkony.
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
        return Column(
          children: [
            Container(
              decoration: BoxDecoration(border: Border(bottom: cara)),
              child: menu(svisle: false),
            ),
            Expanded(child: obsah),
          ],
        );
      },
    );
  }
}

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
    required this.onZpracovatel,
    required this.onPriraditObalku,
    required this.onUvolnitObalku,
    this.jenCteni = false,
  });

  final ServiceOrder order;
  final VoidCallback onBack;
  final bool zobrazitZpet;

  /// Klepnutí na řádek zpracovatele - otevře jeho výběr.
  final VoidCallback? onZpracovatel;

  /// Právo jen ke čtení - štítek „Jen čtení", akce chybí (`null`).
  final bool jenCteni;

  /// Obálka s klíčem - přiřadit (skener nebo číslo), uvolnit.
  final VoidCallback? onPriraditObalku;
  final VoidCallback? onUvolnitObalku;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = context.isIOS;
    final palette = context.palette;

    final identifikace = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // V rozděleném zobrazení není kam se vracet - detail je
            // vedle seznamu, ne nad ním.
            if (zobrazitZpet) ...[
              Semantics(
                button: true,
                label: 'Zpět na seznam zakázek',
                child: GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        // iOS chevron, Android arrow.
                        isIOS
                            ? Icons.arrow_back_ios_new_rounded
                            : Icons.arrow_back_rounded,
                        size: isIOS ? 20 : 22,
                        color: palette.naHlavicce,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.xxs),
            ],
            Text(
              order.id,
              style: AppTextStyles.orderNumber.copyWith(
                fontSize: 13,
                letterSpacing: 0.52,
                color: palette.naHlavicceTlumene,
              ),
            ),
            const SizedBox(width: Insets.base),
            StatusBadge(stav: order.stav, fontSize: 12),
          ],
        ),
        const SizedBox(height: Insets.lg),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 11,
          runSpacing: Insets.xs,
          children: [
            Text(
              order.licensePlate,
              style: AppTextStyles.plateLarge.copyWith(
                color: palette.naHlavicce,
              ),
            ),
            Text(
              order.model,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: palette.naHlavicceTlumene,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.base),
        // VIN má vlastní řádek a je výraznější než ostatní údaje: podle
        // něj se vůz dohledává a často se přepisuje do jiných systémů.
        Row(
          children: [
            Text(
              'VIN',
              style: AppTextStyles.metaSmall.copyWith(
                color: palette.naHlavicceTlumene,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: SelectableText(
                order.vin,
                maxLines: 1,
                style: AppTextStyles.monoLabel.copyWith(
                  fontSize: 15,
                  color: palette.naHlavicce,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        _RadekRegistrace(order: order),
        if (order.barvaVozu case final barva?) _RadekBarvy(barva: barva),
        const SizedBox(height: Insets.xs),
        Text(
          order.customerName,
          style: AppTextStyles.cardBody.copyWith(color: palette.naHlavicce),
        ),
        if (order.mechanicName != null) ...[
          const SizedBox(height: 2),
          Text(
            '${ServiceOrder.rolePopisek}: ${order.mechanicName}',
            style: AppTextStyles.meta.copyWith(
              color: palette.naHlavicceTlumene,
            ),
          ),
        ],
        _RadekZpracovatele(
          zpracovatel: order.zpracovatel,
          onTap: onZpracovatel,
        ),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            // Stav z Heliosu zeleně - Helios je zelený, takže je na první
            // pohled poznat, který stav je z ERP a který z dílny.
            // Právo jen ke čtení - ať je vidět, proč chybí tlačítka.
            if (jenCteni) const _HeaderChip('Jen čtení', key: Key('jen-cteni')),
            if (order.heliosStatus != null)
              _HeaderChip(order.heliosStatus!, barva: AppColors.heliosGreen),
            // Typ hned za stavem: říká o zakázce víc než pobočka, a mezi
            // šedými štítky by se jako poslední ztratil.
            if (order.typZakazky != null)
              _HeaderChip(order.typZakazky!.nazev, zvyrazneny: true),
            if (order.department != null) _HeaderChip(order.departmentLabel),
            _HeaderChip(order.branchLabel),
          ],
        ),
        // Svolávací akce BMW, které se vozu týkají - oranžově, ať je dílna
        // při příjmu nepřehlédne. FitServis+ je u první registrace.
        // Zatím schované (technickeKampaneZapnuteProvider).
        if (ref.watch(technickeKampaneZapnuteProvider) &&
            order.technickeKampane.isNotEmpty) ...[
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final kampan in order.technickeKampane)
                StitekKampane(
                  key: Key('kampan-vozu-${kampan.id}'),
                  druh: DruhStitku.technicka,
                  popisek: [?kampan.kod, kampan.nazev].join(' · '),
                  nadpis: kampan.nazev,
                  podrobnosti: [
                    if (kampan.kod != null) 'Technická kampaň ${kampan.kod}',
                    if (kampan.text.trim().isNotEmpty) kampan.text.trim(),
                  ].join('\n\n'),
                ),
            ],
          ),
        ],
      ],
    );

    return Container(
      decoration: dekoraceHlavicky(palette),
      padding: EdgeInsets.fromLTRB(
        Insets.xxl,
        MediaQuery.paddingOf(context).top + Insets.md,
        Insets.xxl,
        Insets.xl,
      ),
      // Termíny a pojištění vpravo vedle vozu; na telefonu se vedle
      // nevejdou, tak jdou pod štítky.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vedle = constraints.maxWidth >= _sirkaProUdajeVedle;
          final udaje = _UdajeZakazky(
            order: order,
            vedle: vedle,
            onPriraditObalku: onPriraditObalku,
            onUvolnitObalku: onUvolnitObalku,
          );
          return vedle
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identifikace),
                    const SizedBox(width: Insets.xxl),
                    udaje,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identifikace,
                    const SizedBox(height: Insets.lg),
                    udaje,
                  ],
                );
        },
      ),
    );
  }
}

/// Od téhle šířky hlavičky jsou termíny a pojištění vpravo vedle vozu.
/// Míň by na identifikaci vozu zbylo tak málo, že by se nevešel ani
/// řádek s číslem zakázky a stavem.
const double _sirkaProUdajeVedle = 820;

/// Přijato, termín dokončení a u pojistné zakázky pojišťovna a číslo
/// pojistné události - v hlavičce, ať jsou vidět hned po otevření a
/// nezabírají místo kartami v těle detailu.
class _UdajeZakazky extends StatelessWidget {
  const _UdajeZakazky({
    required this.order,
    required this.vedle,
    required this.onPriraditObalku,
    required this.onUvolnitObalku,
  });

  final ServiceOrder order;
  final VoidCallback? onPriraditObalku;
  final VoidCallback? onUvolnitObalku;

  /// Vedle identifikace vozu: pevné sloupce. Pod ní půl na půl.
  final bool vedle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Na navy hlavičce by plná červená zanikla.
    final poTerminu = order.isOverdue()
        ? (context.isDarkMode ? const Color(0xFFFF7A7A) : AppColors.danger)
        : null;
    final pojistna = order.pojisteniPopisek != null;

    Widget udaj(
      String label,
      String hodnota, {
      Color? barva,
      bool mono = true,
      bool vlevo = false,
      bool nahore = false,
    }) {
      return Padding(
        padding: EdgeInsets.only(
          right: vlevo ? Insets.xl : 0,
          bottom: nahore && pojistna ? Insets.md : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.overline.copyWith(
                fontSize: 10.5,
                color: palette.naHlavicceTlumene,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hodnota,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  (mono
                          ? AppTextStyles.dataValue.copyWith(fontSize: 15)
                          : AppTextStyles.cardBody.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ))
                      .copyWith(color: barva ?? palette.naHlavicce),
            ),
          ],
        ),
      );
    }

    return Table(
      key: const Key('hlavicka-udaje'),
      // Vedle vozu pevně: první sloupec širší, ať se název pojišťovny
      // vejde na řádek.
      columnWidths: vedle
          ? const {0: FixedColumnWidth(230), 1: FixedColumnWidth(170)}
          : const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
      children: [
        TableRow(
          children: [
            // Bez času: hodina příjmu nikoho nezajímá.
            udaj(
              'PŘIJATO',
              order.receivedAt == null
                  ? 'Neuvedeno'
                  : AppDateFormat.date(order.receivedAt!),
              vlevo: true,
              nahore: true,
            ),
            udaj(
              'TERMÍN DOKONČENÍ',
              order.dueAt == null
                  ? 'Neuvedeno'
                  : AppDateFormat.date(order.dueAt!),
              barva: poTerminu,
              nahore: true,
            ),
          ],
        ),
        if (pojistna)
          TableRow(
            children: [
              udaj(
                'POJIŠŤOVNA',
                order.pojistovna ?? 'Neuvedeno',
                mono: false,
                vlevo: true,
              ),
              udaj(
                'POJISTNÁ UDÁLOST',
                order.cisloPojistneUdalosti ?? 'Neuvedeno',
              ),
            ],
          ),
        // Obálka s klíčem - náhrada desek s kapsičkou. Přes oba sloupce,
        // ať se vejde kód i tlačítko.
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Insets.md),
              child: _KolonkaObalky(
                obalka: order.obalka,
                onPriradit: onPriraditObalku,
                onUvolnit: onUvolnitObalku,
              ),
            ),
            const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }
}

/// „OBÁLKA S KLÍČEM": kód obálky a Uvolnit, nebo Přiřadit.
class _KolonkaObalky extends StatelessWidget {
  const _KolonkaObalky({
    required this.obalka,
    required this.onPriradit,
    required this.onUvolnit,
  });

  final ObalkaKlice? obalka;
  final VoidCallback? onPriradit;
  final VoidCallback? onUvolnit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final kod = obalka?.kod;

    return Column(
      key: const Key('obalka'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OBÁLKA S KLÍČEM',
          style: AppTextStyles.overline.copyWith(
            fontSize: 10.5,
            color: palette.naHlavicceTlumene,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              // Číslo jako na štítku obálky - velké, podle něj se obálka
              // hledá na tabuli s klíči.
              child: obalka == null
                  ? Text(
                      'Nepřiřazena',
                      style: AppTextStyles.cardBody.copyWith(
                        fontSize: 15,
                        color: palette.naHlavicceTlumene,
                      ),
                    )
                  : CisloObalky(obalka: obalka!, barva: palette.naHlavicce),
            ),
            const SizedBox(width: Insets.lg),
            if ((kod == null ? onPriradit : onUvolnit) != null)
              _TlacitkoObalky(
                key: Key(
                  kod == null
                      ? 'obalka-priradit-hlavicka'
                      : 'obalka-uvolnit-hlavicka',
                ),
                text: kod == null ? 'Přiřadit' : 'Uvolnit',
                zvyraznene: kod == null,
                onTap: (kod == null ? onPriradit : onUvolnit)!,
              ),
          ],
        ),
      ],
    );
  }
}

/// Malé tlačítko v hlavičce - Přiřadit plné, Uvolnit jen obrys, ať se
/// na něj neklepne omylem místo něčeho jiného.
class _TlacitkoObalky extends StatelessWidget {
  const _TlacitkoObalky({
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
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Insets.base),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.compact,
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

/// „Zpracovává: Dvořák Jan" pod zodpovědnou osobou. Na rozdíl od ní se
/// mění v aplikaci - klepnutím se otevře výběr.
class _RadekZpracovatele extends StatelessWidget {
  const _RadekZpracovatele({required this.zpracovatel, required this.onTap});

  final Zpracovatel? zpracovatel;

  /// `null` = jen čtení - jméno bez Převzít / Změnit.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final kdo = zpracovatel;
    final styl = AppTextStyles.meta.copyWith(color: palette.naHlavicceTlumene);

    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('zpracovatel'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          // Ať se do řádku trefí i prst v rukavici.
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Zpracovává: ', style: styl),
                      TextSpan(
                        text: kdo?.jmeno ?? 'nikdo',
                        style: kdo == null
                            ? styl
                            : styl.copyWith(
                                color: palette.naHlavicce,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) const SizedBox(width: Insets.sm),
              if (onTap != null)
                Text(
                  kdo == null ? 'Převzít' : 'Změnit',
                  style: styl.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// První registrace vozu (`prodej_datum` z Heliosu), stáří v měsících
/// a hned vedle štítek FitServis+, když do něj vůz spadá - na jednom
/// řádku, ať je vidět, proč štítek je (nebo není).
class _RadekRegistrace extends ConsumerWidget {
  const _RadekRegistrace({required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final datum = order.prvniRegistrace;

    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs),
      child: Wrap(
        key: const Key('prvni-registrace'),
        spacing: Insets.sm,
        runSpacing: Insets.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '1. REGISTRACE',
            style: AppTextStyles.metaSmall.copyWith(
              color: palette.naHlavicceTlumene,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            datum == null
                ? 'v Heliosu neuvedena'
                : registraceSeStarim(
                    datum,
                    ref.watch(dnesProvider),
                    AppDateFormat.date,
                  ),
            style: datum == null
                ? AppTextStyles.meta.copyWith(color: palette.naHlavicceTlumene)
                : AppTextStyles.meta.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.naHlavicce,
                  ),
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
      ),
    );
  }
}

/// Barva vozu z Heliosu pod první registrací: `BARVA 475 · Black Sapphire`.
class _RadekBarvy extends StatelessWidget {
  const _RadekBarvy({required this.barva});

  final BarvaVozu barva;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs),
      child: Wrap(
        key: const Key('barva-vozu'),
        spacing: Insets.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'BARVA',
            style: AppTextStyles.metaSmall.copyWith(
              color: palette.naHlavicceTlumene,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            barva.popis,
            style: AppTextStyles.meta.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.naHlavicce,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(
    this.label, {
    super.key,
    this.barva,
    this.zvyrazneny = false,
  });

  final String label;

  /// Výplň. Bez ní je chip průsvitný jako ostatní údaje v hlavičce.
  final Color? barva;

  /// Obtažený rámečkem - odliší údaj, který má být vidět dřív než ostatní.
  final bool zvyrazneny;

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
        color: barva ?? palette.hlavickaPrvek,
        borderRadius: BorderRadius.circular(7),
        border: zvyrazneny
            ? Border.all(color: palette.naHlavicceTlumene)
            : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.meta.copyWith(
          color: barva == null ? palette.naHlavicce : Colors.white,
          fontWeight: barva == null ? FontWeight.w400 : FontWeight.w600,
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
    final obrazek = ref.watch(obrazekFotkyProvider(fotka.id));

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
