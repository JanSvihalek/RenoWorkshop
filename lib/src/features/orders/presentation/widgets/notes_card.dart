import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/order_note.dart';
import 'detail_cards.dart';
import 'okno_zapisu.dart';

/// Poznámky mechanika a poradce, nejnovější nahoře.
class NotesCard extends StatelessWidget {
  const NotesCard({super.key, required this.notes, required this.onAddNote});

  final List<OrderNote> notes;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sorted = [...notes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('PRACOVNÍ LIST / POZNÁMKY')),
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
          for (final note in sorted) _NoteRow(note: note),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final OrderNote note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.text,
                  style: AppTextStyles.noteText.copyWith(color: palette.text),
                ),
                const SizedBox(height: 3),
                Text(
                  '${note.author} · ${AppDateFormat.relativeDateTime(note.createdAt)}',
                  style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nejdelší poznámka do pracovního listu.
const maxDelkaPoznamky = 500;

/// Dialog pro přidání poznámky do pracovního listu. Vrací text, nebo
/// `null` při zrušení.
///
/// [spz] a [cisloZakazky] jsou v hlavičce, ať technik ví, ke kterému vozu
/// píše; [autor] je jméno, pod kterým se poznámka uloží.
Future<String?> showAddNoteDialog(
  BuildContext context, {
  required String spz,
  required String cisloZakazky,
  required String autor,
}) {
  return showDialog<String>(
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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _lzeUlozit => _text.text.trim().isNotEmpty;

  void _uloz() {
    if (!_lzeUlozit) return;
    Navigator.of(context).pop(_text.text.trim());
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
      ],
    );
  }
}
