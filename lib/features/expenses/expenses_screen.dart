import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/supabase_service.dart';

// ============================================================
// EXPENSE MODEL
// ============================================================
class Expense {
  final String id;
  final String title;
  final String? description;
  final String category;
  final double amount;
  final String beneficiary;
  final String? receiptImage;
  final DateTime expenseDate;
  final String? createdBy;
  final String? createdByName;

  Expense({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.amount,
    required this.beneficiary,
    this.receiptImage,
    required this.expenseDate,
    this.createdBy,
    this.createdByName,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? 'other',
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      beneficiary: json['beneficiary']?.toString() ?? 'غير محدد',
      receiptImage: json['receipt_image']?.toString(),
      expenseDate: json['expense_date'] != null
          ? DateTime.parse(json['expense_date'].toString())
          : DateTime.now(),
      createdBy: json['created_by']?.toString(),
      createdByName: json['profiles']?['full_name']?.toString(),
    );
  }

  String get categoryLabel {
    const categories = {
      'aid': 'مساعدات وإعانات',
      'maintenance': 'صيانة وترميم',
      'electricity': 'كهرباء وإنارة',
      'water': 'مياه وتزويد',
      'projects': 'مشاريع تنموية',
      'salaries': 'مكافآت وأجور',
      'other': 'مصاريف أخرى',
    };
    return categories[category] ?? category;
  }

  Color get categoryColor {
    const colors = {
      'aid': Color(0xFF059669),
      'maintenance': Color(0xFFD97706),
      'electricity': Color(0xFF2563EB),
      'water': Color(0xFF0891B2),
      'projects': Color(0xFF7C3AED),
      'salaries': Color(0xFFEA580C),
      'other': Color(0xFF64748B),
    };
    return colors[category] ?? const Color(0xFF64748B);
  }

  IconData get categoryIcon {
    const icons = {
      'aid': Icons.volunteer_activism_rounded,
      'maintenance': Icons.build_circle_outlined,
      'electricity': Icons.bolt_rounded,
      'water': Icons.water_drop_rounded,
      'projects': Icons.construction_rounded,
      'salaries': Icons.payments_outlined,
      'other': Icons.category_rounded,
    };
    return icons[category] ?? Icons.category_rounded;
  }
}

// ============================================================
// EXPENSES STATE
// ============================================================
class ExpensesState {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;
  final String selectedCategory;
  final String searchQuery;
  final DateTime? fromDate;
  final DateTime? toDate;

  ExpensesState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory = 'الكل',
    this.searchQuery = '',
    this.fromDate,
    this.toDate,
  });

  ExpensesState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  List<Expense> get filteredExpenses {
    var filtered = expenses;

    if (selectedCategory != 'الكل') {
      filtered = filtered.where((e) => e.categoryLabel == selectedCategory || e.category == selectedCategory).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        return e.title.toLowerCase().contains(query) ||
            e.beneficiary.toLowerCase().contains(query) ||
            e.description?.toLowerCase().contains(query) == true;
      }).toList();
    }

    if (fromDate != null) {
      filtered = filtered.where((e) => e.expenseDate.isAfter(fromDate!)).toList();
    }
    if (toDate != null) {
      filtered = filtered.where((e) => e.expenseDate.isBefore(toDate!.add(const Duration(days: 1)))).toList();
    }

    return filtered;
  }

  double get totalAmount => filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
}

// ============================================================
// EXPENSES PROVIDER
// ============================================================
class ExpensesProvider extends StateNotifier<ExpensesState> {
  ExpensesProvider() : super(ExpensesState()) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await SupabaseService.client
          .from('expenses')
          .select('*, profiles!created_by(full_name)')
          .order('expense_date', ascending: false);

      final expenses = (response as List).map((json) => Expense.fromJson(json)).toList();

      state = state.copyWith(
        expenses: expenses,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(fromDate: from, toDate: to);
  }

  Future<void> deleteExpense(String id) async {
    try {
      await SupabaseService.client
          .from('expenses')
          .delete()
          .eq('id', id);

      final remaining = state.expenses.where((e) => e.id != id).toList();
      state = state.copyWith(expenses: remaining);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> refreshExpenses() async {
    await loadExpenses();
  }
}

final expensesProvider = StateNotifierProvider<ExpensesProvider, ExpensesState>((ref) {
  return ExpensesProvider();
});

// ============================================================
// EXPENSES SCREEN
// ============================================================
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'الكل',
    'مساعدات وإعانات',
    'صيانة وترميم',
    'كهرباء وإنارة',
    'مياه وتزويد',
    'مشاريع تنموية',
    'مكافآت وأجور',
    'مصاريف أخرى'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expensesProvider.notifier).loadExpenses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesProvider);
    final expenses = expensesState.filteredExpenses;
    final isLoading = expensesState.isLoading;
    final error = expensesState.error;
    final totalAmount = expensesState.totalAmount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'سجل المصروفات والفواتير',
        subtitle: '${expenses.length} عملية صرف مسجلة',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(expensesProvider.notifier).refreshExpenses(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Card Banner
          _buildSummaryBanner(totalAmount, expenses.length, isDark),

          // Search and Category Chips
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
                    hintText: 'ابحث بعنوان المصروف أو المستفيد...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(expensesProvider.notifier).setSearch('');
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    ref.read(expensesProvider.notifier).setSearch(value);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = expensesState.selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(
                          cat,
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
                            ref.read(expensesProvider.notifier).setCategory(cat);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Expenses List
          Expanded(
            child: _buildExpensesList(expenses, isLoading, error, isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/add-expense'),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: const Text('تسجيل مصروف', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSummaryBanner(double total, int count, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF8B1E1E), Color(0xFF5A0E0E)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                'إجمالي المصروفات المنفذة',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat('#,##0.00', 'ar').format(total)} د.ج',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          Column(
            children: [
              Text(
                'عدد العمليات',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '$count عملية',
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(List<Expense> expenses, bool isLoading, String? error, bool isDark) {
    if (isLoading && expenses.isEmpty) {
      return const LoadingWidget(message: 'جاري تحميل سجل المصروفات...');
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 50, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('تعذر تحميل بيانات المصروفات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(expensesProvider.notifier).refreshExpenses(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (expenses.isEmpty) {
      return EmptyState(
        title: 'لا توجد مصروفات مسجلة',
        subtitle: _searchController.text.isNotEmpty
            ? 'لم يتم العثور على أي مصروف مطابق للبحث'
            : 'لم يتم تسجيل أي عملية صرف في هذه الفئة بعد.',
        icon: Icons.receipt_long_outlined,
        buttonText: _searchController.text.isNotEmpty ? 'مسح البحث' : 'تسجيل مصروف جديد',
        onButtonPressed: _searchController.text.isNotEmpty
            ? () {
                _searchController.clear();
                ref.read(expensesProvider.notifier).setSearch('');
                setState(() {});
              }
            : () => context.go('/add-expense'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(expensesProvider.notifier).refreshExpenses(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: expenses.length,
        itemBuilder: (context, index) => _buildExpenseCard(expenses[index], isDark),
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense, bool isDark) {
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: expense.categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(expense.categoryIcon, color: expense.categoryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المستفيد: ${expense.beneficiary}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${expense.amount.toStringAsFixed(2)} د.ج',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            if (expense.description != null && expense.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                expense.description!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: expense.categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    expense.categoryLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: expense.categoryColor,
                    ),
                  ),
                ),
                Text(
                  DateFormat('yyyy/MM/dd').format(expense.expenseDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}