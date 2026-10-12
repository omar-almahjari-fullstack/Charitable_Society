import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/audit_log_model.dart';
import 'supabase_service.dart';

// ============================================================
// AUDIT LOGGING & ACTIVITY TRACKING SERVICE (نظام التدقيق الشامل)
// ============================================================

class AuditService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// كشف معلومات الجهاز والنظام
  static String get _deviceUserAgent {
    try {
      if (kIsWeb) return 'Web Browser Client (Flutter)';
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion} • Takaful App v1.0.0';
    } catch (_) {
      return 'Mobile/Desktop Client';
    }
  }

  /// تسجيل حدث تدقيق مركب وغير متزامن (Non-blocking Asynchronous Logging)
  static void logEvent({
    required String action,
    required String module,
    required String entity,
    String? entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String status = 'SUCCESS',
    String? errorMessage,
    String? customUserId,
    String? customUserType,
  }) {
    // تنفيذ غير متزامن تماماً لعدم إبطاء واجهات المستخدم أو العمليات
    Future.microtask(() async {
      try {
        final currentAuthUser = _supabase.auth.currentUser;
        final targetUserId = customUserId ?? currentAuthUser?.id;
        
        String userRole = customUserType ?? 'member';
        if (customUserType == null && targetUserId != null) {
          final profile = await SupabaseService.getCurrentUserProfile();
          userRole = profile?['role'] ?? 'member';
        }

        final payload = {
          'user_id': targetUserId,
          'user_type': userRole,
          'action': action,
          'module': module,
          'entity': entity,
          'entity_id': entityId,
          'old_values': oldValues,
          'new_values': newValues,
          'user_agent': _deviceUserAgent,
          'status': status.toUpperCase(),
          'error_message': errorMessage,
          'created_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('audit_logs').insert(payload);
      } catch (e) {
        // Silently preserve stability
        debugPrint('Audit logging background notice: $e');
      }
    });
  }

  /// دالة متوافقة مع الاستدعاءات السابقة (Backward Compatibility)
  static Future<void> logAction({
    required String action,
    required String description,
    String category = 'عام',
    String? targetId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    logEvent(
      action: action,
      module: category,
      entity: category,
      entityId: targetId,
      oldValues: oldValues,
      newValues: newValues ?? metadata,
      errorMessage: description,
    );
  }

  /// تسجيل عمليات المصادقة والدخول
  static void logAuth({
    required String action,
    required String status,
    String? email,
    String? userId,
    String? errorMessage,
  }) {
    logEvent(
      action: action,
      module: 'auth',
      entity: 'auth.users',
      entityId: userId,
      status: status,
      errorMessage: errorMessage ?? email,
      customUserId: userId,
      customUserType: 'user',
    );
  }

  /// جلب سجلات التدقيق مع الفلاتر المتقدمة والـ Pagination
  static Future<List<AuditLogItem>> fetchAuditLogs({
    String? userId,
    String? action,
    String? module,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    String? searchQuery,
    int limit = 40,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('audit_logs')
          .select('*, profiles!user_id(full_name, role)');

      if (userId != null && userId.isNotEmpty && userId != 'all') {
        query = query.eq('user_id', userId);
      }

      if (action != null && action.isNotEmpty && action != 'الكل') {
        query = query.ilike('action', '%$action%');
      }

      if (module != null && module.isNotEmpty && module != 'الكل') {
        query = query.or('module.ilike.%$module%,entity.ilike.%$module%');
      }

      if (status != null && status.isNotEmpty && status != 'الكل') {
        query = query.eq('status', status.toUpperCase());
      }

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte('created_at', toDate.add(const Duration(days: 1)).toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => AuditLogItem.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      return [];
    }
  }

  /// حساب الفارق بدقة بين كائنين JSON (Diff Engine)
  static Map<String, dynamic> computeDiff(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    final diff = <String, dynamic>{};
    final allKeys = {...before.keys, ...after.keys};

    for (final key in allKeys) {
      final oldVal = before[key];
      final newVal = after[key];
      if (oldVal != newVal) {
        diff[key] = {
          'before': oldVal,
          'after': newVal,
        };
      }
    }
    return diff;
  }
}
