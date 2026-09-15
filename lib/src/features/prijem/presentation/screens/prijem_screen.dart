import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../../orders/presentation/widgets/order_search_field.dart';
import '../controllers/prijem_providers.dart';

/// SPZ tak, jak se porovnává: velká písmena, bez mezer a pomlček.
String kodSpz(String spz) => spz.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Rozdělané zakázky, jejichž SPZ obsahuje dotaz. Nejnovější příjem první.
List<ServiceOrder> zakazkyPodleSpz(List<ServiceOrder> zakazky, String dotaz) {
  final hledane = kodSpz(dotaz);
  if (hledane.length < 3) return const [];
  return [
    for (final zakazka in zakazky)
      if (kodSpz(zakazka.licensePlate).contains(hledane)) zakazka,
  ]..sort(
    (a, b) =>
        (b.receivedAt ?? DateTime(0)).compareTo(a.receivedAt ?? DateTime(0)),
  );
}

/// Příjem vozidla - najít zakázku podle SPZ, projít checklist a nafotit vůz.
///
/// Hledá se mezi zakázkami na dílně: vůz, který se přijímá, má zakázku
/// založenou v Heliosu. Když ji poradce založil před chvílí a synchronizace
/// ji ještě nedotáhla, jde ji dotáhnout tlačítkem.
class PrijemScreen extends ConsumerStatefulWidget {
  const PrijemScreen({
    super.key,
    required this.onOpenZakazka,
    required this.onScan,
  });

  final void Function(ServiceOrder zakazka) onOpenZakazka;
  final VoidCallback onScan;

  @override
  ConsumerState<PrijemScreen> createState() => _PrijemScreenState();
}

class _PrijemScreenState extends ConsumerState<PrijemScreen> {
  final TextEditingController _pole = TextEditingController();
  Timer? _debounce;
  bool _synchronizuje = false;

  /// Poslední dotaz, který do providera poslalo samo pole - změna zvenčí
  /// (skener) se pozná podle toho, že je jiný.
  String _odeslany = '';

  @override
  void initState() {
    super.initState();
    _pole.text = ref.read(dotazPrijmuProvider);
    _odeslany = _pole.text;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pole.dispose();
    super.dispose();
  }

  void _psani(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(otevritJedinyPrijemProvider.notifier).state = false;
      _odeslany = text;
      ref.read(dotazPrijmuProvider.notifier).state = text;
    });
    setState(() {});
  }

  /// Dotáhne zakázky z Heliosu hned, bez čekání na pětiminutový běh.
  Future<void> _synchronizuj() async {
    setState(() => _synchronizuje = true);
    try {
      await ref.read(serviceOrderDataSourceProvider).synchronizuj();
      ref.invalidate(ordersStreamProvider);
      await ref.read(ordersStreamProvider.future);
    } on ServiceOrderException catch (chyba) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(chyba.message)));
      }
    } finally {
      if (mounted) setState(() => _synchronizuje = false);
    }
  }

  void _otevriJedinou(List<ServiceOrder> nalezene) {
    if (!ref.read(otevritJedinyPrijemProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(otevritJedinyPrijemProvider)) return;
      ref.read(otevritJedinyPrijemProvider.notifier).state = false;
      if (nalezene.length == 1) widget.onOpenZakazka(nalezene.single);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dotaz = ref.watch(dotazPrijmuProvider);

    ref.listen(dotazPrijmuProvider, (_, novy) {
      if (novy == _odeslany) return;
      _odeslany = novy;
      _debounce?.cancel();
      _pole.text = novy;
      setState(() {});
    });

    final zakazky = ref.watch(ordersStreamProvider);
    final nalezene = zakazkyPodleSpz(zakazky.valueOrNull ?? const [], dotaz);
    if (zakazky.hasValue && kodSpz(dotaz).length >= 3) _otevriJedinou(nalezene);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          Container(
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
                Text(
                  'Příjem vozidla',
                  style: AppTextStyles.appBarTitle(
                    isIOS: context.isIOS,
                  ).copyWith(color: Colors.white),
                ),
                const SizedBox(height: Insets.lg),
                OrderSearchField(
                  controller: _pole,
                  onChanged: _psani,
                  onScan: widget.onScan,
                  hintText: 'SPZ vozidla',
                ),
              ],
            ),
          ),
          Expanded(
            child: kodSpz(dotaz).length < 3
                ? const _Sdeleni(
                    ikona: Icons.fact_check_outlined,
                    titulek: 'Najděte zakázku',
                    text:
                        'Naskenujte nebo napište SPZ přijímaného vozu. '
                        'U zakázky pak projdete kontrolu a nafotíte vůz.',
                  )
                : zakazky.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (chyba, _) => _Sdeleni(
                      ikona: Icons.cloud_off_rounded,
                      titulek: 'Zakázky se nepodařilo načíst',
                      text: '$chyba',
                    ),
                    data: (_) => nalezene.isEmpty
                        ? _Nenalezeno(
                            synchronizuje: _synchronizuje,
                            onSynchronizuj: _synchronizuj,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              Insets.xl,
                              Insets.lg,
                              Insets.xl,
                              Insets.giant,
                            ),
                            itemCount: nalezene.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: Insets.md),
                            itemBuilder: (_, index) => OrderCard(
                              order: nalezene[index],
                              onTap: () =>
                                  widget.onOpenZakazka(nalezene[index]),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Nenalezeno extends StatelessWidget {
  const _Nenalezeno({
    required this.synchronizuje,
    required this.onSynchronizuj,
  });

  final bool synchronizuje;
  final VoidCallback onSynchronizuj;

  @override
  Widget build(BuildContext context) {
    return _Sdeleni(
      ikona: Icons.search_off_rounded,
      titulek: 'Zakázka na dílně nenalezena',
      text:
          'Pokud ji poradce v Heliosu založil před chvílí, '
          'načtěte nové zakázky.',
      akce: FilledButton.icon(
        onPressed: synchronizuje ? null : onSynchronizuj,
        icon: synchronizuje
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync_rounded),
        label: const Text('Načíst nové zakázky z Heliosu'),
      ),
    );
  }
}

class _Sdeleni extends StatelessWidget {
  const _Sdeleni({
    required this.ikona,
    required this.titulek,
    required this.text,
    this.akce,
  });

  final IconData ikona;
  final String titulek;
  final String text;
  final Widget? akce;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikona, size: 44, color: palette.muted),
            const SizedBox(height: Insets.lg),
            Text(
              titulek,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
            if (akce != null) ...[const SizedBox(height: Insets.xl), akce!],
          ],
        ),
      ),
    );
  }
}
