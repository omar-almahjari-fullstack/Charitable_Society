import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/notification_model.dart';
import '../storage/local_cache_service.dart';
import 'supabase_service.dart';

// ============================================================
// NOTIFICATION RESULT (نتيجة عمليات الإشعارات)
// ============================================================
class NotificationResult {
  final bool isSuccess;
  final String? errorMessage;

  const NotificationResult({required this.isSuccess, this.errorMessage});

  factory NotificationResult.success() => const NotificationResult(isSuccess: true);
  factory NotificationResult.failure(String message) => NotificationResult(isSuccess: false, errorMessage: message);
}

// ============================================================
// FULL NOTIFICATION SERVICE (SUPABASE BACKEND & REALTIME APIS)
// ============================================================
class NotificationService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// دالة مساعدة ذكية لإدراج سجل إشعار تدعم أسماء الحقول المختلفة (body / message / content)
  static Future<void> _safeInsertSingleRow(Map<String, dynamic> baseData, String textContent) async {
    final variations = [
      {'body': textContent, 'message': textContent},
      {'body': textContent},
      {'message': textContent},
      {'content': textContent},
    ];

    Object? lastError;
    for (final v in variations) {
      try {
        final merged = Map<String, dynamic>.from(baseData)..addAll(v);
        await _supabase.from('notifications').insert(merged);
        return; // نجاح
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
  }

  /// 1. جلب التنبيهات مع دعم التصفح والفلترة (GET /api/notifications)
  static Future<List<AppNotification>> getNotifications({
    String filter = 'all',
    int limit = 20,
    int offset = 0,
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? SupabaseService.currentUser?.id;
      if (currentUserId == null) return [];

      // 1. جلب الإشعارات
      dynamic response;
      try {
        var query = _supabase
            .from('notifications')
            .select('*')
            .or('user_id.eq.$currentUserId,user_id.is.null')
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        response = await query;
      } catch (_) {
        var query = _supabase
            .from('notifications')
            .select('*')
            .eq('user_id', currentUserId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        response = await query;
      }

      // 2. جلب سجلات قراءة الإشعارات العامة للعضو
      List<dynamic> reads = [];
      try {
        reads = await _supabase
            .from('notification_reads')
            .select('notification_id')
            .eq('user_id', currentUserId);
      } catch (_) {}

      final readBroadcastIds = reads
          .map((r) => r['notification_id']?.toString())
          .whereType<String>()
          .toSet();

      final list = <AppNotification>[];
      if (response is List) {
        for (final row in response) {
          final notifId = row['id']?.toString() ?? '';
          final notifUserId = row['user_id']?.toString();
          final notifType = (row['type']?.toString() ?? 'SYSTEM').toUpperCase();
          final isBroadcast = notifUserId == null || notifUserId.isEmpty;

          // ⚠️ التحقق الأمني الصارم:
          // إذا كان الإشعار عاماً (user_id = null)، يجب أن يكون إعلاناً عاماً فقط
          // الإشعارات المالية والخاصة لا تظهر إلا للمستخدم المعني فقط
          final isAllowedBroadcast = ['ANNOUNCEMENT', 'BROADCAST', 'PROMO', 'SYSTEM'].contains(notifType);
          if (isBroadcast && !isAllowedBroadcast) {
            continue; // منع ظهور إشعارات مالية أو خاصة لا تحمل معرف مستخدم
          }
          if (!isBroadcast && notifUserId != currentUserId) {
            continue; // منع ظهور إشعارات عضو آخر قطعية
          }

          final isRead = isBroadcast ? readBroadcastIds.contains(notifId) : (row['is_read'] == true);

          final notification = AppNotification.fromJson(
            Map<String, dynamic>.from(row),
            isReadOverride: isRead,
          );

          // تطبيق الفلتر
          if (filter == 'unread' && notification.isRead) continue;
          if (filter == 'read' && !notification.isRead) continue;
          if (filter != 'all' && filter != 'unread' && filter != 'read') {
            if (notification.type.toUpperCase() != filter.toUpperCase()) continue;
          }

          list.add(notification);
        }
      }

      // حفظ الإشعارات محلياً
      if (filter == 'all') {
        try {
          await LocalCacheService.save(
            'cached_notifications_$currentUserId',
            list.map((n) => n.toJson()).toList(),
          );
        } catch (_) {}
      }

      return list;
    } catch (_) {
      // استرجاع الإشعارات من الكاش المحلي
      try {
        final currentUserId = userId ?? SupabaseService.currentUser?.id;
        if (currentUserId != null) {
          final cached = await LocalCacheService.get('cached_notifications_$currentUserId');
          if (cached is List && cached.isNotEmpty) {
            return cached.map((json) => AppNotification.fromJson(Map<String, dynamic>.from(json))).toList();
          }
        }
      } catch (_) {}

      return [];
    }
  }

  /// دالة اختصار لجلب إشعارات المستخدم (Alias)
  static Future<List<AppNotification>> fetchUserNotifications({String? userId, String filter = 'all'}) async {
    return await getNotifications(filter: filter, limit: 50, offset: 0, userId: userId);
  }

  /// 2. نقطة عداد التنبيهات غير المقروءة (GET /api/notifications/unread-count)
  static Future<int> getUnreadCount({String? userId}) async {
    try {
      final notifications = await getNotifications(filter: 'unread', limit: 100, userId: userId);
      return notifications.length;
    } catch (_) {
      return 0;
    }
  }

  /// 3. تعيين تنبيه كمقروء (PATCH /api/notifications/:id/read)
  static Future<bool> markAsRead(dynamic notificationOrId, {String? userId}) async {
    try {
      final currentUserId = userId ?? SupabaseService.currentUser?.id;
      if (currentUserId == null) return false;

      String notificationId;
      bool isBroadcast = false;

      if (notificationOrId is AppNotification) {
        notificationId = notificationOrId.id;
        isBroadcast = notificationOrId.isBroadcast;
      } else {
        notificationId = notificationOrId.toString();
        // التحقق مما إذا كان الإشعار عاماً
        try {
          final res = await _supabase.from('notifications').select('user_id').eq('id', notificationId).maybeSingle();
          isBroadcast = res == null || res['user_id'] == null;
        } catch (_) {}
      }

      if (isBroadcast) {
        try {
          await _supabase.from('notification_reads').upsert({
            'notification_id': notificationId,
            'user_id': currentUserId,
            'read_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      } else {
        await _supabase
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', notificationId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 4. تعيين جميع التنبيهات كمقروءة دفعة واحدة (POST /api/notifications/mark-all-read)
  static Future<bool> markAllAsRead({String? userId, List<AppNotification>? notifications}) async {
    try {
      final currentUserId = userId ?? SupabaseService.currentUser?.id;
      if (currentUserId == null) return false;

      // 1. تحديث الإشعارات الشخصية في جدول notifications
      try {
        await _supabase
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', currentUserId);
      } catch (_) {}

      // 2. تحديث قراءة الإشعارات العامة
      final list = notifications ?? await getNotifications(filter: 'all', limit: 100, userId: currentUserId);
      final broadcastItems = list.where((n) => n.isBroadcast).toList();
      for (final item in broadcastItems) {
        try {
          await _supabase.from('notification_reads').upsert({
            'notification_id': item.id,
            'user_id': currentUserId,
            'read_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 5. حذف تنبيه محدد (DELETE /api/notifications/:id)
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 6. إرسال تنبيه شخصي جديد لمستخدم معين (POST /api/notifications)
  static Future<NotificationResult> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'SYSTEM',
    String? actionUrl,
    String? targetRoute,
    Map<String, dynamic>? extraData,
  }) async {
    final payload = Map<String, dynamic>.from(extraData ?? {});
    final route = actionUrl ?? targetRoute;
    if (route != null) {
      payload['route'] = route;
    }

    try {
      await _safeInsertSingleRow({
        'user_id': userId,
        'title': title,
        'type': type.toUpperCase(),
        'action_url': route,
        'payload': payload,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, body);
      return NotificationResult.success();
    } catch (e) {
      try {
        await _safeInsertSingleRow({
          'user_id': userId,
          'title': title,
          'type': type.toUpperCase(),
          'action_url': route,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        }, body);
        return NotificationResult.success();
      } catch (err) {
        return NotificationResult.failure(err.toString().replaceAll('Exception: ', '').replaceAll('PostgrestException(message: ', '').replaceAll(')', ''));
      }
    }
  }

  /// إرسال إشعار عام / إعلان لكافة الأعضاء (Broadcast)
  static Future<NotificationResult> sendBroadcastNotification({
    required String title,
    required String body,
    String type = 'ANNOUNCEMENT',
    String? actionUrl,
    String? targetRoute,
    Map<String, dynamic>? extraData,
  }) async {
    final payload = Map<String, dynamic>.from(extraData ?? {});
    final route = actionUrl ?? targetRoute;
    if (route != null) {
      payload['route'] = route;
    }

    // محاولة 1: user_id = null
    try {
      await _safeInsertSingleRow({
        'user_id': null,
        'title': title,
        'type': type.toUpperCase(),
        'action_url': route,
        'payload': payload,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, body);
      return NotificationResult.success();
    } catch (_) {
      // محاولة 2: توزيع الإشعار على كافة الأعضاء في profiles
      try {
        final membersRes = await _supabase.from('profiles').select('id');
        if (membersRes.isNotEmpty) {
          for (final m in membersRes) {
            final uid = m['id']?.toString();
            if (uid != null) {
              await _safeInsertSingleRow({
                'user_id': uid,
                'title': title,
                'type': type.toUpperCase(),
                'action_url': route,
                'payload': payload,
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              }, body);
            }
          }
          return NotificationResult.success();
        }
      } catch (e2) {
        return NotificationResult.failure(e2.toString());
      }
    }
    return NotificationResult.failure('تعذر إرسال الإشعار لعدم توفر بيانات الأعضاء');
  }

  /// Alias لإرسال إشعار عام
  static Future<NotificationResult> notifyAllMembers({
    required String title,
    required String body,
    String type = 'ANNOUNCEMENT',
    String? actionUrl,
    String? targetRoute,
    Map<String, dynamic>? extraData,
  }) async {
    return await sendBroadcastNotification(
      title: title,
      body: body,
      type: type,
      actionUrl: actionUrl,
      targetRoute: targetRoute,
      extraData: extraData,
    );
  }

  /// إرسال تنبيه إداري للمشرفين
  static Future<void> notifyAdmins({
    required String title,
    required String body,
    String type = 'ADMIN_ALERT',
    String? targetRoute,
  }) async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      final admins = await _supabase
          .from('profiles')
          .select('id')
          .inFilter('role', ['admin', 'super_admin', 'treasurer']);

      for (var admin in admins) {
        final adminId = admin['id']?.toString();
        if (adminId != null && adminId.isNotEmpty && adminId != currentUserId) {
          await sendNotification(
            userId: adminId,
            title: title,
            body: body,
            type: type,
            targetRoute: targetRoute,
          );
        }
      }
    } catch (_) {}
  }

  /// بث لحظي للإشعارات عبر Supabase Realtime
  static Stream<List<Map<String, dynamic>>> streamNotifications({String? userId}) {
    final currentUserId = userId ?? SupabaseService.currentUser?.id;
    if (currentUserId == null) return const Stream.empty();

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }
}
