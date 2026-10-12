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
// PAYMENT MODEL
// ============================================================
class Payment {
  final String id;
  final String memberId;
  final String memberName;
  final double amount;
  final int paymentMonth;
  final int paymentYear;
  final DateTime paymentDate;
  final String paymentMethod;
  final String receiptNumber;
  final String? walletType;
  final String? walletTransactionId;
  final String? notes;

  Payment({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.paymentMonth,
    required this.paymentYear,
    required this.paymentDate,
    required this.paymentMethod,
    required this.receiptNumber,
    this.walletType,
    this.walletTransactionId,
    this.notes,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      memberName: json['profiles']?['full_name'] ?? json['full_name'] ?? 'عضو غير محدد',
      receiptNumber: json['receipt_number']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMonth: json['payment_month'] ?? 1,
      paymentYear: json['payment_year'] ?? 2026,
      paymentMethod: json['payment_method']?.toString() ?? 'نقدي',
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'].toString())
          : DateTime.now(),
      walletType: json['wallet_type']?.toString(),
      walletTransactionId: json['wallet_transaction_id']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  String get monthName {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    if (paymentMonth >= 1 && paymentMonth <= 12) {
      return months[paymentMonth - 1];
    }
    return 'شهر $paymentMonth';
  }

  String get methodLabel {
    const methods = {
      'cash': 'نقدي',
      'bank_transfer': 'تحويل بنكي',
      'online': 'محفظة إلكترونية',
      'check': 'صك بريدي / بنكي',
    };
    return methods[paymentMethod] ?? paymentMethod;
  }
}

// ============================================================
// PAYMENTS STATE
// ============================================================
class PaymentsState {
  final List<Payment> payments;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String selectedFilter;
  final String selectedWalletFilter;

  PaymentsState({
    this.payments = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedFilter = 'الكل',
    this.selectedWalletFilter = 'الكل',
  });

  PaymentsState copyWith({
    List<Payment>? payments,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedFilter,
    String? selectedWalletFilter,
  }) {
    return PaymentsState(
      payments: payments ?? this.payments,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedWalletFilter: selectedWalletFilter ?? this.selectedWalletFilter,
    );
  }

  List<Payment> get filteredPayments {
    var filtered = payments;

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((payment) {
        return payment.memberName.toLowerCase().contains(query) ||
            payment.receiptNumber.toLowerCase().contains(query);
      }).toList();
    }

    if (selectedFilter != 'الكل') {
      filtered = filtered.where((payment) {
        return payment.methodLabel == selectedFilter || payment.paymentMethod == selectedFilter;
      }).toList();
    }

    if (selectedWalletFilter != 'الكل') {
      if (selectedWalletFilter == 'بدون محفظة') {
        filtered = filtered.where((payment) {
          return payment.walletType == null || payment.walletType!.isEmpty;
        }).toList();
      } else {
        filtered = filtered.where((payment) {
          return payment.walletType == selectedWalletFilter;
        }).toList();
      }
    }

    return filtered;
  }

  List<String> get availableWallets {
    final wallets = <String>{};
    wallets.add('الكل');
    for (var payment in payments) {
      if (payment.walletType != null && payment.walletType!.isNotEmpty) {
        wallets.add(payment.walletType!);
      }
    }
    return wallets.toList();
  }

  double get totalAmount => filteredPayments.fold(0.0, (sum, p) => sum + p.amount);
}

// ============================================================
// PAYMENTS PROVIDER
// ============================================================
class PaymentsProvider extends StateNotifier<PaymentsState> {
  PaymentsProvider() : super(PaymentsState()) {
    loadPayments();
  }

  Future<void> loadPayments() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await SupabaseService.client
          .from('payments')
          .select('*, profiles!member_id(full_name)')
          .order('payment_date', ascending: false);

      final payments = (response as List).map((json) {
        return Payment.fromJson(json);
      }).toList();

      state = state.copyWith(
        payments: payments,
        isLoading: false,
      );

      // حفظ سجل السندات والمدفوعات محلياً
      try {
        await LocalCacheService.save('cached_payments_all', response);
      } catch (_) {}
    } catch (e) {
      // استرجاع السندات من الكاش المحلي عند انقطاع الاتصال
      try {
        final cached = await LocalCacheService.get('cached_payments_all');
        if (cached is List && cached.isNotEmpty) {
          final payments = cached.map((json) => Payment.fromJson(Map<String, dynamic>.from(json))).toList();
          state = state.copyWith(
            payments: payments,
            isLoading: false,
          );
          return;
        }
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void searchPayments(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setWalletFilter(String filter) {
    state = state.copyWith(selectedWalletFilter: filter);
  }

  Future<void> refreshPayments() async {
    await loadPayments();
  }
}

final paymentsProvider =
    StateNotifierProvider<PaymentsProvider, PaymentsState>((ref) {
  return PaymentsProvider();
});

// ============================================================
// PAYMENTS SCREEN
// ============================================================
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = ['الكل', 'نقدي', 'تحويل بنكي', 'محفظة إلكترونية'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentsProvider.notifier).loadPayments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentsState = ref.watch(paymentsProvider);
    final payments = paymentsState.filteredPayments;
    final isLoading = paymentsState.isLoading;
    final error = paymentsState.error;
    final totalAmount = paymentsState.totalAmount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'تحصيل الاشتراكات والمدفوعات',
        subtitle: '${payments.length} سند مسجل',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(paymentsProvider.notifier).refreshPayments(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Metric Card
          _buildSummaryBanner(totalAmount, payments.length, isDark),

          // Search and Filters
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
                  textDirection:  Directionality.of(context),
                  decoration: InputDecoration(
                    hintText: 'بحث برقم السند أو اسم العضو...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(paymentsProvider.notifier).searchPayments('');
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    ref.read(paymentsProvider.notifier).searchPayments(value);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = paymentsState.selectedFilter == filter;
                      return ChoiceChip(
                        label: Text(
                          filter,
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
                            ref.read(paymentsProvider.notifier).setFilter(filter);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Payment List
          Expanded(
            child: _buildPaymentsList(payments, isLoading, error, isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/add-payment'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        label: const Text('تسجيل تحصيل', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSummaryBanner(double total, int count, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                'إجمالي المتحصلات',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat('#,##0.00', 'ar').format(total)} ر.ي',
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
                'عدد السندات',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '$count سند',
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

  Widget _buildPaymentsList(List<Payment> payments, bool isLoading, String? error, bool isDark) {
    if (isLoading && payments.isEmpty) {
      return const LoadingWidget(message: 'جاري تحميل سندات التحصيل...');
    }

    if (error != null && payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 50, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('تعذر تحميل بيانات المدفوعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(paymentsProvider.notifier).refreshPayments(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (payments.isEmpty) {
      return EmptyState(
        title: 'لا توجد دفعات مسجلة',
        subtitle: _searchController.text.isNotEmpty
            ? 'لم يتم العثور على أي سند مطابق للبحث'
            : 'لم يتم تسجيل أي سند تحصيل اشتراك في المنظومة بعد.',
        icon: Icons.receipt_long_rounded,
        buttonText: _searchController.text.isNotEmpty ? 'مسح البحث' : 'تسجيل دفعة جديدة',
        onButtonPressed: _searchController.text.isNotEmpty
            ? () {
                _searchController.clear();
                ref.read(paymentsProvider.notifier).searchPayments('');
                setState(() {});
              }
            : () => context.go('/add-payment'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(paymentsProvider.notifier).refreshPayments(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        itemBuilder: (context, index) => _buildPaymentCard(payments[index], isDark),
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        onTap: () => context.go('/receipt/${payment.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      payment.memberName,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_rounded, color: AppColors.success, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'مسدد',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildTag(
                    icon: Icons.tag_rounded,
                    label: payment.receiptNumber.isEmpty ? 'سند معتمد' : payment.receiptNumber,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  _buildTag(
                    icon: Icons.calendar_month_rounded,
                    label: '${payment.monthName} ${payment.paymentYear}',
                    color: AppColors.accentDark,
                    isDark: isDark,
                  ),
                  _buildTag(
                    icon: Icons.payments_outlined,
                    label: payment.methodLabel,
                    color: AppColors.gold,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Amount & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('yyyy/MM/dd - HH:mm').format(payment.paymentDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    '${payment.amount.toStringAsFixed(2)} ر.ي',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}