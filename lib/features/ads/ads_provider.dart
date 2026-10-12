import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/ads_service.dart';
import '../../data/models/ad_model.dart';

// ============================================================
// ADS STATE
// ============================================================
class AdsState {
  final List<Ad> activeAds;
  final bool isLoading;
  final String? error;

  const AdsState({
    this.activeAds = const [],
    this.isLoading = false,
    this.error,
  });

  AdsState copyWith({
    List<Ad>? activeAds,
    bool? isLoading,
    String? error,
  }) {
    return AdsState(
      activeAds: activeAds ?? this.activeAds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ============================================================
// ADS NOTIFIER
// ============================================================
class AdsNotifier extends StateNotifier<AdsState> {
  AdsNotifier() : super(const AdsState()) {
    loadActiveAds();
  }

  Future<void> loadActiveAds({String placement = 'home_banner'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await AdsService.fetchActiveAds(placement: placement);
      state = state.copyWith(activeAds: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createAd({
    required String title,
    String? description,
    String? imageUrl,
    String? targetUrl,
    String placement = 'home_banner',
  }) async {
    try {
      final ad = await AdsService.createAd(
        title: title,
        description: description,
        imageUrl: imageUrl,
        targetUrl: targetUrl,
        placement: placement,
      );
      if (ad != null) {
        await loadActiveAds(placement: placement);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteAd(String adId) async {
    await AdsService.deleteAd(adId);
    state = state.copyWith(
      activeAds: state.activeAds.where((a) => a.id != adId).toList(),
    );
  }
}

// ============================================================
// ADS PROVIDER
// ============================================================
final adsProvider = StateNotifierProvider<AdsNotifier, AdsState>((ref) {
  return AdsNotifier();
});
