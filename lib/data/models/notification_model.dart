import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

// ============================================================
// COMPREHENSIVE APP NOTIFICATION MODEL (نموذج مركز التنبيهات)
// ============================================================
class AppNotification {
  final String id;
  final String? userId;
  final String title;
  final String body;
  final String type;
  final String? actionUrl;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const AppNotification({
    required this.id,
    this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.actionUrl,
    this.payload = const {},
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  bool get isBroadcast => userId == null || userId!.isEmpty;

  /// الرابط الداخلي المستهدف للتنقل (Deep Link / Action Route)
  String? get targetRoute {
    if (actionUrl != null && actionUrl!.trim().isNotEmpty) {
      return actionUrl;
    }
    if (payload.containsKey('route') && payload['route'] != null) {
      return payload['route'].toString();
    }
    final normalizedType = type.toUpperCase();
    switch (normalizedType) {
      case 'PAYMENT':
      case 'ORDER':
        return '/payments';
      case 'ASSISTANCE':
        return '/assistance';
      case 'SUBSCRIPTION':
      case 'ARREARS':
        return '/subscriptions';
      case 'ALERT':
      case 'MEMBER_STATUS':
        return '/settings';
      case 'ANNOUNCEMENT':
      case 'PROMO':
        return '/announcements';
      default:
        return null;
    }
  }

  /// الوقت النسبي بالعربية (Time Ago)
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins == 1 ? 'منذ دقيقة' : mins == 2 ? 'منذ دقيقتين' : 'منذ $mins دقائق';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? 'منذ ساعة' : hours == 2 ? 'منذ ساعتين' : 'منذ $hours ساعات';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return days == 1 ? 'منذ يوم' : days == 2 ? 'منذ يومين' : 'منذ $days أيام';
    } else {
      return DateFormat('yyyy/MM/dd', 'ar').format(createdAt);
    }
  }

  /// التاريخ والوقت بتنسيق مفصل
  String get formattedDateTime {
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(createdAt);
  }

  factory AppNotification.fromJson(Map<String, dynamic> json, {bool isReadOverride = false}) {
    Map<String, dynamic> parsedPayload = {};
    if (json['payload'] != null) {
      if (json['payload'] is Map) {
        parsedPayload = Map<String, dynamic>.from(json['payload']);
      }
    }

    final rawType = json['type']?.toString() ?? 'SYSTEM';
    final normalizedType = rawType.toUpperCase();

    return AppNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      title: json['title']?.toString() ?? 'تنبيه جديد',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      type: normalizedType,
      actionUrl: json['action_url']?.toString(),
      payload: parsedPayload,
      isRead: isReadOverride || json['is_read'] == true,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'message': body,
      'type': type,
      'action_url': actionUrl,
      'payload': payload,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? actionUrl,
    Map<String, dynamic>? payload,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      actionUrl: actionUrl ?? this.actionUrl,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  String get typeLabel {
    final t = type.toUpperCase();
    switch (t) {
      case 'PAYMENT':
        return 'سند مالي';
      case 'ORDER':
        return 'طلب وسند';
      case 'ASSISTANCE':
        return 'طلب إعانة';
      case 'SUBSCRIPTION':
      case 'ARREARS':
        return 'تذكير بالسداد';
      case 'ALERT':
      case 'ADMIN_ALERT':
        return 'تنبيه إداري';
      case 'PROMO':
        return 'عروض ومبادرات';
      case 'ANNOUNCEMENT':
        return 'إعلان عام';
      case 'MEMBER_STATUS':
        return 'حالة الحساب';
      case 'SYSTEM':
      default:
        return 'تنبيه النظام';
    }
  }

  IconData get icon {
    final t = type.toUpperCase();
    switch (t) {
      case 'PAYMENT':
      case 'ORDER':
        return Icons.account_balance_wallet_rounded;
      case 'ASSISTANCE':
        return Icons.volunteer_activism_rounded;
      case 'SUBSCRIPTION':
      case 'ARREARS':
        return Icons.receipt_long_rounded;
      case 'ALERT':
      case 'ADMIN_ALERT':
        return Icons.warning_amber_rounded;
      case 'PROMO':
        return Icons.local_offer_rounded;
      case 'ANNOUNCEMENT':
        return Icons.campaign_rounded;
      case 'MEMBER_STATUS':
        return Icons.verified_user_rounded;
      case 'SYSTEM':
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    final t = type.toUpperCase();
    switch (t) {
      case 'PAYMENT':
        return AppColors.success;
      case 'ORDER':
        return AppColors.accent;
      case 'ASSISTANCE':
        return AppColors.primary;
      case 'SUBSCRIPTION':
      case 'ARREARS':
        return AppColors.warning;
      case 'ALERT':
      case 'ADMIN_ALERT':
        return AppColors.error;
      case 'PROMO':
      case 'ANNOUNCEMENT':
        return AppColors.gold;
      case 'MEMBER_STATUS':
        return AppColors.accent;
      case 'SYSTEM':
      default:
        return AppColors.primary;
    }
  }
}
