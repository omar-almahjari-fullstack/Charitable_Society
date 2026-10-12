import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/storage/local_cache_service.dart';

// Auth state
class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? userRole;
  final Map<String, dynamic>? userProfile;
  final bool isLoading;

  AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.userRole,
    this.userProfile,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? userRole,
    Map<String, dynamic>? userProfile,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
      userProfile: userProfile ?? this.userProfile,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Auth provider
class AuthProvider extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthProvider(this._authService) : super(AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      if (_authService.isAuthenticated) {
        final user = _authService.currentUser;
        if (user != null) {
          final role = await _authService.getUserRole();
          final profile = await _getUserProfile(user.id);
          
          state = state.copyWith(
            isAuthenticated: true,
            userId: user.id,
            userRole: role ?? 'member',
            userProfile: profile,
          );
          return;
        }
      }
    } catch (e) {
      // Intentionally handle any initial auth checks
    }
    state = AuthState(isAuthenticated: false);
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final profile = await _authService.getUserProfile(userId);
      if (profile != null) {
        try {
          await LocalCacheService.save('cached_user_profile_$userId', profile);
        } catch (_) {}
        return profile;
      }
    } catch (e) {
      // عند انقطاع الاتصال، جلب الملف الشخصي من الكاش المحلي
      try {
        final cached = await LocalCacheService.get('cached_user_profile_$userId');
        if (cached is Map) {
          return Map<String, dynamic>.from(cached);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> refreshProfile() async {
    try {
      final user = _authService.currentUser;
      if (_authService.isAuthenticated && user != null) {
        final role = await _authService.getUserRole();
        final profile = await _getUserProfile(user.id);
        state = state.copyWith(
          userRole: role ?? 'member',
          userProfile: profile,
        );
      }
    } catch (e) {
      // Intentionally safe catch
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      
      final user = response.user;
      if (user != null) {
        final role = await _authService.getUserRole();
        final profile = await _getUserProfile(user.id);
        state = state.copyWith(
          isAuthenticated: true,
          userId: user.id,
          userRole: role ?? 'member',
          userProfile: profile,
          isLoading: false,
        );

        AuditService.logAuth(
          action: 'LOGIN_SUCCESS',
          status: 'SUCCESS',
          email: email,
          userId: user.id,
        );

        return null;
      }
      state = state.copyWith(isLoading: false);

      AuditService.logAuth(
        action: 'LOGIN_FAILED',
        status: 'FAILED',
        email: email,
        errorMessage: 'تعذر الحصول على بيانات المستخدم',
      );

      return 'تعذر الحصول على بيانات المستخدم';
    } catch (e) {
      state = state.copyWith(isLoading: false);
      final errorMsg = AppErrorHandler.handleAuthError(e);

      AuditService.logAuth(
        action: 'LOGIN_FAILED',
        status: 'FAILED',
        email: email,
        errorMessage: errorMsg,
      );

      return errorMsg;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _authService.signUpWithEmail(
        email: email,
        password: password,
        userData: {
          'full_name': fullName,
          'phone': phone,
          'role': 'member',
        },
      );

      AuditService.logAuth(
        action: 'REGISTER_SUCCESS',
        status: 'SUCCESS',
        email: email,
        userId: res.user?.id,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);

      AuditService.logAuth(
        action: 'REGISTER_FAILED',
        status: 'FAILED',
        email: email,
        errorMessage: e.toString(),
      );

      rethrow;
    }
  }

  Future<void> signOut() async {
    final currentUserId = state.userId;
    state = state.copyWith(isLoading: true);
    try {
      if (currentUserId != null) {
        AuditService.logAuth(
          action: 'LOGOUT',
          status: 'SUCCESS',
          userId: currentUserId,
        );
      }
      await _authService.signOut();
    } catch (e) {
      // Ignore network errors on sign out so session is always cleared locally
    } finally {
      state = AuthState(
        isAuthenticated: false,
        userId: null,
        userRole: null,
        userProfile: null,
        isLoading: false,
      );
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

// Provider instance
final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider(AuthService());
});