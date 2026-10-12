import 'package:go_router/go_router.dart';

// استيراد الصفحات
import '../../features/auth/auth_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/dashboard/admin_dashboard.dart';
import '../../features/dashboard/member_home.dart';
import '../../features/members/members_screen.dart';
import '../../features/members/member_details.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/payments/add_payment.dart';
import '../../features/payments/receipt_view.dart';
import '../../features/subscriptions/subscription_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/expenses/add_expense.dart';
import '../../features/assistance/assistance_screen.dart';
import '../../features/assistance/add_assistance.dart';
import '../../features/assistance/assistance_details.dart';
import '../../features/ledger/ledger_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/announcements/announcements_screen.dart';
import '../../features/ads/admin_ads_screen.dart';
import '../../features/settings/settings_screen.dart';
// ✅ استيراد المحافظ
import '../../features/wallets/wallets_screen.dart';
import '../../features/wallets/add_wallet_screen.dart';
// ✅ ✅ ✅ أهم شيء: استيراد نموذج Wallet
import '../../features/wallets/wallet_model.dart';
// ✅ استيراد سجل التدقيق والمراقبة
import '../../features/audit/audit_logs_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // ============ AUTH ROUTES ============
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      // ============ MAIN HOME ============
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // ============ DASHBOARD ============
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/member-home',
        builder: (context, state) => const MemberHome(),
      ),
      
      // ============ MEMBERS ============
      GoRoute(
        path: '/members',
        builder: (context, state) => const MembersScreen(),
      ),
      GoRoute(
        path: '/member-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MemberDetails(memberId: id);
        },
      ),
      
      // ============ PAYMENTS ============
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/add-payment',
        builder: (context, state) => const AddPaymentScreen(),
      ),
      GoRoute(
        path: '/add-payment/:memberId',
        builder: (context, state) {
          final memberId = state.pathParameters['memberId'];
          return AddPaymentScreen(memberId: memberId);
        },
      ),
      GoRoute(
        path: '/receipt/:paymentId',
        builder: (context, state) {
          final paymentId = state.pathParameters['paymentId']!;
          return ReceiptView(paymentId: paymentId);
        },
      ),
      
      // ============ SUBSCRIPTIONS ============
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      
      // ============ EXPENSES ============
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) => const AddExpenseScreen(),
      ),
      
      // ============ ASSISTANCE ============
      GoRoute(
        path: '/assistance',
        builder: (context, state) => const AssistanceScreen(),
      ),
      GoRoute(
        path: '/add-assistance',
        builder: (context, state) => const AddAssistanceScreen(),
      ),
      GoRoute(
        path: '/assistance-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AssistanceDetailsScreen(requestId: id);
        },
      ),
      
      // ============ LEDGER ============
      GoRoute(
        path: '/ledger',
        builder: (context, state) => const LedgerScreen(),
      ),
      
      // ============ REPORTS ============
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      
      // ============ NOTIFICATIONS ============
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      
      // ============ ANNOUNCEMENTS & ADS ============
      GoRoute(
        path: '/announcements',
        builder: (context, state) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: '/admin-ads',
        builder: (context, state) => const AdminAdsScreen(),
      ),
      
      // ============ SETTINGS ============
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      
      // ============ ✅ WALLETS (المحافظ) ============
      GoRoute(
        path: '/wallets',
        builder: (context, state) => const WalletsScreen(),
      ),
      GoRoute(
        path: '/add-wallet',
        builder: (context, state) {
          // ✅ الآن Wallet معرف لأننا استوردنا wallet_model.dart
          final wallet = state.extra is Wallet ? state.extra as Wallet : null;
          return AddWalletScreen(wallet: wallet);
        },
      ),

      // ============ ✅ AUDIT LOGS (سجل التدقيق والمراقبة) ============
      GoRoute(
        path: '/audit-logs',
        builder: (context, state) => const AuditLogsScreen(),
      ),
    ],
  );
}