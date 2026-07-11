import 'package:flutter/material.dart';

import '../../widgets/dashboard_scaffold.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      title: 'Staff Panel',
      icon: Icons.support_agent,
      phaseNote:
          'Staff Dashboard\nApprovals & support chat arrive in Phase 4.',
    );
  }
}
