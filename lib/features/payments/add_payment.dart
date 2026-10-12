import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/network/network_connectivity_service.dart';

class AddPaymentScreen extends ConsumerStatefulWidget {
  final String? memberId;

  const AddPaymentScreen({Key? key, this.memberId}) : super(key: key);

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _transactionIdController = TextEditingController();
  
  String? _selectedMemberId;
  String? _selectedMemberName;
  String? _selectedMethod = 'نقدي';
  String? _selectedWallet;
  String? _selectedPaymentMonth;
  String? _selectedPaymentYear;
  
  bool _isLoading = false;
  bool _isLoadingMembers = true;
  bool _isLoadingMissingMonths = false;
  bool _isLoadingWallets = true;
  
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _missingMonths = [];

  int _monthsCovered = 1;
  final double _monthlySubscription = 1000.0;

  final List<String> _paymentMethods = ['نقدي', 'تحويل بنكي', 'محفظة إلكترونية', 'عملات رقمية'];  
  final List<String> _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  bool get _needsWallet => _selectedMethod == 'محفظة إلكترونية' || _selectedMethod == 'عملات رقمية' || _selectedMethod == 'تحويل بنكي';
  bool get _needsTransactionId => _selectedWallet != null && _selectedWallet!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.memberId;
    _amountController.text = '1000';
    _amountController.addListener(_calculateMonths);
    _loadMembers();
    _loadWallets();
    
    final now = DateTime.now();
    _selectedPaymentMonth = now.month.toString();
    _selectedPaymentYear = now.year.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  void _calculateMonths() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _monthsCovered = (amount / _monthlySubscription).floor();
    });
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, phone, role, monthly_subscription')
          .order('full_name');

      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(response);
          _isLoadingMembers = false;

          if (widget.memberId != null) {
            final existing = _members.firstWhere(
              (m) => m['id'] == widget.memberId,
              orElse: () => {},
            );
            if (existing.isNotEmpty) {
              _selectedMemberId = widget.memberId;
              _selectedMemberName = existing['full_name'] ?? '';
              _loadMissingMonths();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _loadWallets() async {
    setState(() => _isLoadingWallets = true);

    try {
      final response = await SupabaseService.client
          .from('wallets')
          .select('*')
          .eq('is_active', true);

      if (mounted) {
        setState(() {
          _wallets = List<Map<String, dynamic>>.from(response);
          _isLoadingWallets = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWallets = false);
    }
  }

  Future<void> _loadMissingMonths() async {
    if (_selectedMemberId == null) return;
    
    setState(() => _isLoadingMissingMonths = true);

    try {
      // 1. Get Association Start Date (from SharedPreferences first, then Supabase association_settings)
      String startDateStr = '2026-05-01';
      try {
        final prefs = await SharedPreferences.getInstance();
        final localDate = prefs.getString('setting_start_date');
        if (localDate != null && localDate.isNotEmpty) {
          startDateStr = localDate;
        }
      } catch (_) {}

      try {
        final settingsRes = await SupabaseService.client
            .from('association_settings')
            .select('association_start_date')
            .limit(1)
            .maybeSingle();

        if (settingsRes != null && settingsRes['association_start_date'] != null) {
          startDateStr = settingsRes['association_start_date'].toString().split('T').first;
        }
      } catch (_) {}

      final startDate = DateTime.tryParse(startDateStr) ?? DateTime(2026, 5, 1);
      final startYear = startDate.year;
      final startMonth = startDate.month;

      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      // 2. Fetch all paid months for this member from payments table
      final paidResponse = await SupabaseService.client
          .from('payments')
          .select('payment_month, payment_year')
          .eq('member_id', _selectedMemberId!);

      final paidSet = <String>{};
      for (final row in paidResponse) {
        final m = row['payment_month'];
        final y = row['payment_year'];
        if (m != null && y != null) {
          paidSet.add('$y-$m');
        }
      }

      // Also check monthly_coverage if any
      try {
        final coverageRes = await SupabaseService.client
            .from('monthly_coverage')
            .select('month, year')
            .eq('member_id', _selectedMemberId!)
            .eq('is_paid', true);
        for (final row in coverageRes) {
          final m = row['month'];
          final y = row['year'];
          if (m != null && y != null) {
            paidSet.add('$y-$m');
          }
        }
      } catch (_) {}

      // 3. Generate chronological series from start date to current month
      final missing = <Map<String, dynamic>>[];
      var curY = startYear;
      var curM = startMonth;

      while (curY < currentYear || (curY == currentYear && curM <= currentMonth)) {
        final key = '$curY-$curM';
        if (!paidSet.contains(key)) {
          missing.add({
            'missing_month': curM,
            'missing_year': curY,
          });
        }
        curM++;
        if (curM > 12) {
          curM = 1;
          curY++;
        }
      }

      if (mounted) {
        setState(() {
          _missingMonths = missing;
          _isLoadingMissingMonths = false;
          
          if (_missingMonths.isNotEmpty) {
            final first = _missingMonths.first;
            _selectedPaymentMonth = first['missing_month']?.toString() ?? currentMonth.toString();
            _selectedPaymentYear = first['missing_year']?.toString() ?? currentYear.toString();
          } else {
            _selectedPaymentMonth = currentMonth.toString();
            _selectedPaymentYear = currentYear.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMissingMonths = false);
    }
  }

  Future<void> _submitPayment() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isOnline = await NetworkConnectivityService().checkIsOnline();
      if (!isOnline) {
        if (mounted) {
          AppFeedback.showOfflineOperationError(
            context,
            onRetry: () => _submitPayment(),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final userId = SupabaseService.currentUser?.id;
      if (userId == null) throw Exception('الرجاء تسجيل الدخول أولاً');
      if (_selectedMemberId == null) throw Exception('الرجاء اختيار العضو');

      final amount = double.parse(_amountController.text.trim());
      final paymentMonth = int.parse(_selectedPaymentMonth ?? DateTime.now().month.toString());
      final paymentYear = int.parse(_selectedPaymentYear ?? DateTime.now().year.toString());

      // 1. Check duplicate payment in database before submitting
      final existingPayment = await SupabaseService.client
          .from('payments')
          .select('id, receipt_number')
          .eq('member_id', _selectedMemberId!)
          .eq('payment_month', paymentMonth)
          .eq('payment_year', paymentYear)
          .maybeSingle();

      if (existingPayment != null) {
        throw Exception('هذا الشهر مدفوع مسبقاً! تم سداد اشتراك شهر ($paymentMonth/$paymentYear) لهذا العضو من قبل.');
      }

      final response = await SupabaseService.client.rpc(
        'register_payment',
        params: {
          'p_member_id': _selectedMemberId,
          'p_amount': amount,
          'p_payment_method': _selectedMethod ?? 'نقدي',
          'p_wallet_type': _selectedWallet ?? '',
          'p_wallet_transaction_id': _transactionIdController.text.trim(),
          'p_notes': _notesController.text.trim(),
          'p_payment_month': paymentMonth,
          'p_payment_year': paymentYear,
        },
      );

      String? paymentId;
      if (response != null) {
        if (response is Map) {
          if (response['success'] == false) {
            throw Exception(response['error'] ?? 'تعذر تسجيل الدفعة في قاعدة البيانات');
          }
          paymentId = response['payment_id']?.toString() ?? response['id']?.toString();
        } else if (response is String) {
          paymentId = response;
        }
      }

      if (_selectedMemberId != null && _selectedMemberId!.isNotEmpty) {
        NotificationService.sendNotification(
          userId: _selectedMemberId!,
          title: 'إيداع مالي جديد 💳',
          body: 'تم تسجيل سند تحصيل جديد بمبلغ ${amount.toStringAsFixed(2)} ر.ي لحسابك.',
          type: 'payment',
          targetRoute: '/payments',
        );
      }

      NotificationService.notifyAdmins(
        title: 'سند تحصيل مالي 💳',
        body: 'تم تحصيل مبلغ ${amount.toStringAsFixed(2)} ر.ي من العضو ${_selectedMemberName ?? ""}',
        type: 'payment_admin',
        targetRoute: '/payments',
      );

      AuditService.logEvent(
        action: 'CREATE_PAYMENT',
        module: 'المالية',
        entity: 'payments',
        entityId: paymentId,
        newValues: {
          'member_id': _selectedMemberId,
          'amount': amount,
          'payment_month': paymentMonth,
          'payment_year': paymentYear,
          'payment_method': _selectedMethod ?? 'نقدي',
          'wallet_type': _selectedWallet ?? '',
          'notes': _notesController.text.trim(),
        },
        errorMessage: 'تحصيل مبلغ ${amount.toStringAsFixed(2)} ر.ي من العضو ${_selectedMemberName ?? ""}',
      );

      if (mounted) {
        AppFeedback.showSuccess(context, 'تم تسجيل سند التحصيل بنجاح واستخراج الفاتورة');
        if (paymentId != null && paymentId.isNotEmpty) {
          context.go('/receipt/$paymentId');
        } else {
          context.go('/payments');
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
          context,
          AppErrorHandler.handleGeneralError(e),
          onRetry: () => _submitPayment(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'تسجيل سند تحصيل اشتراك',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/payments');
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Member Selection
              _buildSectionCard(
                title: 'تحديد العضو المستفيد',
                icon: Icons.person_search_rounded,
                isDark: isDark,
                children: [
                  _buildMemberDropdown(isDark),
                  if (_selectedMemberId != null) ...[
                    const SizedBox(height: 12),
                    _buildMissingMonthsBanner(isDark),
                  ],
                ],
              ),
              const SizedBox(height: 18),

              // 2. Payment Period & Amount
              _buildSectionCard(
                title: 'تفاصيل الفترة والمبلغ',
                icon: Icons.date_range_rounded,
                isDark: isDark,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedPaymentMonth,
                          decoration: const InputDecoration(
                            labelText: 'الشهر المستحق',
                            prefixIcon: Icon(Icons.calendar_month_outlined, size: 20),
                          ),
                          items: _months.asMap().entries.map((entry) {
                            return DropdownMenuItem(
                              value: (entry.key + 1).toString(),
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedPaymentMonth = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedPaymentYear,
                          decoration: const InputDecoration(labelText: 'السنة'),
                          items: List.generate(5, (index) {
                            final year = (DateTime.now().year - 2 + index).toString();
                            return DropdownMenuItem(value: year, child: Text(year));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedPaymentYear = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الإجمالي المحصل (ر.ي)',
                      prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
                      suffixText: 'ر.ي',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'يرجى إدخال المبلغ';
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) return 'أدخل مبلغاً صالحاً';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'عدد الأشهر المشمولة بالدفعة:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_monthsCovered شهر',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Payment Method & Wallet
              _buildSectionCard(
                title: 'وسيلة الدفع والقناة المالية',
                icon: Icons.account_balance_wallet_outlined,
                isDark: isDark,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'طريقة التحصيل',
                      prefixIcon: Icon(Icons.payments_outlined, size: 20),
                    ),
                    items: _paymentMethods.map((method) {
                      return DropdownMenuItem(value: method, child: Text(method));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMethod = value;
                        if (!_needsWallet) _selectedWallet = null;
                      });
                    },
                  ),
                  if (_needsWallet) ...[
                    const SizedBox(height: 14),
                    _buildWalletDropdown(isDark),
                  ],
                  if (_needsWallet && _needsTransactionId) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _transactionIdController,
                      decoration: const InputDecoration(
                        labelText: 'رقم العملية / الحوالة في المحفظة',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      ),
                      validator: (value) {
                        if (_needsWallet && (value == null || value.trim().isEmpty)) {
                          return 'يرجى إدخال رقم العملية';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات إضافية على السند (اختياري)',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Action
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitPayment,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isLoading ? 'جاري تسجيل السند...' : 'تأكيد وحفظ سند التحصيل',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
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
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMemberDropdown(bool isDark) {
    if (_isLoadingMembers) {
      return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
    }

    return DropdownButtonFormField<String>(
      value: _selectedMemberId,
      hint: const Text('ابحث واختر العضو'),
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'اسم العضو',
        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
      ),
      items: _members.map((member) {
        final name = member['full_name']?.toString() ?? 'غير معروف';
        final phone = member['phone']?.toString() ?? '';
        return DropdownMenuItem<String>(
          value: member['id']?.toString(),
          child: Text(
            '$name ${phone.isNotEmpty ? "($phone)" : ""}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedMemberId = value;
          final member = _members.firstWhere(
            (m) => m['id']?.toString() == value,
            orElse: () => {},
          );
          _selectedMemberName = member['full_name']?.toString() ?? '';
        });
        _loadMissingMonths();
      },
      validator: (value) => (value == null || value.isEmpty) ? 'الرجاء اختيار العضو' : null,
    );
  }

  Widget _buildMissingMonthsBanner(bool isDark) {
    if (_isLoadingMissingMonths) {
      return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
    }

    if (_missingMonths.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success, width: 1.5),
        ),
        child: Row(
          children: const [
            Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '🟢 مسدد لجميع الشهور (العضو مستوفٍ لكافة الاشتراكات حتى التاريخ الحالي)',
                style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
              SizedBox(width: 8),
              Text(
                'الأشهر المسجلة كمتأخرات في السجل (اضغط لتحديد الشهر):',
                style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _missingMonths.map((m) {
              final monthIdx = (m['missing_month'] ?? 1) as int;
              final year = (m['missing_year'] ?? 2026) as int;
              final isSelected = _selectedPaymentMonth == monthIdx.toString() &&
                  _selectedPaymentYear == year.toString();

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedPaymentMonth = monthIdx.toString();
                    _selectedPaymentYear = year.toString();
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.warning : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.warning : AppColors.warning.withOpacity(0.4),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.warning.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    '${_months[monthIdx - 1]} $year',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletDropdown(bool isDark) {
    if (_isLoadingWallets) {
      return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
    }

    return DropdownButtonFormField<String>(
      value: _selectedWallet,
      hint: const Text('اختر المحفظة المستقبلة'),
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'المحفظة / الحساب البنكي',
        prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
      ),
      items: _wallets.map((wallet) {
        final name = wallet['name']?.toString() ?? 'غير معروف';
        return DropdownMenuItem(value: name, child: Text(name));
      }).toList(),
      onChanged: (value) => setState(() => _selectedWallet = value),
      validator: (value) {
        if (_needsWallet && (value == null || value.isEmpty)) {
          return 'الرجاء تحديد المحفظة المستقبلة';
        }
        return null;
      },
    );
  }
}