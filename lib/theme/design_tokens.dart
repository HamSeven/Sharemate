import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF5F7FA);
  static const Color card = Colors.white;

  static const Color primary = Color(0xFF2563EB); // blue-600
  static const Color primarySoft = Color(0xFFDBEAFE);

  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color disabled = Color(0xFFCBD5E1);
}

// ======================
// Radius
// ======================
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius card =
      BorderRadius.all(Radius.circular(lg));
}

// ======================
// Shadows
// ======================
class AppShadows {
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

// ======================
// Text styles
// ======================
class AppText {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}

// ======================
// Buttons (✅ 只保留这一份)
// ======================
class AppButtons {
  /// 🔵 Primary button
  static final ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white, // ✅ 蓝底白字
    elevation: 0,
    minimumSize: const Size.fromHeight(48),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  );

  /// ⚪ Secondary / ghost button
  static final ButtonStyle secondary = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.primary,
    elevation: 0,
    side: const BorderSide(color: AppColors.primary),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );
}
