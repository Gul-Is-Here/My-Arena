import 'package:cached_network_image/cached_network_image.dart';
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
        color: AppColors.surface,
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );

    Widget imageWidget;
    if (path == null) {
      imageWidget = placeholder;
    } else if (path!.startsWith('http://') || path!.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: path!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        placeholder: (context2, url) => placeholder,
        errorWidget: (context2, url, err) => placeholder,
      );
    } else {
      // Local file path — show placeholder on web since dart:io is unavailable.
      imageWidget = placeholder;
    }

    return ClipRRect(borderRadius: radius, child: imageWidget);
  }
}
