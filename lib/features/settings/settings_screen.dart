import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/supabase_service.dart';
import '../auth/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;
  final _profileFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentProfileData();
  }

  void _loadCurrentProfileData() {
    final authState = ref.read(authProvider);
    final user = authState.userProfile;
    if (user != null) {
      _nameController.text = user['full_name'] ?? '';
      _phoneController.text = user['phone'] ?? '';
      _nationalIdController.text = user['national_id'] ?? '';
      _addressController.text = user['address'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _showEditProfileModal(BuildContext context) {
    _loadCurrentProfileData();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: AppColors.cardShadow,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'تعديل البيانات الشخصية',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(modalContext).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // 1. Full Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الرباعي واللقب *',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          hintText: 'أدخل اسمك الرباعي كاملاً',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم الكامل مطلوب' : null,
                      ),
                      const SizedBox(height: 14),
                      // 2. Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف للتواصل *',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          hintText: '77XXXXXXX أو 78 / 73 / 71',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'رقم الهاتف مطلوب';
                          final clean = v.trim();
                          final phoneRegExp = RegExp(r'^(77|78|73|71)\d{7}$');
                          if (!phoneRegExp.hasMatch(clean)) {
                            return 'رقم الموبايل يجب أن يتكون من 9 أرقام ويبدأ بـ (77, 78, 73, 71)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      // 3. National ID
                      TextFormField(
                        controller: _nationalIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهوية الوطنية / البطاقة الشخصية',
                          prefixIcon: Icon(Icons.credit_card_outlined, size: 20),
                          hintText: 'أدخل رقم الهوية إن وجد',
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 4. Address
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الإقامة / القرية',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                          hintText: 'أدخل عنوان السكن أو القرية',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      FocusScope.of(modalContext).unfocus();
                                      if (!_profileFormKey.currentState!.validate()) return;
                                      setModalState(() => _isLoading = true);
                                      setState(() => _isLoading = true);
                                      try {
                                        final userId = SupabaseService.currentUser?.id;
                                        if (userId == null) throw Exception('الرجاء تسجيل الدخول أولاً');

                                        final data = {
                                          'full_name': _nameController.text.trim(),
                                          'phone': _phoneController.text.trim(),
                                          'national_id': _nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim(),
                                          'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
                                          'updated_at': DateTime.now().toIso8601String(),
                                        };

                                        await SupabaseService.client
                                            .from('profiles')
                                            .update(data)
                                            .eq('id', userId)
                                            .select();

                                        ref.invalidate(authProvider);

                                        if (modalContext.mounted) {
                                          Navigator.of(modalContext).pop();
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('تم تحديث البيانات الشخصية بنجاح وحفظها في قاعدة البيانات'),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('خطأ: ${e.toString().replaceAll("Exception: ", "")}'),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) setState(() => _isLoading = false);
                                        setModalState(() => _isLoading = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('حفظ التعديلات'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(80, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.userRole;
    final user = authState.userProfile;
    final isAdmin = role == 'admin' || role == 'super_admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        appBar: CustomAppBar(
          title: 'الملف الشخصي والإعدادات',
          showBackButton: true,
          onBackPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(authProvider);
          },
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            children: [
              // Profile Card
              _buildProfileCard(user, role, isDark),
              const SizedBox(height: 20),

              // Section: My Account & Security
              _buildSection(
                title: 'إعدادات الحساب والأمان',
                icon: Icons.security_rounded,
                isDark: isDark,
                items: [
                  _buildMenuItem(
                    icon: Icons.badge_outlined,
                    title: 'تعديل البيانات الشخصية',
                    subtitle: 'تحديث الاسم، رقم الهاتف، الهوية وعنوان الإقامة',
                    onTap: () => _showEditProfileModal(context),
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    icon: Icons.lock_reset_rounded,
                    title: 'تغيير كلمة المرور',
                    subtitle: 'تحديث الرمز السري للحساب',
                    onTap: () => _showChangePasswordDialog(context),
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'إشعارات الجمعية',
                    subtitle: 'عرض وتخصيص تنبيهات النظام',
                    onTap: () => context.go('/notifications'),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Section: Association Management (Admin Only)
              if (isAdmin) ...[
                _buildSection(
                  title: 'إدارة المنظومة والرقابة المالية',
                  icon: Icons.admin_panel_settings_rounded,
                  isDark: isDark,
                  items: [
                    _buildMenuItem(
                      icon: Icons.history_edu_rounded,
                      title: 'سجل التدقيق والعمليات',
                      subtitle: 'سجل نشاطات المسؤولين والمستخدمين',
                      onTap: () => _showAuditLogsDialog(context),
                      isDark: isDark,
                    ),
                    _buildMenuItem(
                      icon: Icons.tune_rounded,
                      title: 'إعدادات الجمعية العامة',
                      subtitle: 'تحديد قيمة الاشتراك وسقف المساعدات وتاريخ البداية',
                      onTap: () => _showSettingsDialog(context),
                      isDark: isDark,
                    ),
                    _buildMenuItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'إدارة المحافظ البنكية',
                      subtitle: 'تفعيل وتعديل الحسابات المستقبلة',
                      onTap: () => context.go('/wallets'),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Section: Info & Support
              _buildSection(
                title: 'المعلومات والدعم الفني',
                icon: Icons.info_outline_rounded,
                isDark: isDark,
                items: [
                  _buildMenuItem(
                    icon: Icons.help_outline_rounded,
                    title: 'المساعدة والتواصل',
                    subtitle: 'أرقام وعناوين الجمعية',
                    onTap: () => _showHelpDialog(context),
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'سياسة الخصوصية وحماية البيانات',
                    subtitle: 'شروط استخدام المنظومة',
                    onTap: () => _showPrivacyDialog(context),
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    icon: Icons.info_outline_rounded,
                    title: 'حول المنظومة',
                    subtitle: 'الإصدار 1.0.0 (النسخة الرسمية)',
                    onTap: () => _showAboutDialog(context),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sign out button
              OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('تسجيل الخروج من الحساب'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic>? user, String? role, bool isDark) {
    ImageProvider? imageProvider;
    final avatarUrl = user?['avatar_url'] ?? user?['profile_image_url'];

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:')) {
        try {
          final base64String = avatarUrl.split(',').last;
          final bytes = base64Decode(base64String);
          imageProvider = MemoryImage(bytes);
        } catch (_) {}
      } else if (avatarUrl.startsWith('http')) {
        imageProvider = NetworkImage(avatarUrl);
      }
    }

    final fullName = user?['full_name'] ?? 'عضو الجمعية';
    final email = user?['email'] ?? '---';
    final phone = user?['phone'] ?? '---';
    final memberNumber = user?['member_number'] ?? user?['national_id'] ?? user?['id']?.toString().substring(0, 8) ?? '---';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySubtle,
                  border: Border.all(color: AppColors.accent, width: 2),
                  image: imageProvider != null
                      ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                      : null,
                ),
                child: imageProvider == null
                    ? const Icon(Icons.person_rounded, size: 36, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'رقم القيد: $memberNumber • $phone',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                tooltip: 'تعديل البيانات',
                onPressed: () => _showEditProfileModal(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getRoleLabel(role),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.accentDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (user?['address'] != null && user!['address'].toString().isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '📍 ${user['address']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> items,
    required bool isDark,
  }) {
    return Container(
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
              Icon(icon, size: 20, color: AppColors.accent),
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
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.primarySubtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
      ),
      trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textLight),
      onTap: onTap,
    );
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'super_admin':
        return 'المشرف العام';
      case 'treasurer':
        return 'أمين الصندوق';
      case 'member':
      default:
        return 'عضو الجمعية';
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (newPasswordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('كلمة المرور غير متطابقة'), backgroundColor: AppColors.error),
                        );
                        return;
                      }
                      setModalState(() => isProcessing = true);
                      try {
                        await SupabaseService.client.auth.updateUser(
                          UserAttributes(password: newPasswordController.text),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح'), backgroundColor: AppColors.success),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: AppColors.error),
                          );
                        }
                      } finally {
                        setModalState(() => isProcessing = false);
                      }
                    },
              child: const Text('تحديث كلمة المرور'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل ترغب بتسجيل الخروج من حسابك في المنظومة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول المنظومة الرقمية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance_rounded, size: 45, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'جمعية التكافل والتنمية القروية\nنظام التسيير الإداري والمالي الموحد\nالإصدار: 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            const Text(
              'eng : Omar Ghalib Ahmed Al-mahjari\nphone number: 774360827',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('المساعدة والتواصل'),
        content: const Text(
          'للتواصل مع أمانة الجمعية أو الدعم التقني:\n\n'
          '📧 البريد: contact@takaful-village.dz\n'
          '📞 الهاتف: 0550 00 00 00\n'
          '📍 المقر: دار الجمعيات - القرية',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الخصوصية والأمان'),
        content: const Text(
          'تلتزم جمعية التكافل والتنمية القروية بحماية وسرية كافة البيانات الشخصية والمالية للأعضاء والمستفيدين طبقاً للقوانين والأنظمة المعمول بها.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showAuditLogsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سجل العمليات والتدقيق'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 350,
          child: FutureBuilder(
            future: SupabaseService.client
                .from('audit_logs')
                .select('*')
                .order('created_at', ascending: false)
                .limit(40),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('لا توجد سجلات تدقيق متاحة حالياً'));
              }
              final logs = (snapshot.data as List?) ?? [];
              if (logs.isEmpty) {
                return const Center(child: Text('لا توجد سجلات تدقيق'));
              }
              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(log['action'] ?? 'عملية منظومة', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('تفاصيل: ${log['description'] ?? log['details'] ?? "معتمدة"}'),
                    trailing: Text(
                      log['created_at'] != null ? DateFormat('MM/dd HH:mm').format(DateTime.parse(log['created_at'])) : '---',
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'جمعية التكافل والتنمية القروية');
    final subCtrl = TextEditingController(text: '1000');
    final maxAidCtrl = TextEditingController(text: '50000');
    final startDateCtrl = TextEditingController(text: '2024-01-01');

    // 1. Load from SharedPreferences first for instant availability
    SharedPreferences.getInstance().then((prefs) {
      final localName = prefs.getString('setting_association_name');
      final localSub = prefs.getDouble('setting_default_subscription');
      final localMaxAid = prefs.getDouble('setting_max_assistance');
      final localStartDate = prefs.getString('setting_start_date');

      if (localName != null && localName.isNotEmpty) nameCtrl.text = localName;
      if (localSub != null) subCtrl.text = localSub.toStringAsFixed(0);
      if (localMaxAid != null) maxAidCtrl.text = localMaxAid.toStringAsFixed(0);
      if (localStartDate != null && localStartDate.isNotEmpty) startDateCtrl.text = localStartDate;
    }).catchError((_) {});

    // 2. Load from Supabase to sync if available
    SupabaseService.client.from('association_settings').select().limit(1).maybeSingle().then((res) {
      if (res != null) {
        if (res['association_name'] != null && res['association_name'].toString().isNotEmpty) {
          nameCtrl.text = res['association_name'].toString();
        }
        if (res['default_monthly_subscription'] != null) {
          subCtrl.text = res['default_monthly_subscription'].toString();
        }
        if (res['max_assistance_amount'] != null) {
          maxAidCtrl.text = res['max_assistance_amount'].toString();
        }
        if (res['association_start_date'] != null) {
          startDateCtrl.text = res['association_start_date'].toString().split('T').first;
        }
      }
    }).catchError((_) {});

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الجمعية العامة'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'اسم الجمعية الرسمي'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الاشتراك الشهري الافتراضي (ر.ي)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: startDateCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'تاريخ بداية الجمعية / التحصيل',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.edit_calendar_rounded),
                          onPressed: () async {
                            final initialDate = DateTime.tryParse(startDateCtrl.text) ?? DateTime(2024, 1, 1);
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                startDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxAidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سقف المساعدة الفردية (ر.ي)'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final assocName = nameCtrl.text.trim().isEmpty ? 'جمعية التكافل والتنمية القروية' : nameCtrl.text.trim();
              final subAmount = double.tryParse(subCtrl.text.trim()) ?? 1000.0;
              final maxAidAmount = double.tryParse(maxAidCtrl.text.trim()) ?? 50000.0;
              final startDate = startDateCtrl.text.trim().isEmpty ? '2024-01-01' : startDateCtrl.text.trim();

              // Save to SharedPreferences immediately
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('setting_association_name', assocName);
                await prefs.setDouble('setting_default_subscription', subAmount);
                await prefs.setDouble('setting_max_assistance', maxAidAmount);
                await prefs.setString('setting_start_date', startDate);
              } catch (_) {}

              // Save to Supabase
              try {
                await SupabaseService.client.from('association_settings').upsert({
                  'id': 1,
                  'association_name': assocName,
                  'default_monthly_subscription': subAmount,
                  'max_assistance_amount': maxAidAmount,
                  'association_start_date': startDate,
                  'updated_at': DateTime.now().toIso8601String(),
                }).select();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ وتحديث إعدادات الجمعية بنجاح في قاعدة البيانات والمنظومة!'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم الحفظ محلياً بالتطبيق. تنبيه: قاعدة بيانات Supabase بحاجة لتنفيذ سكربت SQL المرفق لإنشاء جدول الإعدادات (${e.toString()})'),
                      backgroundColor: AppColors.warning,
                      duration: const Duration(seconds: 7),
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ الإعدادات'),
          ),
        ],
      ),
    );
  }
}