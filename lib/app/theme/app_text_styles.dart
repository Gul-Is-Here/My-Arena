import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central typography class.
///
/// Three font families:
///   • Space Grotesk  — headings / display (sporty geometric)
///   • Inter          — body / UI copy
///   • Barlow Condensed Bold — scores, timers, stats (scoreboard feel)
///
/// Usage:
///   Text('Hello', style: AppTextStyles.headlineLarge)
///   Text('2:30', style: AppTextStyles.scoreboard)
class AppTextStyles {
  AppTextStyles._();

  // ── Heading family (Space Grotesk) ────────────────────────────────────

  static TextStyle get displayLarge => GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineLarge => GoogleFonts.spaceGrotesk(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineMedium => GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get titleLarge => GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get titleMedium => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  // ── Body / UI family (Inter) ──────────────────────────────────────────

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get button => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      );

  // ── Scoreboard / Stats family (Barlow Condensed) ─────────────────────

  /// Large scoreboard number — e.g. match scores, timers.
  static TextStyle get scoreboardLarge => GoogleFonts.barlowCondensed(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      );

  /// Medium stat — e.g. earnings, booking count badges.
  static TextStyle get scoreboardMedium => GoogleFonts.barlowCondensed(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  /// Inline stat chip — e.g. "PKR 2,500" in a card header.
  static TextStyle get scoreboard => GoogleFonts.barlowCondensed(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      );
}
