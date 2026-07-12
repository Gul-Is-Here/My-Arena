import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Arena/court visual: renders a local picked file when available,
/// otherwise a sporty gradient placeholder (network images arrive with
/// Firebase Storage in the backend phase).
class ArenaImage extends StatelessWidget {
  final String? path;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;

  const ArenaImage({
    super.key,
    this.path,
    this.height,
    this.width,
    this.borderRadius,
    this.placeholderIcon = Icons.stadium_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final file = path != null ? File(path!) : null;
    final bool hasFile = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: radius,
      child: hasFile
          ? Image.file(
              file,
              height: height,
              width: width,
              fit: BoxFit.cover,
            )
          : Container(
              height: height,
              width: width,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  placeholderIcon,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
    );
  }
}
