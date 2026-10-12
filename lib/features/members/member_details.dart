import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/storage/local_cache_service.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/network/network_connectivity_service.dart';
import '../auth/auth_provider.dart';
import 'members_provider.dart';

class MemberDetails extends ConsumerStatefulWidget {
  final String memberId;

  const MemberDetails({Key? key, required this.memberId}) : super(key: key);

  @override
  ConsumerState<MemberDetails> createState() => _MemberDetailsState();
}

class _MemberDetailsState extends ConsumerState<MemberDetails> {
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isConfirming = false;
  final _formKey = GlobalKey<FormState>();

  String _fullName = '';
  String _phone = '';
  String _email = '';
  String _nationalId = '';
  String _address = '';
  String _status = 'active';
  String _role = 'member';
  double _monthlySubscription = 1000.0;
  String _joinDate = '';
  String _memberNumber = '';
  String? _profileImageUrl;
  File? _selectedImage;
  Map<String, dynamic>? _memberData;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _nationalIdController;
  late TextEditingController _addressController;
  late TextEditingController _passwordController;
  late TextEditingController _subscriptionController;

  final List<Map<String, String>> _roles = [
    {'value': 'member', 'label': 'عضو عادي'},
    {'value': 'treasurer', 'label': 'أمين صندوق'},
    {'value': 'admin', 'label': 'مسؤول إدارة'},
    {'value': 'super_admin', 'label': 'المشرف العام'},
  ];

  final List<Map<String, String>> _statuses = [
    {'value': 'active', 'label': 'نشط ومستوفى'},
    {'value': 'suspended', 'label': 'موقوف مؤقتاً'},
    {'value': 'inactive', 'label': 'غير نشط'},
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _nationalIdController = TextEditingController();
    _addressController = TextEditingController();
    _passwordController = TextEditingController(text: '123456');
    _subscriptionController = TextEditingController(text: '1000');
    _loadMemberData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _subscriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberData() async {
    if (widget.memberId == 'new') {
      setState(() {
        _isEditing = true;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', widget.memberId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _memberData = response;
          _fullName = response['full_name'] ?? '';
          _phone = response['phone'] ?? '';
          _email = response['email'] ?? '';
          _nationalId = response['national_id'] ?? '';
          _address = response['address'] ?? '';
          _status = response['status'] ?? 'active';
          _role = response['role'] ?? 'member';
          _monthlySubscription = (response['monthly_subscription'] ?? 50.0).toDouble();
          _joinDate = response['join_date'] != null
              ? DateTime.parse(response['join_date']).toLocal().toString().split(' ')[0]
              : '';
          _memberNumber = response['member_number'] ?? '---';
          _profileImageUrl = response['avatar_url'] ?? response['profile_image_url'];

          _fullNameController.text = _fullName;
          _phoneController.text = _phone;
          _emailController.text = _email;
          _nationalIdController.text = _nationalId;
          _addressController.text = _address;
          _subscriptionController.text = _monthlySubscription.toStringAsFixed(0);
          _isLoading = false;
        });

        // حفظ بيانات العضو محلياً
        try {
          await LocalCacheService.save('cached_member_details_${widget.memberId}', response);
        } catch (_) {}
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // استرجاع تفاصيل العضو من الكاش المحلي
      try {
        final cached = await LocalCacheService.get('cached_member_details_${widget.memberId}');
        if (cached is Map && mounted) {
          setState(() {
            _memberData = Map<String, dynamic>.from(cached);
            _fullName = cached['full_name'] ?? '';
            _phone = cached['phone'] ?? '';
            _email = cached['email'] ?? '';
            _nationalId = cached['national_id'] ?? '';
            _address = cached['address'] ?? '';
            _status = cached['status'] ?? 'active';
            _role = cached['role'] ?? 'member';
            _monthlySubscription = ((cached['monthly_subscription'] ?? 50.0) as num).toDouble();
            _joinDate = cached['join_date'] != null
                ? DateTime.parse(cached['join_date']).toLocal().toString().split(' ')[0]
                : '';
            _memberNumber = cached['member_number'] ?? '---';
            _profileImageUrl = cached['avatar_url'] ?? cached['profile_image_url'];

            _fullNameController.text = _fullName;
            _phoneController.text = _phone;
            _emailController.text = _email;
            _nationalIdController.text = _nationalId;
            _addressController.text = _address;
            _subscriptionController.text = _monthlySubscription.toStringAsFixed(0);
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageAsBase64() async {
    if (_selectedImage == null) return _profileImageUrl;

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64String = base64Encode(bytes);
      final ext = _selectedImage!.path.split('.').last;
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      return _profileImageUrl;
    }
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isOnline = await NetworkConnectivityService().checkIsOnline();
      if (!isOnline) {
        if (mounted) {
          AppFeedback.showOfflineOperationError(
            context,
            onRetry: () => _saveChanges(),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      final imageUrl = await _uploadImageAsBase64();

      final fullNameStr = _fullNameController.text.trim();
      final phoneStr = _phoneController.text.trim();
      final emailStr = _emailController.text.trim().toLowerCase();
      final nationalIdStr = _nationalIdController.text.trim();
      final addressStr = _addressController.text.trim();
      final subAmount = double.tryParse(_subscriptionController.text.trim()) ?? _monthlySubscription;

      final data = {
        'full_name': fullNameStr,
        'phone': phoneStr,
        'email': emailStr.isEmpty ? null : emailStr,
        'national_id': nationalIdStr.isEmpty ? null : nationalIdStr,
        'address': addressStr.isEmpty ? null : addressStr,
        'role': _role,
        'status': _status,
        'monthly_subscription': subAmount,
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (subAmount < 1000) {
        throw Exception('أقل قيمة لاشتراك العضو هي 1000 ر.ي');
      }

      if (widget.memberId == 'new') {
        final defaultPass = _passwordController.text.trim().isEmpty ? '123456' : _passwordController.text.trim();
        final effectiveEmail = emailStr.isNotEmpty ? emailStr : 'member_$phoneStr@takaful.com';

        // 1. Check duplicate full name
        final existingName = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('full_name', fullNameStr)
            .maybeSingle();

        if (existingName != null) {
          throw Exception('هذا الاسم مضاف سابقاً بالجمعية، يرجى كتابة الاسم واللقب بوضوح لتفادي التكرار.');
        }

        // 2. Check duplicate phone
        final phoneResponse = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('phone', phoneStr);

        if (phoneResponse.isNotEmpty) {
          throw Exception('رقم الهاتف هذا مستخدم بالفعل لعضو آخر');
        }

        String? newUserId;

        // 3. Create user in auth.users using isolated GoTrue client (Implicit flow to avoid asyncStorage PKCE error)
        final isolatedAuthClient = SupabaseClient(
          SupabaseService.supabaseUrl,
          SupabaseService.supabaseAnonKey,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );

        try {
          final authRes = await isolatedAuthClient.auth.signUp(
            email: effectiveEmail,
            password: defaultPass,
            data: {
              'full_name': fullNameStr,
              'phone': phoneStr,
              'role': _role,
              'status': _status,
              'national_id': nationalIdStr.isNotEmpty ? nationalIdStr : null,
              'address': addressStr.isNotEmpty ? addressStr : null,
              'monthly_subscription': subAmount,
              'avatar_url': imageUrl,
            },
          );
          newUserId = authRes.user?.id;
        } catch (signUpErr) {
          // If user already exists in auth, attempt sign-in to capture existing UID
          try {
            final loginRes = await isolatedAuthClient.auth.signInWithPassword(
              email: effectiveEmail,
              password: defaultPass,
            );
            newUserId = loginRes.user?.id;
          } catch (_) {
            throw Exception('فشل إنشاء حساب العضو في نظام المصادقة: ${signUpErr.toString().replaceAll("Exception: ", "").replaceAll("AuthApiException: ", "")}');
          }
        }

        if (newUserId == null) {
          throw Exception('تعذر استخراج معرف المستخدم من نظام المصادقة');
        }

        final newProfileData = {
          'id': newUserId,
          'full_name': fullNameStr,
          'phone': phoneStr,
          'email': effectiveEmail,
          'role': _role,
          'status': _status,
          'national_id': nationalIdStr.isNotEmpty ? nationalIdStr : null,
          'address': addressStr.isNotEmpty ? addressStr : null,
          'monthly_subscription': subAmount,
          'avatar_url': imageUrl,
          'join_date': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          await SupabaseService.client.from('profiles').upsert(newProfileData);
        } catch (_) {
          // Fallback update by id if upsert policy restricts insert
          try {
            await SupabaseService.client
                .from('profiles')
                .update({
                  'full_name': fullNameStr,
                  'phone': phoneStr,
                  'email': effectiveEmail,
                  'national_id': nationalIdStr.isNotEmpty ? nationalIdStr : null,
                  'address': addressStr.isNotEmpty ? addressStr : null,
                  'monthly_subscription': subAmount,
                  'avatar_url': imageUrl,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', newUserId);
          } catch (_) {}
        }

        NotificationService.sendNotification(
          userId: newUserId,
          title: 'مرحباً بك في الجمعية 🌿',
          body: 'تم تفعيل حسابك بنجاح. كلمة المرور الافتراضية الخاصة بك هي ($defaultPass). يمكنكم تسجيل الدخول ومتابعة خدماتكم.',
          type: 'member_status',
          targetRoute: '/home',
        );

        AuditService.logEvent(
          action: 'CREATE_MEMBER',
          module: 'الأعضاء',
          entity: 'profiles',
          entityId: newUserId,
          oldValues: null,
          newValues: data,
          errorMessage: 'تم إضافة العضو الجديد $fullNameStr إلى الجمعية',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إضافة العضو وتفعيل كلمة المرور الافتراضية ($defaultPass) بنجاح! يمكنه تسجيل الدخول برقم الهاتف أو البريد.'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 6),
            ),
          );
          ref.read(membersProvider.notifier).loadMembers();
          context.go('/members');
        }
      } else {
        // Check duplicate name for existing member
        final existingName = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('full_name', fullNameStr)
            .maybeSingle();

        if (existingName != null && existingName['id'] != widget.memberId) {
          throw Exception('هذا الاسم مضاف سابقاً لعضو آخر بالجمعية.');
        }

        final updateResponse = await SupabaseService.client
            .from('profiles')
            .update(data)
            .eq('id', widget.memberId)
            .select();

        if (updateResponse.isEmpty) {
          throw Exception('تعذر تحديث بيانات العضو في قاعدة البيانات. يرجى التثبت من صلاحيات الحساب (RLS Policy).');
        }

        NotificationService.sendNotification(
          userId: widget.memberId,
          title: 'تحديث بيانات الحساب 👤',
          body: 'تم تحديث بيانات ملفك الشخصي وحالة عضويتك في الجمعية بنجاح.',
          type: 'member_status',
          targetRoute: '/settings',
        );

        AuditService.logEvent(
          action: 'UPDATE_MEMBER',
          module: 'الأعضاء',
          entity: 'profiles',
          entityId: widget.memberId,
          oldValues: _memberData,
          newValues: data,
          errorMessage: 'قام المدير بتحديث بيانات العضو $fullNameStr',
        );

        if (mounted) {
          AppFeedback.showSuccess(context, 'تم حفظ وتحديث بيانات العضو بنجاح في قاعدة البيانات');
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
          await _loadMemberData();
          ref.read(membersProvider.notifier).loadMembers();
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
          context,
          AppErrorHandler.handleGeneralError(e),
          onRetry: () => _saveChanges(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmMember() async {
    setState(() => _isConfirming = true);
    try {
      // 1. Update status directly in profiles table
      await SupabaseService.client
          .from('profiles')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.memberId);

      // 2. Safely attempt to call RPC to confirm email in auth.users if function exists
      try {
        await SupabaseService.client.rpc(
          'confirm_user_by_admin',
          params: {'p_user_id': widget.memberId},
        );
      } catch (_) {}

      NotificationService.sendNotification(
        userId: widget.memberId,
        title: 'تأكيد واعتماد العضوية',
        body: 'تهانينا! تم تفعيل وتأكيد حسابكم في الجمعية بنجاح من قِبل إدارة الجمعية.',
        type: 'member_status',
      );

      AuditService.logEvent(
        action: 'ACTIVATE_MEMBER',
        module: 'الأعضاء',
        entity: 'profiles',
        entityId: widget.memberId,
        oldValues: {'status': 'pending'},
        newValues: {'status': 'active'},
        errorMessage: 'قام المدير بتأكيد وتفعيل حساب العضو $_fullName',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل وتأكيد حساب العضوية بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadMemberData();
        ref.read(membersProvider.notifier).loadMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التأكيد: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Future<void> _deactivateMember() async {
    try {
      // 1. Update status directly in profiles table
      await SupabaseService.client
          .from('profiles')
          .update({
            'status': 'suspended',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.memberId);

      // 2. Safely attempt to call RPC to revoke confirmation in auth.users if function exists
      try {
        await SupabaseService.client.rpc(
          'deactivate_user_by_admin',
          params: {'p_user_id': widget.memberId},
        );
      } catch (_) {}

      NotificationService.sendNotification(
        userId: widget.memberId,
        title: 'تعليق وتجميد العضوية',
        body: 'تنبيه: تم تعليق وتجميد حساب عضويتكم مؤقتاً من قِبل إدارة الجمعية.',
        type: 'member_status',
      );

      AuditService.logEvent(
        action: 'SUSPEND_MEMBER',
        module: 'الأعضاء',
        entity: 'profiles',
        entityId: widget.memberId,
        oldValues: {'status': 'active'},
        newValues: {'status': 'suspended'},
        errorMessage: 'قام المدير بتعليق وتجميد حساب العضو $_fullName',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إيقاف وتجميد تأكيد حساب العضو بنجاح'),
            backgroundColor: AppColors.warning,
          ),
        );
        _loadMemberData();
        ref.read(membersProvider.notifier).loadMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التعليق: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteMember() async {
    // 1. Check if member has related records (payments, assistance requests, financial transactions)
    setState(() => _isSaving = true);
    try {
      int paymentsCount = 0;
      int aidCount = 0;
      int txCount = 0;

      try {
        final pRes = await SupabaseService.client
            .from('payments')
            .select('id')
            .eq('member_id', widget.memberId);
        paymentsCount = pRes.length;
      } catch (_) {}

      try {
        final aRes = await SupabaseService.client
            .from('assistance_requests')
            .select('id')
            .eq('member_id', widget.memberId);
        aidCount = aRes.length;
      } catch (_) {}

      try {
        final txRes = await SupabaseService.client
            .from('financial_transactions')
            .select('id')
            .eq('member_id', widget.memberId);
        txCount = txRes.length;
      } catch (_) {}

      setState(() => _isSaving = false);

      // If the member has associated financial records, warn and block deletion to protect data integrity
      if (paymentsCount > 0 || aidCount > 0 || txCount > 0) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                SizedBox(width: 10),
                Text('تعذر حذف العضو', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لا يمكن حذف سجل العضو ($_fullName) نهائياً لوجود بيانات وسجلات مالية مرتبطة به في النظام:',
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (paymentsCount > 0)
                  Text('• عدد سندات الاشتراكات: $paymentsCount سند', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (aidCount > 0)
                  Text('• عدد طلبات الإعانة: $aidCount طلب', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (txCount > 0)
                  Text('• عدد القيود المالية: $txCount قيد محاسبي', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                const Text(
                  'حفاظاً على سلامة الحسابات وميزانية الجمعية، يُنصح بتجميد وتعليق حسابه بدلاً من الحذف.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deactivateMember();
                },
                icon: const Icon(Icons.block_rounded, size: 18),
                label: const Text('تجميد الحساب الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
        return;
      }

      // If no related records exist, confirm permanent deletion
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('تأكيد الحذف النهائي'),
          content: Text('هل أنت متأكد من حذف العضو ($_fullName) نهائياً من قاعدة البيانات؟ لن يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('نعم، حذف نهائي'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isSaving = true);

      await SupabaseService.client
          .from('profiles')
          .delete()
          .eq('id', widget.memberId);

      AuditService.logEvent(
        action: 'DELETE_MEMBER',
        module: 'الأعضاء',
        entity: 'profiles',
        entityId: widget.memberId,
        oldValues: _memberData,
        newValues: null,
        errorMessage: 'قام المدير بحذف سجل العضو $_fullName نهائياً لعدم وجود سجلات مالية له',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف سجل العضو نهائياً من قاعدة البيانات بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(membersProvider.notifier).loadMembers();
        context.go('/members');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحذف: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _isAdmin {
    final authState = ref.watch(authProvider);
    final role = authState.userRole;
    return role == 'admin' || role == 'super_admin' || role == 'treasurer';
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.memberId == 'new';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: isNew ? 'تسجيل عضو جديد' : 'ملف العضوية',
        subtitle: isNew ? null : _fullName,
        showBackButton: true,
        actions: [
          if (!isNew && !_isLoading)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_note_rounded,
                color: Colors.white,
                size: 26,
              ),
              onPressed: _isEditing ? _saveChanges : () => setState(() => _isEditing = true),
              tooltip: _isEditing ? 'حفظ التعديلات' : 'تعديل البيانات',
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'جاري تحميل ملف العضو...')
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Member Profile Header & Avatar
                    _buildProfileHeader(isNew, isDark),
                    const SizedBox(height: 20),

                    // Section 1: Personal Details
                    _buildCardSection(
                      title: 'البيانات الشخصية والاتصال',
                      icon: Icons.person_pin_rounded,
                      isDark: isDark,
                      children: [
                        _buildInputField(
                          label: 'الاسم واللقب كاملاً',
                          controller: _fullNameController,
                          icon: Icons.badge_outlined,
                          isEditing: _isEditing || isNew,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                        ),
                        _buildInputField(
                          label: 'رقم الهاتف للتواصل (9 أرقام)',
                          controller: _phoneController,
                          icon: Icons.phone_outlined,
                          isEditing: _isEditing || isNew,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'رقم الهاتف مطلوب';
                            final clean = v.trim();
                            final phoneReg = RegExp(r'^(77|78|73|71)\d{7}$');
                            if (!phoneReg.hasMatch(clean)) {
                              return 'رقم الهاتف يجب أن يتكون من 9 أرقام ويبدأ بـ (77, 78, 73, 71)';
                            }
                            return null;
                          },
                        ),
                        _buildInputField(
                          label: 'البريد الإلكتروني',
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          isEditing: _isEditing || isNew,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v != null && v.trim().isNotEmpty && !v.contains('@')) ? 'بريد غير صالح' : null,
                        ),
                        if (isNew)
                          _buildInputField(
                            label: 'كلمة المرور الافتراضية للحساب',
                            controller: _passwordController,
                            icon: Icons.lock_outline_rounded,
                            isEditing: true,
                          ),
                        _buildInputField(
                          label: 'رقم التعريف الوطني / بطاقة الهوية',
                          controller: _nationalIdController,
                          icon: Icons.credit_card_rounded,
                          isEditing: _isEditing || isNew,
                        ),
                        _buildInputField(
                          label: 'عنوان الإقامة / القرية',
                          controller: _addressController,
                          icon: Icons.location_on_outlined,
                          isEditing: _isEditing || isNew,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Membership & Administration
                    _buildCardSection(
                      title: 'بيانات العضوية والاشتراك',
                      icon: Icons.card_membership_rounded,
                      isDark: isDark,
                      children: [
                        if (!isNew)
                          _buildReadOnlyField(
                            label: 'رقم القيد في الجمعية',
                            value: _memberNumber.isEmpty ? 'قيد التوليد' : _memberNumber,
                            icon: Icons.tag_rounded,
                            isDark: isDark,
                          ),
                        if (!isNew)
                          _buildReadOnlyField(
                            label: 'تاريخ الانتساب والاعتماد',
                            value: _joinDate,
                            icon: Icons.calendar_today_outlined,
                            isDark: isDark,
                          ),
                        _buildInputField(
                          label: 'قيمة الاشتراك الشهري (ر.ي)',
                          controller: _subscriptionController,
                          icon: Icons.monetization_on_outlined,
                          isEditing: _isEditing || isNew,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'قيمة الاشتراك مطلوبة';
                            final amt = double.tryParse(v.trim()) ?? 0.0;
                            if (amt < 1000) {
                              return 'أقل قيمة لااشتراك العضو هي 1000 ر.ي';
                            }
                            return null;
                          },
                        ),
                        _buildDropdownField(
                          label: 'الصفة / الدور الإداري',
                          value: _role,
                          items: _roles,
                          icon: Icons.admin_panel_settings_outlined,
                          isEditing: _isEditing || isNew,
                          onChanged: (v) {
                            if (v != null) setState(() => _role = v);
                          },
                        ),
                        _buildDropdownField(
                          label: 'وضعية وحالة الحساب',
                          value: _status,
                          items: _statuses,
                          icon: Icons.health_and_safety_outlined,
                          isEditing: _isEditing || isNew,
                          onChanged: (v) {
                            if (v != null) setState(() => _status = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Admin Action Buttons
                    if (_isEditing || isNew)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveChanges,
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ البيانات'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (!isNew)
                            OutlinedButton(
                              onPressed: () => setState(() => _isEditing = false),
                              child: const Text('إلغاء'),
                            ),
                        ],
                      )
                    else if (_isAdmin && !isNew) ...[
                      if (_status != 'active')
                        ElevatedButton.icon(
                          onPressed: _isConfirming ? null : _confirmMember,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.verified_rounded, size: 18),
                          label: const Text('تفعيل واعتماد العضوية'),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showDeactivateDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.warning,
                                side: const BorderSide(color: AppColors.warning, width: 1.5),
                              ),
                              icon: const Icon(Icons.pause_circle_outline, size: 18),
                              label: const Text('تعليق العضوية'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showDeleteDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error, width: 1.5),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('حذف السجل'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(bool isNew, bool isDark) {
    ImageProvider? imageProvider;
    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      if (_profileImageUrl!.startsWith('data:')) {
        try {
          final base64String = _profileImageUrl!.split(',').last;
          final bytes = base64Decode(base64String);
          imageProvider = MemoryImage(bytes);
        } catch (_) {}
      } else if (_profileImageUrl!.startsWith('http')) {
        imageProvider = NetworkImage(_profileImageUrl!);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySubtle,
                  border: Border.all(color: AppColors.accent, width: 2.5),
                  image: imageProvider != null
                      ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                      : null,
                ),
                child: imageProvider == null
                    ? const Icon(Icons.person_rounded, size: 50, color: AppColors.primary)
                    : null,
              ),
              if (_isEditing || isNew)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: InkWell(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isNew ? 'إضافة ملف جديد' : _fullName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          if (!isNew) ...[
            const SizedBox(height: 4),
            Text(
              'رقم العضوية: ${_memberNumber.isEmpty ? '---' : _memberNumber}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardSection({
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isEditing
          ? TextFormField(
              controller: controller,
              validator: validator,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon, size: 20),
              ),
            )
          : _buildReadOnlyField(
              label: label,
              value: controller.text.isEmpty ? '---' : controller.text,
              icon: icon,
              isDark: false,
            ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required IconData icon,
    required bool isEditing,
    required Function(String?) onChanged,
  }) {
    if (!isEditing) {
      final selectedLabel = items.firstWhere(
        (i) => i['value'] == value,
        orElse: () => {'label': value},
      )['label']!;
      return _buildReadOnlyField(label: label, value: selectedLabel, icon: icon, isDark: false);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item['value'],
            child: Text(item['label'] ?? item['value']!),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _showDeactivateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعليق العضوية'),
        content: const Text('هل ترغب بتعليق عضوية هذا العضو مؤقتاً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivateMember();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('تأكيد التعليق'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف ملف العضو'),
        content: const Text('تحذير: سيتم حذف سجل العضو بالكامل من المنظومة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMember();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }
}
