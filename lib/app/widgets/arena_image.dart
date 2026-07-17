import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
    final placeholder = Container(
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
    );

    Widget imageWidget;
    if (path == null) {
      imageWidget = placeholder;
    } else if (path!.startsWith('http://') || path!.startsWith('https://')) {
      imageWidget = Image.network(
        path!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, e, s) => placeholder,
      );
    } else {
      final file = File(path!);
      imageWidget = file.existsSync()
          ? Image.file(file, height: height, width: width, fit: BoxFit.cover)
          : placeholder;
    }

    return ClipRRect(borderRadius: radius, child: imageWidget);
  }
}
