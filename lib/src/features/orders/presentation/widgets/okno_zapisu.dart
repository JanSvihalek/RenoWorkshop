import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';

/// Společný vzhled oken, kterými se do zakázky něco zapisuje (poznámka do
/// pracovního listu, dílenský stav).
///
/// Nahoře nadpis a ke kterému vozu se píše, pod tím [obsah], dole kdo se
/// pod zápis podepíše a Zrušit / potvrzení. [onPotvrdit] `null` = zatím
/// není co uložit, tlačítko je šedé.
class OknoZapisu extends StatelessWidget {
  const OknoZapisu({
    super.key,
    required this.nadpis,
    required this.kam,
    required this.spz,
    required this.cisloZakazky,
    required this.autor,
    required this.potvrdit,
    required this.onPotvrdit,
    required this.obsah,
    this.potvrditKey,
  });

  final String nadpis;

  /// Kam zápis patří - „do pracovního listu", „do postupu zakázky".
  final String kam;
  final String spz;
  final String cisloZakazky;
  final String autor;

  /// Text potvrzovacího tlačítka.
  final String potvrdit;
  final VoidCallback? onPotvrdit;
  final Key? potvrditKey;
  final List<Widget> obsah;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Dialog(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Insets.xxl,
        vertical: Insets.xl,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Insets.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hlavicka(context),
              const SizedBox(height: Insets.xl),
              ...obsah,
              const SizedBox(height: Insets.xxl),
              _paticka(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hlavicka(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nadpis,
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$kam · '),
                    TextSpan(
                      text: spz,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    TextSpan(text: ' · $cisloZakazky'),
                  ],
                ),
                style: AppTextStyles.meta.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.base),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Zavřít',
          icon: const Icon(Icons.close_rounded, size: 20),
          color: palette.muted2,
          style: IconButton.styleFrom(backgroundColor: palette.plate),
        ),
      ],
    );
  }

  Widget _paticka(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Uloží se jako $autor · teď',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ),
        const SizedBox(width: Insets.base),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: palette.text,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          ),
          child: Text('Zrušit', style: AppTextStyles.buttonLabel),
        ),
        const SizedBox(width: Insets.sm),
        FilledButton(
          key: potvrditKey,
          onPressed: onPotvrdit,
          style: FilledButton.styleFrom(
            // Tmavomodrá by na tmavém okně zanikla.
            backgroundColor: context.isDarkMode
                ? AppColors.accent
                : AppColors.primary,
            disabledBackgroundColor: palette.plate,
            disabledForegroundColor: palette.muted,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.button),
            ),
          ),
          child: Text(potvrdit, style: AppTextStyles.buttonLabel),
        ),
      ],
    );
  }
}

/// Rámeček pole v [OknoZapisu]; s fokusem se obarví.
BoxDecoration vzhledRamecku(BuildContext context, {bool aktivni = false}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(Radii.button),
    border: Border.all(
      color: aktivni ? AppColors.accent : context.palette.hairline2,
      width: 1.5,
    ),
  );
}

/// Popisek nad polem - „STAV", „KDE VŮZ STOJÍ".
class PopisekPole extends StatelessWidget {
  const PopisekPole(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xs),
      child: Text(
        text,
        style: AppTextStyles.overline.copyWith(color: context.palette.muted),
      ),
    );
  }
}

/// Textové pole v rámečku [OknoZapisu].
///
/// S [sDiktovanim] má pod textem řádek s nápovědou k diktování a
/// počítadlem znaků - pro delší texty. [poleKey] dostane samotný
/// [TextField].
class PoleZapisu extends StatefulWidget {
  const PoleZapisu({
    super.key,
    required this.controller,
    required this.napoveda,
    required this.maxDelka,
    this.poleKey,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.sDiktovanim = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String napoveda;
  final int maxDelka;
  final Key? poleKey;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  final bool sDiktovanim;
  final ValueChanged<String>? onChanged;

  @override
  State<PoleZapisu> createState() => _PoleZapisuState();
}

class _PoleZapisuState extends State<PoleZapisu> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rámeček se mění s fokusem, počítadlo s psaním.
    _focus.addListener(_obnov);
    widget.controller.addListener(_obnov);
  }

  @override
  void didUpdateWidget(PoleZapisu old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_obnov);
      widget.controller.addListener(_obnov);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_obnov);
    _focus.dispose();
    super.dispose();
  }

  void _obnov() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final viceRadku = widget.maxLines > 1;
    final textPole = viceRadku
        ? AppTextStyles.noteText.copyWith(fontSize: 15)
        : AppTextStyles.cardBody.copyWith(fontSize: 15);
    final drobne = AppTextStyles.metaSmall.copyWith(color: palette.muted);

    return GestureDetector(
      // Klepnutí kamkoli do rámečku (i na řádek s počítadlem) = psát.
      onTap: _focus.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.base,
          Insets.lg,
          widget.sDiktovanim ? Insets.md : Insets.base,
        ),
        decoration: vzhledRamecku(context, aktivni: _focus.hasFocus),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: widget.poleKey,
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              keyboardType: viceRadku ? TextInputType.multiline : null,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.maxDelka),
              ],
              onChanged: widget.onChanged,
              style: textPole.copyWith(color: palette.text),
              decoration: InputDecoration.collapsed(
                hintText: widget.napoveda,
                hintStyle: textPole.copyWith(color: palette.muted),
              ),
            ),
            if (widget.sDiktovanim) ...[
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  // Diktuje se tlačítkem mikrofonu na systémové
                  // klávesnici - appka vlastní rozpoznávání řeči nemá.
                  Icon(Icons.mic_none_rounded, size: 15, color: palette.muted),
                  const SizedBox(width: Insets.xxs),
                  Expanded(
                    child: Text('Diktovat přes klávesnici', style: drobne),
                  ),
                  Text(
                    '${widget.controller.text.length} / ${widget.maxDelka}',
                    style: drobne.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
