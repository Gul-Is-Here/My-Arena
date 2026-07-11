import 'package:flutter/material.dart';

/// App color palette — Electric Blue + Black (Bold & Sporty)
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2979FF); // Electric Blue
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accent = Color(0xFF00E5FF); // Cyan glow

  // Surfaces
  static const Color black = Color(0xFF0A0A0A); // Dark backgrounds
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBg = Color(0xFFF5F7FA);

  // Status
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFAB00);

  // Text
  static const Color textDark = Color(0xFF0A0A0A);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFF9E9E9E);

  // Gradients (sporty CTAs)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [primaryDark, black],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
