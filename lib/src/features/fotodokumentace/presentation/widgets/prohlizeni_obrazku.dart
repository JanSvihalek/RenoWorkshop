import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/dokument.dart';
import '../controllers/fotky_providers.dart';

/// Otevře obrázek ze složky zakázky přes celou obrazovku a dovolí listovat
/// ostatními obrázky ze složky - prstem do strany, na tabletu i šipkami.
/// Jako prohlížení fotek, jen bez mazání: ruční soubory spravuje kolega
/// na počítači.
Future<void> otevriProhlizeniObrazku(
  BuildContext context, {
  required String orderId,
  required Dokument obrazek,
  required List<Dokument> obrazky,
}) {
  final index = obrazky.indexWhere((d) => d.id == obrazek.id);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ProhlizeniObrazku(
        orderId: orderId,
        obrazky: obrazky.isEmpty ? [obrazek] : obrazky,
        pocatecni: index < 0 ? 0 : index,
      ),
    ),
  );
}

class ProhlizeniObrazku extends StatefulWidget {
  const ProhlizeniObrazku({
    super.key,
    required this.orderId,
    required this.obrazky,
    this.pocatecni = 0,
  });

  final String orderId;
  final List<Dokument> obrazky;
  final int pocatecni;

  @override
  State<ProhlizeniObrazku> createState() => _ProhlizeniObrazkuState();
}

class _ProhlizeniObrazkuState extends State<ProhlizeniObrazku> {
  late final PageController _stranky = PageController(
    initialPage: widget.pocatecni,
  );
  late int _aktualni = widget.pocatecni;

  /// Zvětšený obrázek se posouvá prstem - listování by ho vytrhlo.
  bool _zvetseno = false;

  @override
  void dispose() {
    _stranky.dispose();
    super.dispose();
  }

  void _jdiNa(int index) => _stranky.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final obrazek = widget.obrazky[_aktualni];
    final pocet = widget.obrazky.length;
    final zmeneno = obrazek.zmenenoAt;
    final popis = [
      if (pocet > 1) '${_aktualni + 1} / $pocet',
      if (zmeneno != null) AppDateFormat.dateTime(zmeneno),
      ?obrazek.umisteni,
    ].join(' · ');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              obrazek.nazev,
              key: const Key('obrazek-nazev'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardBody.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (popis.isNotEmpty)
              Text(
                popis,
                style: AppTextStyles.metaSmall.copyWith(color: Colors.white70),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            key: const Key('obrazky-stranky'),
            controller: _stranky,
            physics: _zvetseno
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: pocet,
            onPageChanged: (index) => setState(() {
              _aktualni = index;
              _zvetseno = false;
            }),
            itemBuilder: (context, index) => _Stranka(
              key: ValueKey(widget.obrazky[index].id),
              orderId: widget.orderId,
              obrazek: widget.obrazky[index],
              onZvetseni: (zvetseno) {
                if (index == _aktualni && zvetseno != _zvetseno) {
                  setState(() => _zvetseno = zvetseno);
                }
              },
            ),
          ),
          if (_aktualni > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: _Sipka(
                key: const Key('obrazek-predchozi'),
                ikona: Icons.chevron_left_rounded,
                popis: 'Předchozí obrázek',
                onTap: () => _jdiNa(_aktualni - 1),
              ),
            ),
          if (_aktualni < pocet - 1)
            Align(
              alignment: Alignment.centerRight,
              child: _Sipka(
                key: const Key('obrazek-dalsi'),
                ikona: Icons.chevron_right_rounded,
                popis: 'Další obrázek',
                onTap: () => _jdiNa(_aktualni + 1),
              ),
            ),
        ],
      ),
    );
  }
}

/// Jeden obrázek se zvětšením prsty; než dorazí celý, ukáže se náhled.
class _Stranka extends ConsumerStatefulWidget {
  const _Stranka({
    super.key,
    required this.orderId,
    required this.obrazek,
    required this.onZvetseni,
  });

  final String orderId;
  final Dokument obrazek;
  final ValueChanged<bool> onZvetseni;

  @override
  ConsumerState<_Stranka> createState() => _StrankaState();
}

class _StrankaState extends ConsumerState<_Stranka> {
  final TransformationController _transformace = TransformationController();

  @override
  void dispose() {
    _transformace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final klic = (widget.orderId, widget.obrazek.id);
    final obrazek = ref.watch(obrazekDokumentuProvider(klic));
    final nahled = ref.watch(nahledDokumentuProvider(klic)).valueOrNull;

    return Center(
      child: obrazek.when(
        data: (bajty) => InteractiveViewer(
          transformationController: _transformace,
          maxScale: 6,
          onInteractionEnd: (_) =>
              widget.onZvetseni(_transformace.value.getMaxScaleOnAxis() > 1.01),
          child: Image.memory(
            bajty,
            fit: BoxFit.contain,
            // Formát, který telefon neumí ukázat - aspoň náhled ze služby.
            errorBuilder: (_, _, _) => nahled == null
                ? const _Nejde()
                : Image.memory(nahled, fit: BoxFit.contain),
          ),
        ),
        loading: () => nahled == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Stack(
                alignment: Alignment.center,
                children: [
                  Image.memory(
                    nahled,
                    key: const Key('obrazek-nahled'),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ),
        error: (_, _) => const _Nejde(),
      ),
    );
  }
}

class _Nejde extends StatelessWidget {
  const _Nejde();

  @override
  Widget build(BuildContext context) => const Text(
    'Obrázek se nepodařilo načíst.',
    style: TextStyle(color: Colors.white70),
  );
}

class _Sipka extends StatelessWidget {
  const _Sipka({
    super.key,
    required this.ikona,
    required this.popis,
    required this.onTap,
  });

  final IconData ikona;
  final String popis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      child: IconButton(
        tooltip: popis,
        onPressed: onTap,
        iconSize: 36,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
        ),
        icon: Icon(ikona),
      ),
    );
  }
}
