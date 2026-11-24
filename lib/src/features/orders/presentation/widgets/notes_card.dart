import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/order_note.dart';
import 'detail_cards.dart';
import 'okno_zapisu.dart';

/// Zvýrazněné poznámky nahoře, jinak nejnovější nahoře.
List<OrderNote> serazenePoznamky(List<OrderNote> notes) =>
    [...notes]..sort((a, b) {
      if (a.zvyraznena != b.zvyraznena) return a.zvyraznena ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

/// Žlutá zvýrazněné poznámky - jako web (`--oranzova`).
({Color znacka, Color pozadi, Color text}) _zluta(BuildContext context) {
  final tmava = context.isDarkMode;
  return (
    znacka: const Color(0xFFE8A93A),
    pozadi: const Color(0xFFE8A93A).withValues(alpha: tmava ? 0.18 : 0.16),
    text: tmava ? const Color(0xFFE8A93A) : const Color(0xFFB8740A),
  );
}

/// Poznámky mechanika a poradce. Zvýrazněné (zapnout jde při psaní
/// i později) jsou nahoře a žlutě, ať je na první pohled vidět, že tam
/// něco důležitého je.
class NotesCard extends StatelessWidget {
  const NotesCard({
    super.key,
    required this.notes,
    required this.onAddNote,
    this.onZvyraznit,
  });

  final List<OrderNote> notes;

  /// `null` = jen čtení, bez přidávání.
  final VoidCallback? onAddNote;

  /// Zapne / vypne zvýraznění. `null` = jen čtení.
  final void Function(OrderNote note, bool zvyraznit)? onZvyraznit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sorted = serazenePoznamky(notes);

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('PRACOVNÍ LIST / POZNÁMKY')),
              if (onAddNote != null)
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: onAddNote,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Přidat',
                        style: AppTextStyles.chip.copyWith(
                          fontSize: 13,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          if (sorted.isEmpty)
            Text(
              'Zatím žádné poznámky.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          for (final note in sorted)
            _NoteRow(
              key: Key('poznamka-${note.id}'),
              note: note,
              onZvyraznit: onZvyraznit == null
                  ? null
                  : () => onZvyraznit!(note, !note.zvyraznena),
            ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({super.key, required this.note, this.onZvyraznit});

  final OrderNote note;
  final VoidCallback? onZvyraznit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final zluta = _zluta(context);
    final zvyraznena = note.zvyraznena;

    final vlajka = Icon(
      zvyraznena ? Icons.flag_rounded : Icons.outlined_flag_rounded,
      size: 20,
      color: zvyraznena ? zluta.text : palette.muted,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.lg),
      padding: zvyraznena
          ? const EdgeInsets.fromLTRB(Insets.md, Insets.sm, 0, Insets.sm)
          : EdgeInsets.zero,
      decoration: zvyraznena
          ? BoxDecoration(
              color: zluta.pozadi,
              borderRadius: BorderRadius.circular(Radii.input),
              border: Border(left: BorderSide(color: zluta.znacka, width: 3)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!zvyraznena) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: palette.hairline2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.text,
                  style: AppTextStyles.noteText.copyWith(
                    color: palette.text,
                    fontWeight: zvyraznena ? FontWeight.w600 : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${note.author} · ${AppDateFormat.relativeDateTime(note.createdAt)}',
                  style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          if (onZvyraznit != null)
            IconButton(
              key: Key('poznamka-zvyraznit-${note.id}'),
              tooltip: zvyraznena ? 'Zrušit zvýraznění' : 'Zvýraznit',
              onPressed: onZvyraznit,
              visualDensity: VisualDensity.compact,
              icon: vlajka,
            )
          else if (zvyraznena)
            Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Tooltip(message: 'Zvýrazněná', child: vlajka),
            ),
        ],
      ),
    );
  }
}

/// Nejdelší poznámka do pracovního listu.
const maxDelkaPoznamky = 500;

/// Co technik napsal: text a jestli poznámku hned zvýraznit.
typedef NovaPoznamka = ({String text, bool zvyraznit});

/// Dialog pro přidání poznámky do pracovního listu. Vrací text a volbu
/// zvýraznění, nebo `null` při zrušení.
///
/// [spz] a [cisloZakazky] jsou v hlavičce, ať technik ví, ke kterému vozu
/// píše; [autor] je jméno, pod kterým se poznámka uloží.
Future<NovaPoznamka?> showAddNoteDialog(
  BuildContext context, {
  required String spz,
  required String cisloZakazky,
  required String autor,
}) {
  return showDialog<NovaPoznamka>(
    context: context,
    builder: (_) =>
        _NovaPoznamkaDialog(spz: spz, cisloZakazky: cisloZakazky, autor: autor),
  );
}

class _NovaPoznamkaDialog extends StatefulWidget {
  const _NovaPoznamkaDialog({
    required this.spz,
    required this.cisloZakazky,
    required this.autor,
  });

  final String spz;
  final String cisloZakazky;
  final String autor;

  @override
  State<_NovaPoznamkaDialog> createState() => _NovaPoznamkaDialogState();
}

class _NovaPoznamkaDialogState extends State<_NovaPoznamkaDialog> {
  final _text = TextEditingController();
  bool _zvyraznit = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _lzeUlozit => _text.text.trim().isNotEmpty;

  void _uloz() {
    if (!_lzeUlozit) return;
    Navigator.of(context).pop((text: _text.text.trim(), zvyraznit: _zvyraznit));
  }

  @override
  Widget build(BuildContext context) {
    return OknoZapisu(
      nadpis: 'Nová poznámka',
      kam: 'do pracovního listu',
      spz: widget.spz,
      cisloZakazky: widget.cisloZakazky,
      autor: widget.autor,
      potvrdit: 'Uložit',
      potvrditKey: const Key('nova-poznamka-ulozit'),
      onPotvrdit: _lzeUlozit ? _uloz : null,
      obsah: [
        PoleZapisu(
          poleKey: const Key('nova-poznamka-text'),
          controller: _text,
          napoveda: 'Co je na zakázce nového?',
          maxDelka: maxDelkaPoznamky,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          sDiktovanim: true,
          // Tlačítko Uložit se rozsvítí s prvním znakem.
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Insets.sm),
        CheckboxListTile(
          key: const Key('nova-poznamka-zvyraznit'),
          value: _zvyraznit,
          onChanged: (v) => setState(() => _zvyraznit = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Zvýraznit'),
          subtitle: const Text('Poznámka bude nahoře a žlutě'),
        ),
      ],
    );
  }
}
