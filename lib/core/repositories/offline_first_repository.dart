import '../errors/app_error_handler.dart';
import '../network/network_connectivity_service.dart';
import '../storage/local_cache_service.dart';

// ============================================================
// REPOSITORY RESULT PATTERN (نموذج نتائج البيانات الموحد)
// ============================================================

sealed class RepoResult<T> {
  const RepoResult();
}

class RepoSuccess<T> extends RepoResult<T> {
  final T data;
  const RepoSuccess(this.data);
}

class RepoCached<T> extends RepoResult<T> {
  final T data;
  final String message;
  const RepoCached(this.data, {this.message = 'أنت في وضع عدم الاتصال، يتم عرض البيانات المحفوظة محلياً.'});
}

class RepoFailure<T> extends RepoResult<T> {
  final String message;
  final dynamic originalError;
  const RepoFailure(this.message, {this.originalError});
}

// ============================================================
// OFFLINE-FIRST REPOSITORY PATTERN
// مستودع البيانات الذكي: يقرر جلب البيانات من الشبكة وحفظها أو استخدام الكاش المحلي
// ============================================================

class OfflineFirstRepository {
  /// جلب البيانات بنمط Offline-First مع ضمان عدم توقف التطبيق
  static Future<RepoResult<T>> fetch<T>({
    required String cacheKey,
    required Future<T> Function() remoteFetcher,
    required T Function(dynamic cachedJson) fromCache,
    required dynamic Function(T data) toCache,
    bool forceRefresh = false,
  }) async {
    final isOnline = await NetworkConnectivityService().checkIsOnline();

    // 1. إذا كان متصلاً بالإنترنت ولم يُطلب فرض الكاش فقط:
    if (isOnline && !forceRefresh) {
      try {
        final remoteData = await remoteFetcher();
        // حفظ في الكاش للمرات القادمة في الخلفية
        try {
          final serializable = toCache(remoteData);
          await LocalCacheService.save(cacheKey, serializable);
        } catch (_) {}

        return RepoSuccess<T>(remoteData);
      } catch (error) {
        // إذا فشل الطلب بالرغم من توفر الاتصال (خطأ شبكة / سيرفر)، نلجأ للكاش المحلي
        final cachedRaw = await LocalCacheService.get(cacheKey);
        if (cachedRaw != null) {
          try {
            final cachedData = fromCache(cachedRaw);
            return RepoCached<T>(cachedData, message: 'تعذر الاتصال بالخادم، يتم عرض البيانات المحفوظة محلياً.');
          } catch (_) {}
        }
        return RepoFailure<T>(AppErrorHandler.handleGeneralError(error), originalError: error);
      }
    }

    // 2. إذا كان المستخدم غير متصل بالإنترنت:
    final cachedRaw = await LocalCacheService.get(cacheKey);
    if (cachedRaw != null) {
      try {
        final cachedData = fromCache(cachedRaw);
        return RepoCached<T>(cachedData, message: 'أنت في وضع عدم الاتصال، يتم عرض البيانات المحفوظة محلياً.');
      } catch (_) {
        return RepoFailure<T>('البيانات المحفوظة محلياً غير صالحة.');
      }
    }

    return RepoFailure<T>('لا يتوفر اتصال بالإنترنت ولا توجد بيانات محفوظة محلياً بعد.');
  }

  /// تنفيذ عملية تعديل أو إضافة (Mutation) مع معالجة الأخطاء
  static Future<RepoResult<T>> mutate<T>({
    required Future<T> Function() action,
    String? successMessage,
  }) async {
    final isOnline = await NetworkConnectivityService().checkIsOnline();
    if (!isOnline) {
      return RepoFailure<T>('لا يتوفر اتصال بالإنترنت لإتمام هذه العملية، يرجى الاتصال بالشبكة والمحاولة مجدداً.');
    }

    try {
      final result = await action();
      return RepoSuccess<T>(result);
    } catch (error) {
      return RepoFailure<T>(AppErrorHandler.handleGeneralError(error), originalError: error);
    }
  }
}
