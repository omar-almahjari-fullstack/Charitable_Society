import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static late SupabaseClient _client;
  
  static SupabaseClient get client => _client;
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }
  
  // ============================================================
  // ✅ GETTERS - إصدار يعمل على جميع الإصدارات
  // ============================================================
  
  static SupabaseClient get supabase => _client;
  
  static SupabaseQueryBuilder from(String table) => _client.from(table);
  
  // ✅ استخدم dynamic - هذا هو الحل الوحيد الذي يعمل على جميع الإصدارات
  static dynamic get storage => _client.storage;
  
  static dynamic get realtime => _client.realtime;
  
  // ============================================================
  // ✅ AUTH - إصدار يعمل على جميع الإصدارات
  // ============================================================
  
  static dynamic get auth => _client.auth;
  
  static User? get currentUser => _client.auth.currentUser;
  
  static Session? get currentSession => _client.auth.currentSession;
  
  static bool get isAuthenticated => currentUser != null;
  
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }
  
  static Future<String?> getCurrentUserRole() async {
    final profile = await getCurrentUserProfile();
    return profile?['role'] as String?;
  }
  
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}