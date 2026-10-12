import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/audit_service.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _beneficiaryController = TextEditingController();
  String _selectedCategory = 'aid';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _categories = [
    {'value': 'aid', 'label': 'مساعدات وإعانات', 'icon': Icons.volunteer_activism_rounded},
    {'value': 'maintenance', 'label': 'صيانة وترميم', 'icon': Icons.build_circle_outlined},
    {'value': 'electricity', 'label': 'كهرباء وإنارة', 'icon': Icons.bolt_rounded},
    {'value': 'water', 'label': 'مياه وتزويد', 'icon': Icons.water_drop_rounded},
    {'value': 'projects', 'label': 'مشاريع تنموية', 'icon': Icons.construction_rounded},
    {'value': 'salaries', 'label': 'مكافآت وأجور', 'icon': Icons.payments_outlined},
    {'value': 'other', 'label': 'مصاريف أخرى', 'icon': Icons.category_rounded},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _beneficiaryController.dispose();
    super.dispose();
  }

  Future<void> _submitExpense() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) throw Exception('الرجاء تسجيل الدخول أولاً');

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'amount': double.parse(_amountController.text.trim()),
        'beneficiary': _beneficiaryController.text.trim(),
        'expense_date': DateTime.now().toIso8601String(),
        'created_by': userId,
      };

      await SupabaseService.client.from('expenses').insert(data);

      final titleStr = _titleController.text.trim();
      final amountStr = _amountController.text.trim();
      final beneficiaryStr = _beneficiaryController.text.trim();

      NotificationService.notifyAdmins(
        title: 'سند صرف جديد',
        body: 'تسجيل عملية صرف بمبلغ $amountStr د.ج بعنوان "$titleStr" لصالح $beneficiaryStr',
        type: 'expense_admin',
      );

      AuditService.logAction(
        action: 'سند صرف مصروفات',
        description: 'تسجيل مصروف بمبلغ $amountStr د.ج بعنوان "$titleStr" لصالح $beneficiaryStr',
        category: 'المالية',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل عملية الصرف بنجاح في السجل المالي'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/expenses');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
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
        title: 'تسجيل عملية صرف جديدة',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/expenses');
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
              Container(
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
                      children: const [
                        Icon(Icons.receipt_long_rounded, color: AppColors.error, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'بيانات المصروف والفاتورة',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان المصروف / البيان',
                        hintText: 'مثال: صيانة مضخة المياه الرئيسية',
                        prefixIcon: Icon(Icons.title_rounded, size: 20),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'البيان مطلوب' : null,
                    ),
                    const SizedBox(height: 14),

                    // Beneficiary
                    TextFormField(
                      controller: _beneficiaryController,
                      decoration: const InputDecoration(
                        labelText: 'المستفيد / الجهة المستلمة',
                        hintText: 'اسم الشخص، المقاول، أو المؤسسة',
                        prefixIcon: Icon(Icons.person_pin_circle_outlined, size: 20),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'اسم المستفيد مطلوب' : null,
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ الإجمالي المنصرف (د.ج)',
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
                        suffixText: 'د.ج',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'المبلغ مطلوب';
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) return 'أدخل مبلغاً صالحاً';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'تصنيف المصروف في الميزانية',
                        prefixIcon: Icon(Icons.category_outlined, size: 20),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['value'] as String,
                          child: Row(
                            children: [
                              Icon(cat['icon'] as IconData, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(cat['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'تفاصيل إضافية / مبررات الصرف (اختياري)',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isLoading ? 'جاري تسجيل المصروف...' : 'اعتماد وتسجيل المصروف',
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
}