import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'workshop_bottom_nav.dart';
import 'workshop_side_nav.dart';

/// Rám tabletové obrazovky: svislý navigační pruh vlevo, obsah vpravo.
///
/// Na telefonu se navigace kreslí dole ve `Scaffoldu` každé obrazovky,
/// na tabletu je společná a obrazovka se do ní jen vloží.
class TabletShell extends ConsumerWidget {
  const TabletShell({
    super.key,
    required this.active,
    required this.onSelect,
    required this.child,
  });

  final WorkshopTab active;
  final ValueChanged<WorkshopTab> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        WorkshopSideNav(
          active: active,
          onSelect: onSelect,
          employee: ref.watch(currentEmployeeProvider),
        ),
        Expanded(child: child),
      ],
    );
  }
}
