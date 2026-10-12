import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthFailureException implements Exception {
  final String message;
  final bool isEmailNotConfirmed;

  const AuthFailureException(this.message, {this.isEmailNotConfirmed = false});

  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient _supabase = SupabaseService.client;
  
  // Sign in with email or phone and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      String cleanInput = email.trim().toLowerCase();
      String targetEmail = cleanInput;
      String? fallbackEmail;

      // If user typed a phone number or member number instead of email
      if (!cleanInput.contains('@')) {
        final digitsOnly = cleanInput.replaceAll(RegExp(r'\D'), '');
        final standardPhone = digitsOnly.startsWith('967')
            ? digitsOnly.substring(3)
            : (digitsOnly.startsWith('0') ? digitsOnly.substring(1) : digitsOnly);

        Map<String, dynamic>? profile;
        try {
          profile = await _supabase
              .from('profiles')
              .select('email, phone')
              .or('phone.eq.$cleanInput,phone.eq.$standardPhone,member_number.eq.$cleanInput')
              .maybeSingle();
        } catch (_) {
          // Ignore unauthenticated RLS read errors
        }

        if (profile != null && profile['email'] != null && (profile['email'] as String).isNotEmpty) {
          targetEmail = profile['email'];
          fallbackEmail = 'member_${standardPhone.isNotEmpty ? standardPhone : cleanInput}@takaful.com';
        } else {
          targetEmail = 'member_${standardPhone.isNotEmpty ? standardPhone : cleanInput}@takaful.com';
          fallbackEmail = 'phone_${standardPhone.isNotEmpty ? standardPhone : cleanInput}@association.org';
        }
      }

      AuthResponse response;
      try {
        response = await _supabase.auth.signInWithPassword(
          email: targetEmail,
          password: password,
        );
      } on AuthApiException catch (e) {
        if (fallbackEmail != null &&
            fallbackEmail != targetEmail &&
            (e.code == 'invalid_credentials' || e.message.toLowerCase().contains('invalid'))) {
          response = await _supabase.auth.signInWithPassword(
            email: fallbackEmail,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      final user = response.user;
      if (user != null) {
        try {
          final profile = await _supabase
              .from('profiles')
              .select('status, role')
              .eq('id', user.id)
              .maybeSingle();

          final status = profile?['status']?.toString();
          if (status == 'suspended') {
            await _supabase.auth.signOut();
            throw const AuthFailureException(
              'تم إيقاف وتجميد حسابك من قِبل إدارة الجمعية. يرجى التواصل مع المدير لإعادة تنشيط الحساب.',
            );
          } else if (status == 'pending') {
            await _supabase.auth.signOut();
            throw const AuthFailureException(
              'حسابك بانتظار موافقة وتأكيد المدير. يرجى التواصل مع إدارة الجمعية لتنشيط الحساب.',
            );
          }
        } catch (statusErr) {
          if (statusErr is AuthFailureException) rethrow;
          // Safe catch to ensure login succeeds even if profile query encounters a transient issue
        }
      }

      return response;
    } on AuthApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.code == 'email_not_confirmed' ||
          msg.contains('email_not_confirmed') ||
          msg.contains('email not confirmed')) {
        throw const AuthFailureException(
          'بريدك الإلكتروني غير مؤكد، أو بانتظار تأكيد المدير من داخل التطبيق.',
          isEmailNotConfirmed: true,
        );
      }

      if (e.code == 'invalid_credentials' ||
          msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials') ||
          e.statusCode == '400') {
        throw const AuthFailureException('رقم الهاتف / البريد الإلكتروني أو كلمة المرور غير صحيحة.');
      }

      throw AuthFailureException(e.message.isNotEmpty ? e.message : 'تعذر تسجيل الدخول الآن.');
    } catch (e) {
      if (e is AuthFailureException) rethrow;
      final errorStr = e.toString().replaceAll('Exception: ', '').replaceAll('AuthApiException: ', '');
      if (errorStr.toLowerCase().contains('invalid') || errorStr.toLowerCase().contains('credentials')) {
        throw const AuthFailureException('رقم الهاتف / البريد الإلكتروني أو كلمة المرور غير صحيحة.');
      }
      throw AuthFailureException(errorStr.isNotEmpty ? errorStr : 'تعذر تسجيل الدخول الآن. يرجى التأكد من البيانات.');
    }
  }
  
  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
  
  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // Get current user
  User? get currentUser => _supabase.auth.currentUser;
  
  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
  
  // Get user role
  Future<String?> getUserRole() async {
    if (!isAuthenticated) return null;
    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUser!.id)
          .maybeSingle();
      
      return response?['role'] as String?;
    } catch (e) {
      return 'member';
    }
  }

  // Get full user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }
}