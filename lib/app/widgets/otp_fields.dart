import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_text_styles.dart';

/// Row of 6 single-digit boxes used by all OTP screens.
/// Improvements over original:
/// - Animated border/bg transitions (empty → focused → filled)
/// - Error state with shake animation
/// - Paste support (auto-fills all boxes)
/// - Better backspace (clears & moves back)
/// - Focus glow shadow
class OtpFields extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError; // flip true → triggers shake + red state

  const OtpFields({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.hasError = false,
  });

  @override
  State<OtpFields> createState() => _OtpFieldsState();
}

class _OtpFieldsState extends State<OtpFields>
    with SingleTickerProviderStateMixin {
  late final List<TextEditingController> _controllers = List.generate(
    widget.length,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _nodes = List.generate(
    widget.length,
    (_) => FocusNode(),
  );
  final List<bool> _focused = [];

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _focused.addAll(List.filled(widget.length, false));

    // Shake animation for error state
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    for (int i = 0; i < widget.length; i++) {
      _nodes[i].addListener(() {
        setState(() => _focused[i] = _nodes[i].hasFocus);
      });
    }
  }

  @override
  void didUpdateWidget(OtpFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger shake whenever hasError flips to true
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Handles a pasted string: strips non-digits and fills boxes left→right.
  void _handlePaste(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (int i = 0; i < widget.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    // Land focus on the last filled box (or the last box)
    final landAt =
        (digits.length >= widget.length ? widget.length - 1 : digits.length - 1)
            .clamp(0, widget.length - 1);
    _nodes[landAt].requestFocus();
    setState(() {});
    widget.onChanged(_otp);
    if (_otp.length == widget.length) widget.onCompleted?.call(_otp);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (i) => _box(i, cs)),
      ),
    );
  }

  Widget _box(int index, ColorScheme cs) {
    final isFocused = _focused[index];
    final isFilled = _controllers[index].text.isNotEmpty;

    // ── Visual state tokens ──────────────────────────────────────────
    final Color borderColor;
    final Color bgColor;
    final double borderWidth;
    final List<BoxShadow> shadows;

    if (widget.hasError) {
      borderColor = cs.error;
      bgColor = cs.error.withValues(alpha: 0.06);
      borderWidth = 1.5;
      shadows = [];
    } else if (isFocused) {
      borderColor = cs.primary;
      bgColor = cs.primary.withValues(alpha: 0.05);
      borderWidth = 2.0;
      shadows = [
        BoxShadow(
          color: cs.primary.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isFilled) {
      borderColor = cs.primary.withValues(alpha: 0.45);
      bgColor = cs.primary.withValues(alpha: 0.04);
      borderWidth = 1.5;
      shadows = [];
    } else {
      borderColor = cs.outline.withValues(alpha: 0.35);
      bgColor = Colors.transparent;
      borderWidth = 1.0;
      shadows = [];
    }
    // ────────────────────────────────────────────────────────────────

    // Fixed line-height keeps the glyph's box exactly as tall as expected,
    // independent of the active font-scale, so it can never overflow the
    // fixed-size container below and get clipped.
    final digitStyle = AppTextStyles.bodyLarge.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.0,
      color: widget.hasError ? cs.error : null,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: KeyboardListener(
        // Dedicated FocusNode so KeyboardListener doesn't steal TextField focus
        focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _controllers[index - 1].clear();
            _nodes[index - 1].requestFocus();
            widget.onChanged(_otp);
            setState(() {});
          }
        },
        // Center handles both axes directly rather than leaning on
        // InputDecorator's own alignment/padding math, which is what was
        // clipping the digits against the fixed-height box above.
        child: Center(
          child: TextField(
            controller: _controllers[index],
            focusNode: _nodes[index],
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: TextInputType.number,
            maxLength: 6, // allow ≥1 char so paste triggers onChanged
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            // style: TextStyle(color: Colors.black),
            cursorHeight: digitStyle.fontSize,
            cursorColor: widget.hasError ? cs.error : cs.primary,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
            onChanged: (value) {
              // Full OTP pasted into one box
              if (value.length > 1) {
                _handlePaste(value);
                return;
              }
              // Clamp to 1 char (safety)
              if (value.length > 1) {
                _controllers[index].text = value[0];
              }
              if (value.isNotEmpty && index < widget.length - 1) {
                _nodes[index + 1].requestFocus();
              }
              widget.onChanged(_otp);
              if (_otp.length == widget.length) {
                widget.onCompleted?.call(_otp);
              }
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}
