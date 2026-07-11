import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// Full-screen loading layer stacked above a screen's content.
class LoadingOverlay extends StatelessWidget {
  final RxBool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Obx(
          () => isLoading.value
              ? Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
