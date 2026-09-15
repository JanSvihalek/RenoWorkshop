import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../fotodokumentace/presentation/widgets/fotodokumentace_karta.dart';
import '../../../prijem/presentation/widgets/prijem_karta.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/order_actions_controller.dart';
import '../controllers/orders_providers.dart';
import '../widgets/detail_cards.dart';
import '../widgets/notes_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/pridat_stav_sheet.dart';
import '../widgets/predmet_opravy_card.dart';
import '../widgets/status_timeline.dart';
import '../widgets/zavady_card.dart';

/// Detail zakázky: stav, časová osa, fotodokumentace, poznámky, závady.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.onBack,
    this.zobrazitZpet = true,
    this.onFotodokumentace,
    this.onPrijem,
  });

  final String orderId;
  final VoidCallback onBack;

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
  });

  final ServiceOrder order;
  final VoidCallback onBack;
  final bool zobrazitZpet;
  final ValueChanged<String>? onFotodokumentace;
  final ValueChanged<String>? onPrijem;

  Future<void> _pridejStav(BuildContext context, WidgetRef ref) async {
    final vybrany = await vyberStav(context);
    if (vybrany == null || !context.mounted) return;

    final hotovo = await ref
        .read(orderActionsProvider.notifier)
        .pridejStav(
          order.id,
          kod: vybrany.kod,
          nazev: vybrany.nazev,
          poznamka: vybrany.poznamka,
        );

    if (hotovo && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${order.id} · stav přidán')));
    }
  }

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

  Future<void> _upravPredmet(BuildContext context, WidgetRef ref) async {
    final text = await upravPredmetOpravy(context, order.predmetOpravy);
    // null = zrušeno; prázdný text je platná úprava (smazání).
    if (text == null || text == (order.predmetOpravy ?? '')) return;
    await ref
        .read(orderActionsProvider.notifier)
        .ulozPredmetOpravy(order.id, text);
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final text = await showAddNoteDialog(context);
    if (text == null || text.isEmpty) return;
    await ref
        .read(orderActionsProvider.notifier)
        .addNote(orderId: order.id, text: text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(orderActionsProvider).isLoading;
    final overdue = order.isOverdue();

    return Column(
      children: [
        _DetailHeader(order: order, onBack: onBack, zobrazitZpet: zobrazitZpet),
        Expanded(
          child: ListView(
            // Dole i systémová lišta telefonu: spodní tlačítko, které ji
            // dřív kryl, už tu není.
            padding: EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.xl,
              Insets.xl,
              Insets.huge + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: InfoBox(
                      label: 'PŘIJATO',
                      // Bez času: s ním se datum v úzkém sloupci lámalo
                      // do dvou řádků a hodina příjmu nikoho nezajímá.
                      value: order.receivedAt == null
                          ? 'Neuvedeno'
                          : AppDateFormat.date(order.receivedAt!),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: InfoBox(
                      label: 'TERMÍN DOKONČENÍ',
                      value: order.dueAt == null
                          ? 'Neuvedeno'
                          : AppDateFormat.date(order.dueAt!),
                      valueColor: overdue ? AppColors.danger : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.base),
              if (order.pojisteniPopisek != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InfoBox(
                        label: 'POJIŠŤOVNA',
                        value: order.pojistovna ?? 'Neuvedeno',
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: InfoBox(
                        label: 'POJISTNÁ UDÁLOST',
                        value: order.cisloPojistneUdalosti ?? 'Neuvedeno',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.base),
              ],
              PredmetOpravyCard(
                predmet: order.predmetOpravy,
                onUpravit: () => _upravPredmet(context, ref),
              ),
              const SizedBox(height: Insets.base),
              DetailCard(
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
                        _PridatStavOdkaz(
                          isBusy: isBusy,
                          onTap: () => _pridejStav(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.base),
                    StatusTimeline(
                      historie: order.historieStavu,
                      bay: order.bayLabel,
                      onSmazat: (stav) => _smazStav(context, ref, stav),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.base),
              if (onPrijem != null) ...[
                // Příjem před fotkami - vůz se nejdřív zkontroluje, pak
                // se nafotí, a nálezy z kontroly má vidět každý.
                PrijemKarta(
                  orderId: order.id,
                  onOtevrit: () => onPrijem!(order.id),
                ),
                const SizedBox(height: Insets.base),
              ],
              if (onFotodokumentace != null) ...[
                // Hned pod postupem: při příjmu je to první, co se u zakázky
                // dělá, a během opravy se k fotkám vrací.
                FotodokumentaceKarta(
                  orderId: order.id,
                  onOtevrit: () => onFotodokumentace!(order.id),
                ),
                const SizedBox(height: Insets.base),
              ],
              // Poznámky hned pod postupem - dopisují se k tomu, co se na
              // zakázce děje, a čtou se spolu s ním.
              NotesCard(
                notes: order.notes,
                onAddNote: () => _addNote(context, ref),
              ),
              const SizedBox(height: Insets.base),
              // Závady z Heliosu, jen ke čtení. Dřív tu byla karta úkonů
              // s odškrtáváním, do které ale nikdy nic neteklo.
              ZavadyCard(zavady: order.zavady),
            ],
          ),
        ),
      ],
    );
  }
}

/// Navy hlavička detailu - identifikace vozidla a zakázky.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.order,
    required this.onBack,
    required this.zobrazitZpet,
  });

  final ServiceOrder order;
  final VoidCallback onBack;
  final bool zobrazitZpet;

  @override
  Widget build(BuildContext context) {
    final isIOS = context.isIOS;

    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.xxl,
        MediaQuery.paddingOf(context).top + Insets.md,
        Insets.xxl,
        Insets.xl,
      ),
      child: Column(
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
                          color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.7),
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
                style: AppTextStyles.plateLarge.copyWith(color: Colors.white),
              ),
              Text(
                order.model,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xC7FFFFFF),
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
                  color: Colors.white.withValues(alpha: 0.5),
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
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            order.customerName,
            style: AppTextStyles.cardBody.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (order.mechanicName != null) ...[
            const SizedBox(height: 2),
            Text(
              '${ServiceOrder.rolePopisek}: ${order.mechanicName}',
              style: AppTextStyles.meta.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: Insets.base),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              // Stav z Heliosu zeleně - Helios je zelený, takže je na první
              // pohled poznat, který stav je z ERP a který z dílny.
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
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(this.label, {this.barva, this.zvyrazneny = false});

  final String label;

  /// Výplň. Bez ní je chip průsvitný jako ostatní údaje v hlavičce.
  final Color? barva;

  /// Obtažený rámečkem - odliší údaj, který má být vidět dřív než ostatní.
  final bool zvyrazneny;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 5),
      // Delší štítek (VIN, dlouhý název řady) si vezme celý řádek a zbytek
      // se zalomí pod něj; přes šířku obrazovky ale nesmí.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 2 * Insets.xxl,
      ),
      decoration: BoxDecoration(
        color: barva ?? Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7),
        border: zvyrazneny
            ? Border.all(color: Colors.white.withValues(alpha: 0.45))
            : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.meta.copyWith(
          color: Colors.white.withValues(alpha: barva == null ? 0.82 : 1),
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
