import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF2F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFE8F0F3);
  static const border = Color(0xFFD5E2E8);
  static const text = Color(0xFF0F1C24);
  static const textSecondary = Color(0xFF5A6F7A);
  static const textMuted = Color(0xFF8A9BA5);
  static const primary = Color(0xFF0D7A8C);
  static const primarySoft = Color(0xFFD6EEF2);
  static const accent = Color(0xFF1FA8A0);
  static const success = Color(0xFF2E9B63);
  static const warning = Color(0xFFD4A017);
  static const danger = Color(0xFFC44B4B);
  static const mapBg = Color(0xFF0B2A33);
  static const mapRing = Color(0xFF1A4A56);
  static const qualityGood = Color(0xFF2E9B63);
  static const qualityFair = Color(0xFFD4A017);
  static const qualityPoor = Color(0xFFC44B4B);
  static const tabInactive = Color(0xFF8A9BA5);

  // Koyu tema
  static const darkBg = Color(0xFF10181C);
  static const darkSurface = Color(0xFF1C282E);
  static const darkSurfaceMuted = Color(0xFF26343A);
  static const darkBorder = Color(0xFF3A4C54);
  static const darkText = Color(0xFFF2F7F9);
  static const darkTextSecondary = Color(0xFFB8C9D1);
  static const darkTextMuted = Color(0xFF8FA3AD);
  static const darkPrimarySoft = Color(0xFF1A3F48);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageBg(BuildContext context) =>
      isDark(context) ? darkBg : bg;

  static Color card(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color muted(BuildContext context) =>
      isDark(context) ? darkSurfaceMuted : surfaceMuted;

  static Color line(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color foreground(BuildContext context) =>
      isDark(context) ? darkText : text;

  static Color secondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color hint(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color softPrimary(BuildContext context) =>
      isDark(context) ? darkPrimarySoft : primarySoft;
}
