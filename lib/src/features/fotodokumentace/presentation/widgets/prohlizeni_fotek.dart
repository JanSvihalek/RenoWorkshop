import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../domain/entities/fotka.dart';
import '../controllers/fotky_providers.dart';

/// Otevře fotku přes celou obrazovku a dovolí listovat ostatními z téže
/// sekce - prstem do strany, na tabletu i šipkami.
///
/// Bez [fotky] je v prohlížeči jen ta jedna (fotka místa v detailu
/// zakázky).
Future<void> otevriProhlizeniFotky(
  BuildContext context, {
  required String orderId,
  required Fotka fotka,
  List<Fotka>? fotky,
}) {
  final seznam = fotky == null || fotky.isEmpty ? [fotka] : fotky;
  final index = seznam.indexWhere((f) => f.id == fotka.id);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ProhlizeniFotek(
        orderId: orderId,
        fotky: seznam,
        pocatecni: index < 0 ? 0 : index,
      ),
    ),
  );
}

/// Fotky přes celou obrazovku - listování, zvětšení prsty, kdo a kdy
/// fotku nahrál, smazání.
class ProhlizeniFotek extends ConsumerStatefulWidget {
  const ProhlizeniFotek({
    super.key,
    required this.orderId,
    required this.fotky,
    this.pocatecni = 0,
  });

  final String orderId;
  final List<Fotka> fotky;
  final int pocatecni;

  @override
  ConsumerState<ProhlizeniFotek> createState() => _ProhlizeniFotekState();
}

class _ProhlizeniFotekState extends ConsumerState<ProhlizeniFotek> {
  late final PageController _stranky = PageController(
    initialPage: widget.pocatecni,
  );
  late final List<Fotka> _fotky = [...widget.fotky];
  late int _aktualni = widget.pocatecni;

  /// Zvětšená fotka se posouvá prstem - listování by ji vytrhlo.
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

  Future<void> _smaz() async {
    final fotka = _fotky[_aktualni];
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog.adaptive(
        title: const Text('Smazat fotku?'),
        content: const Text(
          'Fotka zmizí z aplikace i ze sdílené složky na serveru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (potvrzeno != true || !mounted) return;

    try {
      await ref.read(fotkyDataSourceProvider).smazFotku(fotka.id);
      ref.invalidate(fotkyZakazkyProvider(widget.orderId));
      if (!mounted) return;
      // Poslední fotka sekce - není co ukazovat.
      if (_fotky.length == 1) {
        Navigator.of(context).pop();
        return;
      }
      // Zůstane se na stejném místě, tedy na následující fotce (u poslední
      // na předchozí).
      setState(() {
        _fotky.removeAt(_aktualni);
        if (_aktualni >= _fotky.length) _aktualni = _fotky.length - 1;
        _zvetseno = false;
      });
      _stranky.jumpToPage(_aktualni);
    } on ServiceOrderException catch (chyba) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(chyba.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotka = _fotky[_aktualni];
    final vice = _fotky.length > 1;
    final popis = [
      fotka.kategorie.nazev,
      AppDateFormat.dateTime(fotka.nahranoAt),
      if (fotka.nahralKdo != null) fotka.nahralKdo!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vice)
              Text(
                '${_aktualni + 1} / ${_fotky.length}',
                key: const Key('fotka-poradi'),
                style: AppTextStyles.cardBody.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              popis,
              style: AppTextStyles.metaSmall.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Smazat fotku',
            onPressed: _smaz,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            key: const Key('fotky-stranky'),
            controller: _stranky,
            physics: _zvetseno
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: _fotky.length,
            onPageChanged: (index) => setState(() {
              _aktualni = index;
              _zvetseno = false;
            }),
            itemBuilder: (context, index) => _Stranka(
              key: ValueKey(_fotky[index].id),
              fotka: _fotky[index],
              onZvetseni: (zvetseno) {
                if (index == _aktualni && zvetseno != _zvetseno) {
                  setState(() => _zvetseno = zvetseno);
                }
              },
            ),
          ),
          // Šipky po stranách - na tabletu se na ně trefí líp než tažením,
          // a v rukavicích taky.
          if (vice && _aktualni > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: _Sipka(
                key: const Key('fotka-predchozi'),
                ikona: Icons.chevron_left_rounded,
                popis: 'Předchozí fotka',
                onTap: () => _jdiNa(_aktualni - 1),
              ),
            ),
          if (vice && _aktualni < _fotky.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: _Sipka(
                key: const Key('fotka-dalsi'),
                ikona: Icons.chevron_right_rounded,
                popis: 'Další fotka',
                onTap: () => _jdiNa(_aktualni + 1),
              ),
            ),
        ],
      ),
    );
  }
}

/// Jedna fotka se zvětšením prsty. Dá vědět, když je zvětšená, ať se
/// místo posouvání obrázku nelistuje.
class _Stranka extends ConsumerStatefulWidget {
  const _Stranka({super.key, required this.fotka, required this.onZvetseni});

  final Fotka fotka;
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

  void _konecZmeny(ScaleEndDetails _) {
    widget.onZvetseni(_transformace.value.getMaxScaleOnAxis() > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    final obrazek = ref.watch(obrazekFotkyProvider(widget.fotka.id));

    return Center(
      child: obrazek.when(
        data: (bajty) => InteractiveViewer(
          transformationController: _transformace,
          maxScale: 6,
          onInteractionEnd: _konecZmeny,
          child: Image.memory(bajty, fit: BoxFit.contain),
        ),
        loading: () => const CircularProgressIndicator(color: Colors.white),
        error: (_, _) => const Text(
          'Fotku se nepodařilo načíst.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
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
