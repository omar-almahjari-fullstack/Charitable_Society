import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_cache_service.dart';
import 'wallet_model.dart';

class WalletsProvider extends StateNotifier<WalletsState> {
  WalletsProvider() : super(WalletsState()) {
    loadWallets();
  }

  Future<void> loadWallets() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await SupabaseService.client
          .from('wallets')
          .select('*')
          .order('name');
      
      final wallets = (response as List).map((json) {
        return Wallet.fromJson(json);
      }).toList();

      state = state.copyWith(
        wallets: wallets,
        isLoading: false,
        error: null,
      );

      // حفظ قائمة المحافظ والحسابات في الكاش المحلي
      try {
        await LocalCacheService.save('cached_wallets_list', response);
      } catch (_) {}
    } catch (e) {
      // استرجاع المحافظ من الكاش المحلي عند انقطاع الاتصال
      try {
        final cached = await LocalCacheService.get('cached_wallets_list');
        if (cached is List && cached.isNotEmpty) {
          final wallets = cached.map((json) => Wallet.fromJson(Map<String, dynamic>.from(json))).toList();
          state = state.copyWith(
            wallets: wallets,
            isLoading: false,
            error: null,
          );
          return;
        }
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        error: 'حدث خطأ أثناء تحميل المحافظ: ${e.toString()}',
      );
    }
  }

  void searchWallets(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> addWallet(Wallet wallet) async {
    try {
      // ✅ التحقق من تسجيل الدخول فقط عند الإضافة
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('الرجاء تسجيل الدخول أولاً');
      }

      final response = await SupabaseService.client
          .from('wallets')
          .insert(wallet.toJson())
          .select();

      if (response.isNotEmpty) {
        final newWallet = Wallet.fromJson(response.first);
        state = state.copyWith(
          wallets: [newWallet, ...state.wallets],
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateWallet(Wallet wallet) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('الرجاء تسجيل الدخول أولاً');
      }

      await SupabaseService.client
          .from('wallets')
          .update(wallet.toJson())
          .eq('id', wallet.id);

      final updatedWallets = state.wallets.map((w) {
        return w.id == wallet.id ? wallet : w;
      }).toList();

      state = state.copyWith(
        wallets: updatedWallets,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleWalletStatus(String id, bool isActive) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('الرجاء تسجيل الدخول أولاً');
      }

      await SupabaseService.client
          .from('wallets')
          .update({'is_active': isActive})
          .eq('id', id);

      final updatedWallets = state.wallets.map((w) {
        if (w.id == id) {
          return Wallet(
            id: w.id,
            name: w.name,
            type: w.type,
            accountNumber: w.accountNumber,
            isActive: isActive,
            createdAt: w.createdAt,
          );
        }
        return w;
      }).toList();

      state = state.copyWith(
        wallets: updatedWallets,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteWallet(String id) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('الرجاء تسجيل الدخول أولاً');
      }

      await SupabaseService.client
          .from('wallets')
          .delete()
          .eq('id', id);

      final remainingWallets = state.wallets
          .where((w) => w.id != id)
          .toList();

      state = state.copyWith(
        wallets: remainingWallets,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> refreshWallets() async {
    await loadWallets();
  }
}

final walletsProvider = StateNotifierProvider<WalletsProvider, WalletsState>((ref) {
  return WalletsProvider();
});