import 'package:intl/intl.dart';

// ============================================================
// AUDIT LOG ITEM MODEL (نموذج سجل التدقيق والمراقبة)
// ============================================================

class AuditLogItem {
  final String id;
  final String? userId;
  final String? userName;
  final String userType; // 'admin', 'super_admin', 'treasurer', 'member', 'system_worker'
  final String action; // 'CREATE_PAYMENT', 'UPDATE_MEMBER', 'DELETE_RECORD', etc.
  final String module; // 'members', 'payments', 'wallets', 'assistance', 'settings', 'auth'
  final String entity;
  final String? entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? ipAddress;
  final String? userAgent;
  final String status; // 'SUCCESS', 'FAILED'
  final String? errorMessage;
  final DateTime createdAt;

  AuditLogItem({
    required this.id,
    this.userId,
    this.userName,
    this.userType = 'member',
    required this.action,
    required this.module,
    required this.entity,
    this.entityId,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    this.status = 'SUCCESS',
    this.errorMessage,
    required this.createdAt,
  });

  bool get isSuccess => status.toUpperCase() == 'SUCCESS';

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    // Handling profiles full_name join if available
    String? name = json['profiles']?['full_name'] ?? json['user_name'];
    
    // Parse old_values and new_values safely
    Map<String, dynamic>? oldVal;
    if (json['old_values'] is Map) {
      oldVal = Map<String, dynamic>.from(json['old_values']);
    } else if (json['old_data'] is Map) {
      oldVal = Map<String, dynamic>.from(json['old_data']);
    }

    Map<String, dynamic>? newVal;
    if (json['new_values'] is Map) {
      newVal = Map<String, dynamic>.from(json['new_values']);
    } else if (json['new_data'] is Map) {
      newVal = Map<String, dynamic>.from(json['new_data']);
    }

    return AuditLogItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userName: name,
      userType: json['user_type']?.toString() ?? json['user_role']?.toString() ?? 'member',
      action: json['action']?.toString() ?? 'UNKNOWN_ACTION',
      module: json['module']?.toString() ?? json['category']?.toString() ?? json['table_name']?.toString() ?? 'عام',
      entity: json['entity']?.toString() ?? json['table_name']?.toString() ?? 'system',
      entityId: json['entity_id']?.toString() ?? json['record_id']?.toString() ?? json['target_id']?.toString(),
      oldValues: oldVal,
      newValues: newVal,
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      status: (json['status']?.toString() ?? 'SUCCESS').toUpperCase(),
      errorMessage: json['error_message']?.toString() ?? json['description']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_type': userType,
      'action': action,
      'module': module,
      'entity': entity,
      'entity_id': entityId,
      'old_values': oldValues,
      'new_values': newValues,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'status': status,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// تسمية عربية واضحة للعملية
  String get actionLabelArabic {
    final act = action.toUpperCase();
    if (act.contains('CREATE_PAYMENT') || act.contains('سند تحصيل')) return 'تسجيل سند تحصيل مالي 💳';
    if (act.contains('UPDATE_PAYMENT')) return 'تعديل سند تحصيل ✏️';
    if (act.contains('DELETE_PAYMENT')) return 'إلغاء سند مالي 🗑️';
    if (act.contains('CREATE_MEMBER') || act.contains('إضافة عضو')) return 'تسجيل عضو جديد 👤';
    if (act.contains('UPDATE_MEMBER') || act.contains('تعديل بيانات عضو')) return 'تعديل بيانات عضو 📝';
    if (act.contains('DELETE_MEMBER')) return 'حذف سجل عضو ❌';
    if (act.contains('SUSPEND_MEMBER') || act.contains('تجميد')) return 'تجميد وتعليق عضوية ⏸️';
    if (act.contains('ACTIVATE_MEMBER') || act.contains('تفعيل')) return 'تفعيل وتأكيد عضوية ✅';
    if (act.contains('CREATE_WALLET') || act.contains('إضافة محفظة')) return 'إضافة محفظة / حساب 🏦';
    if (act.contains('UPDATE_WALLET')) return 'تحديث بيانات محفظة 🔄';
    if (act.contains('CREATE_ASSISTANCE') || act.contains('طلب مساعدة')) return 'تقديم طلب مساعدة 🤝';
    if (act.contains('APPROVE_ASSISTANCE') || act.contains('اعتماد مساعدة')) return 'اعتماد طلب مساعدة 🟢';
    if (act.contains('REJECT_ASSISTANCE')) return 'رفض طلب مساعدة 🔴';
    if (act.contains('CREATE_ANNOUNCEMENT') || act.contains('نشر إعلان')) return 'نشر إعلان وتعميم 📢';
    if (act.contains('UPDATE_SETTINGS') || act.contains('إعدادات')) return 'تحديث إعدادات الجمعية ⚙️';
    if (act.contains('LOGIN_SUCCESS')) return 'تسجيل دخول ناجح 🔑';
    if (act.contains('LOGIN_FAILED')) return 'فشل محاولة الدخول ⚠️';
    if (act.contains('EXPORT_PDF')) return 'تصدير تقرير PDF 📄';
    if (act.contains('EXPORT_EXCEL')) return 'تصدير كشف Excel 📊';
    return action;
  }

  /// تسمية عربية للقسم / الجدول
  String get moduleLabelArabic {
    final mod = module.toLowerCase();
    if (mod.contains('payment') || mod.contains('مالية')) return 'المالية والاشتراكات';
    if (mod.contains('member') || mod.contains('profile') || mod.contains('أعضاء')) return 'سجل الأعضاء';
    if (mod.contains('wallet') || mod.contains('محافظ')) return 'المحافظ البنكية';
    if (mod.contains('assistance') || mod.contains('مساعدات')) return 'المساعدات الإنسانية';
    if (mod.contains('announcement') || mod.contains('إعلانات')) return 'الإعلانات والبيانات';
    if (mod.contains('setting') || mod.contains('إعدادات')) return 'إعدادات النظام';
    if (mod.contains('auth') || mod.contains('مصادقة')) return 'الأمان والدخول';
    if (mod.contains('report') || mod.contains('تقارير')) return 'نظام التقارير';
    return module;
  }

  /// حساب الفروقات المحددة بين القيم القديمة والجديدة
  Map<String, Map<String, dynamic>> get diffValues {
    final diffs = <String, Map<String, dynamic>>{};
    if (oldValues == null && newValues == null) return diffs;

    final allKeys = <String>{
      ...?oldValues?.keys,
      ...?newValues?.keys,
    };

    // Ignore timestamp/noise fields
    const ignoredKeys = {'updated_at', 'created_at', 'avatar_url', 'id'};

    for (final key in allKeys) {
      if (ignoredKeys.contains(key)) continue;
      final oldVal = oldValues?[key];
      final newVal = newValues?[key];

      if (oldVal != newVal) {
        diffs[key] = {
          'old': oldVal,
          'new': newVal,
        };
      }
    }

    return diffs;
  }

  String get formattedDateTime {
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(createdAt);
  }
}
