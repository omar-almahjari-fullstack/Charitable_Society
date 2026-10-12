import 'package:flutter/material.dart';

class AppColors {
  // ============================================================
  // 🎨 الألوان الرسمية - هوية حكومية/خيرية راقية وموحدة
  // ============================================================
  
  // ✅ اللون الكحلي الأساسي (Primary Navy)
  static const Color primary = Color(0xFF0B2545);
  static const Color primaryLight = Color(0xFF133E6D);
  static const Color primaryDark = Color(0xFF061426);
  static const Color primarySubtle = Color(0xFFEBF1F8);

  // ✅ اللون الثانوي / التفاعلي (Accent Teal / Persian Green)
  static const Color accent = Color(0xFF00A896);
  static const Color accentLight = Color(0xFF02C39A);
  static const Color accentDark = Color(0xFF028090);
  static const Color accentSubtle = Color(0xFFE6F7F5);

  // توافق مع الأسماء القديمة
  static const Color secondary = accent;
  static const Color secondaryLight = accentLight;
  static const Color secondaryDark = accentDark;

  // ✅ الألوان المميزة (ذهب ملكي راقي)
  static const Color gold = Color(0xFFC89B3C);
  static const Color goldLight = Color(0xFFF3E5C8);
  static const Color goldDark = Color(0xFF9E7520);
  static const Color goldSubtle = Color(0xFFFAF5EB);

  // ✅ ألوان الحالات (Status Colors)
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ✅ ألوان الوضع الفاتح (Light Mode)
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // ✅ ألوان نصوص الوضع الفاتح
  static const Color textPrimary = Color(0xFF0B2545);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGold = Color(0xFFC89B3C);

  // ✅ ألوان الوضع الداكن (Dark Mode)
  static const Color darkBackground = Color(0xFF091422);
  static const Color darkSurface = Color(0xFF0F2036);
  static const Color darkSurfaceElevated = Color(0xFF162D4A);
  static const Color darkCard = Color(0xFF0F2036);
  static const Color darkBorder = Color(0xFF1E3A5F);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // ✅ التدرجات اللونية الاحترافية
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0B2545), Color(0xFF133E6D)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF00A896), Color(0xFF028090)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFC89B3C), Color(0xFFE2B755)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0B2545), Color(0xFF0F325C), Color(0xFF005F55)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF059669), Color(0xFF047857)],
  );

  // ✅ الظلال المريحة للعين والمتوازنة
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0B2545).withOpacity(0.04),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0B2545).withOpacity(0.02),
      blurRadius: 4,
      spreadRadius: 0,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: const Color(0xFF0B2545).withOpacity(0.08),
      blurRadius: 24,
      spreadRadius: -2,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.25),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];
}