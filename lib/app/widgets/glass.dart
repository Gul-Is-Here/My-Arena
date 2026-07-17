import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted "liquid glass" card: backdrop blur + translucent gradient fill,
/// hairline border and a soft drop shadow. Works over [AmbientBackground]
/// blobs in both light and dark themes.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final double blur;
  final Color? tint;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
    this.blur = 16,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final t = tint;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            (t ?? Colors.white).withValues(alpha: 0.12),
                            (t ?? Colors.white).withValues(alpha: 0.04),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.40),
                          ],
                  ),
                  border: Border.all(
                    width: 1.2,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft gradient "light blobs" floating behind glass content — this is what
/// makes the blur visibly liquid. Place your scrollable as [child].
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strength = isDark ? 0.45 : 0.30;

    Widget blob(Color color, double size) => IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: strength),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        );

    return Stack(
      children: [
        Positioned(top: -90, left: -70, child: blob(AppColors.primary, 320)),
        Positioned(top: 120, right: -110, child: blob(AppColors.accent, 280)),
        Positioned(
            bottom: -60, left: -50, child: blob(AppColors.primaryDark, 300)),
        Positioned(bottom: 160, right: -80, child: blob(AppColors.primary, 220)),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Floating dark pill bottom navigation — "Arena Command" theme: icon-only,
/// with a solid green rounded-square highlight on the active tab.
/// Pair with `Scaffold(extendBody: true)` so content scrolls beneath it.
class GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  static const _surface = Color(0xFF191C22);
  static const _outline = Color(0xFF3B494B);
  static const _green = Color(0xFF79FF5B);
  static const _onSurfaceVar = Color(0xFFB9CACB);

  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: _surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(width: 1.2, color: _outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(child: _navItem(context, i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int i) {
    final selected = i == selectedIndex;
    final dest = destinations[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDestinationSelected(i),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconTheme(
            data: IconThemeData(
              color: selected ? const Color(0xFF0B0E14) : _onSurfaceVar,
              size: 22,
            ),
            child: selected ? dest.selectedIcon ?? dest.icon : dest.icon,
          ),
        ),
      ),
    );
  }
}
