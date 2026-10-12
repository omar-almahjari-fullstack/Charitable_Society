import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_cache_service.dart';

// ============================================================
// MEMBER SUBSCRIPTIONS & RECEIPTS SCREEN (شاشة اشتراكات العضو)
// ============================================================
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = true;

  // Selected Year for History & Tracker
  int _selectedYear = DateTime.now().year;
  final List<int> _availableYears = [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2];

  // Financial Metrics
  double _monthlyFee = 1000.0;
  String _memberStatus = 'active';
  double _totalCumulativePaid = 0.0;
  double _selectedYearPaidAmount = 0.0;
  int _selectedYearPaidMonthsCount = 0;

  // Overdue Details
  List<String> _overdueMonthsLabels = [];
  double _totalOverdueAmount = 0.0;

  // Payments List
  List<Map<String, dynamic>> _allPayments = [];

  final List<String> _monthsNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'ar');

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      // Safe Parallel Execution
      final results = await Future.wait([
        // 0: Profile
        SupabaseService.client
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .maybeSingle()
            .catchError((_) => null),

        // 1: All Payments for this Member
        SupabaseService.client
            .from('payments')
            .select('*')
            .eq('member_id', userId)
            .order('created_at', ascending: false)
            .catchError((_) => <dynamic>[]),

        // 2: Association Settings
        SupabaseService.client
            .from('association_settings')
            .select('*')
            .catchError((_) => <dynamic>[]),
      ]);

      final profileMap = results[0] as Map<String, dynamic>?;
      final paymentsList = results[1] as List;
      final settingsList = results[2] as List;

      // 1. Profile Info
      double monthlySubscription = 1000.0;
      String status = 'active';

      if (profileMap != null) {
        monthlySubscription = ((profileMap['monthly_subscription'] ?? 1000.0) as num).toDouble();
        status = profileMap['status']?.toString() ?? 'active';
      }

      // 2. Association Start Date
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
      double cumulativeTotal = 0.0;
      double selectedYearTotal = 0.0;
      final paidMonthsAllTime = <String>{};
      final paidMonthsInSelectedYear = <int>{};
      final List<Map<String, dynamic>> parsedPayments = [];

      for (final item in paymentsList) {
        final p = item as Map<String, dynamic>;
        final amt = ((p['amount'] ?? 0) as num).toDouble();
        cumulativeTotal += amt;

        final pYear = p['payment_year'] as int?;
        final pMonth = p['payment_month'] as int?;

        if (pYear != null && pMonth != null) {
          paidMonthsAllTime.add('${pYear}_$pMonth');
          if (pYear == _selectedYear) {
            paidMonthsInSelectedYear.add(pMonth);
            selectedYearTotal += amt;
          }
        }

        parsedPayments.add(p);
      }

      // 4. Calculate Overdue Months
      final List<String> overdueLabels = [];
      if (status != 'exempt' && status != 'معفي') {
        int y = startYear;
        int m = startMonth;

        while (y < currentYear || (y == currentYear && m <= currentMonth)) {
          final key = '${y}_$m';
          if (!paidMonthsAllTime.contains(key)) {
            final monthName = (m >= 1 && m <= 12) ? _monthsNames[m - 1] : 'شهر $m';
            overdueLabels.add('$monthName $y');
          }
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
      }

      final overdueTotal = overdueLabels.length * monthlySubscription;

      if (mounted) {
        setState(() {
          _monthlyFee = monthlySubscription;
          _memberStatus = status;
          _totalCumulativePaid = cumulativeTotal;
          _selectedYearPaidAmount = selectedYearTotal;
          _selectedYearPaidMonthsCount = paidMonthsInSelectedYear.length;
          _overdueMonthsLabels = overdueLabels;
          _totalOverdueAmount = overdueTotal;
          _allPayments = parsedPayments;
          _isLoading = false;
        });

        // حفظ كشف الاشتراكات في التخزين المحلي لاستعراضه دون إنترنت
        try {
          await LocalCacheService.save('member_subscriptions_$userId', {
            'monthly_fee': monthlySubscription,
            'status': status,
            'cumulative_total': cumulativeTotal,
            'selected_year_total': selectedYearTotal,
            'paid_months_count': paidMonthsInSelectedYear.length,
            'overdue_labels': overdueLabels,
            'overdue_total': overdueTotal,
            'payments': parsedPayments,
          });
        } catch (_) {}
      }
    } catch (_) {
      // عند تعذر الاتصال بالخادم، جلب النسخة المحفوظة محلياً فوراً
      try {
        final userId = SupabaseService.currentUser?.id;
        if (userId != null) {
          final cached = await LocalCacheService.get('member_subscriptions_$userId');
          if (cached != null && mounted) {
            setState(() {
              _monthlyFee = (cached['monthly_fee'] as num?)?.toDouble() ?? _monthlyFee;
              _memberStatus = cached['status']?.toString() ?? _memberStatus;
              _totalCumulativePaid = (cached['cumulative_total'] as num?)?.toDouble() ?? _totalCumulativePaid;
              _selectedYearPaidAmount = (cached['selected_year_total'] as num?)?.toDouble() ?? _selectedYearPaidAmount;
              _selectedYearPaidMonthsCount = cached['paid_months_count'] as int? ?? _selectedYearPaidMonthsCount;
              _overdueMonthsLabels = List<String>.from(cached['overdue_labels'] ?? []);
              _totalOverdueAmount = (cached['overdue_total'] as num?)?.toDouble() ?? _totalOverdueAmount;
              _allPayments = List<Map<String, dynamic>>.from(cached['payments'] ?? []);
              _isLoading = false;
            });
            return;
          }
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'سجل الاشتراكات والمدفوعات',
        subtitle: '${_currencyFormat.format(_monthlyFee)} ر.ي شهرياً',
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
            onPressed: _loadSubscriptionData,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'جاري قراءة كشف الاشتراكات والسندات...')
          : RefreshIndicator(
              onRefresh: _loadSubscriptionData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Year Selector & Commitment Hero Card
                    _buildYearlyTrackerCard(isDark),
                    const SizedBox(height: 18),

                    // 12 Months Interactive Matrix
                    _buildMonthsMatrix(isDark),
                    const SizedBox(height: 18),

                    // Overdue Status & Dues Breakdown
                    _buildOverdueBreakdownCard(isDark),
                    const SizedBox(height: 22),

                    // Receipts & Payments History Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'سجل السندات والإيصالات الرسمية',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_allPayments.length} سند مسجل',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Receipts List
                    if (_allPayments.isEmpty)
                      const EmptyState(
                        title: 'لا توجد سندات سداد مسجلة بعد',
                        subtitle: 'عند سداد أي اشتراك شهري للإدارة ستظهر إيصالاتك وسنداتك هنا.',
                        icon: Icons.receipt_long_outlined,
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _allPayments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _allPayments[index];
                          return _buildPaymentCard(item, isDark);
                        },
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildYearlyTrackerCard(bool isDark) {
    final progress = (_selectedYearPaidMonthsCount / 12).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'كشف اشتراكات سنة: ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            dropdownColor: AppColors.primaryDark,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 20),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            items: _availableYears.map((y) {
                              return DropdownMenuItem<int>(
                                value: y,
                                child: Text('$y'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedYear = val;
                                  _loadSubscriptionData();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_selectedYearPaidMonthsCount من 12 شهراً مسدداً في هذا العام',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مسدد سنة $_selectedYear', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${_currencyFormat.format(_selectedYearPaidAmount)} ر.ي',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي التراكمي التاريخي', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${_currencyFormat.format(_totalCumulativePaid)} ر.ي',
                      style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthsMatrix(bool isDark) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final paidMonths = _allPayments
        .where((p) => p['payment_year'] == _selectedYear && p['payment_month'] != null)
        .map((p) => p['payment_month'] as int)
        .toSet();

    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                'حالة شهور سنة $_selectedYear',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildLegend(AppColors.success, 'مسدد', isDark),
                  const SizedBox(width: 8),
                  _buildLegend(AppColors.error, 'متأخر', isDark),
                  const SizedBox(width: 8),
                  _buildLegend(isDark ? AppColors.darkBorder : AppColors.border, 'قادم', isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthNum = index + 1;
              final isPaid = paidMonths.contains(monthNum);
              final isPastOrCurrent = (_selectedYear < currentYear) ||
                  (_selectedYear == currentYear && monthNum <= currentMonth);

              Color bgColor;
              Color borderColor;
              Color textColor;
              String statusLabel;

              if (isPaid) {
                bgColor = AppColors.successLight;
                borderColor = AppColors.success;
                textColor = AppColors.success;
                statusLabel = 'مسدد ✅';
              } else if (isPastOrCurrent) {
                bgColor = AppColors.errorLight;
                borderColor = AppColors.error.withValues(alpha: 0.6);
                textColor = AppColors.error;
                statusLabel = 'متأخر ⚠️';
              } else {
                bgColor = isDark ? AppColors.darkSurfaceElevated : AppColors.background;
                borderColor = isDark ? AppColors.darkBorder : AppColors.border;
                textColor = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
                statusLabel = 'قادم ⏳';
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _monthsNames[index],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark && !isPaid && !isPastOrCurrent
                            ? AppColors.darkTextPrimary
                            : textColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
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

  Widget _buildLegend(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueBreakdownCard(bool isDark) {
    final isUpToDate = _overdueMonthsLabels.isEmpty;
    final isExempt = _memberStatus == 'exempt' || _memberStatus == 'معفي';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUpToDate
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isUpToDate ? Icons.verified_user_rounded : Icons.warning_rounded,
                    color: isUpToDate ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'كشف المتأخرات والمستحقات الفعلية',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUpToDate ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExempt
                      ? 'معفي'
                      : (isUpToDate ? 'خالص السداد' : '${_overdueMonthsLabels.length} أشهر مستحقة'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUpToDate ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isExempt)
            Text(
              'حسابك معفي من سداد الاشتراكات الشهرية بناءً على قرار إدارة الجمعية.',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            )
          else if (isUpToDate)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تهانينا! لا توجد أي متأخرات مالية مستحقة عليك حتى الشهر الحالي.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'الأشهر المتأخرة غير المسددة:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _overdueMonthsLabels.map((lbl) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    lbl,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي المبلغ المطلوب سداده:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    '${_currencyFormat.format(_totalOverdueAmount)} ر.ي',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> item, bool isDark) {
    final id = item['id']?.toString() ?? '';
    final receiptNum = item['receipt_number']?.toString() ?? 'سند قبض';
    final amount = ((item['amount'] ?? 0) as num).toDouble();
    final pMonth = (item['payment_month'] ?? 1) as int;
    final pYear = item['payment_year'] ?? 2026;
    final paymentMethod = item['payment_method']?.toString() ?? 'نقدي';
    final notes = item['notes']?.toString();
    final date = item['created_at'] != null
        ? DateTime.parse(item['created_at'].toString())
        : (item['payment_date'] != null ? DateTime.parse(item['payment_date'].toString()) : DateTime.now());

    final monthName = (pMonth >= 1 && pMonth <= 12) ? _monthsNames[pMonth - 1] : 'شهر $pMonth';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/receipt/$id'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'اشتراك $monthName $pYear',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              paymentMethod,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'رقم السند: $receiptNum • ${DateFormat('yyyy/MM/dd HH:mm').format(date)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                      ),
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'ملاحظات: $notes',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_currencyFormat.format(amount)} ر.ي',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'طباعة الإيصال',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.print_rounded, size: 12, color: AppColors.primary),
                      ],
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
}