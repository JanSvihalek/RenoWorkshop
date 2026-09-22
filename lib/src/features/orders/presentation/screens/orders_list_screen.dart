import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../controllers/orders_providers.dart';
import '../widgets/order_card.dart';
import '../widgets/order_search_field.dart';
import '../widgets/orders_empty_state.dart';
import '../widgets/filtr_lista.dart';
import '../widgets/tabulka_zakazek.dart';
import '../../../settings/domain/entities/nastaveni.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';

/// Hlavní obrazovka: všechny zakázky na dílně (ne "moje vozidlo").
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({
    super.key,
    required this.onOpenOrder,
    this.vRozdelenem = false,
    this.vybranaId,
    required this.onScanCode,
  });

  final void Function(ServiceOrder order) onOpenOrder;

  /// Na tabletu je seznam levý sloupec vedle detailu: nemá vlastní spodní
  /// navigaci (ta je jako svislý pruh vlevo) a označuje vybranou zakázku.
  final bool vRozdelenem;

  /// Číslo právě otevřené zakázky - v rozděleném zobrazení musí být na
  /// první pohled poznat, ke které kartě patří detail vedle.
  final String? vybranaId;

  /// Otevření skeneru VINu a SPZ.
  final VoidCallback onScanCode;

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _nacitaZHeliosu = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(orderFilterProvider).query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounce ~250 ms - ve fázi 2 to ušetří dotazy na server.
  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) ref.read(orderFilterProvider.notifier).setQuery(query);
    });
    setState(() {});
  }

  /// Otevře skener. Vybraný kód se doplní do hledání a rovnou se
  /// hledá v archivu - kvůli tomu se VIN fotí.
  void _skenuj() => widget.onScanCode();

  /// Dotáhne zakázky z Heliosu hned, bez čekání na pětiminutovou
  /// synchronizaci. Služba to pustí nejvýš jednou za minutu pro celou
  /// dílnu - kdo přijde dřív, dostane hlášku, za kolik to zkusit.
  ///
  /// Z prázdného výsledku hledání ([zHledani]) se jediná nalezená zakázka
  /// rovnou otevře - kvůli ní se načítalo.
  Future<void> _nacistZHeliosu({bool zHledani = false}) async {
    if (_nacitaZHeliosu) return;
    setState(() => _nacitaZHeliosu = true);
    try {
      await ref.read(serviceOrderDataSourceProvider).synchronizuj();
      if (zHledani) {
        ref.read(otevritJedinouZakazkuProvider.notifier).state = true;
      }
      ref.invalidate(ordersStreamProvider);
      await ref.read(ordersStreamProvider.future);
      if (!zHledani) _oznam('Zakázky jsou načtené z Heliosu');
    } on ServiceOrderException catch (chyba) {
      _oznam(chyba.message);
    } finally {
      if (mounted) setState(() => _nacitaZHeliosu = false);
    }
  }

  void _oznam(String zprava) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(zprava)));
  }

  /// Po naskenování otevře jedinou nalezenou zakázku. Příznak se shodí
  /// v každém případě, ať se zakázka neotevře sama později při psaní.
  void _otevriJedinou(List<ServiceOrder> nalezene) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(otevritJedinouZakazkuProvider)) return;
      ref.read(otevritJedinouZakazkuProvider.notifier).state = false;
      if (nalezene.length == 1) widget.onOpenOrder(nalezene.single);
    });
  }

  /// Stažení prstem: dílnu i archiv znovu ze serveru.
  Future<void> _obnovit() async {
    ref.invalidate(ordersStreamProvider);
    ref.invalidate(archivProvider);
  }

  /// Zruší filtry lišty, ale nechá hledaný text - kvůli němu se hledá.
  void _zrusFiltryKromeHledani() {
    final dotaz = ref.read(orderFilterProvider).query;
    ref.read(orderFilterProvider.notifier)
      ..reset()
      ..setQuery(dotaz);
  }

  void _resetFilters() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(orderFilterProvider.notifier).reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final orders = ref.watch(filteredOrdersProvider);
    final filter = ref.watch(orderFilterProvider);
    final zobrazeni = ref.watch(nastaveniProvider).zobrazeniZakazek;
    // Od tří znaků se hledá i v archivu - výsledky jsou pak ve dvou
    // částech, na dílně a v archivu.
    final hledaVArchivu = filter.query.trim().length >= 3;

    // Hledání vyplněné zvenčí (skener) se musí objevit i v poli - seznam
    // zůstává otevřený pod skenerem a pole by jinak ukazovalo starý text.
    ref.listen(orderFilterProvider, (predchozi, novy) {
      if (novy.query == predchozi?.query) return;
      if (novy.query == _searchController.text) return;
      _debounce?.cancel();
      _searchController.text = novy.query;
    });

    if (ref.watch(otevritJedinouZakazkuProvider) && orders.hasValue) {
      _otevriJedinou(orders.requireValue);
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _ListHeader(
            naTablet: widget.vRozdelenem,
            searchController: _searchController,
            onQueryChanged: _onQueryChanged,
            onScan: _skenuj,
            nacitaZHeliosu: _nacitaZHeliosu,
            onNacistZHeliosu: _nacistZHeliosu,
          ),
          const FiltrLista(),
          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ListError(
                message: '$error',
                onRetry: () => ref.invalidate(ordersStreamProvider),
              ),
              // Stažení prstem funguje i nad prázdným a krátkým seznamem:
              // dílenský stav je sdílený a člověk chce vidět, co mezitím
              // udělali ostatní, i když se nemá kam posouvat.
              // Při hledání výsledky ve dvou částech - na dílně a v archivu.
              // Karty i v režimu tabulky: nalezených je pár a archiv je
              // pod dílnou jako druhá část, kterou tabulka neumí.
              data: (data) => hledaVArchivu
                  ? RefreshIndicator.adaptive(
                      onRefresh: _obnovit,
                      child: _VysledkyHledani(
                        naDilne: data,
                        archiv: ref.watch(archivKHledaniProvider),
                        vybranaId: widget.vybranaId,
                        onOpenOrder: widget.onOpenOrder,
                        // `activeCount` počítá i hledaný text.
                        jineFiltry: filter.activeCount > 1,
                        onZrusitFiltry: _zrusFiltryKromeHledani,
                        nacitaZHeliosu: _nacitaZHeliosu,
                        onNacistZHeliosu: () => _nacistZHeliosu(zHledani: true),
                        onZnovuArchiv: () => ref.invalidate(archivProvider),
                      ),
                    )
                  : data.isEmpty
                  ? RefreshIndicator.adaptive(
                      onRefresh: () async =>
                          ref.invalidate(ordersStreamProvider),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.sizeOf(context).height * 0.6,
                          ),
                          child: OrdersEmptyState(
                            onResetFilters: _resetFilters,
                          ),
                        ),
                      ),
                    )
                  : zobrazeni == ZobrazeniZakazek.tabulka
                  ? RefreshIndicator.adaptive(
                      onRefresh: () async =>
                          ref.invalidate(ordersStreamProvider),
                      // Řádky tabulky jsou svislý seznam uvnitř vodorovně
                      // posuvné tabulky - výchozí nastavení poslouchá jen
                      // nejvyšší úroveň, a stažení prstem by nereagovalo.
                      notificationPredicate: (oznameni) =>
                          oznameni.metrics.axis == Axis.vertical,
                      child: TabulkaZakazek(
                        zakazky: data,
                        onOpenOrder: widget.onOpenOrder,
                      ),
                    )
                  : RefreshIndicator.adaptive(
                      onRefresh: () async =>
                          ref.invalidate(ordersStreamProvider),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          Insets.xl,
                          Insets.lg,
                          Insets.xl,
                          Insets.huge,
                        ),
                        itemCount: data.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Insets.md),
                        itemBuilder: (_, index) => OrderCard(
                          order: data[index],
                          onTap: () => widget.onOpenOrder(data[index]),
                          jeVybrana: widget.vybranaId == data[index].id,
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

/// Navy hlavička seznamu - titul, hledání, výběr útvaru.
class _ListHeader extends ConsumerWidget {
  const _ListHeader({
    required this.naTablet,
    required this.searchController,
    required this.onQueryChanged,
    required this.onScan,
    required this.nacitaZHeliosu,
    required this.onNacistZHeliosu,
  });

  /// Na tabletu leží hlavička ve stejné šedé jako seznam pod ní. Tmavomodrý
  /// pruh v úzkém sloupci vedle navy navigace a detailu tvořil těžký blok;
  /// na telefonu je hlavička přes celou šířku a navy zůstává.
  final bool naTablet;

  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onScan;
  final bool nacitaZHeliosu;
  final VoidCallback onNacistZHeliosu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = context.isIOS;
    final palette = context.palette;
    final employee = ref.watch(currentEmployeeProvider);
    final text = naTablet ? palette.text : Colors.white;

    return Container(
      color: naTablet ? palette.background : AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.xxl,
        MediaQuery.paddingOf(context).top + Insets.base,
        Insets.xxl,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Zakázky na dílně',
                  style: AppTextStyles.appBarTitle(
                    isIOS: isIOS,
                  ).copyWith(color: text),
                ),
              ),
              _TlacitkoHeliosu(
                naTmavem: !naTablet,
                nacita: nacitaZHeliosu,
                onPressed: onNacistZHeliosu,
              ),
              const SizedBox(width: Insets.sm),
              _PrepinacZobrazeni(naTmavem: !naTablet),
              const SizedBox(width: Insets.sm),
              _EmployeeAvatar(initials: employee?.initials ?? 'RW'),
            ],
          ),
          const SizedBox(height: Insets.lg),
          OrderSearchField(
            controller: searchController,
            onChanged: onQueryChanged,
            onScan: onScan,
            naTmavem: !naTablet,
            // Hledá se i mezi uzavřenými - ať to je vidět dřív, než
            // člověk začne psát.
            hintText: 'SPZ, VIN, zakázka – i v archivu',
          ),
        ],
      ),
    );
  }
}

/// Výsledky hledání: nejdřív zakázky na dílně, pod nimi uzavřené
/// z archivu. Archiv se hledá sám, bez tlačítka - kdo hledá zpětně, často
/// neví, jestli je zakázka ještě na dílně.
class _VysledkyHledani extends StatelessWidget {
  const _VysledkyHledani({
    required this.naDilne,
    required this.archiv,
    required this.vybranaId,
    required this.onOpenOrder,
    required this.jineFiltry,
    required this.onZrusitFiltry,
    required this.nacitaZHeliosu,
    required this.onNacistZHeliosu,
    required this.onZnovuArchiv,
  });

  final List<ServiceOrder> naDilne;

  /// `null` uvnitř = ještě se nehledá (uživatel dopisuje).
  final AsyncValue<List<ServiceOrder>?> archiv;
  final String? vybranaId;
  final void Function(ServiceOrder order) onOpenOrder;

  /// Kromě hledání je zapnutý i filtr lišty - na dílně pak může něco
  /// chybět kvůli němu.
  final bool jineFiltry;
  final VoidCallback onZrusitFiltry;
  final bool nacitaZHeliosu;
  final VoidCallback onNacistZHeliosu;
  final VoidCallback onZnovuArchiv;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final zArchivu = archiv.valueOrNull;
    final hleda = archiv.isLoading || (archiv.hasValue && zArchivu == null);

    Widget karta(ServiceOrder zakazka) => Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: OrderCard(
        order: zakazka,
        onTap: () => onOpenOrder(zakazka),
        jeVybrana: vybranaId == zakazka.id,
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.lg,
        Insets.xl,
        Insets.huge,
      ),
      children: [
        _NadpisSekce(
          key: const Key('sekce-dilna'),
          ikona: Icons.garage_rounded,
          text: 'Na dílně',
          pocet: naDilne.length,
        ),
        if (naDilne.isEmpty)
          _NicNaDilne(
            jineFiltry: jineFiltry,
            onZrusitFiltry: onZrusitFiltry,
            nacitaZHeliosu: nacitaZHeliosu,
            onNacistZHeliosu: onNacistZHeliosu,
          )
        else
          for (final zakazka in naDilne) karta(zakazka),
        const SizedBox(height: Insets.lg),
        _NadpisSekce(
          key: const Key('sekce-archiv'),
          ikona: Icons.inventory_2_outlined,
          text: 'V archivu – uzavřené',
          pocet: hleda || archiv.hasError ? null : zArchivu?.length,
        ),
        if (archiv.hasError && !hleda)
          _RadekArchivu(
            key: const Key('archiv-chyba'),
            text: archiv.error is ServiceOrderException
                ? (archiv.error! as ServiceOrderException).message
                : 'V archivu se nepodařilo hledat.',
            barva: AppColors.danger,
            akce: TextButton(
              onPressed: onZnovuArchiv,
              child: const Text('Zkusit znovu'),
            ),
          )
        else if (hleda)
          const _RadekArchivu(
            key: Key('archiv-hleda'),
            text: 'Hledám i mezi uzavřenými zakázkami…',
            nacita: true,
          )
        else if (zArchivu!.isEmpty)
          _RadekArchivu(text: 'V archivu nic dalšího.', barva: palette.muted)
        else
          for (final zakazka in zArchivu) karta(zakazka),
      ],
    );
  }
}

class _NadpisSekce extends StatelessWidget {
  const _NadpisSekce({
    super.key,
    required this.ikona,
    required this.text,
    required this.pocet,
  });

  final IconData ikona;
  final String text;

  /// `null` = ještě se neví (hledá se).
  final int? pocet;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Icon(ikona, size: 16, color: palette.muted),
          const SizedBox(width: Insets.sm),
          Text(
            pocet == null
                ? text.toUpperCase()
                : '${text.toUpperCase()} · $pocet',
            style: AppTextStyles.metaSmall.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(child: Container(height: 1, color: palette.hairline)),
        ],
      ),
    );
  }
}

class _NicNaDilne extends StatelessWidget {
  const _NicNaDilne({
    required this.jineFiltry,
    required this.onZrusitFiltry,
    required this.nacitaZHeliosu,
    required this.onNacistZHeliosu,
  });

  final bool jineFiltry;
  final VoidCallback onZrusitFiltry;
  final bool nacitaZHeliosu;
  final VoidCallback onNacistZHeliosu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final styl = TextButton.styleFrom(
      foregroundColor: AppColors.accent,
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      textStyle: AppTextStyles.cardBody.copyWith(fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            jineFiltry
                ? 'Na dílně nic neodpovídá hledání a zapnutým filtrům.'
                : 'Na dílně nic neodpovídá. Zakázku, kterou poradce právě '
                      'založil, načtete z Heliosu.',
            style: AppTextStyles.cardBody.copyWith(color: palette.muted),
          ),
          Wrap(
            spacing: Insets.sm,
            children: [
              TextButton.icon(
                onPressed: nacitaZHeliosu ? null : onNacistZHeliosu,
                style: styl,
                icon: nacitaZHeliosu
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Načíst nové zakázky z Heliosu'),
              ),
              if (jineFiltry)
                TextButton.icon(
                  onPressed: onZrusitFiltry,
                  style: styl,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: const Text('Zrušit filtry'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadekArchivu extends StatelessWidget {
  const _RadekArchivu({
    super.key,
    required this.text,
    this.barva,
    this.nacita = false,
    this.akce,
  });

  final String text;
  final Color? barva;
  final bool nacita;
  final Widget? akce;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: [
          if (nacita) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Insets.md),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.cardBody.copyWith(
                color: barva ?? palette.muted,
              ),
            ),
          ),
          ?akce,
        ],
      ),
    );
  }
}

/// Přepnutí mezi kartami a řádkovou tabulkou. Volba se pamatuje
/// v nastavení telefonu, takže seznam se příště otevře stejně.
class _PrepinacZobrazeni extends ConsumerWidget {
  const _PrepinacZobrazeni({required this.naTmavem});

  /// V navy hlavičce (telefon) jsou ikony bílé, v šedé na tabletu tmavé.
  final bool naTmavem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vybrane = ref.watch(nastaveniProvider).zobrazeniZakazek;
    final barva = naTmavem ? Colors.white : palette.text;

    Widget tlacitko(ZobrazeniZakazek zobrazeni, IconData ikona) {
      final aktivni = zobrazeni == vybrane;
      return Semantics(
        button: true,
        selected: aktivni,
        label: 'Zobrazení: ${zobrazeni.label}',
        child: GestureDetector(
          key: Key('zobrazeni-${zobrazeni.name}'),
          onTap: () => ref
              .read(nastaveniProvider.notifier)
              .zmenZobrazeniZakazek(zobrazeni),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 34,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: aktivni
                  ? (naTmavem ? Colors.white24 : palette.hairline2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Icon(
              ikona,
              size: 18,
              color: aktivni ? barva : barva.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: naTmavem ? Colors.white30 : palette.hairline2,
        ),
        borderRadius: BorderRadius.circular(Radii.chip + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tlacitko(ZobrazeniZakazek.karty, Icons.view_agenda_outlined),
          tlacitko(ZobrazeniZakazek.tabulka, Icons.table_rows_outlined),
        ],
      ),
    );
  }
}

/// Ruční načtení z Heliosu - pro zakázku, kterou poradce právě založil
/// a mechanik na ni čeká. Stažení prstem dolů Helios nevolá, jen znovu
/// načte naši databázi.
class _TlacitkoHeliosu extends StatelessWidget {
  const _TlacitkoHeliosu({
    required this.naTmavem,
    required this.nacita,
    required this.onPressed,
  });

  final bool naTmavem;
  final bool nacita;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final barva = naTmavem ? Colors.white : context.palette.text;
    return Tooltip(
      message: 'Načíst nové zakázky z Heliosu',
      child: Semantics(
        button: true,
        label: 'Načíst nové zakázky z Heliosu',
        child: GestureDetector(
          key: const Key('nacist-z-heliosu'),
          onTap: nacita ? null : onPressed,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: naTmavem ? Colors.white30 : context.palette.hairline2,
              ),
              borderRadius: BorderRadius.circular(Radii.chip + 2),
            ),
            child: nacita
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: barva,
                    ),
                  )
                : Icon(Icons.sync_rounded, size: 19, color: barva),
          ),
        ),
      ),
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 34, color: palette.muted),
            const SizedBox(height: Insets.base),
            Text(
              'Zakázky se nepodařilo načíst',
              style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.xl),
            FilledButton(onPressed: onRetry, child: const Text('Zkusit znovu')),
          ],
        ),
      ),
    );
  }
}
