import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/czech_plurals.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/orders_providers.dart';
import '../widgets/branch_segmented_control.dart';
import '../widgets/order_card.dart';
import '../widgets/order_filter_sheet.dart';
import '../widgets/order_search_field.dart';
import '../widgets/orders_empty_state.dart';
import '../widgets/status_filter_chips.dart';
import '../../../../core/widgets/workshop_bottom_nav.dart';

/// Hlavní obrazovka: všechny zakázky na dílně (ne "moje vozidlo").
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({
    super.key,
    required this.onOpenOrder,
    required this.onSelectTab,
  });

  final void Function(ServiceOrder order) onOpenOrder;
  final ValueChanged<WorkshopTab> onSelectTab;

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

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

  void _resetFilters() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(orderFilterProvider.notifier).reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filter = ref.watch(orderFilterProvider);
    final orders = ref.watch(filteredOrdersProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _ListHeader(
            visibleCount: orders.valueOrNull?.length,
            searchController: _searchController,
            onQueryChanged: _onQueryChanged,
          ),
          StatusFilterChips(
            selected: filter.status,
            onChanged: ref.read(orderFilterProvider.notifier).setStatus,
          ),
          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ListError(
                message: '$error',
                onRetry: () => ref.invalidate(ordersStreamProvider),
              ),
              data: (data) => data.isEmpty
                  ? SingleChildScrollView(
                      child: OrdersEmptyState(onResetFilters: _resetFilters),
                    )
                  : RefreshIndicator.adaptive(
                      onRefresh: () async =>
                          ref.invalidate(ordersStreamProvider),
                      child: ListView.separated(
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
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: WorkshopBottomNav(
        active: WorkshopTab.orders,
        onSelect: widget.onSelectTab,
      ),
    );
  }
}

/// Navy hlavička seznamu - titul, hledání, přepínač poboček.
class _ListHeader extends ConsumerWidget {
  const _ListHeader({
    required this.visibleCount,
    required this.searchController,
    required this.onQueryChanged,
  });

  final int? visibleCount;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = context.isIOS;
    final filter = ref.watch(orderFilterProvider);
    final employee = ref.watch(currentEmployeeProvider);

    return Container(
      color: AppColors.primary,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zakázky na dílně',
                      style: AppTextStyles.appBarTitle(
                        isIOS: isIOS,
                      ).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      visibleCount == null
                          ? 'Načítám zakázky...'
                          : '${orderCountLabel(visibleCount!)} · směna 6:30-15:00',
                      style: AppTextStyles.appBarMeta.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIconButton(
                icon: Icons.tune_rounded,
                badgeCount: filter.activeCount,
                onTap: () => OrderFilterSheet.show(context),
              ),
              const SizedBox(width: Insets.md),
              _EmployeeAvatar(initials: employee?.initials ?? 'RW'),
            ],
          ),
          const SizedBox(height: Insets.lg),
          OrderSearchField(
            controller: searchController,
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: Insets.lg),
          BranchSegmentedControl(
            branches: ref.watch(availableBranchesProvider),
            selectedCode: filter.branchCode,
            onChanged: ref.read(orderFilterProvider.notifier).setBranch,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Řazení a filtry',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
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
