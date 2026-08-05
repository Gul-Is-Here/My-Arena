import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ProfilePhotoUploadScreen extends StatefulWidget {
  const ProfilePhotoUploadScreen({super.key});

  @override
  State<ProfilePhotoUploadScreen> createState() =>
      _ProfilePhotoUploadScreenState();
}

class _ProfilePhotoUploadScreenState extends State<ProfilePhotoUploadScreen>
    with TickerProviderStateMixin {
  final auth = AuthController.to;
  final _picker = ImagePicker();

  File? _selected;
  bool _uploading = false;
  String? _error;

  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _avatarCtrl;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _avatarScale;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _avatarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _pulse = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _avatarScale = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xfile == null) return;
      setState(() {
        _selected = File(xfile.path);
        _error = null;
      });
      _avatarCtrl.reset();
      _avatarCtrl.forward();
      _pulseCtrl.stop();
    } catch (e) {
      setState(() => _error = 'Could not access camera/gallery. Check permissions.');
    }
  }

  void _removeImage() {
    setState(() {
      _selected = null;
      _error = null;
    });
    _pulseCtrl.repeat(reverse: true);
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Add Profile Photo',
                  style: AppTextStyles.titleMedium),
              const SizedBox(height: 20),
              _SourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take a photo',
                onTap: () {
                  Get.back();
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from gallery',
                onTap: () {
                  Get.back();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_selected != null) ...[
                const SizedBox(height: 12),
                _SourceTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove photo',
                  color: AppColors.error,
                  onTap: () {
                    Get.back();
                    _removeImage();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _upload() async {
    if (_selected == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await auth.uploadProfilePhoto(_selected!);
      auth.goToRoleDashboard();
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = 'Upload failed. Please try again.';
      });
    }
  }

  void _skip() => auth.goToRoleDashboard();

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser.value;
    final initials = (user?.name.isNotEmpty == true)
        ? user!.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),

                        // Progress bar — step 2 of 2
                        Row(
                          children: List.generate(
                            2,
                            (i) => Expanded(
                              child: Container(
                                height: 3,
                                margin:
                                    EdgeInsets.only(right: i < 1 ? 6 : 0),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add your photo',
                                style: AppTextStyles.headlineLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A profile photo helps others recognise you on the platform.',
                                style: AppTextStyles.bodyLarge.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 56),

                        // Avatar
                        GestureDetector(
                          onTap: _uploading ? null : _showSourceSheet,
                          child: _selected != null
                              ? ScaleTransition(
                                  scale: _avatarScale,
                                  child: _AvatarWithImage(
                                    file: _selected!,
                                    onEdit: _uploading ? null : _showSourceSheet,
                                  ),
                                )
                              : AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (_, child) => Transform.scale(
                                    scale: _pulse.value,
                                    child: child,
                                  ),
                                  child: _AvatarPlaceholder(initials: initials),
                                ),
                        ),

                        const SizedBox(height: 20),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _selected != null
                              ? TextButton.icon(
                                  key: const ValueKey('change'),
                                  onPressed:
                                      _uploading ? null : _showSourceSheet,
                                  icon: const Icon(Icons.edit_rounded,
                                      size: 16,
                                      color: AppColors.primary),
                                  label: Text(
                                    'Change photo',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primary),
                                  ),
                                )
                              : TextButton.icon(
                                  key: const ValueKey('add'),
                                  onPressed:
                                      _uploading ? null : _showSourceSheet,
                                  icon: const Icon(Icons.add_a_photo_rounded,
                                      size: 16,
                                      color: AppColors.textDisabled),
                                  label: Text(
                                    'Tap to add a photo',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textDisabled),
                                  ),
                                ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _ErrorBanner(message: _error!),
                        ],

                        const SizedBox(height: 32),

                        if (_uploading)
                          Obx(() => _UploadProgress(
                                progress: auth.photoUploadProgress.value,
                              )),
                      ],
                    ),
                  ),
                ),

                // Bottom actions
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Column(
                    children: [
                      AnimatedOpacity(
                        opacity: _selected != null ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 250),
                        child: _PrimaryButton(
                          label: _uploading ? 'Uploading…' : 'Save & Continue',
                          loading: _uploading,
                          onPressed:
                              (_selected != null && !_uploading) ? _upload : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _uploading ? null : _skip,
                        child: Text(
                          'Skip for now',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textDisabled),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AvatarPlaceholder extends StatelessWidget {
  final String initials;
  const _AvatarPlaceholder({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: AppTextStyles.headlineLarge.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        // Dashed ring (decorative)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _DashedCirclePainter()),
          ),
        ),
        // Camera badge
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt_rounded,
                size: 20, color: AppColors.onPrimary),
          ),
        ),
      ],
    );
  }
}

class _AvatarWithImage extends StatelessWidget {
  final File file;
  final VoidCallback? onEdit;
  const _AvatarWithImage({required this.file, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: 160,
              height: 160,
            ),
          ),
        ),
        // Edit badge
        Positioned(
          bottom: 6,
          right: 6,
          child: GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(Icons.edit_rounded,
                  size: 18, color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashCount = 28;
    const gapFraction = 0.4;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.shortestSide / 2) + 10;

    for (int i = 0; i < dashCount; i++) {
      final start = (i * 2 * math.pi / dashCount);
      final sweep = (2 * math.pi / dashCount) * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UploadProgress extends StatelessWidget {
  final double progress;
  const _UploadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            backgroundColor: AppColors.elevated,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          progress > 0
              ? 'Uploading ${(progress * 100).toInt()}%…'
              : 'Preparing upload…',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _PrimaryButton({
    required this.label,
    required this.loading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                ),
              )
            : Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Material(
      color: AppColors.elevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(color: c),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
