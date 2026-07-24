import 'package:flutter/material.dart';

/// App color palette — MyArena brand system.
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────
  static const Color primary   = Color(0xFFCCFF00); // Volt / Electric Lime
  static const Color secondary = Color(0xFF2979FF); // Electric Blue
  static const Color accent    = Color(0xFFFF5C00); // Burnt Orange (live/hot)

  // ── Dark-theme neutrals ───────────────────────────────────────────────
  static const Color background = Color(0xFF0B0E11);
  static const Color surface    = Color(0xFF151A1F);
  static const Color elevated   = Color(0xFF1E252C);
  static const Color border     = Color(0xFF2A323B);

  // ── Text (dark theme) ─────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF98A2B0);
  static const Color textDisabled  = Color(0xFF5C6672);
  static const Color onPrimary     = Color(0xFF0B0E11); // text on lime buttons

  // ── Semantic ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);

  // ── Light-theme surfaces (used on owner-side light cards, etc.) ───────
  static const Color lightBg      = Color(0xFFF2F4F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color textDark     = Color(0xFF0B0E11);

  // ── Token alias (spec name) ───────────────────────────────────────────
  static const Color surfaceElevated = elevated;

  // ── Legacy aliases (keeps existing references compiling) ─────────────
  static const Color black        = background;
  static const Color darkSurface  = surface;
  static const Color darkCard     = elevated;
  static const Color textLight    = textPrimary;
  static const Color textGrey     = textSecondary;
  static const Color primaryDark  = Color(0xFF0D47A1);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [primaryDark, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
