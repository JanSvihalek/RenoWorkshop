import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'kampane_panel.dart';

/// Technické kampaně přes celou obrazovku - na telefonu z pruhu nad
/// seznamem zakázek. Na tabletu je stejný panel vedle seznamu.
class KampaneScreen extends StatelessWidget {
  const KampaneScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: onBack,
          tooltip: 'Zpět',
          icon: Icon(Icons.arrow_back_rounded, color: palette.text),
        ),
      ),
      body: const SafeArea(top: false, child: KampanePanel()),
    );
  }
}
