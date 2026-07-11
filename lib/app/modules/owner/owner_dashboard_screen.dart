import 'package:flutter/material.dart';

import '../../widgets/dashboard_scaffold.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      title: 'Owner Dashboard',
      icon: Icons.stadium_outlined,
      phaseNote:
          'Owner Dashboard\nArena setup, revenue stats & boosts arrive in Phase 2.',
    );
  }
}
