import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../monitoring/presentation/monitoring_screen.dart';
import 'uzivatele_screen.dart';

/// Admin (jen admin) - záložky Uživatelé a práva a Monitoring, stejně
/// jako Admin na webu.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, this.jakoZalozka = false});

  /// Záložka Admin v hlavní navigaci - bez šipky zpět. Jinak samostatná
  /// obrazovka (z plánovače).
  final bool jakoZalozka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: !jakoZalozka,
          title: Text(
            'Admin',
            style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: palette.text,
            unselectedLabelColor: palette.muted2,
            indicatorColor: AppColors.accent,
            dividerColor: palette.hairline,
            labelStyle: AppTextStyles.cardBody.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(key: Key('admin-uzivatele'), text: 'Uživatelé a práva'),
              Tab(key: Key('admin-monitoring'), text: 'Monitoring'),
            ],
          ),
        ),
        // Bez přejetí prstem - v monitoringu a seznamu se posouvá i do stran.
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [UzivateleScreen(vnorena: true), MonitoringScreen()],
        ),
      ),
    );
  }
}
