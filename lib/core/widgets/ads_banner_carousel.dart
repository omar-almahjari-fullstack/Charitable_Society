import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/ads/ads_provider.dart';
import '../../data/models/ad_model.dart';

// ============================================================
// DYNAMIC ADS & PUBLIC BANNER CAROUSEL WIDGET
// ============================================================
class AdsBannerCarousel extends ConsumerStatefulWidget {
  final String placement;
  final double height;

  const AdsBannerCarousel({
    Key? key,
    this.placement = 'home_banner',
    this.height = 140.0,
  }) : super(key: key);

  @override
  ConsumerState<AdsBannerCarousel> createState() => _AdsBannerCarouselState();
}

class _AdsBannerCarouselState extends ConsumerState<AdsBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final adsState = ref.read(adsProvider);
      if (adsState.activeAds.length > 1 && _pageController.hasClients) {
        final nextPage = (_currentPage + 1) % adsState.activeAds.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsState = ref.watch(adsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (adsState.isLoading) {
      return Container(
        height: widget.height,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final ads = adsState.activeAds;

    // حالة عدم وجود إعلانات نشطة: عرض بنر ترحيبي افتراضي بالجمعية
    if (ads.isEmpty) {
      return _buildDefaultBanner(isDark);
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: ads.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final ad = ads[index];
              return _buildAdCard(ad, isDark);
            },
          ),
        ),
        if (ads.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              ads.length,
              (idx) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == idx ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == idx
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdCard(Ad ad, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: ad.hasImage ? null : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
        image: ad.hasImage
            ? DecorationImage(
                image: NetworkImage(ad.imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (ad.targetUrl != null && ad.targetUrl!.startsWith('/')) {
              context.go(ad.targetUrl!);
            } else {
              context.go('/announcements');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: ad.hasImage
                  ? LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '📢 إعلان وقرار عام',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ad.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ad.description != null && ad.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          ad.description!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBanner(bool isDark) {
    return Container(
      width: double.infinity,
      height: widget.height,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'منظومة إدارة التكافل والتنمية القروية 🌿',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'جميع التنبيهات والإعلانات الرسمية صادرة من إدارة الجمعية وموثقة لحظياً.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
