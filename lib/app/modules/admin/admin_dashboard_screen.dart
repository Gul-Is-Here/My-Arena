import 'package:flutter/material.dart';

import '../../widgets/dashboard_scaffold.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      title: 'Admin Panel',
      icon: Icons.admin_panel_settings_outlined,
      phaseNote:
          'Admin Dashboard\nPlatform management tools arrive in Phase 4.',
    );
  }
}
