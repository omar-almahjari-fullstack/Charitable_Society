import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

// ============================================================
// APP FEEDBACK & ALERTS SYSTEM (نظام التنبيهات والرسائل التفاعلية)
// ============================================================

class AppFeedback {
  /// 1. إظهار رسالة نجاح خضراء أنيقة
  static void showSuccess(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    _showFloatingSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.success,
    );
  }

  /// 2. إظهار رسالة خطأ واضحة ومهذبة مع زر إعادة المحاولة الاختياري
  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
    String retryLabel = 'إعادة المحاولة',
  }) {
    HapticFeedback.heavyImpact();
    _showFloatingSnackBar(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppColors.error,
      action: onRetry != null
          ? SnackBarAction(
              label: retryLabel,
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
      duration: onRetry != null ? const Duration(seconds: 6) : const Duration(seconds: 4),
    );
  }

  /// 3. إظهار رسالة تحذير أو تذكير
  static void showWarning(BuildContext context, String message) {
    HapticFeedback.mediumImpact();
    _showFloatingSnackBar(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: AppColors.warning,
    );
  }

  /// 4. إظهار رسالة عدم الاتصال بالإنترنت عند محاولة تنفيذ عملية تتطلب شبكة
  static void showOfflineOperationError(
    BuildContext context, {
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    showError(
      context,
      customMessage ?? 'الرجاء التحقق من اتصالك بالإنترنت والمحاولة مجدداً.',
      onRetry: onRetry,
      retryLabel: 'حاول مرة أخرى',
    );
  }

  /// 5. إظهار رسالة تنبيه الوضع غير المتصل
  static void showOffline(BuildContext context, {String? customMessage}) {
    HapticFeedback.selectionClick();
    _showFloatingSnackBar(
      context,
      message: customMessage ?? 'أنت تعمل حالياً في وضع عدم الاتصال، يتم عرض البيانات المحفوظة محلياً.',
      icon: Icons.wifi_off_rounded,
      backgroundColor: const Color(0xFF334155),
    );
  }

  /// الدالة المساعدة لإنشاء SnackBar عائم بتصميم Material حديث
  static void _showFloatingSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        action: action,
      ),
    );
  }

  /// 5. إظهار نافذة حوارية تأكيدية مخصصة (Custom Confirmation Dialog)
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool isDestructive = false,
    IconData icon = Icons.help_outline_rounded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: isDestructive ? AppColors.error : AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
