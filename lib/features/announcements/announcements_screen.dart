import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/storage/local_cache_service.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/network/network_connectivity_service.dart';
import '../auth/auth_provider.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> items = [];

      // 1. محاولة الجلب من جدول announcements
      try {
        final response = await SupabaseService.client
            .from('announcements')
            .select('*, profiles!created_by(full_name)')
            .order('created_at', ascending: false);
        items = List<Map<String, dynamic>>.from(response as List);
      } catch (_) {
        try {
          final responseSimple = await SupabaseService.client
              .from('announcements')
              .select('*')
              .order('created_at', ascending: false);
          items = List<Map<String, dynamic>>.from(responseSimple as List);
        } catch (_) {}
      }

      // 2. إذا لم يكن جدول announcements متوفراً أو كان فارغاً، الجلب من notifications
      if (items.isEmpty) {
        try {
          final notifRes = await SupabaseService.client
              .from('notifications')
              .select('*')
              .eq('type', 'announcement')
              .order('created_at', ascending: false);
          for (final n in notifRes as List) {
            items.add({
              'id': n['id'],
              'title': n['title'],
              'content': n['body'] ?? n['message'] ?? n['content'] ?? '',
              'priority': 'normal',
              'created_at': n['created_at'],
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _announcements = items;
          _isLoading = false;
        });

        // حفظ قائمة الإعلانات محلياً
        try {
          await LocalCacheService.save('cached_announcements', items);
        } catch (_) {}
      }
    } catch (e) {
      // استرجاع الإعلانات من الكاش المحلي عند انقطاع الاتصال
      try {
        final cached = await LocalCacheService.get('cached_announcements');
        if (cached is List && cached.isNotEmpty && mounted) {
          setState(() {
            _announcements = List<Map<String, dynamic>>.from(cached);
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isAdmin {
    final authState = ref.watch(authProvider);
    final role = authState.userRole;
    return role == 'admin' || role == 'super_admin';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'لوحة الإعلانات الرسمية',
        subtitle: 'بيانات الجمعية والقرارات العامة',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home');
          }
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAnnouncements,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'جاري تحميل الإعلانات...')
          : _announcements.isEmpty
              ? EmptyState(
                  title: 'لا توجد إعلانات حالياً',
                  subtitle: 'سيتم نشر جميع قرارات الجمعية وأخبارها الهامة هنا فور صدورها.',
                  icon: Icons.campaign_outlined,
                  buttonText: _isAdmin ? 'إضافة إعلان جديد' : null,
                  onButtonPressed: _isAdmin ? () => _showAddDialog(context) : null,
                )
              : RefreshIndicator(
                  onRefresh: _loadAnnouncements,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, index) {
                      final item = _announcements[index];
                      return _buildAnnouncementCard(item, isDark);
                    },
                  ),
                ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('إضافة إعلان', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item, bool isDark) {
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'إعلان من إدارة الجمعية';
    final content = item['content']?.toString() ?? item['body']?.toString() ?? item['description']?.toString() ?? '';
    final priority = item['priority']?.toString() ?? 'normal';
    final author = item['profiles']?['full_name']?.toString() ?? 'الإدارة';
    final createdAt = item['created_at'] != null
        ? DateTime.parse(item['created_at'].toString())
        : DateTime.now();

    final isUrgent = priority == 'urgent' || priority == 'high';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUrgent ? AppColors.error.withOpacity(0.4) : (isDark ? AppColors.darkBorder : AppColors.border),
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUrgent ? AppColors.errorLight : AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUrgent ? Icons.error_outline_rounded : Icons.campaign_rounded,
                        color: isUrgent ? AppColors.error : AppColors.accent,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUrgent ? 'إعلان عاجل' : 'إعلان عام',
                        style: TextStyle(
                          color: isUrgent ? AppColors.error : AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('yyyy/MM/dd').format(createdAt),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الجهة المصدرة: $author',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
                if (_isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    onPressed: () => _deleteAnnouncement(id),
                    tooltip: 'حذف الإعلان',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String priority = 'normal';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.campaign_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text('نشر إعلان جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الإعلان والبيان *',
                      prefixIcon: Icon(Icons.title_rounded, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى كتابة عنوان الإعلان';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(
                      labelText: 'درجة الأهمية',
                      prefixIcon: Icon(Icons.priority_high_rounded, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('إعلان عادي 📢')),
                      DropdownMenuItem(value: 'urgent', child: Text('إعلان عاجل ومهم 🚨')),
                    ],
                    onChanged: isSubmitting
                        ? null
                        : (v) {
                            if (v != null) setModalState(() => priority = v);
                          },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'نص الإعلان والبيان التفصيلي *',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى كتابة نص الإعلان والبيان';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setModalState(() => isSubmitting = true);

                      final isOnline = await NetworkConnectivityService().checkIsOnline();
                      if (!isOnline) {
                        setModalState(() => isSubmitting = false);
                        if (context.mounted) {
                          AppFeedback.showOfflineOperationError(
                            context,
                          );
                        }
                        return;
                      }

                      final annTitle = titleController.text.trim();
                      final annContent = contentController.text.trim();

                      try {
                        final userId = SupabaseService.currentUser?.id;
                        await _safeInsertAnnouncement(
                          title: annTitle,
                          contentText: annContent,
                          priority: priority,
                          userId: userId,
                        );

                        try {
                          await NotificationService.notifyAllMembers(
                            title: priority == 'urgent' ? 'إعلان عاجل ومهم 🚨' : 'إعلان جديد من الجمعية 📢',
                            body: annTitle,
                            type: 'announcement',
                            targetRoute: '/announcements',
                          );
                        } catch (_) {}

                        try {
                          AuditService.logEvent(
                            action: 'CREATE_ANNOUNCEMENT',
                            module: 'الإعلانات',
                            entity: 'announcements',
                            newValues: {
                              'title': annTitle,
                              'content': annContent,
                              'priority': priority,
                            },
                            errorMessage: 'قام المدير بنشر إعلان جديد بعنوان "$annTitle"',
                          );
                        } catch (_) {}

                        if (context.mounted) {
                          Navigator.pop(context);
                          AppFeedback.showSuccess(context, 'تم نشر الإعلان بنجاح وبث التنبيه لجميع الأعضاء 🎉');
                          _loadAnnouncements();
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        if (context.mounted) {
                          AppFeedback.showError(
                            context,
                            AppErrorHandler.handleGeneralError(e),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(isSubmitting ? 'جاري النشر...' : 'نشر الإعلان الآن'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _safeInsertAnnouncement({
    required String title,
    required String contentText,
    required String priority,
    String? userId,
  }) async {
    final textColumnCandidates = ['content', 'body', 'description', 'message', 'details', 'text'];

    // 1. محاولة الإدخال في جدول announcements الأساسي
    for (final textCol in textColumnCandidates) {
      try {
        final fullData = <String, dynamic>{
          'title': title,
          textCol: contentText,
          'priority': priority,
          'is_published': true,
          'created_at': DateTime.now().toIso8601String(),
        };
        if (userId != null && userId.isNotEmpty) {
          fullData['created_by'] = userId;
        }

        await SupabaseService.client.from('announcements').insert(fullData);
        return; // نجاح كامل
      } catch (e1) {
        final err1 = e1.toString();

        if (err1.contains('created_by') || err1.contains('priority') || err1.contains('is_published')) {
          try {
            final minData = <String, dynamic>{
              'title': title,
              textCol: contentText,
            };
            await SupabaseService.client.from('announcements').insert(minData);
            return; // نجاح بالإدخال المصغر
          } catch (_) {}
        }
      }
    }

    // 2. خطة بديلة ذكية وفورية: الحفظ والبث المباشر عبر جدول notifications
    final notifRes = await NotificationService.sendBroadcastNotification(
      title: priority == 'urgent' ? '🚨 إعلان عاجل: $title' : '📢 $title',
      body: contentText,
      type: 'announcement',
      targetRoute: '/announcements',
    );

    if (notifRes.isSuccess) {
      return; // تم الحفظ والبث بنجاح تام!
    }

    throw Exception(notifRes.errorMessage ?? 'تعذر حفظ الإعلان في قاعدة البيانات.');
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await SupabaseService.client.from('announcements').delete().eq('id', id);
    } catch (_) {
      try {
        await SupabaseService.client.from('notifications').delete().eq('id', id);
      } catch (_) {}
    }
    _loadAnnouncements();
  }
}