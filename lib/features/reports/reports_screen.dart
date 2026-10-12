import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:typed_data';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_cache_service.dart';
import '../../core/utils/arabic_pdf_helper.dart';

// ============================================================
// DATA MODELS FOR MEMBER & FINANCIAL REPORTS
// ============================================================

class MemberMonthlyAnalysis {
  final int monthNumber;
  final String monthName;
  final int year;
  final double requiredAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status; // 'مدفوع', 'غير مدفوع', 'مدفوع جزئياً'
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? referenceNumber;

  MemberMonthlyAnalysis({
    required this.monthNumber,
    required this.monthName,
    required this.year,
    required this.requiredAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.paymentDate,
    this.paymentMethod,
    this.referenceNumber,
  });
}

class MemberFullReportData {
  final Map<String, dynamic> profile;
  final int selectedYear;
  final double totalRequiredYearly;
  final double totalPaidYearly;
  final double totalRemainingYearly;
  final double totalArrearsAllTime;
  final int paidMonthsCount;
  final int unpaidMonthsCount;
  final int partialMonthsCount;
  final DateTime? lastPaymentDate;
  final double? lastPaymentAmount;
  final String? lastPaymentMethod;
  final List<String> paymentMethodsUsed;
  final int totalTransactionsCount;
  final List<MemberMonthlyAnalysis> monthlyBreakdown;

  MemberFullReportData({
    required this.profile,
    required this.selectedYear,
    required this.totalRequiredYearly,
    required this.totalPaidYearly,
    required this.totalRemainingYearly,
    required this.totalArrearsAllTime,
    required this.paidMonthsCount,
    required this.unpaidMonthsCount,
    required this.partialMonthsCount,
    this.lastPaymentDate,
    this.lastPaymentAmount,
    this.lastPaymentMethod,
    required this.paymentMethodsUsed,
    required this.totalTransactionsCount,
    required this.monthlyBreakdown,
  });
}

class MemberSummaryItem {
  final Map<String, dynamic> profile;
  final String memberId;
  final String fullName;
  final String memberNumber;
  final String phone;
  final String status; // 'active', 'suspended', 'inactive'
  final double monthlySubscription;
  final double paidForSelectedMonth;
  final String monthPaymentStatus; // 'مدفوع', 'غير مدفوع', 'مدفوع جزئياً'
  final double totalPaidYearly;
  final double totalRemainingYearly;

  MemberSummaryItem({
    required this.profile,
    required this.memberId,
    required this.fullName,
    required this.memberNumber,
    required this.phone,
    required this.status,
    required this.monthlySubscription,
    required this.paidForSelectedMonth,
    required this.monthPaymentStatus,
    required this.totalPaidYearly,
    required this.totalRemainingYearly,
  });
}

class AllMembersReportData {
  final int year;
  final int month; // 0 for all months or 1..12
  final String accountStatusFilter;
  final String paymentStatusFilter;
  final String searchQuery;
  final int totalMembersCount;
  final int activeMembersCount;
  final int suspendedMembersCount;
  final int inactiveMembersCount;
  final int paidThisMonthCount;
  final int unpaidThisMonthCount;
  final int partialThisMonthCount;
  final double totalCollectedThisMonth;
  final double totalExpectedThisMonth;
  final double totalCollectedYearly;
  final double totalExpectedYearly;
  final List<MemberSummaryItem> membersSummary;

  AllMembersReportData({
    required this.year,
    required this.month,
    required this.accountStatusFilter,
    required this.paymentStatusFilter,
    required this.searchQuery,
    required this.totalMembersCount,
    required this.activeMembersCount,
    required this.suspendedMembersCount,
    required this.inactiveMembersCount,
    required this.paidThisMonthCount,
    required this.unpaidThisMonthCount,
    required this.partialThisMonthCount,
    required this.totalCollectedThisMonth,
    required this.totalExpectedThisMonth,
    required this.totalCollectedYearly,
    required this.totalExpectedYearly,
    required this.membersSummary,
  });
}

class FinancialReportData {
  final double totalIncome;
  final double totalExpenses;
  final double netBalance;
  final int incomeCount;
  final int expenseCount;
  final double averageTransaction;
  final Map<String, double> methodTotals;
  final Map<String, double> expenseCategoryTotals;
  final List<Map<String, dynamic>> filteredTransactions;

  FinancialReportData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netBalance,
    required this.incomeCount,
    required this.expenseCount,
    required this.averageTransaction,
    required this.methodTotals,
    required this.expenseCategoryTotals,
    required this.filteredTransactions,
  });
}

// ============================================================
// REPORT TAB & FILTER ENUMS
// ============================================================

enum MainReportTab { memberReport, financialReport }

// ============================================================
// SYSTEM REPORT STATE
// ============================================================

class SystemReportState {
  final bool isLoading;
  final String? error;
  final MainReportTab activeTab;

  // Data Collections
  final List<Map<String, dynamic>> allMembers;
  final List<Map<String, dynamic>> allPayments;
  final List<Map<String, dynamic>> allTransactions;

  // Member Report Filters
  final String? selectedMemberId; // null or 'all' for All-Members Report
  final int selectedMemberYear;
  final int selectedMemberMonth; // 0 for 'الكل', 1..12
  final String selectedMemberAccountStatus; // 'الكل', 'active', 'suspended', 'inactive'
  final String selectedMemberPaymentStatus; // 'الكل', 'مدفوع', 'غير مدفوع', 'مدفوع جزئياً'
  final String memberSearchQuery;

  // Financial Report Filters
  final String finYear; // 'الكل', '2024', '2025', '2026', '2027'
  final String finMonth; // 'الكل', '1', '2', ... '12'
  final DateTime? finFromDate;
  final DateTime? finToDate;
  final String finTransactionType; // 'الكل', 'إيرادات', 'مصروفات'
  final String finPaymentMethod; // 'الكل', 'نقدي', 'تحويل بنكي', 'محفظة إلكترونية', 'عملات رقمية'
  final String finExpenseCategory; // 'الكل', 'aid', 'maintenance', 'electricity', 'water', 'projects', 'salaries', 'other'
  final String finWalletType; // 'الكل', 'cash', 'bank', 'online', 'crypto'
  final String finSearchQuery;
  final double? finMinAmount;
  final double? finMaxAmount;

  // Computed Outputs
  final MemberFullReportData? currentMemberReport;
  final AllMembersReportData? currentAllMembersReport;
  final FinancialReportData? currentFinancialReport;

  SystemReportState({
    this.isLoading = false,
    this.error,
    this.activeTab = MainReportTab.memberReport,
    this.allMembers = const [],
    this.allPayments = const [],
    this.allTransactions = const [],
    this.selectedMemberId = 'all',
    required this.selectedMemberYear,
    this.selectedMemberMonth = 0,
    this.selectedMemberAccountStatus = 'الكل',
    this.selectedMemberPaymentStatus = 'الكل',
    this.memberSearchQuery = '',
    this.finYear = 'الكل',
    this.finMonth = 'الكل',
    this.finFromDate,
    this.finToDate,
    this.finTransactionType = 'الكل',
    this.finPaymentMethod = 'الكل',
    this.finExpenseCategory = 'الكل',
    this.finWalletType = 'الكل',
    this.finSearchQuery = '',
    this.finMinAmount,
    this.finMaxAmount,
    this.currentMemberReport,
    this.currentAllMembersReport,
    this.currentFinancialReport,
  });

  SystemReportState copyWith({
    bool? isLoading,
    String? error,
    MainReportTab? activeTab,
    List<Map<String, dynamic>>? allMembers,
    List<Map<String, dynamic>>? allPayments,
    List<Map<String, dynamic>>? allTransactions,
    String? selectedMemberId,
    int? selectedMemberYear,
    int? selectedMemberMonth,
    String? selectedMemberAccountStatus,
    String? selectedMemberPaymentStatus,
    String? memberSearchQuery,
    String? finYear,
    String? finMonth,
    DateTime? finFromDate,
    DateTime? finToDate,
    String? finTransactionType,
    String? finPaymentMethod,
    String? finExpenseCategory,
    String? finWalletType,
    String? finSearchQuery,
    double? finMinAmount,
    double? finMaxAmount,
    MemberFullReportData? currentMemberReport,
    AllMembersReportData? currentAllMembersReport,
    FinancialReportData? currentFinancialReport,
  }) {
    return SystemReportState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      activeTab: activeTab ?? this.activeTab,
      allMembers: allMembers ?? this.allMembers,
      allPayments: allPayments ?? this.allPayments,
      allTransactions: allTransactions ?? this.allTransactions,
      selectedMemberId: selectedMemberId ?? this.selectedMemberId,
      selectedMemberYear: selectedMemberYear ?? this.selectedMemberYear,
      selectedMemberMonth: selectedMemberMonth ?? this.selectedMemberMonth,
      selectedMemberAccountStatus: selectedMemberAccountStatus ?? this.selectedMemberAccountStatus,
      selectedMemberPaymentStatus: selectedMemberPaymentStatus ?? this.selectedMemberPaymentStatus,
      memberSearchQuery: memberSearchQuery ?? this.memberSearchQuery,
      finYear: finYear ?? this.finYear,
      finMonth: finMonth ?? this.finMonth,
      finFromDate: finFromDate ?? this.finFromDate,
      finToDate: finToDate ?? this.finToDate,
      finTransactionType: finTransactionType ?? this.finTransactionType,
      finPaymentMethod: finPaymentMethod ?? this.finPaymentMethod,
      finExpenseCategory: finExpenseCategory ?? this.finExpenseCategory,
      finWalletType: finWalletType ?? this.finWalletType,
      finSearchQuery: finSearchQuery ?? this.finSearchQuery,
      finMinAmount: finMinAmount ?? this.finMinAmount,
      finMaxAmount: finMaxAmount ?? this.finMaxAmount,
      currentMemberReport: currentMemberReport ?? this.currentMemberReport,
      currentAllMembersReport: currentAllMembersReport ?? this.currentAllMembersReport,
      currentFinancialReport: currentFinancialReport ?? this.currentFinancialReport,
    );
  }
}

class SystemReportNotifier extends StateNotifier<SystemReportState> {
  SystemReportNotifier() : super(SystemReportState(selectedMemberYear: DateTime.now().year, selectedMemberMonth: DateTime.now().month)) {
    loadAllData();
  }

  static const List<String> monthNamesArabic = [
    'يناير (1)', 'فبراير (2)', 'مارس (3)', 'أبريل (4)', 'مايو (5)', 'يونيو (6)',
    'يوليو (7)', 'أغسطس (8)', 'سبتمبر (9)', 'أكتوبر (10)', 'نوفمبر (11)', 'ديسمبر (12)'
  ];

  static const Map<String, String> expenseCategoriesArabic = {
    'الكل': 'كافة الفئات والمصروفات',
    'aid': 'مساعدات وإعانات مالية',
    'maintenance': 'صيانة وترميم',
    'electricity': 'كهرباء وإنارة',
    'water': 'مياه وتزويد',
    'projects': 'مشاريع تنموية',
    'salaries': 'مكافآت وأجور إدارية',
    'other': 'مصاريف تشغيلية أخرى',
  };

  String _getNormalizedMethod(Map<String, dynamic> t) {
    final walletType = t['wallet_type']?.toString().trim();
    final walletTxId = t['wallet_transaction_id']?.toString().trim();
    final methodStr = t['payment_method']?.toString().trim().toLowerCase() ?? '';

    if ((walletType != null && walletType.isNotEmpty) ||
        (walletTxId != null && walletTxId.isNotEmpty)) {
      return 'محفظة إلكترونية';
    }

    if (methodStr == 'online' ||
        methodStr == 'wallet' ||
        methodStr.contains('محفظة') ||
        methodStr.contains('بريدي') ||
        methodStr.contains('ccp') ||
        methodStr.contains('الذهبية')) {
      return 'محفظة إلكترونية';
    }

    if (methodStr == 'bank_transfer' ||
        methodStr == 'bank' ||
        methodStr.contains('بنك') ||
        methodStr.contains('تحويل') ||
        methodStr.contains('صك')) {
      return 'تحويل بنكي';
    }

    if (methodStr == 'crypto' || methodStr.contains('عملات')) {
      return 'عملات رقمية';
    }

    return 'نقدي';
  }

  Future<void> loadAllData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final membersResponse = await SupabaseService.client.from('profiles').select('*').order('full_name');
      final members = List<Map<String, dynamic>>.from(membersResponse);

      final paymentsResponse = await SupabaseService.client.from('payments').select('*').order('payment_date', ascending: false);
      final payments = List<Map<String, dynamic>>.from(paymentsResponse);

      final txResponse = await SupabaseService.client.from('financial_transactions').select('*, profiles!created_by(full_name)').order('created_at', ascending: false);
      var transactions = List<Map<String, dynamic>>.from(txResponse);

      final paymentsMap = {for (var p in payments) p['id']?.toString(): p};

      for (var i = 0; i < transactions.length; i++) {
        final t = Map<String, dynamic>.from(transactions[i]);
        if (t['reference_table'] == 'payments' && t['reference_id'] != null) {
          final p = paymentsMap[t['reference_id'].toString()];
          if (p != null) {
            t['payment_method'] = p['payment_method'] ?? t['payment_method'];
            t['wallet_type'] = p['wallet_type'];
            t['wallet_transaction_id'] = p['wallet_transaction_id'];
          }
        }
        transactions[i] = t;
      }

      state = state.copyWith(
        allMembers: members,
        allPayments: payments,
        allTransactions: transactions,
        isLoading: false,
      );

      recalculate();

      // حفظ بيانات التقارير محلياً للاستعراض دون اتصال
      try {
        await LocalCacheService.save('cached_reports_data', {
          'members': members,
          'payments': payments,
          'transactions': transactions,
        });
      } catch (_) {}
    } catch (e) {
      // استرجاع بيانات التقارير من الكاش المحلي
      try {
        final cached = await LocalCacheService.get('cached_reports_data');
        if (cached is Map && cached.isNotEmpty) {
          final members = List<Map<String, dynamic>>.from(cached['members'] ?? []);
          final payments = List<Map<String, dynamic>>.from(cached['payments'] ?? []);
          final transactions = List<Map<String, dynamic>>.from(cached['transactions'] ?? []);

          state = state.copyWith(
            allMembers: members,
            allPayments: payments,
            allTransactions: transactions,
            isLoading: false,
          );
          recalculate();
          return;
        }
      } catch (_) {}

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setActiveTab(MainReportTab tab) {
    state = state.copyWith(activeTab: tab);
    recalculate();
  }

  // Member Filter Actions
  void setSelectedMember(String? memberId) {
    state = state.copyWith(selectedMemberId: memberId);
    recalculate();
  }

  void setSelectedMemberYear(int year) {
    state = state.copyWith(selectedMemberYear: year);
    recalculate();
  }

  void setSelectedMemberMonth(int month) {
    state = state.copyWith(selectedMemberMonth: month);
    recalculate();
  }

  void setSelectedMemberAccountStatus(String status) {
    state = state.copyWith(selectedMemberAccountStatus: status);
    recalculate();
  }

  void setSelectedMemberPaymentStatus(String status) {
    state = state.copyWith(selectedMemberPaymentStatus: status);
    recalculate();
  }

  void setMemberSearchQuery(String query) {
    state = state.copyWith(memberSearchQuery: query);
    recalculate();
  }

  // Financial Filter Actions
  void setFinYear(String year) {
    state = state.copyWith(finYear: year);
    recalculate();
  }

  void setFinMonth(String month) {
    state = state.copyWith(finMonth: month);
    recalculate();
  }

  void setFinDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(finFromDate: from, finToDate: to);
    recalculate();
  }

  void setFinTransactionType(String type) {
    state = state.copyWith(finTransactionType: type);
    recalculate();
  }

  void setFinPaymentMethod(String method) {
    state = state.copyWith(finPaymentMethod: method);
    recalculate();
  }

  void setFinExpenseCategory(String category) {
    state = state.copyWith(finExpenseCategory: category);
    recalculate();
  }

  void setFinWalletType(String wallet) {
    state = state.copyWith(finWalletType: wallet);
    recalculate();
  }

  void setFinSearchQuery(String query) {
    state = state.copyWith(finSearchQuery: query);
    recalculate();
  }

  void setFinMinMaxAmount(double? min, double? max) {
    state = state.copyWith(finMinAmount: min, finMaxAmount: max);
    recalculate();
  }

  void resetFinancialFilters() {
    state = state.copyWith(
      finYear: 'الكل',
      finMonth: 'الكل',
      finFromDate: null,
      finToDate: null,
      finTransactionType: 'الكل',
      finPaymentMethod: 'الكل',
      finExpenseCategory: 'الكل',
      finWalletType: 'الكل',
      finSearchQuery: '',
      finMinAmount: null,
      finMaxAmount: null,
    );
    recalculate();
  }

  void recalculate() {
    final singleMemberReport = _computeSingleMemberReport();
    final allMembersReport = _computeAllMembersReport();
    final financialReport = _computeFinancialReport();

    state = state.copyWith(
      currentMemberReport: singleMemberReport,
      currentAllMembersReport: allMembersReport,
      currentFinancialReport: financialReport,
    );
  }

  MemberFullReportData? _computeSingleMemberReport() {
    if (state.selectedMemberId == null || state.selectedMemberId == 'all' || state.allMembers.isEmpty) return null;

    final member = state.allMembers.firstWhere(
      (m) => m['id']?.toString() == state.selectedMemberId,
      orElse: () => {},
    );

    if (member.isEmpty) return null;

    final memberId = member['id']?.toString() ?? '';
    final monthlyFee = ((member['monthly_subscription'] ?? 50.0) as num).toDouble();
    final year = state.selectedMemberYear;

    final memberPayments = state.allPayments.where((p) => p['member_id']?.toString() == memberId).toList();

    List<MemberMonthlyAnalysis> breakdown = [];
    int paidCount = 0;
    int unpaidCount = 0;
    int partialCount = 0;
    double totalPaidYearly = 0;

    for (int m = 1; m <= 12; m++) {
      final monthPayments = memberPayments.where((p) {
        final pMonth = p['payment_month'] != null ? (p['payment_month'] as num).toInt() : null;
        final pYear = p['payment_year'] != null ? (p['payment_year'] as num).toInt() : null;
        return pMonth == m && (pYear == year || (pYear == null && p['payment_date'] != null && DateTime.parse(p['payment_date']).year == year));
      }).toList();

      final paidForMonth = monthPayments.fold(0.0, (sum, p) => sum + ((p['amount'] ?? 0.0) as num).toDouble());
      totalPaidYearly += paidForMonth;

      final remaining = (monthlyFee - paidForMonth) > 0 ? (monthlyFee - paidForMonth) : 0.0;

      String status;
      if (paidForMonth >= monthlyFee) {
        status = 'مدفوع';
        paidCount++;
      } else if (paidForMonth > 0) {
        status = 'مدفوع جزئياً';
        partialCount++;
      } else {
        status = 'غير مدفوع';
        unpaidCount++;
      }

      final lastP = monthPayments.isNotEmpty ? monthPayments.first : null;

      breakdown.add(MemberMonthlyAnalysis(
        monthNumber: m,
        monthName: monthNamesArabic[m - 1],
        year: year,
        requiredAmount: monthlyFee,
        paidAmount: paidForMonth,
        remainingAmount: remaining,
        status: status,
        paymentDate: lastP != null && lastP['payment_date'] != null ? DateTime.parse(lastP['payment_date']) : null,
        paymentMethod: lastP?['payment_method']?.toString(),
        referenceNumber: lastP?['receipt_number']?.toString() ?? lastP?['wallet_transaction_id']?.toString(),
      ));
    }

    final totalRequiredYearly = monthlyFee * 12;
    final totalRemainingYearly = (totalRequiredYearly - totalPaidYearly) > 0 ? (totalRequiredYearly - totalPaidYearly) : 0.0;

    final allTimePaid = memberPayments.fold(0.0, (sum, p) => sum + ((p['amount'] ?? 0.0) as num).toDouble());
    final joinDate = member['created_at'] != null ? DateTime.parse(member['created_at']) : DateTime(2024);
    final monthsSinceJoin = ((DateTime.now().year - joinDate.year) * 12 + DateTime.now().month - joinDate.month + 1).clamp(1, 120);
    final totalRequiredAllTime = monthlyFee * monthsSinceJoin;
    final totalArrearsAllTime = (totalRequiredAllTime - allTimePaid) > 0 ? (totalRequiredAllTime - allTimePaid) : 0.0;

    final lastPayment = memberPayments.isNotEmpty ? memberPayments.first : null;
    final methodsUsed = memberPayments.map((p) => p['payment_method']?.toString() ?? 'نقدي').toSet().toList();

    return MemberFullReportData(
      profile: member,
      selectedYear: year,
      totalRequiredYearly: totalRequiredYearly,
      totalPaidYearly: totalPaidYearly,
      totalRemainingYearly: totalRemainingYearly,
      totalArrearsAllTime: totalArrearsAllTime,
      paidMonthsCount: paidCount,
      unpaidMonthsCount: unpaidCount,
      partialMonthsCount: partialCount,
      lastPaymentDate: lastPayment != null && lastPayment['payment_date'] != null ? DateTime.parse(lastPayment['payment_date']) : null,
      lastPaymentAmount: lastPayment != null ? ((lastPayment['amount'] ?? 0.0) as num).toDouble() : null,
      lastPaymentMethod: lastPayment?['payment_method']?.toString(),
      paymentMethodsUsed: methodsUsed,
      totalTransactionsCount: memberPayments.length,
      monthlyBreakdown: breakdown,
    );
  }

  AllMembersReportData? _computeAllMembersReport() {
    if (state.allMembers.isEmpty) return null;

    final year = state.selectedMemberYear;
    final targetMonth = state.selectedMemberMonth; // 0 for 'الكل', or 1..12
    final q = state.memberSearchQuery.trim().toLowerCase();

    List<MemberSummaryItem> items = [];
    int activeCount = 0;
    int suspendedCount = 0;
    int inactiveCount = 0;

    int paidThisMonthCount = 0;
    int unpaidThisMonthCount = 0;
    int partialThisMonthCount = 0;

    double totalCollectedThisMonth = 0;
    double totalExpectedThisMonth = 0;
    double totalCollectedYearly = 0;
    double totalExpectedYearly = 0;

    for (var m in state.allMembers) {
      final mId = m['id']?.toString() ?? '';
      final name = (m['full_name'] ?? '').toString();
      final phone = (m['phone'] ?? '').toString();
      final memberNum = (m['member_number'] ?? '').toString();
      final natId = (m['national_id'] ?? '').toString();
      final status = m['status'] ?? 'active';
      final monthlyFee = ((m['monthly_subscription'] ?? 50.0) as num).toDouble();

      if (status == 'active') {
        activeCount++;
      } else if (status == 'suspended') {
        suspendedCount++;
      } else {
        inactiveCount++;
      }

      // Filter payments for this member
      final mPayments = state.allPayments.where((p) => p['member_id']?.toString() == mId).toList();

      // Yearly total paid
      final paidYear = mPayments.fold(0.0, (sum, p) {
        final pYear = p['payment_year'] != null ? (p['payment_year'] as num).toInt() : (p['payment_date'] != null ? DateTime.parse(p['payment_date']).year : year);
        return pYear == year ? sum + ((p['amount'] ?? 0.0) as num).toDouble() : sum;
      });

      totalCollectedYearly += paidYear;
      totalExpectedYearly += (monthlyFee * 12);

      // Monthly payment for target month
      double paidMonth = 0;
      if (targetMonth > 0) {
        final monthPs = mPayments.where((p) {
          final pMonth = p['payment_month'] != null ? (p['payment_month'] as num).toInt() : null;
          final pYear = p['payment_year'] != null ? (p['payment_year'] as num).toInt() : (p['payment_date'] != null ? DateTime.parse(p['payment_date']).year : year);
          return pMonth == targetMonth && pYear == year;
        });
        paidMonth = monthPs.fold(0.0, (sum, p) => sum + ((p['amount'] ?? 0.0) as num).toDouble());
        totalCollectedThisMonth += paidMonth;
        totalExpectedThisMonth += monthlyFee;
      }

      String monthPayStatus;
      if (targetMonth > 0) {
        if (paidMonth >= monthlyFee) {
          monthPayStatus = 'مدفوع';
          paidThisMonthCount++;
        } else if (paidMonth > 0) {
          monthPayStatus = 'مدفوع جزئياً';
          partialThisMonthCount++;
        } else {
          monthPayStatus = 'غير مدفوع';
          unpaidThisMonthCount++;
        }
      } else {
        monthPayStatus = paidYear >= (monthlyFee * 12) ? 'مدفوع بالكامل' : (paidYear > 0 ? 'سداد جزئي' : 'غير مسدد');
      }

      final remainingYearly = (monthlyFee * 12 - paidYear) > 0 ? (monthlyFee * 12 - paidYear) : 0.0;

      final summaryItem = MemberSummaryItem(
        profile: m,
        memberId: mId,
        fullName: name,
        memberNumber: memberNum,
        phone: phone,
        status: status,
        monthlySubscription: monthlyFee,
        paidForSelectedMonth: paidMonth,
        monthPaymentStatus: monthPayStatus,
        totalPaidYearly: paidYear,
        totalRemainingYearly: remainingYearly,
      );

      // Apply Filters
      bool matchesSearch = q.isEmpty || name.toLowerCase().contains(q) || phone.toLowerCase().contains(q) || memberNum.toLowerCase().contains(q) || natId.toLowerCase().contains(q);
      bool matchesAccountStatus = state.selectedMemberAccountStatus == 'الكل' || status == state.selectedMemberAccountStatus;
      bool matchesPaymentStatus = state.selectedMemberPaymentStatus == 'الكل' || monthPayStatus == state.selectedMemberPaymentStatus;

      if (matchesSearch && matchesAccountStatus && matchesPaymentStatus) {
        items.add(summaryItem);
      }
    }

    return AllMembersReportData(
      year: year,
      month: targetMonth,
      accountStatusFilter: state.selectedMemberAccountStatus,
      paymentStatusFilter: state.selectedMemberPaymentStatus,
      searchQuery: q,
      totalMembersCount: state.allMembers.length,
      activeMembersCount: activeCount,
      suspendedMembersCount: suspendedCount,
      inactiveMembersCount: inactiveCount,
      paidThisMonthCount: paidThisMonthCount,
      unpaidThisMonthCount: unpaidThisMonthCount,
      partialThisMonthCount: partialThisMonthCount,
      totalCollectedThisMonth: totalCollectedThisMonth,
      totalExpectedThisMonth: totalExpectedThisMonth,
      totalCollectedYearly: totalCollectedYearly,
      totalExpectedYearly: totalExpectedYearly,
      membersSummary: items,
    );
  }

  FinancialReportData _computeFinancialReport() {
    var filtered = List<Map<String, dynamic>>.from(state.allTransactions);

    // 1. Filter by Year
    if (state.finYear != 'الكل') {
      final y = int.tryParse(state.finYear);
      if (y != null) {
        filtered = filtered.where((t) {
          final date = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;
          return date != null && date.year == y;
        }).toList();
      }
    }

    // 2. Filter by Month
    if (state.finMonth != 'الكل') {
      final m = int.tryParse(state.finMonth);
      if (m != null) {
        filtered = filtered.where((t) {
          final date = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;
          return date != null && date.month == m;
        }).toList();
      }
    }

    // 3. Filter by Date Range
    if (state.finFromDate != null) {
      filtered = filtered.where((t) {
        final date = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;
        return date != null && date.isAfter(state.finFromDate!.subtract(const Duration(seconds: 1)));
      }).toList();
    }
    if (state.finToDate != null) {
      filtered = filtered.where((t) {
        final date = t['created_at'] != null ? DateTime.parse(t['created_at']) : null;
        return date != null && date.isBefore(state.finToDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // 4. Filter by Transaction Type
    if (state.finTransactionType != 'الكل') {
      final targetType = state.finTransactionType == 'إيرادات' ? 'income' : 'expense';
      filtered = filtered.where((t) => t['transaction_type'] == targetType).toList();
    }

    // 5. Filter by Payment Method / Normalized check
    if (state.finPaymentMethod != 'الكل') {
      filtered = filtered.where((t) {
        final norm = _getNormalizedMethod(t);
        return norm == state.finPaymentMethod;
      }).toList();
    }

    // 6. Filter Expenses by Assistance / Category Type
    if (state.finExpenseCategory != 'الكل') {
      filtered = filtered.where((t) {
        if (t['transaction_type'] != 'expense') return true;
        final cat = (t['category'] ?? '').toString().toLowerCase();
        final desc = (t['description'] ?? '').toString().toLowerCase();
        final target = state.finExpenseCategory.toLowerCase();
        return cat.contains(target) || desc.contains(target);
      }).toList();
    }

    // 7. Filter Income by Wallet / Source Type
    if (state.finWalletType != 'الكل') {
      filtered = filtered.where((t) {
        if (t['transaction_type'] != 'income') return true;
        final wallet = (t['wallet_type'] ?? '').toString().toLowerCase();
        final method = (t['payment_method'] ?? '').toString().toLowerCase();
        final target = state.finWalletType.toLowerCase();
        return wallet.contains(target) || method.contains(target) || _getNormalizedMethod(t).contains(state.finWalletType);
      }).toList();
    }

    // 8. Filter by Search Query
    if (state.finSearchQuery.isNotEmpty) {
      final q = state.finSearchQuery.toLowerCase();
      filtered = filtered.where((t) {
        final desc = (t['description'] ?? '').toString().toLowerCase();
        final cat = (t['category'] ?? '').toString().toLowerCase();
        final num = (t['transaction_number'] ?? '').toString().toLowerCase();
        final user = (t['profiles']?['full_name'] ?? '').toString().toLowerCase();
        final walletType = (t['wallet_type'] ?? '').toString().toLowerCase();
        return desc.contains(q) || cat.contains(q) || num.contains(q) || user.contains(q) || walletType.contains(q);
      }).toList();
    }

    // 9. Filter by Min / Max Amount
    if (state.finMinAmount != null) {
      filtered = filtered.where((t) {
        final amt = t['transaction_type'] == 'income' ? (t['income_amount'] ?? 0.0) : (t['expense_amount'] ?? 0.0);
        return (amt as num).toDouble() >= state.finMinAmount!;
      }).toList();
    }
    if (state.finMaxAmount != null) {
      filtered = filtered.where((t) {
        final amt = t['transaction_type'] == 'income' ? (t['income_amount'] ?? 0.0) : (t['expense_amount'] ?? 0.0);
        return (amt as num).toDouble() <= state.finMaxAmount!;
      }).toList();
    }

    // Compute Aggregates
    double totalInc = 0;
    double totalExp = 0;
    int incCount = 0;
    int expCount = 0;
    Map<String, double> methodTotals = {'نقدي': 0, 'تحويل بنكي': 0, 'محفظة إلكترونية': 0, 'عملات رقمية': 0};
    Map<String, double> categoryTotals = {};

    for (var t in filtered) {
      final isInc = t['transaction_type'] == 'income';
      final amt = isInc ? ((t['income_amount'] ?? 0.0) as num).toDouble() : ((t['expense_amount'] ?? 0.0) as num).toDouble();
      final normMethod = _getNormalizedMethod(t);
      final cat = (t['category'] ?? 'عام').toString();

      if (isInc) {
        totalInc += amt;
        incCount++;
      } else {
        totalExp += amt;
        expCount++;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + amt;
      }

      methodTotals[normMethod] = (methodTotals[normMethod] ?? 0.0) + amt;
    }

    final net = totalInc - totalExp;
    final totalCount = filtered.length;
    final avgAmt = totalCount > 0 ? (totalInc + totalExp) / totalCount : 0.0;

    return FinancialReportData(
      totalIncome: totalInc,
      totalExpenses: totalExp,
      netBalance: net,
      incomeCount: incCount,
      expenseCount: expCount,
      averageTransaction: avgAmt,
      methodTotals: methodTotals,
      expenseCategoryTotals: categoryTotals,
      filteredTransactions: filtered,
    );
  }
}

final systemReportProvider = StateNotifierProvider<SystemReportNotifier, SystemReportState>((ref) {
  return SystemReportNotifier();
});

// ============================================================
// MAIN REPORTS SCREEN UI
// ============================================================

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  final TextEditingController _minAmtController = TextEditingController();
  final TextEditingController _maxAmtController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _memberSearchController.dispose();
    _minAmtController.dispose();
    _maxAmtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(systemReportProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'نظام التقارير الماليّة والأعضاء الشامل',
        subtitle: 'تقارير تفصيلية شاملة مع فلاتر خيارات متقدمة',
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
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            onPressed: () => _exportReportPDF(reportState),
            tooltip: 'تصدير PDF',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Colors.white),
            onPressed: () => _exportReportExcel(reportState),
            tooltip: 'تصدير Excel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(systemReportProvider.notifier).loadAllData(),
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: reportState.isLoading
          ? const LoadingWidget(message: 'جاري استخراج البيانات وتقارير الأعضاء والحسابات...')
          : Column(
              children: [
                // Top Tab Selector (👥 تقرير الأعضاء | 📊 تقرير المالية)
                _buildTabSegmentHeader(reportState, isDark),

                // Main Tab Body
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: reportState.activeTab == MainReportTab.memberReport
                        ? _buildApprovedMemberReportView(reportState, isDark)
                        : _buildComprehensiveFinancialReportView(reportState, isDark),
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // TAB SEGMENT HEADER
  // ============================================================

  Widget _buildTabSegmentHeader(SystemReportState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: '👥 تقرير الأعضاء',
              isSelected: state.activeTab == MainReportTab.memberReport,
              onTap: () => ref.read(systemReportProvider.notifier).setActiveTab(MainReportTab.memberReport),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildTabButton(
              label: '📊 تقرير الماليّة',
              isSelected: state.activeTab == MainReportTab.financialReport,
              onTap: () => ref.read(systemReportProvider.notifier).setActiveTab(MainReportTab.financialReport),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required bool isSelected, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSurfaceElevated : AppColors.primarySubtle),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
          boxShadow: isSelected ? AppColors.cardShadow : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 1: APPROVED MEMBER REPORT VIEW (ALL MEMBERS OR SINGLE MEMBER)
  // ============================================================

  Widget _buildApprovedMemberReportView(SystemReportState state, bool isDark) {
    final isAllMembersMode = state.selectedMemberId == 'all' || state.selectedMemberId == null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Member Selector Box (Supports 'all' or Individual Member)
        Container(
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
                children: [
                  const Icon(Icons.manage_search_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'اختر نوع التقرير (جميع الأعضاء أو عضو محدد)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: state.selectedMemberId ?? 'all',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'نطاق التقرير',
                        prefixIcon: Icon(Icons.people_alt_rounded, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text(
                            '👥 جميع الأعضاء (كشف شامل لكافة الحسابات)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ),
                        ...state.allMembers.map((m) {
                          return DropdownMenuItem<String>(
                            value: m['id']?.toString(),
                            child: Text(
                              '👤 ${m['full_name']} (${m['phone'] ?? "بدون هاتف"})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) => ref.read(systemReportProvider.notifier).setSelectedMember(val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: state.selectedMemberYear,
                      decoration: const InputDecoration(
                        labelText: 'السنة الماليّة',
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      items: [2024, 2025, 2026, 2027].map((y) {
                        return DropdownMenuItem<int>(
                          value: y,
                          child: Text('$y', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) ref.read(systemReportProvider.notifier).setSelectedMemberYear(val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (isAllMembersMode) ...[
          // ALL MEMBERS COMPREHENSIVE VIEW
          _buildAllMembersComprehensiveSection(state, isDark),
        ] else ...[
          // SINGLE MEMBER VIEW
          _buildSingleMemberView(state, isDark),
        ],
      ],
    );
  }

  // ============================================================
  // ALL MEMBERS REPORT SECTION (KPIs + FILTERS + FULL TABLE LIST)
  // ============================================================

  Widget _buildAllMembersComprehensiveSection(SystemReportState state, bool isDark) {
    final allReport = state.currentAllMembersReport;
    if (allReport == null) {
      return const EmptyState(title: 'لا توجد أعضاء مسجلين', subtitle: 'قم بتسجيل أعضاء جُدد للتمكن من رؤية كشف التقرير الشامل.', icon: Icons.people_outline_rounded);
    }

    final months = [
      {'val': 0, 'label': 'كل الأشهر (إجمالي السنة)'},
      {'val': 1, 'label': '1- يناير'},
      {'val': 2, 'label': '2- فبراير'},
      {'val': 3, 'label': '3- مارس'},
      {'val': 4, 'label': '4- أبريل'},
      {'val': 5, 'label': '5- مايو'},
      {'val': 6, 'label': '6- يونيو'},
      {'val': 7, 'label': '7- يوليو'},
      {'val': 8, 'label': '8- أغسطس'},
      {'val': 9, 'label': '9- سبتمبر'},
      {'val': 10, 'label': '10- أكتوبر'},
      {'val': 11, 'label': '11- نوفمبر'},
      {'val': 12, 'label': '12- ديسمبر'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // All-Members Filtering Bar
        Container(
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
                children: [
                  const Icon(Icons.filter_alt_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'تصفية وفلترة حالة جميع الأعضاء حسب الشهر والحساب',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Row 1: Month Selector & Account Status
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: state.selectedMemberMonth,
                      decoration: const InputDecoration(labelText: 'تصفية بالشهر', prefixIcon: Icon(Icons.date_range_rounded, size: 18)),
                      items: months.map((m) => DropdownMenuItem<int>(value: m['val'] as int, child: Text(m['label'] as String, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) ref.read(systemReportProvider.notifier).setSelectedMemberMonth(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: state.selectedMemberAccountStatus,
                      decoration: const InputDecoration(labelText: 'حالة الحساب', prefixIcon: Icon(Icons.person_pin_rounded, size: 18)),
                      items: ['الكل', 'active', 'suspended', 'inactive'].map((s) {
                        String label = s == 'active' ? 'نشط ومستوفى' : (s == 'suspended' ? 'موقوف مؤقتاً' : (s == 'inactive' ? 'غير نشط' : 'كافة الحالات'));
                        return DropdownMenuItem(value: s, child: Text(label, style: const TextStyle(fontSize: 12)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) ref.read(systemReportProvider.notifier).setSelectedMemberAccountStatus(val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter Row 2: Monthly Payment Status & Search
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: state.selectedMemberPaymentStatus,
                      decoration: const InputDecoration(labelText: 'حالة السداد بالشهر', prefixIcon: Icon(Icons.fact_check_rounded, size: 18)),
                      items: ['الكل', 'مدفوع', 'غير مدفوع', 'مدفوع جزئياً'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) ref.read(systemReportProvider.notifier).setSelectedMemberPaymentStatus(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _memberSearchController,
                  decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو رقم الهاتف...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _memberSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () {
                                  _memberSearchController.clear();
                                  ref.read(systemReportProvider.notifier).setMemberSearchQuery('');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => ref.read(systemReportProvider.notifier).setMemberSearchQuery(v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Executive KPIs Summary for All-Members
        _buildAllMembersKPIGrid(allReport, isDark),
        const SizedBox(height: 20),

        // Header for All-Members List Table
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'كشف ومتابعة الأعضاء المفلترة (${allReport.membersSummary.length} عضو)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
            if (allReport.month > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: BorderRadius.circular(10)),
                child: Text('الشهر: ${allReport.month}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // All Members List Items
        if (allReport.membersSummary.isEmpty)
          const EmptyState(title: 'لا يوجد أعضاء مطابقين للفلترة', subtitle: 'حاول تغيير شروط الفلترة أو تفقد كلمة البحث.', icon: Icons.person_off_rounded)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allReport.membersSummary.length,
            itemBuilder: (context, index) {
              final item = allReport.membersSummary[index];
              return _buildAllMemberSummaryCard(item, allReport.month, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildAllMembersKPIGrid(AllMembersReportData r, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile('إجمالي الأعضاء', '${r.totalMembersCount} عضو', Icons.groups_rounded, AppColors.primary, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('الأعضاء النشطين', '${r.activeMembersCount} عضو', Icons.verified_user_rounded, AppColors.success, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('الموقوفين مؤقتاً', '${r.suspendedMembersCount} عضو', Icons.pause_circle_outline, AppColors.warning, isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile(r.month > 0 ? 'المحصل لشهر ${r.month}' : 'المحصل السنوي', '${(r.month > 0 ? r.totalCollectedThisMonth : r.totalCollectedYearly).toStringAsFixed(0)} ر.ي', Icons.payments_rounded, AppColors.success, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile(r.month > 0 ? 'المستهدف لشهر ${r.month}' : 'المستهدف السنوي', '${(r.month > 0 ? r.totalExpectedThisMonth : r.totalExpectedYearly).toStringAsFixed(0)} ر.ي', Icons.account_balance_wallet_rounded, AppColors.gold, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile(r.month > 0 ? 'مسددين شهر ${r.month}' : 'مسددين بالكامل', '${r.month > 0 ? r.paidThisMonthCount : r.paidThisMonthCount} عضو', Icons.task_alt_rounded, AppColors.primary, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildAllMemberSummaryCard(MemberSummaryItem item, int targetMonth, bool isDark) {
    final isPaid = item.monthPaymentStatus == 'مدفوع' || item.monthPaymentStatus == 'مدفوع بالكامل';
    final isPartial = item.monthPaymentStatus == 'مدفوع جزئياً' || item.monthPaymentStatus == 'سداد جزئي';
    final statusColor = isPaid ? AppColors.success : (isPartial ? AppColors.gold : AppColors.error);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(isPaid ? Icons.check_circle_rounded : (isPartial ? Icons.timelapse_rounded : Icons.cancel_rounded), color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fullName,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    ),
                    Text(
                      'هاتف: ${item.phone.isEmpty ? "غير مسجل" : item.phone} • قيد: ${item.memberNumber.isEmpty ? "---" : item.memberNumber}',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(item.monthPaymentStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.status == 'active' ? 'نشط ومستوفى' : (item.status == 'suspended' ? 'موقوف مؤقتاً' : 'غير نشط'),
                    style: TextStyle(fontSize: 10, color: item.status == 'active' ? AppColors.success : AppColors.error),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactStatTile('الاشتراك الشهري', '${item.monthlySubscription.toStringAsFixed(0)} ر.ي', isDark),
                _buildCompactStatTile(targetMonth > 0 ? 'المسدد لشهر $targetMonth' : 'المحصل سنوياً', '${(targetMonth > 0 ? item.paidForSelectedMonth : item.totalPaidYearly).toStringAsFixed(0)} ر.ي', isDark),
                _buildCompactStatTile('المتبقي سنوياً', '${item.totalRemainingYearly.toStringAsFixed(0)} ر.ي', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatTile(String title, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
      ],
    );
  }

  // ============================================================
  // SINGLE MEMBER VIEW
  // ============================================================

  Widget _buildSingleMemberView(SystemReportState state, bool isDark) {
    final memberReport = state.currentMemberReport;

    if (memberReport == null) {
      return const EmptyState(title: 'اختر عضواً', subtitle: 'حدد عضواً من القائمة أعلاه لمراجعة حسابه المالي.', icon: Icons.person_search_rounded);
    }

    return Column(
      children: [
        _buildMemberProfileCard(memberReport.profile, isDark),
        const SizedBox(height: 16),
        _buildMemberFinancialKPIGrid(memberReport, isDark),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'تحليل أشهر سنة ${memberReport.selectedYear} (12 شهراً)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
            DropdownButton<String>(
              value: state.selectedMemberPaymentStatus,
              underline: const SizedBox(),
              items: ['الكل', 'مدفوع', 'غير مدفوع', 'مدفوع جزئياً'].map((s) {
                return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));
              }).toList(),
              onChanged: (val) {
                if (val != null) ref.read(systemReportProvider.notifier).setSelectedMemberPaymentStatus(val);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildMonthlyBreakdownList(memberReport.monthlyBreakdown, state.selectedMemberPaymentStatus, isDark),
      ],
    );
  }

  Widget _buildMemberProfileCard(Map<String, dynamic> profile, bool isDark) {
    final name = profile['full_name'] ?? 'عضو';
    final phone = profile['phone'] ?? 'غير مسجل';
    final nationalId = profile['national_id'] ?? 'غير مسجل';
    final role = profile['role'] ?? 'member';
    final status = profile['status'] ?? 'active';
    final fee = ((profile['monthly_subscription'] ?? 50.0) as num).toDouble();
    final joinDate = profile['created_at'] != null ? DateFormat('yyyy/MM/dd').format(DateTime.parse(profile['created_at'])) : '---';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withOpacity(0.8), width: 1.5),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('هاتف: $phone • الهوية: $nationalId', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'active' ? AppColors.success : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status == 'active' ? 'نشط' : 'موقوف', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWhiteSubText('الاشتراك الشهري', '${fee.toStringAsFixed(0)} ر.ي'),
                Container(width: 1, height: 20, color: Colors.white24),
                _buildWhiteSubText('الصفة', role == 'admin' ? 'مدير' : 'عضو'),
                Container(width: 1, height: 20, color: Colors.white24),
                _buildWhiteSubText('الانضمام', joinDate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteSubText(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildMemberFinancialKPIGrid(MemberFullReportData r, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile('المطلوب سنوياً', '${r.totalRequiredYearly.toStringAsFixed(0)} ر.ي', Icons.request_quote_rounded, AppColors.primary, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('المحصل سنوياً', '${r.totalPaidYearly.toStringAsFixed(0)} ر.ي', Icons.check_circle_rounded, AppColors.success, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('المتبقي سنوياً', '${r.totalRemainingYearly.toStringAsFixed(0)} ر.ي', Icons.pending_actions_rounded, AppColors.error, isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile('الأشهر المدفوعة', '${r.paidMonthsCount} شهور', Icons.task_alt_rounded, AppColors.success, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('المدفوعة جزئياً', '${r.partialMonthsCount} شهور', Icons.timelapse_rounded, AppColors.gold, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('غير المدفوعة', '${r.unpaidMonthsCount} شهور', Icons.cancel_outlined, AppColors.error, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBreakdownList(List<MemberMonthlyAnalysis> list, String filter, bool isDark) {
    var filtered = list;
    if (filter != 'الكل') {
      filtered = list.where((m) => m.status == filter).toList();
    }

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('لا توجد أشهر مطابقة للفكرة المحددة.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isPaid = item.status == 'مدفوع';
        final isPartial = item.status == 'مدفوع جزئياً';
        final statusColor = isPaid ? AppColors.success : (isPartial ? AppColors.gold : AppColors.error);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(isPaid ? Icons.check_circle_rounded : (isPartial ? Icons.timelapse_rounded : Icons.cancel_rounded), color: statusColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'شهر ${item.monthName}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(item.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المطلوب: ${item.requiredAmount.toStringAsFixed(0)} ر.ي', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  Text('المدفوع: ${item.paidAmount.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                  Text('المتبقي: ${item.remainingAmount.toStringAsFixed(0)} ر.ي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: item.remainingAmount > 0 ? AppColors.error : AppColors.textSecondary)),
                ],
              ),
              if (item.paymentDate != null) ...[
                const SizedBox(height: 6),
                Text(
                  'طريقة الدفع: ${item.paymentMethod ?? "نقدي"} • التاريخ: ${DateFormat("yyyy/MM/dd").format(item.paymentDate!)} • مرجع: ${item.referenceNumber ?? "سند"}',
                  style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // TAB 2: COMPREHENSIVE FINANCIAL REPORT VIEW (WITH CATEGORY & WALLET FILTERS)
  // ============================================================

  Widget _buildComprehensiveFinancialReportView(SystemReportState state, bool isDark) {
    final finReport = state.currentFinancialReport;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Filter Controls Card
        _buildFinancialFiltersAccordion(state, isDark),
        const SizedBox(height: 16),

        if (finReport == null || finReport.filteredTransactions.isEmpty) ...[
          const EmptyState(title: 'لا توجد بيانات مطابقة', subtitle: 'تأكد من تعديل فلاتر البحث والخيارات أعلاه.', icon: Icons.filter_alt_off_rounded),
        ] else ...[
          // Executive Financial KPI Summary Cards
          _buildFinancialExecutiveKPIs(finReport, isDark),
          const SizedBox(height: 18),

          // Payment Methods Breakdown Row
          _buildMethodTotalsRow(finReport.methodTotals, isDark),
          const SizedBox(height: 18),

          // Income vs Expense Chart Card
          _buildFinancialBarChart(finReport, isDark),
          const SizedBox(height: 18),

          // Filtered Transactions Detailed List
          Text(
            'سجل التفاصيل للعمليات المفلترة (${finReport.filteredTransactions.length} قيد)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          _buildFilteredTransactionsList(finReport.filteredTransactions, isDark),
        ],
      ],
    );
  }

  Widget _buildFinancialFiltersAccordion(SystemReportState state, bool isDark) {
    final years = ['الكل', '2024', '2025', '2026', '2027'];
    final months = [
      {'val': 'الكل', 'label': 'كل الأشهر (12)'},
      {'val': '1', 'label': '1- يناير'},
      {'val': '2', 'label': '2- فبراير'},
      {'val': '3', 'label': '3- مارس'},
      {'val': '4', 'label': '4- أبريل'},
      {'val': '5', 'label': '5- مايو'},
      {'val': '6', 'label': '6- يونيو'},
      {'val': '7', 'label': '7- يوليو'},
      {'val': '8', 'label': '8- أغسطس'},
      {'val': '9', 'label': '9- سبتمبر'},
      {'val': '10', 'label': '10- أكتوبر'},
      {'val': '11', 'label': '11- نوفمبر'},
      {'val': '12', 'label': '12- ديسمبر'},
    ];
    final types = ['الكل', 'إيرادات', 'مصروفات'];
    final methods = ['الكل', 'نقدي', 'تحويل بنكي', 'محفظة إلكترونية', 'عملات رقمية'];
    final categories = SystemReportNotifier.expenseCategoriesArabic;

    final hasActiveFilters = state.finYear != 'الكل' ||
        state.finMonth != 'الكل' ||
        state.finTransactionType != 'الكل' ||
        state.finPaymentMethod != 'الكل' ||
        state.finExpenseCategory != 'الكل' ||
        state.finWalletType != 'الكل' ||
        state.finFromDate != null ||
        state.finToDate != null ||
        state.finSearchQuery.isNotEmpty ||
        state.finMinAmount != null ||
        state.finMaxAmount != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasActiveFilters ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.border)),
        boxShadow: AppColors.cardShadow,
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Icon(Icons.tune_rounded, color: hasActiveFilters ? AppColors.accent : AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'الفلاتر التفصيلية الشاملة للتقرير المالي',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
            const Spacer(),
            if (hasActiveFilters)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _minAmtController.clear();
                  _maxAmtController.clear();
                  ref.read(systemReportProvider.notifier).resetFinancialFilters();
                },
                child: const Text('إعادة ضبط', style: TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Row 1: Year & Month Filter
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.finYear,
                        decoration: const InputDecoration(labelText: 'السنة الماليّة', prefixIcon: Icon(Icons.calendar_month_rounded, size: 18)),
                        items: years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          if (val != null) ref.read(systemReportProvider.notifier).setFinYear(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.finMonth,
                        decoration: const InputDecoration(labelText: 'الشهر المطلوب', prefixIcon: Icon(Icons.date_range_rounded, size: 18)),
                        items: months.map((m) => DropdownMenuItem(value: m['val']!, child: Text(m['label']!, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          if (val != null) ref.read(systemReportProvider.notifier).setFinMonth(val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Transaction Type & Payment Method
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.finTransactionType,
                        decoration: const InputDecoration(labelText: 'نوع الحركة', prefixIcon: Icon(Icons.swap_vert_rounded, size: 18)),
                        items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          if (val != null) ref.read(systemReportProvider.notifier).setFinTransactionType(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.finPaymentMethod,
                        decoration: const InputDecoration(labelText: 'طريقة الدفع/المحفظة', prefixIcon: Icon(Icons.payment_rounded, size: 18)),
                        items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          if (val != null) ref.read(systemReportProvider.notifier).setFinPaymentMethod(val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 3: Expense Category Filter (فلترة المصروفات بحسب نوع المساعدة/الفئة)
                DropdownButtonFormField<String>(
                  value: state.finExpenseCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'فلترة المصروفات (نوع المساعدة/الفئة)',
                    prefixIcon: Icon(Icons.category_rounded, size: 18),
                  ),
                  items: categories.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) ref.read(systemReportProvider.notifier).setFinExpenseCategory(val);
                  },
                ),
                const SizedBox(height: 12),

                // Row 4: Custom Date Range Pickers
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: state.finFromDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            ref.read(systemReportProvider.notifier).setFinDateRange(date, state.finToDate);
                          }
                        },
                        icon: const Icon(Icons.event_rounded, size: 16),
                        label: Text(
                          state.finFromDate != null ? 'من: ${DateFormat('yyyy/MM/dd').format(state.finFromDate!)}' : 'من تاريخ',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: state.finToDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            ref.read(systemReportProvider.notifier).setFinDateRange(state.finFromDate, date);
                          }
                        },
                        icon: const Icon(Icons.event_available_rounded, size: 16),
                        label: Text(
                          state.finToDate != null ? 'إلى: ${DateFormat('yyyy/MM/dd').format(state.finToDate!)}' : 'إلى تاريخ',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Input Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث في النص، الوصف، اسم المستخدم، أو مرجع القيد...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(systemReportProvider.notifier).setFinSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => ref.read(systemReportProvider.notifier).setFinSearchQuery(val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialExecutiveKPIs(FinancialReportData fin, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile('إجمالي الإيرادات', '${fin.totalIncome.toStringAsFixed(0)} ر.ي', Icons.trending_up_rounded, AppColors.success, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('إجمالي المصروفات', '${fin.totalExpenses.toStringAsFixed(0)} ر.ي', Icons.trending_down_rounded, AppColors.error, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('صافي الرصيد', '${fin.netBalance.toStringAsFixed(0)} ر.ي', Icons.account_balance_rounded, fin.netBalance >= 0 ? AppColors.success : AppColors.error, isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile('قيود الإيراد', '${fin.incomeCount} قيد', Icons.arrow_circle_down_rounded, AppColors.success, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('قيود المصروف', '${fin.expenseCount} قيد', Icons.arrow_circle_up_rounded, AppColors.error, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('متوسط العملية', '${fin.averageTransaction.toStringAsFixed(0)} ر.ي', Icons.analytics_rounded, AppColors.gold, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodTotalsRow(Map<String, double> totals, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: totals.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('${entry.key}: ', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                Text('${entry.value.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.success)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFinancialBarChart(FinancialReportData fin, bool isDark) {
    final maxVal = (fin.totalIncome > fin.totalExpenses ? fin.totalIncome : fin.totalExpenses) * 1.2;

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
            children: const [
              Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('المقارنة البيانية للإيرادات والمصروفات المفلترة', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal : 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = group.x == 0 ? 'إيرادات' : 'مصروفات';
                      return BarTooltipItem('$label\n${rod.toY.toInt()} ر.ي', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final style = TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold);
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(value.toInt() == 0 ? 'الإيرادات' : 'المصروفات', style: style),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: fin.totalIncome, color: AppColors.success, width: 32, borderRadius: BorderRadius.circular(6))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: fin.totalExpenses, color: AppColors.error, width: 32, borderRadius: BorderRadius.circular(6))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredTransactionsList(List<Map<String, dynamic>> list, bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final t = list[index];
        final isIncome = t['transaction_type'] == 'income';
        final amount = isIncome ? ((t['income_amount'] ?? 0.0) as num).toDouble() : ((t['expense_amount'] ?? 0.0) as num).toDouble();
        final method = t['payment_method']?.toString() ?? 'نقدي';
        final category = t['category']?.toString() ?? 'عام';
        final creator = t['profiles']?['full_name']?.toString() ?? 'المدير';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isIncome ? AppColors.successLight : AppColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isIncome ? AppColors.success : AppColors.error, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['description'] ?? 'قيد مالي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                    Text(
                      'الفئة: $category • بواسطة: $creator • الطريقة: $method • ${t['created_at'] != null ? DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(t['created_at'])) : "---"}',
                      style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('${isIncome ? "+" : "-"}${amount.toStringAsFixed(0)} ر.ي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isIncome ? AppColors.success : AppColors.error)),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // PDF & EXCEL EXPORTERS FOR ALL-MEMBERS AND FINANCIAL REPORTS
  // ============================================================

  Future<void> _exportReportPDF(SystemReportState state) async {
    try {
      final fontRegular = await ArabicPdfHelper.loadArabicFont();
      final fontBold = await ArabicPdfHelper.loadArabicBoldFont();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
      );

      final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

      if (state.activeTab == MainReportTab.memberReport) {
        if (state.selectedMemberId == 'all' || state.selectedMemberId == null) {
          final report = state.currentAllMembersReport;
          if (report == null || report.membersSummary.isEmpty) return;

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4.landscape,
              textDirection: pw.TextDirection.rtl,
              build: (context) {
                return [
                  pw.Header(
                    level: 0,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(ArabicPdfHelper.reshape('جمعية التكافل والتنمية القروية'), style: pw.TextStyle(font: fontBold, fontSize: 18)),
                        pw.SizedBox(height: 4),
                        pw.Text(ArabicPdfHelper.reshape('كشف التقرير الشامل لحالة جميع الأعضاء - سنة ${report.year} ${report.month > 0 ? "(شهر ${report.month})" : ""}'), style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                        pw.Text(ArabicPdfHelper.reshape('تاريخ الاستخراج: $dateStr • إجمالي الأعضاء: ${report.totalMembersCount} • المسددين: ${report.paidThisMonthCount}'), style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 8),
                        pw.Divider(),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text(ArabicPdfHelper.reshape('نشطين: ${report.activeMembersCount}'), style: pw.TextStyle(font: fontBold, fontSize: 9)),
                        pw.Text(ArabicPdfHelper.reshape('موقوفين: ${report.suspendedMembersCount}'), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.red800)),
                        pw.Text(ArabicPdfHelper.reshape('المحصل: ${(report.month > 0 ? report.totalCollectedThisMonth : report.totalCollectedYearly).toStringAsFixed(0)} ر.ي'), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.green800)),
                        pw.Text(ArabicPdfHelper.reshape('المستهدف: ${(report.month > 0 ? report.totalExpectedThisMonth : report.totalExpectedYearly).toStringAsFixed(0)} ر.ي'), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue800)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                        children: [
                          _pdfCell('رقم العضوية', isHeader: true, font: fontBold),
                          _pdfCell('اسم العضو كاملاً', isHeader: true, font: fontBold),
                          _pdfCell('الهاتف', isHeader: true, font: fontBold),
                          _pdfCell('حالة الحساب', isHeader: true, font: fontBold),
                          _pdfCell('الاشتراك', isHeader: true, font: fontBold),
                          _pdfCell(report.month > 0 ? 'سداد شهر ${report.month}' : 'حالة السنة', isHeader: true, font: fontBold),
                          _pdfCell('المحصل الفعلي', isHeader: true, font: fontBold),
                          _pdfCell('المتبقي السنوي', isHeader: true, font: fontBold),
                        ],
                      ),
                      ...report.membersSummary.map((item) {
                        final statusStr = item.status == 'active' ? 'نشط' : (item.status == 'suspended' ? 'موقوف' : 'غير نشط');
                        return pw.TableRow(
                          children: [
                            _pdfCell(item.memberNumber.isEmpty ? '---' : item.memberNumber, font: fontRegular),
                            _pdfCell(item.fullName, font: fontRegular),
                            _pdfCell(item.phone, font: fontRegular),
                            _pdfCell(statusStr, font: fontRegular),
                            _pdfCell('${item.monthlySubscription.toStringAsFixed(0)} ر.ي', font: fontRegular),
                            _pdfCell(item.monthPaymentStatus, font: fontRegular),
                            _pdfCell('${(report.month > 0 ? item.paidForSelectedMonth : item.totalPaidYearly).toStringAsFixed(0)} ر.ي', font: fontRegular),
                            _pdfCell('${item.totalRemainingYearly.toStringAsFixed(0)} ر.ي', font: fontRegular),
                          ],
                        );
                      }),
                    ],
                  ),
                ];
              },
            ),
          );
        } else {
          final r = state.currentMemberReport;
          if (r == null) return;

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              textDirection: pw.TextDirection.rtl,
              build: (context) {
                return [
                  pw.Header(
                    level: 0,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(ArabicPdfHelper.reshape('جمعية التكافل والتنمية القروية'), style: pw.TextStyle(font: fontBold, fontSize: 18)),
                        pw.SizedBox(height: 4),
                        pw.Text(ArabicPdfHelper.reshape('كشف حساب واشتراكات العضو الرسمية'), style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                        pw.Text(ArabicPdfHelper.reshape('العضو: ${r.profile['full_name']} • السنة: ${r.selectedYear} • تاريخ الاستخراج: $dateStr'), style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 8),
                        pw.Divider(),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                        children: [
                          _pdfCell('الشهر', isHeader: true, font: fontBold),
                          _pdfCell('المطلوب', isHeader: true, font: fontBold),
                          _pdfCell('المدفوع', isHeader: true, font: fontBold),
                          _pdfCell('المتبقي', isHeader: true, font: fontBold),
                          _pdfCell('الحالة', isHeader: true, font: fontBold),
                        ],
                      ),
                      ...r.monthlyBreakdown.map((m) {
                        return pw.TableRow(
                          children: [
                            _pdfCell(m.monthName, font: fontRegular),
                            _pdfCell('${m.requiredAmount.toStringAsFixed(0)} ر.ي', font: fontRegular),
                            _pdfCell('${m.paidAmount.toStringAsFixed(0)} ر.ي', font: fontRegular),
                            _pdfCell('${m.remainingAmount.toStringAsFixed(0)} ر.ي', font: fontRegular),
                            _pdfCell(m.status, font: fontRegular),
                          ],
                        );
                      }),
                    ],
                  ),
                ];
              },
            ),
          );
        }
      } else {
        final fin = state.currentFinancialReport;
        final filterDesc = 'سنة: ${state.finYear} • شهر: ${state.finMonth} • نوع: ${state.finTransactionType} • فئة: ${state.finExpenseCategory} • طريقة: ${state.finPaymentMethod}';

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            textDirection: pw.TextDirection.rtl,
            build: (context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(ArabicPdfHelper.reshape('جمعية التكافل والتنمية القروية'), style: pw.TextStyle(font: fontBold, fontSize: 18)),
                      pw.SizedBox(height: 4),
                      pw.Text(ArabicPdfHelper.reshape('التقرير المالي العام التفصيلي المفلتر'), style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                      pw.Text(ArabicPdfHelper.reshape('الفلاتر: $filterDesc • تاريخ الاستخراج: $dateStr'), style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                if (fin != null) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text(ArabicPdfHelper.reshape('إجمالي الإيرادات: ${fin.totalIncome.toStringAsFixed(0)} ر.ي'), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.Text(ArabicPdfHelper.reshape('إجمالي المصروفات: ${fin.totalExpenses.toStringAsFixed(0)} ر.ي'), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.Text(ArabicPdfHelper.reshape('صافي الرصيد: ${fin.netBalance.toStringAsFixed(0)} ر.ي'), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                        children: [
                          _pdfCell('البيان / الوصف', isHeader: true, font: fontBold),
                          _pdfCell('النوع', isHeader: true, font: fontBold),
                          _pdfCell('الفئة / نوع المساعدة', isHeader: true, font: fontBold),
                          _pdfCell('طريقة الدفع/المحفظة', isHeader: true, font: fontBold),
                          _pdfCell('المبلغ', isHeader: true, font: fontBold),
                        ],
                      ),
                      ...fin.filteredTransactions.map((t) {
                        final isInc = t['transaction_type'] == 'income';
                        final amt = isInc ? ((t['income_amount'] ?? 0.0) as num).toDouble() : ((t['expense_amount'] ?? 0.0) as num).toDouble();
                        final method = t['payment_method']?.toString() ?? (t['wallet_type'] != null ? 'محفظة إلكترونية' : 'نقدي');
                        final category = t['category']?.toString() ?? 'عام';

                        return pw.TableRow(
                          children: [
                            _pdfCell(t['description'] ?? 'قيد', font: fontRegular),
                            _pdfCell(isInc ? 'إيراد' : 'مصروف', font: fontRegular),
                            _pdfCell(category, font: fontRegular),
                            _pdfCell(method, font: fontRegular),
                            _pdfCell('${amt.toStringAsFixed(0)} ر.ي', font: fontRegular),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ];
            },
          ),
        );
      }

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'تقرير_الجمعية_المفلتر.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تصدير PDF: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportReportExcel(SystemReportState state) async {
    try {
      final excel = Excel.createExcel();

      if (state.activeTab == MainReportTab.memberReport) {
        final Sheet sheet = excel['تقرير_جميع_الأعضاء'];
        excel.setDefaultSheet('تقرير_جميع_الأعضاء');

        sheet.appendRow([
          TextCellValue('رقم العضوية'),
          TextCellValue('اسم العضو كاملاً'),
          TextCellValue('رقم الهاتف'),
          TextCellValue('حالة الحساب'),
          TextCellValue('الاشتراك الشهري (ر.ي)'),
          TextCellValue('حالة السداد بالشهر'),
          TextCellValue('المحصل الفعلي (ر.ي)'),
          TextCellValue('المتبقي السنوي (ر.ي)'),
        ]);

        final report = state.currentAllMembersReport;
        if (report != null) {
          for (var item in report.membersSummary) {
            sheet.appendRow([
              TextCellValue(item.memberNumber),
              TextCellValue(item.fullName),
              TextCellValue(item.phone),
              TextCellValue(item.status == 'active' ? 'نشط' : (item.status == 'suspended' ? 'موقوف' : 'غير نشط')),
              TextCellValue(item.monthlySubscription.toStringAsFixed(0)),
              TextCellValue(item.monthPaymentStatus),
              TextCellValue((report.month > 0 ? item.paidForSelectedMonth : item.totalPaidYearly).toStringAsFixed(0)),
              TextCellValue(item.totalRemainingYearly.toStringAsFixed(0)),
            ]);
          }
        }
      } else {
        final Sheet sheet = excel['التقرير_المالي'];
        excel.setDefaultSheet('التقرير_المالي');

        sheet.appendRow([
          TextCellValue('البيان / الوصف'),
          TextCellValue('النوع'),
          TextCellValue('الفئة / نوع المساعدة'),
          TextCellValue('طريقة الدفع / المحفظة'),
          TextCellValue('بواسطة'),
          TextCellValue('التاريخ والوقت'),
          TextCellValue('المبلغ (ر.ي)'),
        ]);

        final fin = state.currentFinancialReport;
        if (fin != null) {
          for (var t in fin.filteredTransactions) {
            final isInc = t['transaction_type'] == 'income';
            final amt = isInc ? ((t['income_amount'] ?? 0.0) as num).toDouble() : ((t['expense_amount'] ?? 0.0) as num).toDouble();
            final method = t['payment_method']?.toString() ?? (t['wallet_type'] != null ? 'محفظة إلكترونية' : 'نقدي');
            final category = t['category']?.toString() ?? 'عام';
            final creator = t['profiles']?['full_name']?.toString() ?? 'المدير';
            final dateStr = t['created_at'] != null ? DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(t['created_at'])) : '---';

            sheet.appendRow([
              TextCellValue(t['description'] ?? ''),
              TextCellValue(isInc ? 'إيراد' : 'مصروف'),
              TextCellValue(category),
              TextCellValue(method),
              TextCellValue(creator),
              TextCellValue(dateStr),
              TextCellValue('${amt.toStringAsFixed(0)} ر.ي'),
            ]);
          }
        }
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        await Printing.sharePdf(bytes: Uint8List.fromList(fileBytes), filename: 'تقرير_الجمعية_المستخرج.xlsx');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تصدير Excel: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false, pw.Font? font}) {
    final reshapedText = ArabicPdfHelper.reshape(text);
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        reshapedText,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: font,
        ),
      ),
    );
  }
}