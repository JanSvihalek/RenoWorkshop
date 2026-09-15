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

/// Hlavní obrazovka: všechny zakázky na dílně (ne "moje vozidlo").
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({
    super.key,
    required this.onOpenOrder,
    this.vRozdelenem = false,
    this.vybranaId,
    required this.onSearchArchive,
    required this.onScanCode,
  });

  final void Function(ServiceOrder order) onOpenOrder;

  /// Na tabletu je seznam levý sloupec vedle detailu: nemá vlastní spodní
  /// navigaci (ta je jako svislý pruh vlevo) a označuje vybranou zakázku.
  final bool vRozdelenem;

  /// Číslo právě otevřené zakázky - v rozděleném zobrazení musí být na
  /// první pohled poznat, ke které kartě patří detail vedle.
  final String? vybranaId;
  final ValueChanged<String> onSearchArchive;

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

  /// Dotáhne zakázky z Heliosu hned. Když pak hledání najde jedinou,
  /// otevře se - kvůli ní se načítalo.
  Future<void> _nacistZHeliosu() async {
    setState(() => _nacitaZHeliosu = true);
    try {
      await ref.read(serviceOrderDataSourceProvider).synchronizuj();
      ref.read(otevritJedinouZakazkuProvider.notifier).state = true;
      ref.invalidate(ordersStreamProvider);
      await ref.read(ordersStreamProvider.future);
    } on ServiceOrderException catch (chyba) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(chyba.message)));
      }
    } finally {
      if (mounted) setState(() => _nacitaZHeliosu = false);
    }
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
            // Archiv se nabízí, jakmile je co hledat - ne až když seznam
            // nic nenajde. Zakázka může být rozdělaná i v archivu (starší
            // oprava téhož vozu) a tudy se k ní člověk dostane rovnou.
            onHledatVArchivu: filter.query.trim().length >= 3
                ? () => widget.onSearchArchive(filter.query.trim())
                : null,
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
              data: (data) => data.isEmpty
                  ? RefreshIndicator.adaptive(
                      onRefresh: () async =>
                          ref.invalidate(ordersStreamProvider),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        // Jen nejmenší výška, ne pevná: s nabídkou Heliosu
                        // a archivu by se na nízkém displeji nevešel.
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.sizeOf(context).height * 0.6,
                          ),
                          child: OrdersEmptyState(
                            onResetFilters: _resetFilters,
                            onNacistZHeliosu:
                                _searchController.text.trim().length >= 3
                                ? _nacistZHeliosu
                                : null,
                            nacitaZHeliosu: _nacitaZHeliosu,
                            onHledatVArchivu:
                                _searchController.text.trim().length >= 3
                                ? () => widget.onSearchArchive(
                                    _searchController.text.trim(),
                                  )
                                : null,
                          ),
                        ),
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
    required this.onHledatVArchivu,
  });

  /// Na tabletu leží hlavička ve stejné šedé jako seznam pod ní. Tmavomodrý
  /// pruh v úzkém sloupci vedle navy navigace a detailu tvořil těžký blok;
  /// na telefonu je hlavička přes celou šířku a navy zůstává.
  final bool naTablet;

  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onScan;

  /// `null`, dokud není zadaný dost dlouhý dotaz.
  final VoidCallback? onHledatVArchivu;

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
              _EmployeeAvatar(initials: employee?.initials ?? 'RW'),
            ],
          ),
          const SizedBox(height: Insets.lg),
          OrderSearchField(
            controller: searchController,
            onChanged: onQueryChanged,
            onScan: onScan,
            naTmavem: !naTablet,
          ),
          if (onHledatVArchivu != null) ...[
            const SizedBox(height: Insets.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onHledatVArchivu,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: naTablet ? AppColors.accent : Colors.white70,
                      ),
                      const SizedBox(width: Insets.xs),
                      Text(
                        'Hledat i v archivu',
                        style: AppTextStyles.cardBody.copyWith(
                          color: naTablet ? AppColors.accent : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
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
