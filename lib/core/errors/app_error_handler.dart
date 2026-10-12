import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// APP ERROR HANDLER & ARABIC TRANSLATION SERVICE
// نظام إدارة الأخطاء ورسائل التنبيه المهذبة باللغة العربية
// ============================================================

class AppErrorHandler {
  /// 1. معالج أخطاء المصادقة وتسجيل الدخول (Auth Error Handler)
  static String handleAuthError(dynamic error) {
    if (error == null) return 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.';

    final errorStr = error.toString().toLowerCase();

    // عدم وجود اتصال بالإنترنت
    if (error is SocketException ||
        errorStr.contains('socketexception') ||
        errorStr.contains('network') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('clientexception')) {
      return 'لا يتوفر اتصال بالإنترنت، يرجى التأكد من تشغيل الواي فاي أو بيانات الهاتف والمحاولة مجدداً.';
    }

    // انتهاء المهلة
    if (error is TimeoutException || errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'استغرق الخادم وقتاً طويلاً للاستجابة، تحقق من جودة الاتصال وحاول مجدداً.';
    }

    // أخطاء Supabase Auth
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final code = error.statusCode?.toString() ?? '';

      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials') ||
          msg.contains('wrong password') ||
          msg.contains('user not found')) {
        return 'اسم المستخدم أو كلمة المرور غير صحيحة، يرجى التحقق وإعادة المحاولة.';
      }
      if (msg.contains('email not confirmed')) {
        return 'الحساب غير مفعّل بعد، يرجى التواصل مع إدارة الجمعية لتفعيل حسابك.';
      }
      if (msg.contains('user already registered') || msg.contains('already exists')) {
        return 'رقم الهاتف أو البريد الإلكتروني مسجل بالفعل لحساب آخر.';
      }
      if (msg.contains('rate limit') || code == '429') {
        return 'تم تجاوز الحد المسموح من المحاولات، يرجى الانتظار دقيقة والمحاولة مجدداً.';
      }
      if (msg.contains('session expired') || msg.contains('jwt expired') || msg.contains('invalid claim')) {
        return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.';
      }
      if (msg.contains('password is too short') || msg.contains('weak password')) {
        return 'كلمة المرور ضعيفة جداً، يرجى إدخال كلمة مرور مكونة من 6 خانات على الأقل.';
      }
    }

    // استخدام الحساب في جهاز آخر
    if (errorStr.contains('session_conflict') ||
        errorStr.contains('already in use') ||
        errorStr.contains('multiple_devices')) {
      return 'الحساب قيد الاستخدام حالياً على جهاز آخر.';
    }

    // انتهاء الجلسة
    if (errorStr.contains('unauthorized') ||
        errorStr.contains('jwt') ||
        errorStr.contains('401') ||
        errorStr.contains('expired')) {
      return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.';
    }

    // خطأ عام مهذب
    return 'اسم المستخدم أو كلمة المرور غير صحيحة، يرجى التحقق وإعادة المحاولة.';
  }

  /// 2. معالج الأخطاء العامة لطلبات الشبكة وقاعدة البيانات (Global Exception Handler)
  static String handleGeneralError(dynamic error, {String fallback = 'حدث خطأ غير متوقع أثناء معالجة الطلب، يرجى المحاولة لاحقاً.'}) {
    if (error == null) return fallback;

    // معالجة نصوص الاستثناءات الصريحة
    if (error is Exception) {
      final text = error.toString().replaceAll('Exception: ', '').trim();
      // إذا كان الاستثناء مكتوباً بالعربية مباشرة من الخدمة، نعرضه للمستخدم
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(text) && !text.contains('PostgrestException')) {
        return text;
      }
    }

    final errorStr = error.toString().toLowerCase();

    // انقطاع الشبكة
    if (error is SocketException ||
        errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('clientexception')) {
      return 'لا يتوفر اتصال بالإنترنت، يرجى التحقق من الشبكة وإعادة المحاولة.';
    }

    // بطء الاتصال والمهلة
    if (error is TimeoutException || errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'استغرق الخادم وقتاً طويلاً للاستجابة، تحقق من جودة الاتصال وحاول مجدداً.';
    }

    // استثناءات PostgREST و Supabase
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final msg = error.message.toLowerCase();

      if (code == '23505' || msg.contains('unique constraint')) {
        return 'هذا السجل مضاف مسبقاً في النظام ولا يمكن تكراره.';
      }
      if (code == '23503' || msg.contains('foreign key')) {
        return 'البيانات المرتبطة غير متوفرة أو تم حذفها مسبقاً.';
      }
      if (code == '42501' || msg.contains('permission denied') || msg.contains('rls')) {
        return 'ليس لديك الصلاحية الكافية لإتمام هذا الإجراء.';
      }
      if (code == 'PGRST116' || msg.contains('single json object')) {
        return 'لم يتم العثور على البيانات المطلوبة.';
      }
    }

    return fallback;
  }

  /// 3. رسائل النجاح الثابتة الموحدة
  static const String loginSuccessMessage = 'تم تسجيل الدخول بنجاح، مرحباً بك! 🌿';
  static const String logoutSuccessMessage = 'تم تسجيل الخروج بنجاح.';
  static const String offlineModeActiveMessage = 'أنت تعمل حالياً في وضع عدم الاتصال، يتم عرض البيانات المحفوظة محلياً.';
  static const String onlineRestoredMessage = 'تم استعادة الاتصال بالإنترنت وتحديث البيانات بنجاح. ✅';
  static const String emptyFieldsMessage = 'يرجى إدخال اسم المستخدم وكلمة المرور للمتابعة.';
}
