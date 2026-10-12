import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/ads_service.dart';
import '../../data/models/ad_model.dart';

// ============================================================
// ADMIN ADS & PUBLIC DATA MANAGEMENT SCREEN (إدارة الإعلانات)
// ============================================================
class AdminAdsScreen extends ConsumerStatefulWidget {
  const AdminAdsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends ConsumerState<AdminAdsScreen> {
  bool _isLoading = true;
  List<Ad> _ads = [];

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final list = await AdsService.fetchAllAds();
      if (mounted) {
        setState(() {
          _ads = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'إدارة الإعلانات والبيانات العامة',
        subtitle: 'البنرات والدعاية والبيانات العامة',
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAds,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'جاري تحميل قائمة الإعلانات...')
          : _ads.isEmpty
              ? EmptyState(
                  title: 'لا توجد إعلانات مسجلة بعد',
                  subtitle: 'يمكنك إضافة بنرات إعلانية وتوجيهية تظهر للأعضاء بالشاشة الرئيسية.',
                  icon: Icons.campaign_outlined,
                  buttonText: 'إضافة إعلان جديد',
                  onButtonPressed: () => _showAddAdDialog(context),
                )
              : RefreshIndicator(
                  onRefresh: _loadAds,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    itemCount: _ads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ad = _ads[index];
                      return _buildAdTile(ad, isDark);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAdDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('إضافة إعلان', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildAdTile(Ad ad, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ad.isActive ? AppColors.successLight : AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                ad.isActive ? Icons.campaign_rounded : Icons.campaign_outlined,
                color: ad.isActive ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  if (ad.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      ad.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ad.isValidNow ? AppColors.successLight : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ad.isValidNow ? 'ساري وفعال ✅' : 'منتهي / متوقف ⚠️',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ad.isValidNow ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الموضع: ${ad.placement}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: ad.isActive,
              activeColor: AppColors.success,
              onChanged: (val) async {
                await AdsService.toggleAdStatus(ad.id, ad.isActive);
                _loadAds();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              onPressed: () async {
                await AdsService.deleteAd(ad.id);
                _loadAds();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAdDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final imageController = TextEditingController();
    final targetController = TextEditingController();
    String placement = 'home_banner';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.campaign_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text('إضافة إعلان جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الإعلان *',
                      prefixIcon: Icon(Icons.title_rounded, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال عنوان الإعلان';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'الوصف أو التفاصيل (اختياري)',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: imageController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الصورة (URL اختياري)',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.image_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: targetController,
                    decoration: const InputDecoration(
                      labelText: 'رابط التوجيه الداخلي (مسار الصفحة)',
                      hintText: '/announcements',
                      prefixIcon: Icon(Icons.link_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: placement,
                    decoration: const InputDecoration(
                      labelText: 'موضع الإعلان',
                      prefixIcon: Icon(Icons.view_carousel_outlined, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'home_banner', child: Text('البنر الرئيسي بالشاشة الرئيسية')),
                      DropdownMenuItem(value: 'announcements', child: Text('شاشة الإعلانات')),
                      DropdownMenuItem(value: 'popup', child: Text('نافذة منبثقة')),
                    ],
                    onChanged: isSubmitting
                        ? null
                        : (v) {
                            if (v != null) setModalState(() => placement = v);
                          },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setModalState(() => isSubmitting = true);
                      final t = titleController.text.trim();

                      try {
                        await AdsService.createAd(
                          title: t,
                          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                          imageUrl: imageController.text.trim().isEmpty ? null : imageController.text.trim(),
                          targetUrl: targetController.text.trim().isEmpty ? '/announcements' : targetController.text.trim(),
                          placement: placement,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إضافة الإعلان وتفعيله بنجاح 🎉'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadAds();
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ أثناء حفظ الإعلان: ${e.toString().replaceAll("Exception: ", "")}'),
                              backgroundColor: AppColors.error,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ الإعلان'),
            ),
          ],
        ),
      ),
    );
  }
}
