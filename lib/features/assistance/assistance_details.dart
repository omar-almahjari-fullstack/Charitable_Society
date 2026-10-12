import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../auth/auth_provider.dart';

class AssistanceDetailsScreen extends ConsumerStatefulWidget {
  final String requestId;

  const AssistanceDetailsScreen({Key? key, required this.requestId}) : super(key: key);

  @override
  ConsumerState<AssistanceDetailsScreen> createState() => _AssistanceDetailsScreenState();
}

class _AssistanceDetailsScreenState extends ConsumerState<AssistanceDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadRequestData();
  }

  Future<void> _loadRequestData() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('assistance_requests')
          .select('*, profiles!member_id(full_name, phone, national_id, address)')
          .eq('id', widget.requestId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _requestData = response;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'لم يتم العثور على بيانات الطلب';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus, {String? reason, double? approvedAmount}) async {
    setState(() => _isProcessing = true);
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (reason != null) updateData['rejection_reason'] = reason;
      if (approvedAmount != null) updateData['approved_amount'] = approvedAmount;

      await SupabaseService.client
          .from('assistance_requests')
          .update(updateData)
          .eq('id', widget.requestId);

      final memberId = _requestData?['member_id']?.toString();
      final title = _requestData?['title']?.toString() ?? 'طلب المساعدة';

      if (memberId != null && memberId.isNotEmpty) {
        String statusAr = _getStatusLabel(newStatus);
        String bodyMsg = 'تم تحديث حالة طلب المساعدة "$title" إلى ($statusAr).';
        if (newStatus == 'approved' && approvedAmount != null && approvedAmount > 0) {
          bodyMsg = 'تمت الموافقة على طلب المساعدة "$title" واعتمد مبلغ ${approvedAmount.toStringAsFixed(0)} ر.ي لصرفه لكم.';
        } else if (newStatus == 'rejected' && reason != null && reason.isNotEmpty) {
          bodyMsg = 'تم رفض طلب المساعدة "$title". السبب: $reason';
        }

        NotificationService.sendNotification(
          userId: memberId,
          title: 'تحديث حالة طلب المساعدة 🤝',
          body: bodyMsg,
          type: 'assistance',
          targetRoute: '/assistance',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة الطلب إلى ${_getStatusLabel(newStatus)} وإرسال إشعار للعضو'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadRequestData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مقبولة';
      case 'rejected':
        return 'مرفوضة';
      case 'completed':
        return 'منفذة ومكتملة';
      case 'pending':
      default:
        return 'قيد الدراسة';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'completed':
        return AppColors.accent;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.userRole;
    final isAdmin = role == 'admin' || role == 'super_admin' || role == 'treasurer';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'تفاصيل ملف الإعانة',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/assistance');
          }
        },
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'جاري تحميل تفاصيل الطلب...')
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadRequestData, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    children: [
                      _buildDetailsCard(isDark),
                      const SizedBox(height: 20),

                      // Admin Decision Actions
                      if (isAdmin && _requestData != null)
                        _buildAdminActionSection(isDark),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailsCard(bool isDark) {
    final req = _requestData!;
    final profile = req['profiles'] as Map<String, dynamic>?;
    final memberName = profile?['full_name'] ?? 'عضو مسجل';
    final phone = profile?['phone'] ?? '---';
    final nationalId = profile?['national_id'] ?? '---';
    final address = profile?['address'] ?? '---';
    final title = req['title'] ?? 'طلب مساعدة اجتماعية';
    final description = req['description'] ?? 'لا يوجد شرح إضافي';
    final requestedAmount = ((req['requested_amount'] ?? 0) as num).toDouble();
    final approvedAmount = ((req['approved_amount'] ?? 0) as num).toDouble();
    final status = req['status']?.toString() ?? 'pending';
    final statusLabel = _getStatusLabel(status);
    final statusColor = _getStatusColor(status);
    final rejectionReason = req['rejection_reason']?.toString();
    final createdAt = req['created_at'] != null
        ? DateTime.parse(req['created_at'].toString())
        : DateTime.now();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('yyyy/MM/dd').format(createdAt),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // Financial Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('المبلغ المطلوب', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '${requestedAmount.toStringAsFixed(0)} ر.ي',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 30, color: isDark ? AppColors.darkBorder : AppColors.border),
                  Column(
                    children: [
                      const Text('المبلغ المعتمد', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '${approvedAmount.toStringAsFixed(0)} ر.ي',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Member Info
            const Text(
              'بيانات صاحب الطلب',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _buildRowItem(Icons.person_outline_rounded, 'الاسم:', memberName),
            _buildRowItem(Icons.phone_outlined, 'الهاتف:', phone),
            _buildRowItem(Icons.credit_card_rounded, 'رقم الهوية:', nationalId),
            _buildRowItem(Icons.location_on_outlined, 'العنوان:', address),

            const Divider(height: 24),

            // Description
            const Text(
              'شرح الحالة والظروف الاجتماعية',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),

            if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سبب القرار: $rejectionReason',
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRowItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات لجنة المساعدات والتضامن',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _showApproveDialog(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('قبول واعتماد'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _showRejectDialog(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('رفض الطلب'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showApproveDialog() {
    final amountController = TextEditingController(
      text: ((_requestData?['requested_amount'] ?? 0) as num).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الموافقة على طلب الإعانة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('حدد المبلغ المعتمد للصرف للمستفيد:'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ المعتمد (ر.ي)', suffixText: 'ر.ي'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text.trim()) ?? 0;
              Navigator.pop(context);
              _updateStatus('approved', approvedAmount: amt);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('تأكيد الموافقة'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض طلب المساعدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى توضيح سبب رفض الطلب للأمانة والشفافية:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'سبب الرفض'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              Navigator.pop(context);
              _updateStatus('rejected', reason: reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }
}