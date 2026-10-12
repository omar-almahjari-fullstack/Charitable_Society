import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/network/network_connectivity_service.dart';
import '../../core/services/audit_service.dart';
import 'wallet_model.dart';
import 'wallets_provider.dart';

class AddWalletScreen extends ConsumerStatefulWidget {
  final Wallet? wallet;

  const AddWalletScreen({Key? key, this.wallet}) : super(key: key);

  @override
  ConsumerState<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends ConsumerState<AddWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  String _selectedType = 'bank';
  bool _isActive = true;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _types = [
    {'value': 'bank', 'label': 'حساب بنكي / بريدي (CCP / RIB)', 'desc': 'الحساب الجاري الرئيسي لاستقبال اشتراكات الأعضاء', 'icon': Icons.account_balance_rounded},
    {'value': 'mobile', 'label': 'تطبيق جوال / دفع إلكتروني (BaridiMob)', 'label2': 'تطبيقات الدفع السريع والبطاقات البريدية', 'icon': Icons.phone_android_rounded},
    {'value': 'crypto', 'label': 'محفظة رقمية مخصصة', 'desc': 'محفظة الدفع الإلكتروني السريع', 'icon': Icons.currency_bitcoin_rounded},
    {'value': 'exchange', 'label': 'منصة حوالات مالية', 'desc': 'حساب التحويلات المالية والحوالات البريدية', 'icon': Icons.currency_exchange_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.wallet != null) {
      _nameController.text = widget.wallet!.name;
      _accountNumberController.text = widget.wallet!.accountNumber ?? '';
      _selectedType = widget.wallet!.type;
      _isActive = widget.wallet!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveWallet() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isOnline = await NetworkConnectivityService().checkIsOnline();
      if (!isOnline) {
        if (mounted) {
          AppFeedback.showOfflineOperationError(
            context,
            onRetry: () => _saveWallet(),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final wallet = Wallet(
        id: widget.wallet?.id ?? '',
        name: _nameController.text.trim(),
        type: _selectedType,
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        isActive: _isActive,
        createdAt: widget.wallet?.createdAt ?? DateTime.now(),
      );

      if (widget.wallet == null) {
        await ref.read(walletsProvider.notifier).addWallet(wallet);
        AuditService.logEvent(
          action: 'CREATE_WALLET',
          module: 'المحافظ',
          entity: 'wallets',
          entityId: wallet.id,
          newValues: wallet.toJson(),
          errorMessage: 'إضافة محفظة أو حساب بنكي جديد (${wallet.name})',
        );
      } else {
        await ref.read(walletsProvider.notifier).updateWallet(wallet);
        AuditService.logEvent(
          action: 'UPDATE_WALLET',
          module: 'المحافظ',
          entity: 'wallets',
          entityId: wallet.id,
          oldValues: widget.wallet!.toJson(),
          newValues: wallet.toJson(),
          errorMessage: 'تعديل بيانات المحفظة (${wallet.name})',
        );
      }

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          widget.wallet == null
              ? 'تم تسجيل وإضافة المحفظة بنجاح'
              : 'تم حفظ تعديلات المحفظة بنجاح',
        );
        context.go('/wallets');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
          context,
          AppErrorHandler.handleGeneralError(e),
          onRetry: () => _saveWallet(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.wallet != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: isEditing ? 'تعديل بيانات الحساب' : 'إضافة حساب / محفظة جديدة',
        subtitle: 'تحديد قنوات تحصيل الميزانية والاشتراكات',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/wallets');
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
              // Main Card Form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'المعلومات الأساسية للحساب',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Name Input
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الحساب / البنك / المحفظة',
                        hintText: 'مثال: بريد الجزائر CCP، بنك الفلاحة، BaridiMob',
                        prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الحساب مطلوب' : null,
                    ),
                    const SizedBox(height: 16),

                    // Account Number / RIB Input
                    TextFormField(
                      controller: _accountNumberController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'رقم الحساب / RIB / المفتاح (اختياري)',
                        hintText: '00799999000123456789',
                        prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Wallet Type Selection Cards
              Text(
                'نوع القناة المالية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: _types.map((typeMap) {
                  final val = typeMap['value'] as String;
                  final isSelected = _selectedType == val;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.08)
                            : (isDark ? AppColors.darkSurface : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : AppColors.border),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              typeMap['icon'] as IconData,
                              color: isSelected ? Colors.white : AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  typeMap['label'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: val,
                            groupValue: _selectedType,
                            activeColor: AppColors.primary,
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedType = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Active Switch Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تفعيل الحساب لاستقبال الاشتراكات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    _isActive ? 'الحساب ظاهر ونشط في شاشات سداد الدفعات' : 'الحساب معطل ومخفي مؤقتاً',
                    style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                  ),
                  value: _isActive,
                  activeTrackColor: AppColors.accent,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
              const SizedBox(height: 26),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveWallet,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isLoading
                      ? 'جاري الاعتماد...'
                      : (isEditing ? 'تحديث بيانات الحساب' : 'حفظ واعتام الحساب البنكي'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}