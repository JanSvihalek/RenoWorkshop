import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Záložky spodní navigace.
enum WorkshopTab { orders, settings }

/// Spodní navigace dílny.
class WorkshopBottomNav extends StatelessWidget {
  const WorkshopBottomNav({
    super.key,
    required this.active,
    required this.onSelect,
  });

  final WorkshopTab active;
  final ValueChanged<WorkshopTab> onSelect;

  static const List<_NavItem> _items = [
    _NavItem(
      WorkshopTab.orders,
      'Zakázky',
      Icons.assignment_outlined,
      Icons.assignment,
    ),
    _NavItem(
      WorkshopTab.settings,
      'Nastavení',
      Icons.settings_outlined,
      Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIOS = context.isIOS;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.only(
            top: isIOS ? 9 : 10,
            left: 8,
            right: 8,
            bottom: bottomInset + (isIOS ? 8 : 10),
          ),
          decoration: BoxDecoration(
            color: palette.card.withValues(alpha: 0.94),
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: Row(
            children: [
              for (final item in _items)
                Expanded(
                  child: _NavButton(
                    item: item,
                    isActive: item.tab == active,
                    onTap: item.tab == active ? null : () => onSelect(item.tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.tab, this.label, this.icon, this.activeIcon);

  final WorkshopTab tab;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIOS = context.isIOS;
    final activeColor = context.isDarkMode
        ? AppColors.accent
        : AppColors.primary;
    final color = isActive ? activeColor : palette.muted;

    return Semantics(
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              // Android: aktivní ikona plná, iOS: vždy outline.
              isActive && !isIOS ? item.activeIcon : item.icon,
              size: isIOS ? 22 : 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: isIOS ? 10.5 : 11.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
