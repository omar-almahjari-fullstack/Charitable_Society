import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/notifications/notifications_provider.dart';

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.userProfile;
    final role = authState.userRole;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String fullName = user?['full_name'] ?? 'عضو الجمعية';
    final String email = user?['email'] ?? 'member@charity.dz';
    final String? avatarUrl = user?['avatar_url'];

    ImageProvider? imageProvider;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:')) {
        try {
          final base64String = avatarUrl.split(',').last;
          final bytes = base64Decode(base64String);
          imageProvider = MemoryImage(bytes);
        } catch (_) {}
      } else if (avatarUrl.startsWith('http')) {
        imageProvider = NetworkImage(avatarUrl);
      }
    }

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ✅ Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 48, bottom: 24, right: 24, left: 24),
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: AppColors.accentLight,
                            width: 2,
                          ),
                          image: imageProvider != null
                              ? DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageProvider == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 34,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.accentLight.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getRoleLabel(role),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✅ Navigation Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'الرئيسية واللوحة العامة',
                    onTap: () => _navigate(context, '/home'),
                  ),

                  if (role != 'member') ...[
                    _buildDrawerItem(
                      context,
                      icon: Icons.people_outline_rounded,
                      activeIcon: Icons.people_rounded,
                      label: 'إدارة سجل الأعضاء',
                      onTap: () => _navigate(context, '/members'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet_rounded,
                      label: 'إدارة المحافظ والحسابات',
                      onTap: () => _navigate(context, '/wallets'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.payments_outlined,
                      activeIcon: Icons.payments_rounded,
                      label: 'تحصيل الاشتراكات والمدفوعات',
                      onTap: () => _navigate(context, '/payments'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'سجل المصروفات والفواتير',
                      onTap: () => _navigate(context, '/expenses'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.menu_book_rounded,
                      activeIcon: Icons.menu_book_rounded,
                      label: 'دفتر الأستاذ المالي المزدوج',
                      onTap: () => _navigate(context, '/ledger'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.insert_chart_outlined_rounded,
                      activeIcon: Icons.insert_chart_rounded,
                      label: 'التقارير المالية والتحليلات',
                      onTap: () => _navigate(context, '/reports'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.campaign_outlined,
                      activeIcon: Icons.campaign_rounded,
                      label: 'إدارة البنرات والإعلانات',
                      onTap: () => _navigate(context, '/admin-ads'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_edu_outlined,
                      activeIcon: Icons.history_edu_rounded,
                      label: 'سجل التدقيق والمراقبة',
                      onTap: () => _navigate(context, '/audit-logs'),
                    ),
                  ] else ...[
                    _buildDrawerItem(
                      context,
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'سجل اشتراكاتي',
                      onTap: () => _navigate(context, '/subscriptions'),
                    ),
                  ],

                  _buildDrawerItem(
                    context,
                    icon: Icons.volunteer_activism_outlined,
                    activeIcon: Icons.volunteer_activism_rounded,
                    label: 'طلبات المساعدات والدعم',
                    onTap: () => _navigate(context, '/assistance'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.campaign_outlined,
                    activeIcon: Icons.campaign_rounded,
                    label: 'الإعلانات والبيانات العامة',
                    onTap: () => _navigate(context, '/announcements'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.notifications_none_rounded,
                    activeIcon: Icons.notifications_rounded,
                    label: 'مركز التنبيهات',
                    badgeCount: ref.watch(unreadNotificationsCountProvider),
                    onTap: () => _navigate(context, '/notifications'),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                    child: Divider(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                      thickness: 1,
                    ),
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.manage_accounts_outlined,
                    activeIcon: Icons.manage_accounts_rounded,
                    label: 'إعدادات الحساب والملف',
                    onTap: () => _navigate(context, '/settings'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.info_outline_rounded,
                    activeIcon: Icons.info_rounded,
                    label: 'عن المنصة والجمعية',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.logout_rounded,
                    label: 'تسجيل الخروج',
                    isDestructive: true,
                    onTap: () => _showLogoutDialog(context, ref),
                  ),
                ],
              ),
            ),

            // ✅ Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'منظومة إدارة التكافل القروية v1.0.0',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'eng : Omar Ghalib Ahmed Al-mahjari\nphone number: 774360827',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      fontSize: 10,
                      letterSpacing: 0.3,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    IconData? activeIcon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    int badgeCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = isDestructive
        ? AppColors.error
        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.errorLight.withOpacity(0.4)
                : (isDark ? AppColors.darkSurfaceElevated : AppColors.primarySubtle),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? AppColors.error : AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : null,
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
    );
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'إدارة النظام';
      case 'super_admin':
        return 'المشرف العام';
      case 'treasurer':
        return 'أمين الصندوق';
      case 'member':
      default:
        return 'عضو مسجل';
    }
  }

  void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.go(route);
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified_rounded, color: AppColors.accent, size: 24),
            SizedBox(width: 8),
            Text('عن المنصة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'جمعية التكافل والتنمية القروية',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary),
            ),
            SizedBox(height: 6),
            Text(
              'منصة رقمية موحدة لإدارة الاشتراكات والمصروفات ودعم الأسر المحتاجة بشفافية محاسبية تامة وفق المعايير الحديثة.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('هل ترغب حقاً في تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(110, 42),
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}