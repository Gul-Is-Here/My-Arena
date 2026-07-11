import 'package:flutter/material.dart';

import '../../widgets/dashboard_scaffold.dart';

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      title: 'My Arena',
      icon: Icons.sports_soccer,
      phaseNote:
          'Customer Dashboard\nArena discovery & booking arrive in Phase 2–3.',
    );
  }
}
