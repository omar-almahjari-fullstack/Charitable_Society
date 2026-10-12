import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_drawer.dart';
import '../auth/auth_provider.dart';
import '../dashboard/admin_dashboard.dart';
import '../dashboard/member_home.dart';
import '../members/members_screen.dart';
import '../payments/payments_screen.dart';
import '../assistance/assistance_screen.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/notifications_provider.dart';
import '../settings/settings_screen.dart';
import '../subscriptions/subscription_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<NavigationItem> _getNavigationItems(String? role) {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return [
          const NavigationItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'الرئيسية',
          ),
          const NavigationItem(
            icon: Icons.people_outline_rounded,
            activeIcon: Icons.people_rounded,
            label: 'الأعضاء',
          ),
          const NavigationItem(
            icon: Icons.payments_outlined,
            activeIcon: Icons.payments_rounded,
            label: 'المالية',
          ),
          const NavigationItem(
            icon: Icons.volunteer_activism_outlined,
            activeIcon: Icons.volunteer_activism_rounded,
            label: 'الطلبات',
          ),
          const NavigationItem(
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts_rounded,
            label: 'حسابي',
          ),
        ];
      case 'treasurer':
        return [
          const NavigationItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'الرئيسية',
          ),
          const NavigationItem(
            icon: Icons.people_outline_rounded,
            activeIcon: Icons.people_rounded,
            label: 'الأعضاء',
          ),
          const NavigationItem(
            icon: Icons.payments_outlined,
            activeIcon: Icons.payments_rounded,
            label: 'المالية',
          ),
          const NavigationItem(
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            label: 'التنبيهات',
          ),
          const NavigationItem(
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts_rounded,
            label: 'حسابي',
          ),
        ];
      case 'member':
      default:
        return [
          const NavigationItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'الرئيسية',
          ),
          const NavigationItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'اشتراكاتي',
          ),
          const NavigationItem(
            icon: Icons.volunteer_activism_outlined,
            activeIcon: Icons.volunteer_activism_rounded,
            label: 'المساعدات',
          ),
          const NavigationItem(
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            label: 'التنبيهات',
          ),
          const NavigationItem(
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts_rounded,
            label: 'حسابي',
          ),
        ];
    }
  }

  List<Widget> _getScreens(String? role) {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return [
          const AdminDashboard(),
          const MembersScreen(),
          const PaymentsScreen(),
          const AssistanceScreen(),
          const SettingsScreen(),
        ];
      case 'treasurer':
        return [
          const AdminDashboard(),
          const MembersScreen(),
          const PaymentsScreen(),
          const NotificationsScreen(),
          const SettingsScreen(),
        ];
      case 'member':
      default:
        return [
          const MemberHome(),
          const SubscriptionScreen(),
          const AssistanceScreen(),
          const NotificationsScreen(),
          const SettingsScreen(),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.userRole;
    final items = _getNavigationItems(role);
    final screens = _getScreens(role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return PopScope(
      canPop: safeIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && safeIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: const CustomDrawer(),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(62),
            child: AppBar(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'جمعية التكافل والتنمية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go('/notifications'),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Badge(
                          isLabelVisible: unreadCount > 0,
                          label: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                          backgroundColor: AppColors.accent,
                          textColor: Colors.white,
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: IndexedStack(
            index: safeIndex,
            children: screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = safeIndex == index;

                    return InkWell(
                      onTap: () => setState(() => _currentIndex = index),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 14 : 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? AppColors.accent.withOpacity(0.2)
                                  : AppColors.primarySubtle)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: item.label == 'التنبيهات' && unreadCount > 0,
                              label: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800),
                              ),
                              backgroundColor: AppColors.accent,
                              textColor: Colors.white,
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected
                                    ? (isDark ? AppColors.accentLight : AppColors.primary)
                                    : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? AppColors.accentLight : AppColors.primary)
                                    : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}