import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/ad_model.dart';
import '../storage/local_cache_service.dart';
import 'supabase_service.dart';

// ============================================================
// ADS & PUBLIC DATA SERVICE (SUPABASE BACKEND INTEGRATION)
// ============================================================
class AdsService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// جلب الإعلانات النشطة والصالحة للعرض حسب الموضع (placement)
  static Future<List<Ad>> fetchActiveAds({String placement = 'home_banner'}) async {
    try {
      final response = await _supabase
          .from('ads')
          .select('*')
          .eq('is_active', true)
          .eq('placement', placement)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((json) => Ad.fromJson(Map<String, dynamic>.from(json)))
          .where((ad) => ad.isValidNow)
          .toList();

      try {
        await LocalCacheService.save('cached_ads_$placement', response);
      } catch (_) {}

      return list;
    } catch (_) {
      // محاولة استرجاع الإعلانات من الكاش المحلي أولاً
      try {
        final cached = await LocalCacheService.get('cached_ads_$placement');
        if (cached is List && cached.isNotEmpty) {
          return cached
              .map((json) => Ad.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
      } catch (_) {}
      // احتياطي: إذا لم يكن جدول ads مقماً بعد، جلب الإعلانات النشطة من جدول announcements
      try {
        final annResponse = await _supabase
            .from('announcements')
            .select('*')
            .eq('is_published', true)
            .order('created_at', ascending: false)
            .limit(5);

        return (annResponse as List).map((item) {
          return Ad(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? 'إعلان من الجمعية',
            description: item['content']?.toString(),
            placement: placement,
            isActive: true,
            createdAt: item['created_at'] != null
                ? DateTime.parse(item['created_at'].toString())
                : DateTime.now(),
          );
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// جلب كافة الإعلانات (للإدارة)
  static Future<List<Ad>> fetchAllAds() async {
    try {
      final response = await _supabase
          .from('ads')
          .select('*')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Ad.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// إضافة إعلان جديد
  static Future<Ad?> createAd({
    required String title,
    String? description,
    String? imageUrl,
    String? targetUrl,
    String placement = 'home_banner',
    bool isActive = true,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      final payload = {
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'target_url': targetUrl,
        'placement': placement,
        'is_active': isActive,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase.from('ads').insert(payload).select().single();
      return Ad.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      rethrow;
    }
  }

  /// تبديل حالة نشاط الإعلان (تفعيل / إيقاف)
  static Future<bool> toggleAdStatus(String adId, bool currentStatus) async {
    try {
      await _supabase
          .from('ads')
          .update({'is_active': !currentStatus})
          .eq('id', adId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// حذف إعلان
  static Future<bool> deleteAd(String adId) async {
    try {
      await _supabase.from('ads').delete().eq('id', adId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// جلب البيانات والإعدادات العامة للتطبيق (public_data / association_settings)
  static Future<Map<String, String>> fetchPublicSettings() async {
    try {
      final response = await _supabase.from('association_settings').select('*');
      final map = <String, String>{};
      for (final row in response as List) {
        final key = row['setting_key']?.toString();
        final val = row['setting_value']?.toString();
        if (key != null && val != null) {
          map[key] = val;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
