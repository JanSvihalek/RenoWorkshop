import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../fotodokumentace/presentation/ziskani_fotek.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../controllers/orders_providers.dart';
import 'okno_zapisu.dart';

/// Co uživatel vyplnil: stav z číselníku nebo vlastní text, a k tomu
/// nepovinná poznámka.
class VybranyStav {
  const VybranyStav({
    this.kod,
    this.nazev,
    this.poznamka,
    this.misto,
    this.fotkaMista,
  });

  final String? kod;
  final String? nazev;

  /// Na co se čeká, co se domluvilo.
  final String? poznamka;

  /// Kde vůz po tomhle kroku stojí. `null` = nechat, co tam je,
  /// prázdný text místo smaže.
  final String? misto;

  /// Fotka místa, kam technik vůz postavil. Nahraje se do kategorie
  /// Umístění vozu; `null` = nefotil.
  final Uint8List? fotkaMista;
}

/// Formulář pro přidání dílenského stavu.
///
/// Jedno okno: nahoře výběr stavu, pod ním poznámka, dole potvrzení.
/// Dřív se stav ukládal hned po klepnutí v seznamu a poznámka se musela
/// napsat dopředu — tedy dřív, než člověk věděl, k čemu ji píše.
/// [misto] je místo, kde vůz stojí teď - předvyplní se, ať ho technik
/// při každém kroku nepíše znovu. Vzhled je stejný jako u nové poznámky
/// ([OknoZapisu]).
Future<VybranyStav?> vyberStav(
  BuildContext context, {
  String? misto,
  required String spz,
  required String cisloZakazky,
  required String autor,
}) {
  return showDialog<VybranyStav>(
    context: context,
    builder: (_) => _PridatStavOkno(
      misto: misto,
      spz: spz,
      cisloZakazky: cisloZakazky,
      autor: autor,
    ),
  );
}

/// Hodnota v seznamu, která znamená „stav mimo číselník".
const _jiny = '__jiny__';

class _PridatStavOkno extends ConsumerStatefulWidget {
  const _PridatStavOkno({
    this.misto,
    required this.spz,
    required this.cisloZakazky,
    required this.autor,
  });

  final String? misto;
  final String spz;
  final String cisloZakazky;
  final String autor;

  @override
  ConsumerState<_PridatStavOkno> createState() => _PridatStavOknoState();
}

class _PridatStavOknoState extends ConsumerState<_PridatStavOkno> {
  final _vlastni = TextEditingController();
  final _poznamka = TextEditingController();
  late final _misto = TextEditingController(text: widget.misto ?? '');

  /// Vyfocené místo, dokud se stav neuloží.
  Uint8List? _fotka;

  /// Kód vybraného stavu, `_jiny` u vlastního, `null` dokud nic nevybral.
  String? _vybrany;

  @override
  void dispose() {
    _vlastni.dispose();
    _poznamka.dispose();
    _misto.dispose();
    super.dispose();
  }

  bool get _jeVlastni => _vybrany == _jiny;

  /// Přidat jde, teprve když je co uložit.
  bool get _lzePridat =>
      _vybrany != null && (!_jeVlastni || _vlastni.text.trim().isNotEmpty);

  void _potvrd() {
    if (!_lzePridat) return;
    final poznamka = _poznamka.text.trim();
    final misto = _misto.text.trim();

    Navigator.of(context).pop(
      VybranyStav(
        kod: _jeVlastni ? null : _vybrany,
        nazev: _jeVlastni ? _vlastni.text.trim() : null,
        poznamka: poznamka.isEmpty ? null : poznamka,
        // Beze změny se místo neposílá - ať se u něj nepřepisuje čas
        // zápisu, když vůz zůstal stát.
        misto: misto == (widget.misto ?? '') ? null : misto,
        fotkaMista: _fotka,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nabidka = ref.watch(nabidkaStavuProvider);

    return OknoZapisu(
      nadpis: 'Přidat stav',
      kam: 'do postupu zakázky',
      spz: widget.spz,
      cisloZakazky: widget.cisloZakazky,
      autor: widget.autor,
      potvrdit: 'Přidat',
      onPotvrdit: _lzePridat ? _potvrd : null,
      obsah: [
        const PopisekPole('STAV'),
        nabidka.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          // Výpadek nabídky nesmí zabránit zápisu stavu - zbývá
          // vlastní text, což je pořád lepší než nic.
          error: (_, _) => _NabidkaChybi(
            text: 'Nabídku stavů se nepodařilo načíst.',
            jeVlastni: _jeVlastni,
            onVlastni: () => setState(() => _vybrany = _jiny),
          ),
          data: (stavy) => stavy.isEmpty
              ? _NabidkaChybi(
                  text: 'Číselník stavů je zatím prázdný.',
                  jeVlastni: _jeVlastni,
                  onVlastni: () => setState(() => _vybrany = _jiny),
                )
              : _VyberStavu(
                  stavy: stavy,
                  vybrany: _vybrany,
                  onZmena: (kod) => setState(() => _vybrany = kod),
                ),
        ),

        if (_jeVlastni) ...[
          const SizedBox(height: Insets.base),
          const PopisekPole('VLASTNÍ STAV'),
          PoleZapisu(
            controller: _vlastni,
            napoveda: 'Např. Čeká na díl z Německa',
            maxDelka: 100,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],

        const SizedBox(height: Insets.base),
        // Vůz se hýbe právě tehdy, když se mění, co se s ním děje -
        // proto se na místo ptáme u každého kroku.
        const PopisekPole('KDE VŮZ STOJÍ'),
        PoleZapisu(
          poleKey: const Key('stav-misto'),
          controller: _misto,
          napoveda: 'Např. stání 4, lakovna',
          maxDelka: 60,
        ),
        const SizedBox(height: Insets.xs),
        _FotkaMista(
          fotka: _fotka,
          onVyfotit: _vyfotMisto,
          onSmazat: () => setState(() => _fotka = null),
        ),

        const SizedBox(height: Insets.base),
        const PopisekPole('POZNÁMKA (NEPOVINNÁ)'),
        PoleZapisu(
          controller: _poznamka,
          napoveda: 'Např. čeká na díl',
          maxDelka: 500,
          minLines: 2,
          maxLines: 4,
          sDiktovanim: true,
        ),
      ],
    );
  }

  /// Fotka místa - na velkém parkovišti řekne víc než „stání 4".
  Future<void> _vyfotMisto() async {
    final fotka = await ref.read(ziskaniFotekProvider).jednaFotka(context);
    if (fotka != null && mounted) setState(() => _fotka = fotka);
  }
}

/// Nepovinná fotka místa: tlačítko, po vyfocení náhled s křížkem.
class _FotkaMista extends StatelessWidget {
  const _FotkaMista({
    required this.fotka,
    required this.onVyfotit,
    required this.onSmazat,
  });

  final Uint8List? fotka;
  final VoidCallback onVyfotit;
  final VoidCallback onSmazat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final vyfoceno = fotka;

    if (vyfoceno == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('vyfotit-misto'),
          onPressed: onVyfotit,
          icon: const Icon(Icons.add_a_photo_outlined, size: 20),
          label: const Text('Vyfotit místo'),
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
        ),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.input),
          child: Image.memory(
            vyfoceno,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            cacheWidth: 168,
          ),
        ),
        const SizedBox(width: Insets.base),
        Expanded(
          child: Text(
            'Fotka místa se nahraje po uložení stavu.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ),
        IconButton(
          key: const Key('zahodit-fotku-mista'),
          tooltip: 'Zahodit fotku',
          onPressed: onSmazat,
          icon: Icon(Icons.close_rounded, color: palette.muted),
        ),
      ],
    );
  }
}

class _VyberStavu extends StatelessWidget {
  const _VyberStavu({
    required this.stavy,
    required this.vybrany,
    required this.onZmena,
  });

  final List<NabidkaStavu> stavy;
  final String? vybrany;
  final ValueChanged<String?> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      decoration: vzhledRamecku(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: vybrany,
          isExpanded: true,
          hint: Text(
            'Vyberte stav',
            style: AppTextStyles.cardBody.copyWith(
              fontSize: 15,
              color: palette.muted,
            ),
          ),
          borderRadius: BorderRadius.circular(Radii.input),
          dropdownColor: palette.card,
          style: AppTextStyles.cardBody.copyWith(
            fontSize: 15,
            color: palette.text,
          ),
          items: [
            for (final stav in stavy)
              DropdownMenuItem(value: stav.kod, child: Text(stav.nazev)),
            // Na dílně se objeví situace, kterou nikdo dopředu nevymyslel;
            // čekat kvůli ní na úpravu číselníku by znamenalo, že se stav
            // nezapíše vůbec.
            DropdownMenuItem(
              value: _jiny,
              child: Text(
                'Jiný…',
                style: AppTextStyles.cardBody.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          onChanged: onZmena,
        ),
      ),
    );
  }
}

class _NabidkaChybi extends StatelessWidget {
  const _NabidkaChybi({
    required this.text,
    required this.jeVlastni,
    required this.onVlastni,
  });

  final String text;
  final bool jeVlastni;
  final VoidCallback onVlastni;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: AppTextStyles.cardBody.copyWith(color: palette.muted),
        ),
        if (!jeVlastni) ...[
          const SizedBox(height: Insets.sm),
          OutlinedButton.icon(
            onPressed: onVlastni,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Zapsat vlastní stav'),
          ),
        ],
      ],
    );
  }
}
