import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// LOCAL CACHE SERVICE (نظام التخزين المحلي للبيانات دون اتصال)
// ============================================================

class LocalCacheService {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// حفظ البيانات محلياً مع توثيق وقت الحفظ وتحديد مدة الصلاحية الاختيارية
  static Future<bool> save(String key, dynamic data, {Duration? ttl}) async {
    try {
      final prefs = await _getPrefs();
      final now = DateTime.now();
      final cacheObject = {
        'cached_at': now.toIso8601String(),
        'expires_at': ttl != null ? now.add(ttl).toIso8601String() : null,
        'data': data,
      };

      final jsonStr = jsonEncode(cacheObject);
      return await prefs.setString('offline_cache_$key', jsonStr);
    } catch (_) {
      return false;
    }
  }

  /// استرجاع البيانات المحفوظة محلياً مع التحقق من الصلاحية
  static Future<dynamic> get(String key, {bool ignoreExpiration = true}) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString('offline_cache_$key');
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final Map<String, dynamic> cacheObject = jsonDecode(jsonStr);
      final expiresAtStr = cacheObject['expires_at']?.toString();

      if (!ignoreExpiration && expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          // انتهت صلاحية الكاش
          return null;
        }
      }

      return cacheObject['data'];
    } catch (_) {
      return null;
    }
  }

  /// استرجاع قائمة خرائط بيانات (List of Maps) بأمان
  static Future<List<Map<String, dynamic>>> getList(String key) async {
    try {
      final data = await get(key);
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// استرجاع خريطة بيانات (Map) بأمان
  static Future<Map<String, dynamic>?> getMap(String key) async {
    try {
      final data = await get(key);
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// فحص وجود كاش محلي صالح للمفتاح
  static Future<bool> has(String key) async {
    final prefs = await _getPrefs();
    return prefs.containsKey('offline_cache_$key');
  }

  /// حذف كاش محدد
  static Future<bool> remove(String key) async {
    final prefs = await _getPrefs();
    return await prefs.remove('offline_cache_$key');
  }

  /// مسح جميع البيانات المخزنة محلياً للكاش
  static Future<void> clearAll() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith('offline_cache_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
