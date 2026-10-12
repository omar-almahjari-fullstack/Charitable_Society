import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_cache_service.dart';
import '../../core/utils/arabic_pdf_helper.dart';

// ============================================================
// 1. FINANCIAL LEDGER MODEL
// ============================================================
class LedgerTransaction {
  final String id;
  final String transactionNumber;
  final String transactionType;
  final double incomeAmount;
  final double expenseAmount;
  final String category;
  final String description;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime createdAt;
  final String? createdByName;

  LedgerTransaction({
    required this.id,
    required this.transactionNumber,
    required this.transactionType,
    required this.incomeAmount,
    required this.expenseAmount,
    required this.category,
    required this.description,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAt,
    this.createdByName,
  });

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: json['id']?.toString() ?? '',
      transactionNumber: json['transaction_number']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? 'income',
      incomeAmount: ((json['income_amount'] ?? 0.0) as num).toDouble(),
      expenseAmount: ((json['expense_amount'] ?? 0.0) as num).toDouble(),
      category: json['category']?.toString() ?? 'عام',
      description: json['description']?.toString() ?? 'بدون بيان',
      balanceBefore: ((json['balance_before'] ?? 0.0) as num).toDouble(),
      balanceAfter: ((json['balance_after'] ?? 0.0) as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      createdByName: json['profiles']?['full_name']?.toString(),
    );
  }

  bool get isIncome => transactionType == 'income';
  double get amount => isIncome ? incomeAmount : expenseAmount;
}

// ============================================================
// 2. AUDIT LOG MODEL
// ============================================================
class AuditLogItem {
  final String id;
  final String? userId;
  final String userName;
  final String userRole;
  final String action;
  final String category;
  final String description;
  final String? targetId;
  final DateTime createdAt;

  AuditLogItem({
    required this.id,
    this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.category,
    required this.description,
    this.targetId,
    required this.createdAt,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userName: json['user_name']?.toString() ?? 'مستخدم غير معروف',
      userRole: json['user_role']?.toString() ?? 'member',
      action: json['action']?.toString() ?? 'عملية عامة',
      category: json['category']?.toString() ?? 'عام',
      description: json['description']?.toString() ?? 'بدون تفاصيل',
      targetId: json['target_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }
}

// ============================================================
// LEDGER STATE
// ============================================================
class LedgerState {
  final List<LedgerTransaction> transactions;
  final bool isLoading;
  final String? error;
  final String filterType;
  final String searchQuery;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double totalIncome;
  final double totalExpenses;
  final double currentBalance;

  LedgerState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
    this.filterType = 'الكل',
    this.searchQuery = '',
    this.fromDate,
    this.toDate,
    this.totalIncome = 0,
    this.totalExpenses = 0,
    this.currentBalance = 0,
  });

  LedgerState copyWith({
    List<LedgerTransaction>? transactions,
    bool? isLoading,
    String? error,
    String? filterType,
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
    double? totalIncome,
    double? totalExpenses,
    double? currentBalance,
  }) {
    return LedgerState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      filterType: filterType ?? this.filterType,
      searchQuery: searchQuery ?? this.searchQuery,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }

  List<LedgerTransaction> get filteredTransactions {
    var list = transactions;

    if (filterType == 'إيرادات') {
      list = list.where((t) => t.isIncome).toList();
    } else if (filterType == 'مصروفات') {
      list = list.where((t) => !t.isIncome).toList();
    }

    if (fromDate != null) {
      list = list.where((t) => t.createdAt.isAfter(fromDate!.subtract(const Duration(seconds: 1)))).toList();
    }
    if (toDate != null) {
      list = list.where((t) => t.createdAt.isBefore(toDate!.add(const Duration(days: 1)))).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list.where((t) {
        return t.description.toLowerCase().contains(query) ||
            t.category.toLowerCase().contains(query) ||
            t.transactionNumber.toLowerCase().contains(query) ||
            (t.createdByName != null && t.createdByName!.toLowerCase().contains(query));
      }).toList();
    }

    return list;
  }

  double get filteredIncome => filteredTransactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
  double get filteredExpenses => filteredTransactions.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);
}

// ============================================================
// LEDGER PROVIDER
// ============================================================
class LedgerProvider extends StateNotifier<LedgerState> {
  LedgerProvider() : super(LedgerState()) {
    loadLedger();
  }

  Future<void> loadLedger() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await SupabaseService.client
          .from('financial_transactions')
          .select('*, profiles!created_by(full_name)')
          .order('created_at', ascending: false);

      final list = (response as List).map((json) => LedgerTransaction.fromJson(json)).toList();

      double income = 0;
      double expense = 0;
      for (var t in list) {
        if (t.isIncome) income += t.amount;
        else expense += t.amount;
      }
      final balance = list.isNotEmpty ? list.first.balanceAfter : (income - expense);

      state = state.copyWith(
        transactions: list,
        totalIncome: income,
        totalExpenses: expense,
        currentBalance: balance,
        isLoading: false,
      );

      // حفظ بيانات السجل المالي محلياً للاستعراض دون اتصال
      try {
        await LocalCacheService.save('cached_ledger_transactions', response);
      } catch (_) {}
    } catch (e) {
      // استرجاع السجل المالي من الكاش المحلي
      try {
        final cached = await LocalCacheService.get('cached_ledger_transactions');
        if (cached is List && cached.isNotEmpty) {
          final list = cached.map((json) => LedgerTransaction.fromJson(Map<String, dynamic>.from(json))).toList();
          double income = 0;
          double expense = 0;
          for (var t in list) {
            if (t.isIncome) income += t.amount;
            else expense += t.amount;
          }
          final balance = list.isNotEmpty ? list.first.balanceAfter : (income - expense);

          state = state.copyWith(
            transactions: list,
            totalIncome: income,
            totalExpenses: expense,
            currentBalance: balance,
            isLoading: false,
          );
          return;
        }
      } catch (_) {}

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(String filter) => state = state.copyWith(filterType: filter);
  void setSearch(String query) => state = state.copyWith(searchQuery: query);
  void setDateRange(DateTime? from, DateTime? to) => state = state.copyWith(fromDate: from, toDate: to);
  Future<void> refreshLedger() async => await loadLedger();
}

final ledgerProvider = StateNotifierProvider<LedgerProvider, LedgerState>((ref) {
  return LedgerProvider();
});

// ============================================================
// LEDGER & AUDIT CONTROL SCREEN
// ============================================================
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _auditSearchController = TextEditingController();
  final List<String> _filterOptions = ['الكل', 'إيرادات', 'مصروفات'];
  final List<String> _auditCategories = ['الكل', 'الأعضاء', 'المالية', 'المساعدات', 'الأمان والمصادقة'];

  String _selectedAuditCategory = 'الكل';
  bool _isLoadingAuditLogs = true;
  List<AuditLogItem> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ledgerProvider.notifier).loadLedger();
      _loadAuditLogs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _auditSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAuditLogs = true);
    try {
      final response = await SupabaseService.client
          .from('audit_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      final list = (response as List).map((json) => AuditLogItem.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _auditLogs = list;
          _isLoadingAuditLogs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAuditLogs = false);
    }
  }

  List<AuditLogItem> get _filteredAuditLogs {
    return _auditLogs.where((log) {
      final matchesCategory = _selectedAuditCategory == 'الكل' || log.category == _selectedAuditCategory;
      final query = _auditSearchController.text.toLowerCase();
      final matchesSearch = query.isEmpty ||
          log.userName.toLowerCase().contains(query) ||
          log.action.toLowerCase().contains(query) ||
          log.description.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _exportLedgerPDF(LedgerState state) async {
    final transactions = state.filteredTransactions;
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات قيود صادرة للتصدير'), backgroundColor: AppColors.warning),
      );
      return;
    }

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

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(ArabicPdfHelper.reshape('جمعية التكافل والتنمية القروية'), style: pw.TextStyle(font: fontBold, fontSize: 18)),
                    pw.SizedBox(height: 4),
                    pw.Text(ArabicPdfHelper.reshape('كشف الحساب - دفتر القيود المحاسبية العام'), style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text(ArabicPdfHelper.reshape('تاريخ الاستخراج: $dateStr'), style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 10),
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
                      _pdfCell('رقم القيد', isHeader: true, font: fontBold),
                      _pdfCell('البيان والصفة', isHeader: true, font: fontBold),
                      _pdfCell('إيراد (+)', isHeader: true, font: fontBold),
                      _pdfCell('مصروف (-)', isHeader: true, font: fontBold),
                      _pdfCell('التاريخ', isHeader: true, font: fontBold),
                    ],
                  ),
                  ...transactions.map((t) {
                    return pw.TableRow(
                      children: [
                        _pdfCell(t.transactionNumber.isEmpty ? 'قيد' : t.transactionNumber, font: fontRegular),
                        _pdfCell(t.description, font: fontRegular),
                        _pdfCell(t.isIncome ? '${t.amount.toStringAsFixed(2)} ر.ي' : '-', font: fontRegular),
                        _pdfCell(!t.isIncome ? '${t.amount.toStringAsFixed(2)} ر.ي' : '-', font: fontRegular),
                        _pdfCell(DateFormat('yyyy/MM/dd').format(t.createdAt), font: fontRegular),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'كشف_الحساب_المالي.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تصدير التقرير: ${e.toString()}'), backgroundColor: AppColors.error),
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

  @override
  Widget build(BuildContext context) {
    final ledgerState = ref.watch(ledgerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'منظومة الرقابة والدفتر العام',
        subtitle: 'القيود المحاسبية وسجل التدقيق والرقابة الشامل',
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
            onPressed: () => _exportLedgerPDF(ledgerState),
            tooltip: 'تصدير كشف الحساب (PDF)',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              ref.read(ledgerProvider.notifier).refreshLedger();
              _loadAuditLogs();
            },
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation Tabs Bar
          Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'الدفتر المالي'),
                Tab(icon: Icon(Icons.security_rounded, size: 20), text: 'سجل العمليات والتدقيق'),
                Tab(icon: Icon(Icons.analytics_rounded, size: 20), text: 'مركز الرقابة الإدارية'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: FINANCIAL LEDGER
                _buildFinancialLedgerTab(ledgerState, isDark),

                // TAB 2: SYSTEM AUDIT LOGS
                _buildAuditLogsTab(isDark),

                // TAB 3: SUPERVISORY CONTROL PANEL
                _buildSupervisoryDashboardTab(ledgerState, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: FINANCIAL LEDGER VIEW
  // ============================================================
  Widget _buildFinancialLedgerTab(LedgerState ledgerState, bool isDark) {
    final transactions = ledgerState.filteredTransactions;
    final isLoading = ledgerState.isLoading;
    final error = ledgerState.error;

    return Column(
      children: [
        _buildTreasurySummary(ledgerState, isDark),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                textDirection: Directionality.of(context),
                decoration: InputDecoration(
                  hintText: 'ابحث برقم القيد، البيان، أو التصنيف...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(ledgerProvider.notifier).setSearch('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  ref.read(ledgerProvider.notifier).setSearch(v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filterOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final option = _filterOptions[index];
                          final isSelected = ledgerState.filterType == option;
                          return ChoiceChip(
                            label: Text(
                              option,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkBorder : AppColors.border),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(ledgerProvider.notifier).setFilter(option);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _buildTransactionsList(transactions, isLoading, error, isDark),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 2: SYSTEM AUDIT LOGS VIEW
  // ============================================================
  Widget _buildAuditLogsTab(bool isDark) {
    final list = _filteredAuditLogs;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _auditSearchController,
                textDirection: Directionality.of(context),
                decoration: InputDecoration(
                  hintText: 'ابحث عن اسم المستخدم، الإجراء، أو التفاصيل...',
                  prefixIcon: const Icon(Icons.manage_search_rounded, size: 22),
                  suffixIcon: _auditSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _auditSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _auditCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _auditCategories[index];
                    final isSelected = _selectedAuditCategory == cat;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.accent,
                      backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                      onSelected: (val) {
                        if (val) setState(() => _selectedAuditCategory = cat);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingAuditLogs
              ? const LoadingWidget(message: 'جاري تحميل سجل الرقابة والتدقيق الشامل...')
              : list.isEmpty
                  ? const EmptyState(
                      title: 'سجل التدقيق فارغ',
                      subtitle: 'سيتم توثيق كل عملية منفذة من قبل الأعضاء والمدراء في هذا السجل بدقة عالية.',
                      icon: Icons.security_rounded,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAuditLogs,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          return _buildAuditLogCard(item, isDark);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildAuditLogCard(AuditLogItem item, bool isDark) {
    Color categoryColor = AppColors.primary;
    if (item.category == 'الأعضاء') categoryColor = Colors.blue;
    if (item.category == 'المالية') categoryColor = Colors.green;
    if (item.category == 'المساعدات') categoryColor = Colors.orange;
    if (item.category == 'الأمان والمصادقة') categoryColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.fingerprint_rounded, color: categoryColor, size: 22),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.action,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.category,
                style: TextStyle(color: categoryColor, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المفذ: ${item.userName} (${item.userRole})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
                Text(
                  DateFormat('yyyy/MM/dd - HH:mm').format(item.createdAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showAuditDetailsModal(item, isDark),
      ),
    );
  }

  void _showAuditDetailsModal(AuditLogItem item, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.policy_rounded, color: AppColors.accent, size: 24),
                const SizedBox(width: 10),
                Text(
                  'تفاصيل عملية التدقيق الرقابي',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildAuditDetailRow('نوع الإجراء', item.action),
            _buildAuditDetailRow('فئة الرقابة', item.category),
            _buildAuditDetailRow('منفذ العملية', '${item.userName} (${item.userRole})'),
            _buildAuditDetailRow('وصف الإجراء', item.description),
            _buildAuditDetailRow('تاريخ التنفيذ', DateFormat('yyyy/MM/dd - HH:mm:ss').format(item.createdAt)),
            if (item.targetId != null) _buildAuditDetailRow('رقم المرجع / Target', item.targetId!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق التفاصيل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: SUPERVISORY CONTROL PANEL VIEW
  // ============================================================
  Widget _buildSupervisoryDashboardTab(LedgerState ledgerState, bool isDark) {
    final auditCount = _auditLogs.length;
    final financialLogsCount = _auditLogs.where((l) => l.category == 'المالية').length;
    final securityLogsCount = _auditLogs.where((l) => l.category == 'الأمان والمصادقة' || l.category == 'الأعضاء').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'مركز الرقابة الفورية والتحليل الرقابي للمدير',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'مؤشرات الأمان والعمليات المنفذة في المنظومة كاملة',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'إجمالي السجلات الرقابية',
                  value: '$auditCount',
                  icon: Icons.history_toggle_off_rounded,
                  color: AppColors.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'العمليات المالية الحساسة',
                  value: '$financialLogsCount',
                  icon: Icons.monetization_on_outlined,
                  color: AppColors.accent,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'إجراءات الحسابات والأمان',
                  value: '$securityLogsCount',
                  icon: Icons.shield_outlined,
                  color: AppColors.gold,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'رصيد الخزينة الإجمالي',
                  value: '${ledgerState.currentBalance.toStringAsFixed(0)} ر.ي',
                  icon: Icons.account_balance_rounded,
                  color: AppColors.success,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Supervisory Quick Tools
          Text(
            'مهام الإشراف والرقابة السريعة',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildSupervisoryToolTile(
            icon: Icons.history_edu_rounded,
            title: 'فتح سجل التدقيق والمراقبة المتقدم (Visual Diff)',
            subtitle: 'استعراض كافة العمليات مع الفلاتر المتقدمة ومعاينة الفروقات (Old vs New)',
            color: AppColors.accent,
            onTap: () => context.go('/audit-logs'),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildSupervisoryToolTile(
            icon: Icons.verified_user_rounded,
            title: 'تصفية وتقويم الحسابات غير المؤكدة',
            subtitle: 'الانتقال إلى سجل الأعضاء لتأكيد أو تجميد العضويات المعلقة',
            color: AppColors.primary,
            onTap: () => context.go('/members'),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildSupervisoryToolTile(
            icon: Icons.picture_as_pdf_rounded,
            title: 'استخراج تقرير الرقابة والتدقيق العام (PDF)',
            subtitle: 'توليد ملف كامل يحتوي على تاريخ القيود المالية وسجلات الأمان',
            color: AppColors.accent,
            onTap: () => _exportLedgerPDF(ledgerState),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildSupervisoryToolTile(
            icon: Icons.refresh_rounded,
            title: 'إعادة تحديث وفحص سجل الرقابة الحية',
            subtitle: 'جلب أحدث العمليات المنفذة من قِبل أي مستخدم فوراً',
            color: AppColors.success,
            onTap: _loadAuditLogs,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisoryToolTile({
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildTreasurySummary(LedgerState state, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الرصيد الفعلي للخزينة',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${NumberFormat('#,##0.00', 'ar').format(state.currentBalance)} ر.ي',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withOpacity(0.6)),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 26),
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
                Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'إيرادات: ${NumberFormat('#,##0.00', 'ar').format(state.filteredIncome)} ر.ي',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Container(width: 1, height: 20, color: Colors.white24),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, color: Color(0xFFFF7B7B), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'مصروفات: ${NumberFormat('#,##0.00', 'ar').format(state.filteredExpenses)} ر.ي',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
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

  Widget _buildTransactionsList(List<LedgerTransaction> list, bool isLoading, String? error, bool isDark) {
    if (isLoading && list.isEmpty) {
      return const LoadingWidget(message: 'جاري مراجعة دفتر القيود المحاسبية...');
    }

    if (error != null && list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('تعذر تحميل دفتر القيود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(ledgerProvider.notifier).refreshLedger(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return EmptyState(
        title: 'لا توجد قيود محاسبية',
        subtitle: _searchController.text.isNotEmpty
            ? 'لم يتم العثور على أي قيد مطابق للبحث'
            : 'سجل الحركات المالية المزدوج فارغ حالياً.',
        icon: Icons.menu_book_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(ledgerProvider.notifier).refreshLedger(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildTransactionCard(list[index], isDark),
      ),
    );
  }

  Widget _buildTransactionCard(LedgerTransaction t, bool isDark) {
    final isIncome = t.isIncome;
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isIncome ? AppColors.successLight : AppColors.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: amountColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.transactionNumber.isEmpty ? 'قيد مالي معتمد' : t.transactionNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy/MM/dd - HH:mm').format(t.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$sign${t.amount.toStringAsFixed(2)} ر.ي',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              t.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            if (t.createdByName != null && t.createdByName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'المسؤول: ${t.createdByName}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}