import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_sound_service.dart';
import '../../data/models/notification_model.dart';

// ============================================================
// NOTIFICATIONS STATE (حالة مركز التنبيهات)
// ============================================================
class NotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final String selectedFilter;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.selectedFilter = 'الكل',
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  List<AppNotification> get filteredNotifications {
    switch (selectedFilter) {
      case 'غير مقروءة':
        return notifications.where((n) => !n.isRead).toList();
      case 'مقروءة':
        return notifications.where((n) => n.isRead).toList();
      case 'مالية واشتراكات':
        return notifications.where((n) => ['PAYMENT', 'ORDER', 'ARREARS', 'SUBSCRIPTION'].contains(n.type.toUpperCase())).toList();
      case 'طلبات ومساعدات':
        return notifications.where((n) => n.type.toUpperCase() == 'ASSISTANCE').toList();
      case 'إعلانات وإدارية':
        return notifications.where((n) => ['ANNOUNCEMENT', 'ALERT', 'ADMIN_ALERT', 'PROMO', 'SYSTEM', 'MEMBER_STATUS'].contains(n.type.toUpperCase())).toList();
      case 'الكل':
      default:
        return notifications;
    }
  }

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    String? selectedFilter,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

// ============================================================
// NOTIFICATIONS NOTIFIER (إدارة الحالة اللحظية مع البث الحي والصوت)
// ============================================================
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  RealtimeChannel? _realtimeChannel;

  NotificationsNotifier() : super(const NotificationsState()) {
    loadNotifications();
    _subscribeToRealtimeNotifications();
  }

  /// الاشتراك في البث اللحظي لـ Supabase Realtime (بدون الحاجة لتحديث الصفحة)
  void _subscribeToRealtimeNotifications() {
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = SupabaseService.client
          .channel('public:notifications:live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              _handleRealtimePayload(payload);
            },
          )
          .subscribe();
    } catch (_) {}
  }

  void _handleRealtimePayload(PostgresChangePayload payload) {
    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId == null) return;

    if (payload.eventType == PostgresChangeEvent.insert) {
      final newRecord = payload.newRecord;
      final targetUserId = newRecord['user_id']?.toString();
      final type = (newRecord['type']?.toString() ?? 'SYSTEM').toUpperCase();
      final isBroadcastType = ['ANNOUNCEMENT', 'BROADCAST', 'PROMO', 'SYSTEM'].contains(type);

      // ⚠️ التحقق الأمني اللحظي الصارم:
      // إذا كان الإشعار موجهاً لعضو محدد آخر، يتم تجاهله فوراً ولا يتم إصدار صوت أو تحديث القائمة
      if (targetUserId != null && targetUserId.isNotEmpty) {
        if (targetUserId != currentUserId) {
          return; // إشعار خاص بعضو آخر فقط!
        }
      } else {
        // إذا كان user_id غير موجود، نتأكد أنه من الأنواع المسموح ببثها للجميع
        if (!isBroadcastType) {
          return; // إشعار خاص لا يجب أن يبث للعامة
        }
      }

      final newNotification = AppNotification.fromJson(
        Map<String, dynamic>.from(newRecord),
        isReadOverride: false,
      );

      // 1. تشغيل صوت التنبيه والاهتزاز وبنر الإشعار العلوي فوراً
      NotificationSoundService.showInAppNotificationBanner(
        notification: newNotification,
      );

      // 2. تحديث قائمة الإشعارات والعداد في الذاكرة لحظياً دون إعادة تحميل
      final exists = state.notifications.any((n) => n.id == newNotification.id);
      if (!exists) {
        state = state.copyWith(
          notifications: [newNotification, ...state.notifications],
        );
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final updatedRecord = payload.newRecord;
      final id = updatedRecord['id']?.toString();

      final updatedList = state.notifications.map((n) {
        if (n.id == id) {
          return AppNotification.fromJson(
            Map<String, dynamic>.from(updatedRecord),
            isReadOverride: updatedRecord['is_read'] == true,
          );
        }
        return n;
      }).toList();

      state = state.copyWith(notifications: updatedList);
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final oldRecord = payload.oldRecord;
      final id = oldRecord['id']?.toString();
      if (id != null) {
        state = state.copyWith(
          notifications: state.notifications.where((n) => n.id != id).toList(),
        );
      }
    }
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await NotificationService.getNotifications(limit: 50);
      state = state.copyWith(
        notifications: list,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  Future<void> markAsRead(AppNotification notification, {BuildContext? context}) async {
    // 1. Optimistic UI update
    final updatedList = state.notifications.map((n) {
      if (n.id == notification.id) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updatedList);

    // 2. Sync to Backend
    await NotificationService.markAsRead(notification);

    // 3. Deep Linking Navigation if route is specified and context provided
    if (context != null && notification.targetRoute != null) {
      try {
        context.go(notification.targetRoute!);
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead() async {
    final updatedList = state.notifications.map((n) => n.copyWith(isRead: true, readAt: DateTime.now())).toList();
    state = state.copyWith(notifications: updatedList);

    await NotificationService.markAllAsRead(notifications: state.notifications);
  }

  Future<void> deleteNotification(String notificationId) async {
    final updatedList = state.notifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(notifications: updatedList);

    await NotificationService.deleteNotification(notificationId);
  }

  Future<NotificationResult> sendBroadcast({
    required String title,
    required String body,
    String type = 'ANNOUNCEMENT',
    String? targetRoute,
  }) async {
    final result = await NotificationService.sendBroadcastNotification(
      title: title,
      body: body,
      type: type,
      targetRoute: targetRoute,
    );

    if (result.isSuccess) {
      await loadNotifications();
    }
    return result;
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

// ============================================================
// NOTIFICATIONS PROVIDER
// ============================================================
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier();
});

/// Provider مخصص لعدد التنبيهات غير المقروءة (لحساب البادج في شريط التطبيق والقائمة)
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifState = ref.watch(notificationsProvider);
  return notifState.unreadCount;
});
