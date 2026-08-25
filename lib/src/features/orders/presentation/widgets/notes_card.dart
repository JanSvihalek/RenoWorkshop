import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/order_note.dart';
import 'detail_cards.dart';

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
              const Expanded(child: SectionLabel('POZNÁMKY')),
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

/// Dialog pro přidání poznámky. Vrací text, nebo `null` při zrušení.
Future<String?> showAddNoteDialog(BuildContext context) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: const Text('Nová poznámka'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Co je na zakázce nového?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Uložit'),
        ),
      ],
    ),
  );
}
