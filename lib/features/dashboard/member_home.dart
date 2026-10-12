import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/ads_banner_carousel.dart';
import '../../core/storage/local_cache_service.dart';
import '../auth/auth_provider.dart';
import '../notifications/notifications_provider.dart';

// ============================================================
// MEMBER DASHBOARD SCREEN (لوحة تحكم العضو التفاعلية)
// ============================================================
class MemberHome extends ConsumerStatefulWidget {
  const MemberHome({Key? key}) : super(key: key);

  @override
  ConsumerState<MemberHome> createState() => _MemberHomeState();
}

class _MemberHomeState extends ConsumerState<MemberHome> {
  bool _isLoadingStats = true;

  // Member Financial & Subscription Metrics
  double _monthlyFee = 0.0;
  double _totalPaidAmount = 0.0;
  int _currentYearPaidMonths = 0;
  int _overdueMonthsCount = 0;
  double _overdueTotalAmount = 0.0;
  String _memberStatus = 'active';

  // Assistance Requests Stats for Member
  int _totalAssistanceRequests = 0;
  int _pendingAssistanceRequests = 0;
  int _approvedAssistanceRequests = 0;

  // Data Lists
  List<Map<String, dynamic>> _recentPayments = [];
  List<Map<String, dynamic>> _latestAnnouncements = [];
  final Set<String> _dismissedAnnouncementIds = {};

  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'ar');

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingStats = false);
        return;
      }

      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      // Safe Parallel Execution
      final results = await Future.wait([
        // 0: Profile Data
        SupabaseService.client
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .maybeSingle()
            .catchError((_) => null),

        // 1: Member Payments
        SupabaseService.client
            .from('payments')
            .select('*')
            .eq('member_id', userId)
            .order('created_at', ascending: false)
            .catchError((_) => <dynamic>[]),

        // 2: Member Assistance Requests
        SupabaseService.client
            .from('assistance_requests')
            .select('*')
            .eq('member_id', userId)
            .order('created_at', ascending: false)
            .catchError((_) => <dynamic>[]),

        // 3: Latest Announcements
        SupabaseService.client
            .from('announcements')
            .select('*')
            .order('created_at', ascending: false)
            .limit(3)
            .catchError((_) => <dynamic>[]),

        // 4: Association Settings (Start Date)
        SupabaseService.client
            .from('association_settings')
            .select('*')
            .catchError((_) => <dynamic>[]),
      ]);

      final profileMap = results[0] as Map<String, dynamic>?;
      final paymentsList = results[1] as List;
      final aidList = results[2] as List;
      final annList = results[3] as List;
      final settingsList = results[4] as List;

      // 1. Parse Profile
      double monthlySubscription = 1000.0;
      String status = 'active';

      if (profileMap != null) {
        monthlySubscription = ((profileMap['monthly_subscription'] ?? 1000.0) as num).toDouble();
        status = profileMap['status']?.toString() ?? 'active';
      }

      // 2. Parse Settings for Start Date
      int startYear = 2026;
      int startMonth = 1;
      for (final s in settingsList) {
        if (s['setting_key'] == 'association_start_date' && s['setting_value'] != null) {
          final parts = s['setting_value'].toString().split('-');
          if (parts.length >= 2) {
            startYear = int.tryParse(parts[0]) ?? 2026;
            startMonth = int.tryParse(parts[1]) ?? 1;
          }
        }
      }

      // 3. Process Payments
      double totalPaid = 0.0;
      final paidMonthsSet = <String>{};
      int currentYearPaidCount = 0;
      final List<Map<String, dynamic>> recentPaymentsList = [];

      for (int i = 0; i < paymentsList.length; i++) {
        final p = paymentsList[i] as Map<String, dynamic>;
        final amt = ((p['amount'] ?? 0) as num).toDouble();
        totalPaid += amt;

        final pYear = p['payment_year'] as int?;
        final pMonth = p['payment_month'] as int?;

        if (pYear != null && pMonth != null) {
          paidMonthsSet.add('${pYear}_$pMonth');
          if (pYear == currentYear) {
            currentYearPaidCount++;
          }
        }

        if (i < 3) {
          recentPaymentsList.add(p);
        }
      }

      // 4. Calculate Overdue Months
      int overdueMonths = 0;
      if (status != 'exempt' && status != 'معفي') {
        int y = startYear;
        int m = startMonth;

        while (y < currentYear || (y == currentYear && m <= currentMonth)) {
          final key = '${y}_$m';
          if (!paidMonthsSet.contains(key)) {
            overdueMonths++;
          }
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
      }

      final overdueAmount = overdueMonths * monthlySubscription;

      // 5. Process Assistance Requests
      int totalAid = aidList.length;
      int pendingAid = 0;
      int approvedAid = 0;

      for (final a in aidList) {
        final st = a['status']?.toString().toLowerCase();
        if (st == 'pending' || st == 'قيد الدراسة' || st == 'قيد المراجعة') {
          pendingAid++;
        } else if (st == 'approved' || st == 'معتمد' || st == 'مكتمل' || st == 'completed') {
          approvedAid++;
        }
      }

      final parsedAnnouncements = List<Map<String, dynamic>>.from(annList);
      if (parsedAnnouncements.isEmpty) {
        try {
          final notifRes = await SupabaseService.client
              .from('notifications')
              .select('*')
              .eq('type', 'announcement')
              .order('created_at', ascending: false)
              .limit(5);
          for (final n in notifRes as List) {
            parsedAnnouncements.add({
              'id': n['id'],
              'title': n['title'] ?? 'إعلان من إدارة الجمعية',
              'content': n['body'] ?? n['message'] ?? n['content'] ?? '',
              'priority': 'normal',
              'created_at': n['created_at'],
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _monthlyFee = monthlySubscription;
          _totalPaidAmount = totalPaid;
          _currentYearPaidMonths = currentYearPaidCount;
          _overdueMonthsCount = overdueMonths;
          _overdueTotalAmount = overdueAmount;
          _memberStatus = status;
          _totalAssistanceRequests = totalAid;
          _pendingAssistanceRequests = pendingAid;
          _approvedAssistanceRequests = approvedAid;
          _recentPayments = recentPaymentsList;
          _latestAnnouncements = parsedAnnouncements;
          _isLoadingStats = false;
        });

        // حفظ البيانات في الكاش المحلي لاستخدامها عند انقطاع الإنترنت
        try {
          await LocalCacheService.save('member_dashboard_$userId', {
            'monthly_fee': monthlySubscription,
            'total_paid': totalPaid,
            'current_year_paid': currentYearPaidCount,
            'overdue_count': overdueMonths,
            'overdue_amount': overdueAmount,
            'status': status,
            'total_aid': totalAid,
            'pending_aid': pendingAid,
            'approved_aid': approvedAid,
            'recent_payments': recentPaymentsList,
            'announcements': parsedAnnouncements,
          });
        } catch (_) {}
      }
    } catch (_) {
      // عند فشل الاتصال بالشبكة، استرجاع البيانات المحفوظة محلياً فوراً
      try {
        final userId = SupabaseService.currentUser?.id;
        if (userId != null) {
          final cached = await LocalCacheService.get('member_dashboard_$userId');
          if (cached != null && mounted) {
            setState(() {
              _monthlyFee = (cached['monthly_fee'] as num?)?.toDouble() ?? _monthlyFee;
              _totalPaidAmount = (cached['total_paid'] as num?)?.toDouble() ?? _totalPaidAmount;
              _currentYearPaidMonths = cached['current_year_paid'] as int? ?? _currentYearPaidMonths;
              _overdueMonthsCount = cached['overdue_count'] as int? ?? _overdueMonthsCount;
              _overdueTotalAmount = (cached['overdue_amount'] as num?)?.toDouble() ?? _overdueTotalAmount;
              _memberStatus = cached['status']?.toString() ?? _memberStatus;
              _totalAssistanceRequests = cached['total_aid'] as int? ?? _totalAssistanceRequests;
              _pendingAssistanceRequests = cached['pending_aid'] as int? ?? _pendingAssistanceRequests;
              _approvedAssistanceRequests = cached['approved_aid'] as int? ?? _approvedAssistanceRequests;
              _recentPayments = List<Map<String, dynamic>>.from(cached['recent_payments'] ?? []);
              _latestAnnouncements = List<Map<String, dynamic>>.from(cached['announcements'] ?? []);
              _isLoadingStats = false;
            });
            return;
          }
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _refresh() async {
    await ref.read(authProvider.notifier).refreshProfile();
    await _loadMemberData();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.userProfile;
    final fullName = user?['full_name'] ?? 'عضو الجمعية';
    final nationalId = user?['national_id']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Hero Card
              _buildMemberHero(fullName, nationalId, isDark),
              const SizedBox(height: 14),

              // Top Active 3-Day Announcement Banner (إعلان الجمعية البارز لمدة 3 أيام)
              _buildTopAnnouncementBanner(context, isDark),

              // Dynamic Active Ads Banner Carousel
              const AdsBannerCarousel(placement: 'home_banner'),
              const SizedBox(height: 14),

              // Subscription Progress & Status Hero
              _buildSubscriptionStatusCard(context, isDark),
              const SizedBox(height: 18),

              // Member Financial KPI Grid
              _buildMemberKPIGrid(isDark),
              const SizedBox(height: 20),

              // Quick Action Grid
              _buildMemberActions(context, isDark),
              const SizedBox(height: 20),

              // Recent Payment Receipts Section
              _buildRecentReceiptsSection(context, isDark),
              const SizedBox(height: 20),

              // Announcements Section
              _buildAnnouncementsSection(context, isDark),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAnnouncementBanner(BuildContext context, bool isDark) {
    final notifState = ref.watch(notificationsProvider);
    final allAnnouncements = List<Map<String, dynamic>>.from(_latestAnnouncements);

    // دمج الإعلانات المستقبلة لحظياً عبر البث المباشر
    for (final n in notifState.notifications) {
      if (n.type.toUpperCase() == 'ANNOUNCEMENT') {
        final exists = allAnnouncements.any((a) => a['id'] == n.id || a['title'] == n.title);
        if (!exists) {
          allAnnouncements.insert(0, {
            'id': n.id,
            'title': n.title,
            'content': n.body,
            'priority': n.payload['priority']?.toString() ?? 'normal',
            'created_at': n.createdAt.toIso8601String(),
          });
        }
      }
    }

    if (allAnnouncements.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    // تصفية الإعلانات التي تم إنشاؤها خلال آخر 3 أيام (72 ساعة) ولم يتم إخفاؤها مؤقتاً
    final activeAnnouncements = allAnnouncements.where((ann) {
      final id = ann['id']?.toString() ?? '';
      if (_dismissedAnnouncementIds.contains(id)) return false;

      final createdAtStr = ann['created_at']?.toString();
      if (createdAtStr == null) return false;

      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt == null) return false;

      final diff = now.difference(createdAt);
      // التحقق من أن الإعلان ساري ومر عليه أقل من أو يساوي 3 أيام (72 ساعة)
      return diff.inHours >= 0 && diff.inHours <= 72;
    }).toList();

    if (activeAnnouncements.isEmpty) return const SizedBox.shrink();

    final ann = activeAnnouncements.first;
    final id = ann['id']?.toString() ?? '';
    final title = ann['title']?.toString() ?? 'إعلان هام من إدارة الجمعية';
    final content = ann['content']?.toString() ?? ann['body']?.toString() ?? ann['description']?.toString() ?? '';
    final priority = ann['priority']?.toString() ?? 'normal';
    final isUrgent = priority == 'urgent' || priority == 'high';

    final createdAtStr = ann['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
    String timeBadge = 'إعلان جديد 📢';
    if (createdAt != null) {
      final diff = now.difference(createdAt);
      if (diff.inHours < 24) {
        timeBadge = 'نُشر اليوم ⚡';
      } else if (diff.inDays == 1) {
        timeBadge = 'نُشر أمس';
      } else {
        timeBadge = 'منذ ${diff.inDays} أيام (متبقي ${3 - diff.inDays} يوم)';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [
                  const Color(0xFFEF4444).withValues(alpha: isDark ? 0.25 : 0.12),
                  const Color(0xFFF97316).withValues(alpha: isDark ? 0.18 : 0.08),
                ]
              : [
                  const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                  const Color(0xFF0D9488).withValues(alpha: isDark ? 0.18 : 0.08),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUrgent
              ? const Color(0xFFEF4444).withValues(alpha: 0.45)
              : const Color(0xFF10B981).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/announcements'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: isUrgent ? AppColors.error : AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUrgent ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isUrgent ? 'إعلان عاجل ومهم 🚨' : 'إعلان رسمي جديد 📢',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        timeBadge,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // زر إغلاق الإعلان
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _dismissedAnnouncementIds.add(id);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'عرض التفاصيل والبيان كامل',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isUrgent ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: isUrgent ? AppColors.error : AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberHero(String fullName, String nationalId, bool isDark) {
    final isExempt = _memberStatus == 'exempt' || _memberStatus == 'معفي';
    final isSuspended = _memberStatus == 'suspended' || _memberStatus == 'موقوف';

    Color badgeColor = AppColors.success;
    String badgeText = 'عضوية نشطة وفعالة';

    if (isExempt) {
      badgeColor = AppColors.gold;
      badgeText = 'عضو معفي من الاشتراكات';
    } else if (isSuspended) {
      badgeColor = AppColors.error;
      badgeText = 'عضوية موقوفة مؤقتاً';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentLight, width: 1.5),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أهلاً ومرحباً بك،',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (nationalId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        'هوية: $nationalId',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionStatusCard(BuildContext context, bool isDark) {
    final progressRatio = (_currentYearPaidMonths / 12).clamp(0.0, 1.0);
    final percentage = (progressRatio * 100).toInt();
    final isUpToDate = _overdueMonthsCount == 0;
    final isExempt = _memberStatus == 'exempt' || _memberStatus == 'معفي';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.shield_rounded, color: AppColors.accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'وضعية الاشتراكات والمساهمات',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isExempt
                      ? AppColors.primarySubtle
                      : (isUpToDate ? AppColors.successLight : AppColors.warningLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExempt
                      ? 'عضوية معفية'
                      : (isUpToDate ? 'مستوفى للشهر الحالي ✅' : 'متأخر ($_overdueMonthsCount أشهر) ⚠️'),
                  style: TextStyle(
                    color: isExempt
                        ? AppColors.primary
                        : (isUpToDate ? AppColors.success : AppColors.warning),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingStats
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        _buildInfoColumn(
                          'قيمة الاشتراك الشهري',
                          '${_currencyFormat.format(_monthlyFee)} ر.ي/شهر',
                          isDark,
                        ),
                        _buildInfoColumn(
                          'الأشهر المسددة (${DateTime.now().year})',
                          '$_currentYearPaidMonths من 12 شهراً',
                          isDark,
                        ),
                        _buildInfoColumn(
                          'إجمالي المساهمات',
                          '${_currencyFormat.format(_totalPaidAmount)} ر.ي',
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        backgroundColor: isDark ? AppColors.darkBorder : AppColors.borderLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'نسبة سداد سنة ${DateTime.now().year}: $percentage%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        InkWell(
                          onTap: () => context.go('/subscriptions'),
                          child: Row(
                            children: const [
                              Text(
                                'كشف الحساب التفصيلي',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMemberKPIGrid(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _buildKPITile(
          title: 'المتأخرات المطلوبة',
          value: _overdueTotalAmount > 0 ? _currencyFormat.format(_overdueTotalAmount) : '0',
          unit: 'ر.ي',
          icon: Icons.warning_amber_rounded,
          color: _overdueTotalAmount > 0 ? AppColors.error : AppColors.success,
          badgeText: _overdueMonthsCount > 0 ? '$_overdueMonthsCount أشهر متأخرة' : 'خالص السداد',
          isPositive: _overdueMonthsCount == 0,
          onTap: () => context.go('/subscriptions'),
          isDark: isDark,
        ),
        _buildKPITile(
          title: 'طلبات المساعدة',
          value: '$_totalAssistanceRequests',
          unit: 'طلب',
          icon: Icons.volunteer_activism_rounded,
          color: AppColors.accent,
          badgeText: _pendingAssistanceRequests > 0
              ? '$_pendingAssistanceRequests قيد المراجعة'
              : '$_approvedAssistanceRequests معتمد',
          isPositive: _pendingAssistanceRequests == 0,
          onTap: () => context.go('/assistance'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildKPITile({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required String badgeText,
    required bool isPositive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isPositive ? AppColors.successLight : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? AppColors.success : AppColors.warning,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberActions(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الخدمات والمعاملات المباشرة',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.receipt_long_rounded,
                title: 'سجل اشتراكاتي',
                subtitle: 'كشف الدفعات والإيصالات',
                color: AppColors.primary,
                onTap: () => context.go('/subscriptions'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.volunteer_activism_rounded,
                title: 'طلب إعانة / دعم',
                subtitle: 'تقديم طلب مساعدة مالية',
                color: AppColors.accent,
                onTap: () => context.go('/add-assistance'),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReceiptsSection(BuildContext context, bool isDark) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'آخر سندات السداد والإيصالات',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/subscriptions'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('كل السندات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا توجد سندات سداد مسجلة حتى الآن',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentPayments.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final p = _recentPayments[index];
                final id = p['id']?.toString() ?? '';
                final receiptNumber = p['receipt_number']?.toString() ?? 'سند قبض';
                final amount = ((p['amount'] ?? 0) as num).toDouble();
                final pMonth = (p['payment_month'] ?? 1) as int;
                final pYear = p['payment_year'] ?? 2026;
                final monthName = (pMonth >= 1 && pMonth <= 12) ? months[pMonth] : 'شهر $pMonth';
                final date = p['created_at'] != null
                    ? DateTime.parse(p['created_at'].toString())
                    : DateTime.now();

                return InkWell(
                  onTap: () => context.go('/receipt/$id'),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اشتراك $monthName $pYear',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'رقم السند: $receiptNumber • ${DateFormat('yyyy/MM/dd').format(date)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_currencyFormat.format(amount)} ر.ي',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                          const Text(
                            'عرض الإيصال 📄',
                            style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.campaign_rounded, color: AppColors.gold, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'لوحة الإعلانات والبيانات العامة',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/announcements'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('كل البيانات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_latestAnnouncements.isEmpty) ...[
            _buildAnnouncementTile(
              title: 'انعقاد الجمعية العامة العادية',
              date: 'أحدث بيان',
              body: 'ندعو جميع الأعضاء المسجلين لحضور الاجتماعات الدورية والاطلاع على الإعلانات.',
              isDark: isDark,
            ),
          ] else ...[
            for (int i = 0; i < _latestAnnouncements.length; i++) ...[
              if (i > 0) const Divider(height: 18),
              _buildAnnouncementTile(
                title: _latestAnnouncements[i]['title'] ?? 'إعلان عام',
                date: _latestAnnouncements[i]['created_at'] != null
                    ? DateFormat('dd MMMM yyyy', 'ar').format(DateTime.parse(_latestAnnouncements[i]['created_at']))
                    : '',
                body: _latestAnnouncements[i]['content'] ?? _latestAnnouncements[i]['body'] ?? '',
                isDark: isDark,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAnnouncementTile({
    required String title,
    required String date,
    required String body,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (date.isNotEmpty)
              Text(
                date,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}