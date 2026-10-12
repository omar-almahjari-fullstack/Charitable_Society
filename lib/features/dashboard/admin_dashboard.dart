import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/services/supabase_service.dart';

// ============================================================
// DASHBOARD DATA MODELS
// ============================================================
class MonthlyChartData {
  final int monthIndex;
  final String monthName;
  final double amount;
  final int year;

  MonthlyChartData({
    required this.monthIndex,
    required this.monthName,
    required this.amount,
    required this.year,
  });
}

class DashboardTransactionItem {
  final String id;
  final String transactionNumber;
  final String transactionType;
  final double amount;
  final String description;
  final DateTime createdAt;

  DashboardTransactionItem({
    required this.id,
    required this.transactionNumber,
    required this.transactionType,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory DashboardTransactionItem.fromJson(Map<String, dynamic> json) {
    final isIncome = (json['transaction_type'] ?? 'income') == 'income';
    final incomeAmt = ((json['income_amount'] ?? 0.0) as num).toDouble();
    final expenseAmt = ((json['expense_amount'] ?? 0.0) as num).toDouble();
    final amt = ((json['amount'] ?? 0.0) as num).toDouble();

    return DashboardTransactionItem(
      id: json['id']?.toString() ?? '',
      transactionNumber: json['transaction_number']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? 'income',
      amount: amt > 0 ? amt : (isIncome ? incomeAmt : expenseAmt),
      description: json['description']?.toString() ?? json['notes']?.toString() ?? 'عملية مالية',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  bool get isIncome => transactionType == 'income';
}

// ============================================================
// ADMIN DASHBOARD SCREEN
// ============================================================
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  bool _isLoading = true;

  // Real-time Metrics from Supabase
  double _totalTreasuryBalance = 0.0;
  int _totalMembersCount = 0;
  int _activeMembersCount = 0;
  int _overdueMembersCount = 0;
  int _totalAssistanceRequests = 0;
  int _pendingAssistanceRequests = 0;
  double _monthlyExpensesTotal = 0.0;

  // Chart Data: Last 6 Months Real Collections
  List<MonthlyChartData> _last6MonthsData = [];

  // Recent 5 Live Transactions
  List<DashboardTransactionItem> _recentTransactions = [];

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'ar');

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      // Safe Parallel Execution with per-query error isolation
      final results = await Future.wait([
        // 0: Profiles
        SupabaseService.client
            .from('profiles')
            .select('*')
            .order('created_at', ascending: false)
            .catchError((_) => <dynamic>[]),

        // 1: Payments
        SupabaseService.client
            .from('payments')
            .select('*')
            .order('created_at', ascending: false)
            .catchError((_) => <dynamic>[]),

        // 2: Financial Transactions
        SupabaseService.client
            .from('financial_transactions')
            .select('*')
            .order('created_at', ascending: false)
            .catchError((_) => <dynamic>[]),

        // 3: Assistance Requests
        SupabaseService.client
            .from('assistance_requests')
            .select('*')
            .order('created_at', ascending: false)
            .catchError((_) => <dynamic>[]),

        // 4: Wallets
        SupabaseService.client
            .from('wallets')
            .select('*')
            .catchError((_) => <dynamic>[]),

        // 5: Settings
        SupabaseService.client
            .from('association_settings')
            .select('*')
            .catchError((_) => <dynamic>[]),
      ]);

      final profilesRes = results[0] as List;
      final paymentsRes = results[1] as List;
      final txRes = results[2] as List;
      final aidRes = results[3] as List;
      final walletsRes = results[4] as List;
      final settingsRes = results[5] as List;

      // 1. Calculate Profiles Stats
      int totalMembers = profilesRes.length;
      int activeMembers = 0;
      for (final p in profilesRes) {
        final status = p['status']?.toString().toLowerCase();
        if (status == 'active' || status == 'نشط') {
          activeMembers++;
        }
      }

      // 2. Calculate Financials & Treasury Balance
      double treasuryBalance = 0.0;
      double monthlyExpenses = 0.0;
      double totalIn = 0.0;
      double totalOut = 0.0;
      List<DashboardTransactionItem> recentList = [];

      // A) Check Wallets Table first
      if (walletsRes.isNotEmpty) {
        for (final w in walletsRes) {
          treasuryBalance += ((w['current_balance'] ?? 0.0) as num).toDouble();
        }
      }

      // B) Calculate from Financial Transactions
      if (txRes.isNotEmpty) {
        for (int i = 0; i < txRes.length; i++) {
          final tx = txRes[i] as Map<String, dynamic>;
          final inAmt = ((tx['income_amount'] ?? (tx['transaction_type'] == 'income' ? tx['amount'] : 0.0)) ?? 0.0 as num).toDouble();
          final outAmt = ((tx['expense_amount'] ?? (tx['transaction_type'] == 'expense' ? tx['amount'] : 0.0)) ?? 0.0 as num).toDouble();
          totalIn += inAmt;
          totalOut += outAmt;

          if (tx['created_at'] != null) {
            try {
              final txDate = DateTime.parse(tx['created_at'].toString());
              if (txDate.year == currentYear && txDate.month == currentMonth) {
                monthlyExpenses += outAmt;
              }
            } catch (_) {}
          }

          if (i < 5) {
            recentList.add(DashboardTransactionItem.fromJson(tx));
          }
        }

        if (treasuryBalance == 0.0) {
          final latestTx = txRes.first as Map<String, dynamic>;
          if (latestTx['balance_after'] != null) {
            treasuryBalance = ((latestTx['balance_after'] ?? 0.0) as num).toDouble();
          } else {
            treasuryBalance = totalIn - totalOut;
          }
        }
      }

      // C) If financial_transactions is empty, compute from payments
      if (treasuryBalance == 0.0 && paymentsRes.isNotEmpty) {
        double paymentsSum = 0.0;
        for (final p in paymentsRes) {
          paymentsSum += ((p['amount'] ?? 0.0) as num).toDouble();
        }
        treasuryBalance = paymentsSum;
      }

      // 3. Compute Overdue Arrears
      int startYear = 2026;
      int startMonth = 1;
      for (final s in settingsRes) {
        if (s['setting_key'] == 'association_start_date' && s['setting_value'] != null) {
          final parts = s['setting_value'].toString().split('-');
          if (parts.length >= 2) {
            startYear = int.tryParse(parts[0]) ?? 2026;
            startMonth = int.tryParse(parts[1]) ?? 1;
          }
        }
      }

      final paidSet = <String>{};
      final Map<String, double> monthlyIncomeMap = {};

      for (final p in paymentsRes) {
        final mId = p['member_id']?.toString();
        final mMonth = p['payment_month'] as int?;
        final mYear = p['payment_year'] as int?;
        final amt = ((p['amount'] ?? 0.0) as num).toDouble();

        if (mId != null && mMonth != null && mYear != null) {
          paidSet.add('${mId}_${mYear}_$mMonth');
        }

        int targetMonth = mMonth ?? 0;
        int targetYear = mYear ?? 0;
        if (targetMonth == 0 && p['created_at'] != null) {
          try {
            final dt = DateTime.parse(p['created_at'].toString());
            targetMonth = dt.month;
            targetYear = dt.year;
          } catch (_) {}
        }
        if (targetMonth > 0 && targetYear > 0) {
          final key = '${targetYear}_$targetMonth';
          monthlyIncomeMap[key] = (monthlyIncomeMap[key] ?? 0.0) + amt;
        }
      }

      int overdueCount = 0;
      for (final m in profilesRes) {
        final mId = m['id']?.toString();
        if (mId == null) continue;
        final status = m['status']?.toString().toLowerCase();
        if (status == 'exempt' || status == 'suspended' || status == 'معفي' || status == 'موقوف') continue;

        bool isMemberOverdue = false;
        int y = startYear;
        int mo = startMonth;

        while (y < currentYear || (y == currentYear && mo <= currentMonth)) {
          final key = '${mId}_${y}_$mo';
          if (!paidSet.contains(key)) {
            isMemberOverdue = true;
            break;
          }
          mo++;
          if (mo > 12) {
            mo = 1;
            y++;
          }
        }

        if (isMemberOverdue) {
          overdueCount++;
        }
      }

      // 4. Assistance Requests Stats
      int totalAid = aidRes.length;
      int pendingAid = 0;
      for (final a in aidRes) {
        final st = a['status']?.toString().toLowerCase();
        if (st == 'pending' || st == 'قيد المراجعة' || st == 'قيد الدراسة') {
          pendingAid++;
        }
      }

      // 5. Chart 6 Months
      const arabicMonths = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      final List<MonthlyChartData> chartList = [];
      for (int i = 5; i >= 0; i--) {
        DateTime target = DateTime(now.year, now.month - i, 1);
        final key = '${target.year}_${target.month}';
        final monthLabel = arabicMonths[target.month];
        final amount = monthlyIncomeMap[key] ?? 0.0;
        chartList.add(MonthlyChartData(
          monthIndex: 5 - i,
          monthName: monthLabel,
          amount: amount,
          year: target.year,
        ));
      }

      // If recentList is empty but payments exist, populate recent from payments
      if (recentList.isEmpty && paymentsRes.isNotEmpty) {
        for (int i = 0; i < paymentsRes.length && i < 5; i++) {
          final p = paymentsRes[i] as Map<String, dynamic>;
          recentList.add(DashboardTransactionItem(
            id: p['id']?.toString() ?? '',
            transactionNumber: p['receipt_number']?.toString() ?? 'سند قبض',
            transactionType: 'income',
            amount: ((p['amount'] ?? 0.0) as num).toDouble(),
            description: 'تحصيل اشتراك شهري',
            createdAt: p['created_at'] != null ? DateTime.parse(p['created_at'].toString()) : DateTime.now(),
          ));
        }
      }

      if (mounted) {
        setState(() {
          _totalTreasuryBalance = treasuryBalance;
          _totalMembersCount = totalMembers;
          _activeMembersCount = activeMembers;
          _overdueMembersCount = overdueCount;
          _totalAssistanceRequests = totalAid;
          _pendingAssistanceRequests = pendingAid;
          _monthlyExpensesTotal = monthlyExpenses;
          _last6MonthsData = chartList;
          _recentTransactions = recentList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary,
        child: _isLoading
            ? const LoadingWidget(message: 'جاري قراءة المؤشرات المالية...')
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Hero Welcome / Header
                    _buildExecutiveHero(context, isDark),
                    const SizedBox(height: 18),

                    // Primary KPI Metric Grid
                    _buildKPIGrid(isDark),
                    const SizedBox(height: 20),

                    // Financial Chart Section
                    _buildChartSection(isDark),
                    const SizedBox(height: 20),

                    // Quick Shortcuts / Actions
                    _buildQuickActionGrid(context, isDark),
                    const SizedBox(height: 20),

                    // Recent Activity Log
                    _buildRecentTransactionsSection(context, isDark),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildExecutiveHero(BuildContext context, bool isDark) {
    final balanceStr = _currencyFormat.format(_totalTreasuryBalance);

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
                  const Text(
                    'لوحة المؤشرات الإدارية المباشرة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'متابعة حية للاشتراكات والخزينة العامة',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.sensors_rounded, color: AppColors.successLight, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'مباشر',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إجمالي رصيد الصندوق المتاح',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$balanceStr ر.ي',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/ledger'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(60, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('كشف الحساب', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid(bool isDark) {
    final expensesFormatted = NumberFormat('#,##0', 'ar').format(_monthlyExpensesTotal);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.32,
      children: [
        _buildKPICard(
          title: 'الأعضاء المنتسبون',
          value: '$_totalMembersCount',
          unit: 'عضو',
          icon: Icons.people_alt_rounded,
          color: AppColors.primary,
          badgeText: '$_activeMembersCount نشط',
          isPositive: true,
          onTap: () => context.go('/members'),
          isDark: isDark,
        ),
        _buildKPICard(
          title: 'المتأخرون عن السداد',
          value: '$_overdueMembersCount',
          unit: 'عضو',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          badgeText: _overdueMembersCount > 0 ? 'يتطلب متابعة' : 'لا يوجد متأخرات',
          isPositive: _overdueMembersCount == 0,
          onTap: () => context.go('/members'),
          isDark: isDark,
        ),
        _buildKPICard(
          title: 'طلبات الإعانة',
          value: '$_totalAssistanceRequests',
          unit: 'طلب',
          icon: Icons.volunteer_activism_rounded,
          color: AppColors.accentDark,
          badgeText: '$_pendingAssistanceRequests قيد المراجعة',
          isPositive: _pendingAssistanceRequests == 0,
          onTap: () => context.go('/assistance'),
          isDark: isDark,
        ),
        _buildKPICard(
          title: 'مصروفات هذا الشهر',
          value: expensesFormatted,
          unit: 'ر.ي',
          icon: Icons.receipt_long_rounded,
          color: AppColors.error,
          badgeText: 'حركات الشهر',
          isPositive: true,
          onTap: () => context.go('/ledger'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildKPICard({
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
        padding: const EdgeInsets.all(14),
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildChartSection(bool isDark) {
    double maxVal = 10000;
    for (final d in _last6MonthsData) {
      if (d.amount > maxVal) maxVal = d.amount * 1.25;
    }

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حركة الإيرادات والتحصيل الفعلية',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'إجمالي اشتراكات آخر 6 أشهر',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ر.ي',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 180,
            child: _last6MonthsData.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد بيانات تحصيل مسجلة بعد',
                      style: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxVal,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => AppColors.primary,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${_currencyFormat.format(rod.toY)} ر.ي',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                            );
                          },
                        ),
                      ),
                      barGroups: _last6MonthsData.map((d) {
                        final isCurrent = d.monthIndex == 5;
                        return BarChartGroupData(
                          x: d.monthIndex,
                          barRods: [
                            BarChartRodData(
                              toY: d.amount,
                              color: isCurrent ? AppColors.accent : AppColors.primary,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxVal,
                                color: isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : AppColors.borderLight,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < _last6MonthsData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _last6MonthsData[idx].monthName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الخدمات والإجراءات السريعة',
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
              child: _buildActionTile(
                icon: Icons.add_card_rounded,
                label: 'تحصيل اشتراك',
                color: AppColors.accent,
                onTap: () => context.go('/add-payment'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                icon: Icons.receipt_long_rounded,
                label: 'تسجيل مصروف',
                color: AppColors.primary,
                onTap: () => context.go('/add-expense'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                icon: Icons.person_add_alt_1_rounded,
                label: 'إضافة عضو',
                color: AppColors.success,
                onTap: () => context.go('/member-details/new'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                icon: Icons.assessment_rounded,
                label: 'التقارير',
                color: AppColors.gold,
                onTap: () => context.go('/reports'),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.history_edu_rounded,
                label: 'سجل التدقيق',
                color: const Color(0xFF6366F1),
                onTap: () => context.go('/audit-logs'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                icon: Icons.menu_book_rounded,
                label: 'دفتر القيود',
                color: AppColors.primary,
                onTap: () => context.go('/ledger'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'المحافظ',
                color: AppColors.accentDark,
                onTap: () => context.go('/wallets'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                icon: Icons.campaign_rounded,
                label: 'الإعلانات',
                color: AppColors.warning,
                onTap: () => context.go('/announcements'),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(BuildContext context, bool isDark) {
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
              Text(
                'آخر الحركات والقيود المالية المباشرة',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/ledger'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('كشف الحساب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا توجد حركات مالية مسجلة حتى الآن',
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
              itemCount: _recentTransactions.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, idx) {
                final item = _recentTransactions[idx];
                final formattedAmt = _currencyFormat.format(item.amount);
                final sign = item.isIncome ? '+' : '-';
                final timeFormatted = _formatTimeAgo(item.createdAt);

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.isIncome ? AppColors.successLight : AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: item.isIncome ? AppColors.success : AppColors.error,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.transactionNumber.isNotEmpty ? item.transactionNumber : 'سند مالي',
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
                          '$sign$formattedAmt ر.ي',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: item.isIncome ? AppColors.success : AppColors.error,
                          ),
                        ),
                        Text(
                          timeFormatted,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return DateFormat('yyyy/MM/dd', 'ar').format(dt);
  }
}