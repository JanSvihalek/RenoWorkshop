import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/work_item.dart';
import '../controllers/order_actions_controller.dart';
import '../controllers/orders_providers.dart';
import '../widgets/detail_cards.dart';
import '../widgets/mechanic_card.dart';
import '../widgets/notes_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/status_timeline.dart';
import '../widgets/work_items_card.dart';

/// Detail zakázky: stav, časová osa, vozidlo, mechanik, úkony, poznámky.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.onBack,
  });

  final String orderId;
  final VoidCallback onBack;

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
          return _DetailBody(order: order, onBack: onBack);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.order, required this.onBack});

  final ServiceOrder order;
  final VoidCallback onBack;

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    final next = await ref
        .read(orderActionsProvider.notifier)
        .advanceStatus(order);
    if (next != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${order.id} · nový stav: ${next.label}')),
        );
    }
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final text = await showAddNoteDialog(context);
    if (text == null || text.isEmpty) return;
    await ref
        .read(orderActionsProvider.notifier)
        .addNote(orderId: order.id, text: text);
  }

  void _toggleWorkItem(WidgetRef ref, WorkItem item, bool isDone) {
    ref
        .read(orderActionsProvider.notifier)
        .setWorkItemDone(
          orderId: order.id,
          workItemId: item.id,
          isDone: isDone,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(orderActionsProvider).isLoading;
    final overdue = order.isOverdue();

    return Column(
      children: [
        _DetailHeader(order: order, onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.xl,
              Insets.xl,
              Insets.huge,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: InfoBox(
                      label: 'PŘIJATO',
                      value: AppDateFormat.dateTime(order.receivedAt),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: InfoBox(
                      label: 'TERMÍN DOKONČENÍ',
                      value: AppDateFormat.date(order.dueAt),
                      valueColor: overdue ? AppColors.danger : null,
                    ),
                  ),
                ],
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
                    const SectionLabel('POSTUP ZAKÁZKY'),
                    const SizedBox(height: Insets.lg),
                    StatusTimeline(status: order.status, bay: order.bayLabel),
                  ],
                ),
              ),
              const SizedBox(height: Insets.base),
              MechanicCard(
                order: order,
                onContact: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Kontakt na mechanika - připravujeme.'),
                    ),
                  ),
              ),
              const SizedBox(height: Insets.base),
              WorkItemsCard(
                items: order.workItems,
                isBusy: isBusy,
                onToggle: (item, isDone) => _toggleWorkItem(ref, item, isDone),
              ),
              const SizedBox(height: Insets.base),
              NotesCard(
                notes: order.notes,
                onAddNote: () => _addNote(context, ref),
              ),
            ],
          ),
        ),
        _AdvanceStatusBar(
          order: order,
          isBusy: isBusy,
          onAdvance: () => _advance(context, ref),
        ),
      ],
    );
  }
}

/// Navy hlavička detailu - identifikace vozidla a zakázky.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.order, required this.onBack});

  final ServiceOrder order;
  final VoidCallback onBack;

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
              Text(
                order.id,
                style: AppTextStyles.orderNumber.copyWith(
                  fontSize: 13,
                  letterSpacing: 0.52,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: Insets.base),
              StatusBadge(status: order.status, fontSize: 12),
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
          const SizedBox(height: Insets.lg),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              _HeaderChip(order.customerName),
              _HeaderChip('Pobočka ${order.branch.label}'),
              _HeaderChip('VIN ${order.vin}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: AppTextStyles.meta.copyWith(
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

/// Spodní lišta s hlavní akcí - posun zakázky o krok dál.
class _AdvanceStatusBar extends StatelessWidget {
  const _AdvanceStatusBar({
    required this.order,
    required this.isBusy,
    required this.onAdvance,
  });

  final ServiceOrder order;
  final bool isBusy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIOS = context.isIOS;
    final next = order.status.next;
    final enabled = next != null && !isBusy;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.base,
        Insets.xl,
        MediaQuery.paddingOf(context).bottom + Insets.base,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          onTap: enabled ? onAdvance : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: Sizes.ctaHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: next != null ? AppColors.primary : palette.plate,
              // Android: pill CTA, iOS: jemně zaoblený obdélník.
              borderRadius: BorderRadius.circular(
                isIOS ? Radii.ctaIos : Radii.ctaAndroid,
              ),
              boxShadow: next != null
                  ? const [
                      BoxShadow(
                        color: Color(0x47031E49),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    next != null
                        ? 'Posunout na: ${next.label}'
                        : 'Zakázka uzavřena',
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: next != null ? Colors.white : palette.muted,
                    ),
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
