import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/audit_service.dart';

class AddAssistanceScreen extends ConsumerStatefulWidget {
  const AddAssistanceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddAssistanceScreen> createState() => _AddAssistanceScreenState();
}

class _AddAssistanceScreenState extends ConsumerState<AddAssistanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _beneficiaryReasonController = TextEditingController();
  String _selectedCategory = 'علاج ودواء';
  bool _isLoading = false;

  final List<String> _aidCategories = [
    'علاج ودواء',
    'مساعدات غذائية وتموينية',
    'دعم دراسي وحقيبة مدرسية',
    'ترميم سكن وظروف طارئة',
    'مساعدة زواج أو تضامن عام',
    'أخرى',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _beneficiaryReasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) throw Exception('الرجاء تسجيل الدخول أولاً');

      final amount = double.tryParse(_amountController.text.trim()) ?? 0;

      final fullDescription = _beneficiaryReasonController.text.trim().isNotEmpty
          ? '${_descriptionController.text.trim()}\nالمبررات: ${_beneficiaryReasonController.text.trim()}'
          : _descriptionController.text.trim();

      final reqTitle = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'طلب مساعدة - $_selectedCategory';

      await SupabaseService.client.from('assistance_requests').insert({
        'member_id': userId,
        'title': reqTitle,
        'description': fullDescription,
        'requested_amount': amount,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      NotificationService.sendNotification(
        userId: userId,
        title: 'استلام طلب مساعدة',
        body: 'تم استلام طلب المساعدة بعنوان "$reqTitle" وهو قيد الدراسة من قِبل اللجنة.',
        type: 'assistance',
      );

      NotificationService.notifyAdmins(
        title: 'طلب مساعدة جديد 🤝',
        body: 'تم تقديم طلب مساعدة جديد بعنوان "$reqTitle" بمبلغ $amount ر.ي.',
        type: 'assistance_admin',
        targetRoute: '/assistance',
      );

      AuditService.logAction(
        action: 'تقديم طلب مساعدة',
        description: 'تقديم طلب مساعدة بعنوان "$reqTitle" بمبلغ $amount ر.ي',
        category: 'المساعدات',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تقديم طلب المساعدة بنجاح وسيدرس من قِبل اللجنة'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/assistance');
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
        title: 'تقديم استمارة طلب مساعدة',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/assistance');
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
                        Icon(Icons.volunteer_activism_rounded, color: AppColors.accent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'بيانات وموضوع الإعانة',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'نوع المساعدة المطلوبة',
                        prefixIcon: Icon(Icons.category_outlined, size: 20),
                      ),
                      items: _aidCategories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الطلب أو الحالة',
                        hintText: 'مثال: تغطية تكاليف عملية جراحية',
                        prefixIcon: Icon(Icons.title_rounded, size: 20),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'العنوان مطلوب' : null,
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ التقديري المطلوب (ر.ي)',
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
                        suffixText: 'ر.ي',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'يرجى تحديد المبلغ';
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) return 'أدخل مبلغاً صالحاً';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'شرح موجز للظرف الاجتماعي / الصحي',
                        prefixIcon: Icon(Icons.description_outlined, size: 20),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'الشرح مطلوب' : null,
                    ),
                    const SizedBox(height: 14),

                    // Justification
                    TextFormField(
                      controller: _beneficiaryReasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'أي مبررات أو معلومات إضافية (اختياري)',
                        prefixIcon: Icon(Icons.info_outline_rounded, size: 20),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isLoading ? 'جاري إرسال الطلب...' : 'إرسال طلب الإعانة للجنة',
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