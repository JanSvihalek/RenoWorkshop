import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../controllers/orders_providers.dart';

/// Co uživatel vybral: buď stav z číselníku, nebo vlastní text,
/// a k tomu nepovinná poznámka.
class VybranyStav {
  const VybranyStav({this.kod, this.nazev, this.poznamka});

  final String? kod;
  final String? nazev;

  /// Kde vůz stojí, na kterém zvedáku, na co se čeká.
  final String? poznamka;
}

/// Výběr dílenského stavu.
///
/// Nabídka je číselník ze serveru; pod ní je „Jiný" pro stav, na který se
/// nepamatovalo. Ruční zápis tu je schválně: na klempírně se objeví situace,
/// kterou nikdo dopředu nevymyslel, a čekat kvůli ní na úpravu číselníku by
/// znamenalo, že se stav nezapíše vůbec.
Future<VybranyStav?> vyberStav(BuildContext context) {
  return showModalBottomSheet<VybranyStav>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _PridatStavSheet(),
  );
}

class _PridatStavSheet extends ConsumerStatefulWidget {
  const _PridatStavSheet();

  @override
  ConsumerState<_PridatStavSheet> createState() => _PridatStavSheetState();
}

class _PridatStavSheetState extends ConsumerState<_PridatStavSheet> {
  final _vlastni = TextEditingController();
  final _poznamka = TextEditingController();
  bool _pisiVlastni = false;

  @override
  void dispose() {
    _vlastni.dispose();
    _poznamka.dispose();
    super.dispose();
  }

  String? get _zadanaPoznamka {
    final text = _poznamka.text.trim();
    return text.isEmpty ? null : text;
  }

  void _potvrdVlastni() {
    final text = _vlastni.text.trim();
    if (text.isEmpty) return;
    Navigator.of(
      context,
    ).pop(VybranyStav(nazev: text, poznamka: _zadanaPoznamka));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final nabidka = ref.watch(nabidkaStavuProvider);

    return SafeArea(
      child: Padding(
        // Klávesnice nesmí překrýt pole pro vlastní stav.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xxl,
                Insets.xl,
                Insets.xxl,
                Insets.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Přidat stav',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: palette.text,
                      ),
                    ),
                  ),
                  // Bez téhle cesty ven se z omylem otevřené nabídky dalo
                  // odejít jen tím, že člověk nějaký stav opravdu zadal.
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Zavřít',
                    color: palette.muted,
                  ),
                ],
              ),
            ),

            if (!_pisiVlastni)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.xxl,
                  0,
                  Insets.xxl,
                  Insets.base,
                ),
                // Poznámka se píše před výběrem stavu, ne po něm: výběr
                // stav rovnou uloží a zavře nabídku, takže pole potom
                // nemá kam patřit. Kdo poznámku nechce, pole přeskočí.
                child: TextField(
                  controller: _poznamka,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.cardBody.copyWith(color: palette.text),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'Poznámka (nepovinná) – např. stání 4',
                    hintStyle: AppTextStyles.cardBody.copyWith(
                      color: palette.muted,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.input),
                    ),
                  ),
                ),
              ),

            if (_pisiVlastni)
              _VlastniStav(
                controller: _vlastni,
                onPotvrdit: _potvrdVlastni,
                onZpet: () => setState(() => _pisiVlastni = false),
              )
            else
              Flexible(
                child: nabidka.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Insets.giant),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  // Výpadek nabídky nesmí zabránit zápisu stavu - zbývá
                  // vlastní text, což je pořád lepší než nic.
                  error: (_, _) => _Sdeleni(
                    text:
                        'Nabídku stavů se nepodařilo načíst. '
                        'Stav můžete zapsat ručně.',
                    onVlastni: () => setState(() => _pisiVlastni = true),
                  ),
                  data: (stavy) => stavy.isEmpty
                      ? _Sdeleni(
                          text: 'Číselník stavů je zatím prázdný.',
                          onVlastni: () => setState(() => _pisiVlastni = true),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: Insets.sm),
                          children: [
                            for (final stav in stavy)
                              ListTile(
                                title: Text(
                                  stav.nazev,
                                  style: AppTextStyles.cardBody.copyWith(
                                    color: palette.text,
                                  ),
                                ),
                                onTap: () => Navigator.of(context).pop(
                                  VybranyStav(
                                    kod: stav.kod,
                                    poznamka: _zadanaPoznamka,
                                  ),
                                ),
                              ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.edit_note_rounded),
                              title: Text(
                                'Jiný…',
                                style: AppTextStyles.cardBody.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => setState(() => _pisiVlastni = true),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VlastniStav extends StatelessWidget {
  const _VlastniStav({
    required this.controller,
    required this.onPotvrdit,
    required this.onZpet,
  });

  final TextEditingController controller;
  final VoidCallback onPotvrdit;
  final VoidCallback onZpet;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xxl,
        Insets.sm,
        Insets.xxl,
        Insets.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.cardBody.copyWith(color: palette.text),
            decoration: InputDecoration(
              hintText: 'Např. Čeká na díl z Německa',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.input),
              ),
            ),
            onSubmitted: (_) => onPotvrdit(),
          ),
          Row(
            children: [
              TextButton(onPressed: onZpet, child: const Text('Zpět')),
              const Spacer(),
              FilledButton(
                onPressed: onPotvrdit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Přidat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sdeleni extends StatelessWidget {
  const _Sdeleni({required this.text, required this.onVlastni});

  final String text;
  final VoidCallback onVlastni;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xxl,
        Insets.sm,
        Insets.xxl,
        Insets.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTextStyles.cardBody.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.base),
          FilledButton.icon(
            onPressed: onVlastni,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Zapsat vlastní stav'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
