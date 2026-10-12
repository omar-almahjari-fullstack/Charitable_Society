import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/notification_model.dart';
import '../auth/auth_provider.dart';
import 'notifications_provider.dart';

// ============================================================
// FULL COMPREHENSIVE NOTIFICATIONS CENTER SCREEN
// ============================================================
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<String> _filters = [
    'الكل',
    'غير مقروءة',
    'مالية واشتراكات',
    'طلبات ومساعدات',
    'إعلانات وإدارية',
  ];

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsProvider);
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = notifState.filteredNotifications;

    final isAdmin = authState.userRole == 'admin' ||
        authState.userRole == 'super_admin' ||
        authState.userRole == 'treasurer';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'مركز التنبيهات والإشعارات',
        subtitle: notifState.unreadCount > 0
            ? '${notifState.unreadCount} تنبيهات جديدة غير مقروءة'
            : '${notifState.notifications.length} إشعار',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home');
          }
        },
        actions: [
          if (notifState.unreadCount > 0)
            TextButton.icon(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
              label: const Text(
                'قراءة الكل',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showBroadcastDialog(context),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.campaign_rounded, size: 20),
              label: const Text(
                'إرسال إشعار عام',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: Column(
        children: [
          // Filter Tabs Bar
          _buildFilterBar(notifState, isDark),

          // Notifications List
          Expanded(
            child: notifState.isLoading
                ? const LoadingWidget(message: 'جاري تحديث صندوق التنبيهات...')
                : list.isEmpty
                    ? _buildEmptyState(notifState.selectedFilter)
                    : RefreshIndicator(
                        onRefresh: () => ref.read(notificationsProvider.notifier).loadNotifications(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final notification = list[index];
                            return _buildDismissibleNotificationCard(notification, isDark);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(NotificationsState notifState, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final isSelected = notifState.selectedFilter == f;
            int count = 0;
            if (f == 'غير مقروءة') {
              count = notifState.unreadCount;
            }

            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? AppColors.primary : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                ),
                showCheckmark: false,
                onSelected: (val) {
                  ref.read(notificationsProvider.notifier).setFilter(f);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDismissibleNotificationCard(AppNotification item, bool isDark) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(width: 6),
            Text(
              'حذف',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        ref.read(notificationsProvider.notifier).deleteNotification(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف إشعار "${item.title}"'),
            backgroundColor: AppColors.darkSurface,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: _buildNotificationCard(item, isDark),
    );
  }

  Widget _buildNotificationCard(AppNotification item, bool isDark) {
    final timeFormatted = _formatDateTime(item.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isRead
            ? (isDark ? AppColors.darkSurface : Colors.white)
            : (isDark
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.primarySubtle.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRead
              ? (isDark ? AppColors.darkBorder : AppColors.border)
              : AppColors.primary.withValues(alpha: 0.45),
          width: item.isRead ? 1 : 1.6,
        ),
        boxShadow: item.isRead ? AppColors.cardShadow : [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ref.read(notificationsProvider.notifier).markAsRead(item, context: context);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon Container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    color: item.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Type badge & Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.typeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: item.color,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                timeFormatted,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                                ),
                              ),
                              if (!item.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Body Text
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),

                      // Deep Linking Action Prompt
                      if (item.targetRoute != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'اضغط للعرض المباشر',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: item.color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: item.color),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    String title = 'لا توجد إشعارات';
    String subtitle = 'ستصلك كافة التحديثات والأنشطة المالية والإدارية فور صدورها هنا.';

    if (filter == 'غير مقروءة') {
      title = 'لا توجد تنبيهات جديدة';
      subtitle = 'رائع! لقد قمت بالاطلاع على كافة التنبيهات السابقة.';
    } else if (filter == 'مالية واشتراكات') {
      title = 'لا توجد إشعارات مالية';
      subtitle = 'سندات الاشتراكات ومواعيد السداد ستظهر هنا فور إتمامها.';
    } else if (filter == 'طلبات ومساعدات') {
      title = 'لا توجد تحديثات على الإعانات';
      subtitle = 'مستجدات طلبات المساعدة الخاصة بك ستظهر هنا مباشرة.';
    }

    return EmptyState(
      title: title,
      subtitle: subtitle,
      icon: Icons.notifications_none_rounded,
    );
  }

  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return DateFormat('MM/dd HH:mm').format(dt);
  }

  // ============================================================
  // ADMIN BROADCAST NOTIFICATION MODAL
  // ============================================================
  void _showBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedType = 'announcement';
    String selectedRoute = '/home';
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.campaign_rounded, color: AppColors.accent, size: 26),
                          SizedBox(width: 10),
                          Text(
                            'إرسال إشعار عام للجميع',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Category Selector
                  const Text(
                    'نوع التنبيه:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'announcement', child: Text('إعلان عام للجمعية 📢')),
                      DropdownMenuItem(value: 'arrears', child: Text('تذكير عام بسداد الاشتراكات 💳')),
                      DropdownMenuItem(value: 'admin_alert', child: Text('تنبيه وقرار إداري 🏛️')),
                      DropdownMenuItem(value: 'general', child: Text('رسالة عامة 📨')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Title Field
                  const Text(
                    'عنوان الإشعار:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'مثال: موعد اجتماع الجمعية العمومية',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Body Field
                  const Text(
                    'نص الإشعار والتفاصيل:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: bodyController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'اكتب نص التنبيه الموجه لكافة الأعضاء بوضوح...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Send Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isSending
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              final body = bodyController.text.trim();

                              if (title.isEmpty || body.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('يرجى كتابة عنوان الإشعار ونصه بالكامل'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSending = true);

                              final result = await ref
                                  .read(notificationsProvider.notifier)
                                  .sendBroadcast(
                                    title: title,
                                    body: body,
                                    type: selectedType,
                                    targetRoute: selectedRoute,
                                  );

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result.isSuccess
                                        ? 'تم إرسال الإشعار العام لكافة الأعضاء بنجاح!'
                                        : (result.errorMessage ?? 'تعذر إرسال الإشعار. يرجى التأكد من تشغيل سكربت الإشعارات.')),
                                    backgroundColor:
                                        result.isSuccess ? AppColors.success : AppColors.error,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                      icon: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        isSending ? 'جاري البث لكافة الأعضاء...' : 'بث الإشعار الآن',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}